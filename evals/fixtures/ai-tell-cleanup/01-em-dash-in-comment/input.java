package com.example;

import org.springframework.stereotype.Service;

@Service
public class OrderService {

    // 주문 처리 — 재고 확인 후 결제 진행
    public void process(Order order) {
        // 재고 확인 — DB 조회
        boolean inStock = inventory.check(order.getItemId());
        if (!inStock) {
            throw new OutOfStockException("item not available — please retry later");
        }
        payment.charge(order);
    }
}
