package com.example;

public class PaymentValidator {

    public void validate(Payment payment) {
        // Note that the amount must be positive
        if (payment.getAmount() <= 0) {
            throw new IllegalArgumentException("amount must be positive");
        }

        // This ensures that the currency code is not null
        if (payment.getCurrency() == null) {
            throw new IllegalArgumentException("currency required");
        }

        // It is worth noting that we check the card expiry here
        // in order to prevent processing expired cards
        if (payment.getCard().isExpired()) {
            throw new IllegalArgumentException("card expired");
        }

        // Please note that the CVV field is required for online payments
        if (payment.getCvv() == null) {
            throw new IllegalArgumentException("cvv required");
        }
    }
}
