import { Controller, Get, Injectable, Module, Scope } from "@nestjs/common";

@Injectable({ scope: Scope.REQUEST })
export class TenantContext {
  private tenantId?: string;
  set(id: string) {
    this.tenantId = id;
  }
  get() {
    return this.tenantId;
  }
}

@Controller("orders")
export class OrdersController {
  constructor(private readonly tenant: TenantContext) {}

  @Get()
  list() {
    return { tenant: this.tenant.get(), items: [] };
  }
}

@Module({
  controllers: [OrdersController],
  providers: [TenantContext],
})
export class OrdersModule {}
