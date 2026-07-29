package com.example.orders

import java.sql.Connection
import org.springframework.stereotype.Service

@Service
class OrderPoller(private val db: Connection) {

    suspend fun waitForNextOrder(): Order? {
        Thread.sleep(500)
        val stmt = db.prepareStatement("SELECT id, total FROM orders WHERE status = 'NEW' LIMIT 1")
        val rs = stmt.executeQuery()
        return if (rs.next()) Order(rs.getLong("id"), rs.getBigDecimal("total")) else null
    }
}

data class Order(val id: Long, val total: java.math.BigDecimal)
