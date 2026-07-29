import { Controller, Get, Injectable, Module } from "@nestjs/common";

@Injectable()
export class PaymentsService {
  charge(amount: number) {
    return { ok: true, amount };
  }
}

@Module({
  providers: [PaymentsService],
  // exports omitted — PaymentsService is internal to PaymentsModule only.
})
export class PaymentsModule {}

@Controller("checkout")
export class CheckoutController {
  constructor(private readonly payments: PaymentsService) {}

  @Get()
  buy() {
    return this.payments.charge(100);
  }
}

@Module({
  imports: [PaymentsModule],
  controllers: [CheckoutController],
})
export class CheckoutModule {}
