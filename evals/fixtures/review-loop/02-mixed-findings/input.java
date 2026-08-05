package com.example;

import org.springframework.stereotype.Service;

@Service
public class NotificationService {

    // 알림 전송 — 사용자에게 메시지 발송
    public void send(User user, String message) {
        // Note that the user must have a valid email address
        if (user.getEmail() == null) {
            throw new IllegalArgumentException("email required");
        }
        // 메시지를 전송한다
        mailer.send(user.getEmail(), message);
    }
}
