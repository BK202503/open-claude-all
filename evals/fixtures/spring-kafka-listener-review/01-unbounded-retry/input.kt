// build.gradle.kts: org.springframework.boot 3.3.4, org.springframework.kafka:spring-kafka 3.2.4
package com.example.orders

import org.apache.kafka.clients.consumer.ConsumerRecord
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.listener.DefaultErrorHandler
import org.springframework.stereotype.Component
import org.springframework.util.backoff.FixedBackOff

@Configuration
class KafkaErrorHandlerConfig {
    @Bean
    fun defaultErrorHandler(): DefaultErrorHandler {
        // interval=1000ms, maxAttempts defaults to Long.MAX_VALUE → unbounded retry
        return DefaultErrorHandler(FixedBackOff(1000L, Long.MAX_VALUE))
    }
}

@Component
class OrderListener(private val orderService: OrderService) {
    @KafkaListener(topics = ["orders"], groupId = "order-svc")
    fun onOrder(record: ConsumerRecord<String, String>) {
        orderService.process(record.value())
    }
}
