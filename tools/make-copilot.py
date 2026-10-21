#!/usr/bin/env python3
"""Claude Code 用の定義(.claude/agents と CLAUDE.md)から、GitHub Copilot 用のファイルを作る。

作るもの:
  .github/agents/<名前>.agent.md     … カスタムエージェント(13 人)
  .github/copilot-instructions.md    … リポジトリ全体の指示
直すときは .claude/agents と CLAUDE.md を直して、このスクリプトを動かし直す(作ったファイルを手で直さない)。
スキル(.claude/skills)は Copilot がそのまま読むので写さない。hooks は .github/hooks に手で書いた設定から .claude/hooks を呼ぶ。

使い方: python3 tools/make-copilot.py           … 作る
        python3 tools/make-copilot.py --check   … 作り直すと差が出るなら 1 で終わる(CI 用)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_AGENTS = ROOT / ".claude" / "agents"
OUT_AGENTS = ROOT / ".github" / "agents"
SRC_CLAUDE_MD = ROOT / "CLAUDE.md"
OUT_INSTRUCTIONS = ROOT / ".github" / "copilot-instructions.md"

GENERATED = "<!-- このファイルは tools/make-copilot.py が {src} から作ったもの。直すときは元を直して作り直す。 -->"

COPILOT_END = """## 終わるとき
- 報告の最後に、変更したファイル、確かめたこと、確かめていないことを書く。
- 使用量は数えなくてよい(GitHub Copilot の使用量は、組織の使用状況メトリクスと AI クレジットの請求で見る。cs-cost は Claude Code 専用)。"""


def split_frontmatter(text: str):
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        raise SystemExit("frontmatter がありません")
    return m.group(1), m.group(2)


def fm_value(fm: str, key: str):
    m = re.search(rf"^{key}: (.*)$", fm, re.M)
    return m.group(1).strip() if m else None


def fm_list(fm: str, key: str):
    m = re.search(rf"^{key}:\n((?:  - .*\n?)+)", fm + "\n", re.M)
    if not m:
        return []
    return [line.strip()[2:].strip() for line in m.group(1).strip("\n").split("\n")]


def yaml_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def make_agent(src: Path) -> str:
    fm, body = split_frontmatter(src.read_text(encoding="utf-8"))
    name, desc, tools = fm_value(fm, "name"), fm_value(fm, "description"), fm_value(fm, "tools")
    skills = [s for s in fm_list(fm, "skills") if s != "cs-cost"]
    # Claude Code の道具の名前(Read、Edit、Bash など)は、Copilot も同じ働きの別名として受け付ける(公式 Custom agents configuration の Tool aliases)
    tool_list = ", ".join(yaml_str(t.strip()) for t in tools.split(",")) if tools else None
    lines = ["---", f"name: {name}", f"description: {yaml_str(desc)}"]
    if tool_list:
        lines.append(f"tools: [{tool_list}]")
    lines.append("---")
    out = "\n".join(lines) + "\n" + GENERATED.format(src=f".claude/agents/{src.name}") + "\n"
    if skills:
        # Copilot のカスタムエージェントには、手順書を先に読み込む項目(Claude Code の skills:)が無いので、本文で読ませる
        out += "\n## 最初に読む手順書\n作業を始める前に、次の手順書を読んで、その順番に沿って進める。\n"
        out += "".join(f"- `.claude/skills/{s}/SKILL.md`\n" for s in skills)
    body = body.lstrip("\n")
    # Claude Code の会話の記録を数える cs-cost は Copilot では使えないので、「終わるとき」を差し替える
    body, n = re.subn(r"## 終わるとき\n(?:- .*\n?)+", COPILOT_END + "\n", body)
    if n != 1:
        raise SystemExit(f"{src.name}: 「## 終わるとき」の節が見つかりません")
    return out + "\n" + body.rstrip("\n") + "\n"


INSTRUCTION_EDITS = [
    ("# CLAUDE.md\n", "# GitHub Copilot への指示\n\n" + GENERATED.format(src="CLAUDE.md") + "\n"),
    (
        r"- 依頼を 1 件終えて報告する直前に、毎回 cs-cost の手順で .*\n",
        "- 報告の最後に、変更したファイル、確かめたこと、確かめていないことを書く。\n",
    ),
    (r"- コストの集計: .*\n", ""),
    ("## 仕組みで止めていること(.claude/hooks)\n", "## 仕組みで止めていること(.claude/hooks。Copilot は .github/hooks/cs-hooks.json から同じスクリプトを呼ぶ)\n"),
    ("## 担当の分け方(.claude/agents)\n", "## 担当の分け方(.github/agents。手順書は .claude/skills)\n"),
]


def make_instructions() -> str:
    text = SRC_CLAUDE_MD.read_text(encoding="utf-8")
    for pat, rep in INSTRUCTION_EDITS:
        text, n = re.subn(pat if pat.startswith("-") else re.escape(pat), lambda _m: rep, text, count=1)
        if n != 1:
            raise SystemExit(f"CLAUDE.md に、置き換える箇所が見つかりません: {pat[:40]}")
    return text


def main():
    check = "--check" in sys.argv
    want = {OUT_AGENTS / (p.stem + ".agent.md"): make_agent(p) for p in sorted(SRC_AGENTS.glob("*.md"))}
    want[OUT_INSTRUCTIONS] = make_instructions()
    stale = [p for p in OUT_AGENTS.glob("*.agent.md") if p not in want] if OUT_AGENTS.exists() else []
    diff = [p for p, t in want.items() if not p.exists() or p.read_text(encoding="utf-8") != t]
    if check:
        for p in diff + stale:
            print(f"作り直しが必要: {p.relative_to(ROOT)}")
        print("Copilot 用のファイル: " + ("最新" if not (diff or stale) else f"{len(diff) + len(stale)} 件が古い(python3 tools/make-copilot.py を動かす)"))
        sys.exit(1 if diff or stale else 0)
    OUT_AGENTS.mkdir(parents=True, exist_ok=True)
    for p, t in want.items():
        p.write_text(t, encoding="utf-8", newline="\n")
    for p in stale:
        p.unlink()
    print(f"作った: エージェント {len(want) - 1} 本、copilot-instructions.md")


if __name__ == "__main__":
    main()
