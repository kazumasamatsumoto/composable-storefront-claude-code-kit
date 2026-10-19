import { HttpClient } from '@angular/common/http';
export class BadComponent {
  constructor(private http: HttpClient) {}
  load() {
    return this.http.get('https://api.example.com/occ/v2/electronics/products/1?fields=FULL');
  }
}
