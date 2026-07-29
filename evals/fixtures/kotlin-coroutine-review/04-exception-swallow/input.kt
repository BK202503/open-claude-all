package com.example.sync

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import org.slf4j.LoggerFactory

class InventorySync(private val remote: RemoteInventory) {

    private val log = LoggerFactory.getLogger(InventorySync::class.java)

    suspend fun syncOnce(sku: String) {
        try {
            val snapshot = remote.fetch(sku)
            delay(50)
            remote.commit(sku, snapshot)
        } catch (e: CancellationException) {
            log.warn("sync interrupted for {}", sku, e)
        } catch (e: Exception) {
            log.error("sync failed for {}", sku, e)
        }
    }
}

interface RemoteInventory {
    suspend fun fetch(sku: String): Map<String, Int>
    suspend fun commit(sku: String, snapshot: Map<String, Int>)
}
