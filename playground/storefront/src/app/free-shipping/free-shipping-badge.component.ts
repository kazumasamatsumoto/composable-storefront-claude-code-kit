import { ChangeDetectionStrategy, Component } from '@angular/core';
import { Product } from '@spartacus/core';
import { CurrentProductService } from '@spartacus/storefront';
import { Observable } from 'rxjs';

/**
 * 練習用の出発点(ビルドはできません)。
 * 課題: 送料無料の対象商品だけ、価格の下に「送料無料」を出す。
 * OCC の商品の応答には、まだ「送料無料の対象か」を表す項目がありません。
 */
@Component({
  selector: 'app-free-shipping-badge',
  templateUrl: './free-shipping-badge.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class FreeShippingBadgeComponent {
  product$: Observable<Product | null> = this.currentProductService.getProduct();

  constructor(protected currentProductService: CurrentProductService) {}
}
