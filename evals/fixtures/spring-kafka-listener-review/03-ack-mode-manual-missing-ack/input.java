// pom.xml: spring-boot 3.3.4, spring-kafka 3.2.4. Container factory uses AckMode.MANUAL.
package com.example.inventory;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class InventoryListener {

    private final InventoryService inventory;

    public InventoryListener(InventoryService inventory) {
        this.inventory = inventory;
    }

    @KafkaListener(topics = "inventory-updates", groupId = "inventory-svc",
                   containerFactory = "manualAckKafkaListenerContainerFactory")
    public void onUpdate(ConsumerRecord<String, String> record, Acknowledgment ack) {
        if (record.value() == null || record.value().isBlank()) {
            // Early return without ack — offset never committed, record redelivered forever
            return;
        }
        inventory.apply(record.value());
        ack.acknowledge();
    }
}
