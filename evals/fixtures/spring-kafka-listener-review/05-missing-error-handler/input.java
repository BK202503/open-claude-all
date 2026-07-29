// pom.xml: spring-boot 3.3.4, spring-kafka 3.2.4. No CommonErrorHandler / DefaultErrorHandler wired anywhere.
package com.example.audit;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class AuditListener {

    private final AuditService audit;

    public AuditListener(AuditService audit) {
        this.audit = audit;
    }

    @KafkaListener(topics = "audit-events", groupId = "audit-svc")
    public void onEvent(ConsumerRecord<String, String> record) {
        // No @Bean CommonErrorHandler exists in this module. Any RuntimeException
        // here falls through to the container's default handler, which logs and
        // drops the record. Poison messages silently disappear from the audit
        // stream — the exact opposite of what "audit" implies.
        audit.record(record.value());
    }
}
