// build.gradle.kts: spring-boot 3.3.4, spring-kafka 3.3.1 (suspend @KafkaListener requires 3.3+)
package com.example.notifications

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.stereotype.Component

@Component
class NotificationListener(
    private val sender: NotificationSender,
) {
    private val bg = CoroutineScope(Dispatchers.IO)

    @KafkaListener(topics = ["notifications"], groupId = "notification-svc")
    suspend fun onNotify(record: ConsumerRecord<String, String>) {
        // Fire-and-forget on an external scope — parent suspend fun returns
        // immediately, container acks the offset, but sender.send() may not
        // have completed (or may fail). Silent loss on crash / restart.
        bg.launch {
            sender.send(record.value())
        }
    }
}
