import { Injectable } from '@angular/core';
import { WindowRef } from '@spartacus/core';
@Injectable({ providedIn: 'root' })
export class RecentlyViewedService {
  constructor(protected winRef: WindowRef) {}
  save(code: string) {
    if (this.winRef.isBrowser()) {
      this.winRef.localStorage?.setItem('recentlyViewed', code);
      this.winRef.nativeWindow?.scrollTo(0, 0);
    }
  }
}
