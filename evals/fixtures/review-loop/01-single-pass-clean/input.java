package com.example;

import org.springframework.stereotype.Service;

@Service
public class InvoiceService {

    // 인보이스 생성 — 금액 계산 후 저장
    public Invoice create(Order order) {
        // 금액을 계산한다
        long amount = order.getItems().stream()
                .mapToLong(Item::getPrice)
                .sum();
        // 인보이스를 저장한다
        return repository.save(new Invoice(order.getId(), amount));
    }
}
