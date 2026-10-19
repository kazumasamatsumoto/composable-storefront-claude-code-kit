import { CurrentProductService } from '@spartacus/storefront';
export class GoodComponent {
  product$ = this.currentProductService.getProduct();
  constructor(protected currentProductService: CurrentProductService) {}
}
