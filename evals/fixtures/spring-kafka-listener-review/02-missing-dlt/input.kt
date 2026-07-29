// build.gradle.kts: org.springframework.boot 3.3.4, org.springframework.kafka:spring-kafka 3.2.4
package com.example.payments

import org.apache.kafka.clients.consumer.ConsumerRecord
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.listener.DefaultErrorHandler
import org.springframework.stereotype.Component
import org.springframework.util.backoff.FixedBackOff

@Configuration
class PaymentErrorHandlerConfig {
    @Bean
    fun defaultErrorHandler(): DefaultErrorHandler {
        // Bounded retries (good), but no DeadLetterPublishingRecoverer passed.
        // After 3 failed attempts the record is logged and silently dropped.
        return DefaultErrorHandler(FixedBackOff(500L, 3L))
    }
}

@Component
class PaymentListener(private val payments: PaymentService) {
    @KafkaListener(topics = ["payments"], groupId = "payment-svc")
    fun onPayment(record: ConsumerRecord<String, String>) {
        payments.charge(record.value())
    }
}
