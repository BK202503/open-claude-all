package com.example.report

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.springframework.stereotype.Service
import java.security.MessageDigest

@Service
class ReportHasher {

    suspend fun hashLargePayload(payload: ByteArray): String = withContext(Dispatchers.IO) {
        val md = MessageDigest.getInstance("SHA-256")
        var acc = md.digest(payload)
        repeat(200_000) {
            acc = md.digest(acc)
        }
        acc.joinToString("") { "%02x".format(it) }
    }
}
