import { Injectable } from '@angular/core';
@Injectable({ providedIn: 'root' })
export class RecentlyViewedService {
  save(code: string) {
    localStorage.setItem('recentlyViewed', code);
    window.scrollTo(0, 0);
  }
}
