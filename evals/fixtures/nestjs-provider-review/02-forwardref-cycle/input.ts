import { forwardRef, Inject, Injectable, Module } from "@nestjs/common";

@Injectable()
export class UsersService {
  constructor(
    @Inject(forwardRef(() => OrdersService))
    private readonly orders: OrdersService,
  ) {}

  getOrdersFor(userId: string) {
    return this.orders.listByUser(userId);
  }
}

@Injectable()
export class OrdersService {
  constructor(
    @Inject(forwardRef(() => UsersService))
    private readonly users: UsersService,
  ) {}

  listByUser(userId: string) {
    return [{ userId, total: 0 }];
  }
}

@Module({
  providers: [UsersService],
  exports: [UsersService],
  imports: [forwardRef(() => OrdersModule)],
})
export class UsersModule {}

@Module({
  providers: [OrdersService],
  exports: [OrdersService],
  imports: [forwardRef(() => UsersModule)],
})
export class OrdersModule {}
