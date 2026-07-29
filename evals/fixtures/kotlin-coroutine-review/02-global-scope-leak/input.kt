package com.example.notifications

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import org.springframework.stereotype.Component

@Component
class NotificationDispatcher(private val client: EmailClient) {

    fun sendWelcome(userId: Long, email: String) {
        GlobalScope.launch {
            client.send(email, "Welcome!")
            recordSent(userId)
        }
    }

    fun sendReceipt(userId: Long, email: String, pdfBytes: ByteArray) {
        CoroutineScope(Dispatchers.IO).launch {
            client.sendAttachment(email, "Receipt", pdfBytes)
            recordSent(userId)
        }
    }

    private fun recordSent(userId: Long) { /* ... */ }
}

interface EmailClient {
    suspend fun send(to: String, subject: String)
    suspend fun sendAttachment(to: String, subject: String, bytes: ByteArray)
}
