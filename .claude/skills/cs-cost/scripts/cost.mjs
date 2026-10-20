#!/usr/bin/env node
// Claude Code の会話記録(~/.claude/projects/<フォルダ>/<会話>.jsonl とサブエージェントの記録)から
// トークン数を数え、rates.json の単価で API 料金に換算する。記録は読むだけで書き換えない。
// 使い方: node .claude/skills/cs-cost/scripts/cost.mjs [--label "依頼の名前"] [--session <会話ID>]
//         [--log <CSV のパス>] [--no-log] [--project-dir <パス>] [--json]
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : def;
};
const has = (name) => args.includes(name);

const projectDir = path.resolve(opt("--project-dir", process.env.CLAUDE_PROJECT_DIR || process.cwd()));
const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
const projectsDir = path.join(configDir, "projects");
const rates = JSON.parse(fs.readFileSync(opt("--rates", path.join(here, "..", "rates.json")), "utf8"));
const logPath = path.resolve(projectDir, opt("--log", "docs/cost-log.csv"));
const label = opt("--label", "");

function fail(msg) {
  console.error(`cs-cost: ${msg}`);
  process.exit(1);
}

// 会話記録のフォルダ名は、作業フォルダのパスの英数字以外を - にしたもの。違っていれば cwd の記録で探す。
function findSessionFolder() {
  if (!fs.existsSync(projectsDir)) fail(`${projectsDir} がありません`);
  const guess = path.join(projectsDir, projectDir.replace(/[^A-Za-z0-9]/g, "-"));
  if (fs.existsSync(guess)) return guess;
  for (const d of fs.readdirSync(projectsDir)) {
    const dir = path.join(projectsDir, d);
    for (const f of jsonlFiles(dir)) {
      const head = fs.readFileSync(f, "utf8").split("\n", 50);
      if (head.some((l) => l.includes(`"cwd":${JSON.stringify(projectDir)}`))) return dir;
    }
  }
  fail(`${projectDir} の会話記録が ${projectsDir} に見つかりません`);
}

function jsonlFiles(dir) {
  try {
    return fs.readdirSync(dir).filter((f) => f.endsWith(".jsonl")).map((f) => path.join(dir, f));
  } catch {
    return [];
  }
}

// 1 つの記録ファイルの使用量を、モデルごとに足す。同じ応答は複数行に分かれて書かれるので、応答 ID で 1 回だけ数える。
function readUsage(file) {
  const byId = new Map();
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    if (!line.includes('"usage"')) continue;
    let d;
    try {
      d = JSON.parse(line);
    } catch {
      continue;
    }
    const m = d.message;
    if (d.type !== "assistant" || !m || !m.usage || m.model === "<synthetic>") continue;
    byId.set(m.id || d.uuid, { model: m.model, u: m.usage });
  }
  const sums = {};
  for (const { model, u } of byId.values()) {
    const key = model + (u.speed === "fast" ? " (fast)" : "");
    const s = (sums[key] ??= { model, fast: u.speed === "fast", calls: 0, input: 0, cw5m: 0, cw1h: 0, read: 0, output: 0 });
    const cc = u.cache_creation;
    const cw = u.cache_creation_input_tokens || 0;
    const cw1h = cc ? cc.ephemeral_1h_input_tokens || 0 : 0;
    s.calls += 1;
    s.input += u.input_tokens || 0;
    s.cw1h += cw1h;
    s.cw5m += cc ? cc.ephemeral_5m_input_tokens || 0 : cw - cw1h;
    s.read += u.cache_read_input_tokens || 0;
    s.output += u.output_tokens || 0;
  }
  return sums;
}

// モデル名の末尾の日付(-20251001 など)は外して単価表を引く。
function rateFor(model) {
  return rates.models[model] || rates.models[model.replace(/-\d{8}$/, "")] || null;
}

function usd(s) {
  const r = rateFor(s.model);
  if (!r) return null;
  const k = s.fast ? r.fast || 1 : 1;
  return (k * (s.input * r.input + s.cw5m * r.cache_write_5m + s.cw1h * r.cache_write_1h + s.read * r.cache_read + s.output * r.output)) / 1e6;
}

const folder = findSessionFolder();
let mainFile;
if (opt("--session")) {
  mainFile = path.join(folder, `${opt("--session")}.jsonl`);
  if (!fs.existsSync(mainFile)) fail(`${mainFile} がありません`);
} else {
  // 今の会話は今も書き込まれているので、いちばん新しい記録を今の会話とみなす。
  mainFile = jsonlFiles(folder).sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0];
  if (!mainFile) fail(`${folder} に会話記録がありません`);
}
const sessionId = path.basename(mainFile, ".jsonl");

// 担当(サブエージェント)の記録は <会話ID>/subagents/agent-*.jsonl。種類は同じ名前の .meta.json に入っている。
const groups = [{ who: "本会話", sums: readUsage(mainFile) }];
const subDir = path.join(folder, sessionId, "subagents");
const byType = {};
for (const f of jsonlFiles(subDir)) {
  let type = "(種類不明)";
  try {
    type = JSON.parse(fs.readFileSync(f.replace(/\.jsonl$/, ".meta.json"), "utf8")).agentType || type;
  } catch {}
  const g = (byType[type] ??= { who: `担当 ${type}`, runs: 0, sums: {} });
  g.runs += 1;
  for (const [k, s] of Object.entries(readUsage(f))) {
    const t = (g.sums[k] ??= { ...s, calls: 0, input: 0, cw5m: 0, cw1h: 0, read: 0, output: 0 });
    for (const n of ["calls", "input", "cw5m", "cw1h", "read", "output"]) t[n] += s[n];
  }
}
groups.push(...Object.values(byType).sort((a, b) => a.who.localeCompare(b.who)));

const rows = [];
const total = { calls: 0, input: 0, cw: 0, read: 0, output: 0, usd: 0 };
const unknown = new Set();
for (const g of groups) {
  for (const s of Object.values(g.sums)) {
    const c = usd(s);
    if (c === null) unknown.add(s.model);
    rows.push({ who: g.who + (g.runs ? `(${g.runs} 回)` : ""), model: s.model + (s.fast ? " (fast)" : ""), calls: s.calls, input: s.input, cw: s.cw5m + s.cw1h, read: s.read, output: s.output, usd: c });
    total.calls += s.calls;
    total.input += s.input;
    total.cw += s.cw5m + s.cw1h;
    total.read += s.read;
    total.output += s.output;
    total.usd += c || 0;
  }
}

// 前回の記録(同じ会話の最後の行)との差が、この依頼 1 件の分。
let prev = null;
if (fs.existsSync(logPath)) {
  for (const line of fs.readFileSync(logPath, "utf8").trim().split("\n").slice(1)) {
    const c = line.split(",");
    if (c[1] === sessionId) prev = { calls: +c[3], input: +c[4], cw: +c[5], read: +c[6], output: +c[7], usd: +c[8] };
  }
}
const delta = {};
for (const k of Object.keys(total)) delta[k] = total[k] - (prev ? prev[k] : 0);

if (!has("--no-log")) {
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  if (!fs.existsSync(logPath)) fs.writeFileSync(logPath, "日時,会話ID,依頼,呼び出し,入力,キャッシュ書き込み,キャッシュ読み込み,出力,累計USD,今回USD\n");
  const cell = (v) => `"${String(v).replace(/"/g, '""').replace(/[\r\n]+/g, " ")}"`;
  fs.appendFileSync(logPath, [new Date().toISOString(), sessionId, cell(label), total.calls, total.input, total.cw, total.read, total.output, total.usd.toFixed(4), delta.usd.toFixed(4)].join(",") + "\n");
}

if (has("--json")) {
  console.log(JSON.stringify({ sessionId, label, rows, total, delta, unknownModels: [...unknown], rates: { source: rates.source, checked: rates.checked } }, null, 2));
  process.exit(0);
}

const n = (v) => v.toLocaleString("en-US");
const m = (v) => (v === null ? "単価なし" : `$${v.toFixed(2)}`);
const out = [];
out.push(`### コスト(API 料金に換算。単価は ${rates.checked} 時点の公式料金表)`);
out.push("");
out.push("| 区分 | モデル | 呼び出し | 入力 | キャッシュ書き込み | キャッシュ読み込み | 出力 | 金額 |");
out.push("|---|---|---:|---:|---:|---:|---:|---:|");
for (const r of rows) out.push(`| ${r.who} | ${r.model} | ${n(r.calls)} | ${n(r.input)} | ${n(r.cw)} | ${n(r.read)} | ${n(r.output)} | ${m(r.usd)} |`);
out.push(`| **会話の累計** | | ${n(total.calls)} | ${n(total.input)} | ${n(total.cw)} | ${n(total.read)} | ${n(total.output)} | **${m(total.usd)}** |`);
out.push(`| **今回の依頼${label ? `(${label})` : ""}** | ${prev ? "前回の記録から" : "記録なし(会話の初めから)"} | ${n(delta.calls)} | ${n(delta.input)} | ${n(delta.cw)} | ${n(delta.read)} | ${n(delta.output)} | **${m(delta.usd)}** |`);
out.push("");
out.push(`会話 ID: ${sessionId}${has("--no-log") ? "" : ` / 記録: ${path.relative(projectDir, logPath) || logPath}`}`);
if (unknown.size) out.push(`rates.json に単価が無いモデル(金額に入っていない): ${[...unknown].join(", ")}`);
console.log(out.join("\n"));
