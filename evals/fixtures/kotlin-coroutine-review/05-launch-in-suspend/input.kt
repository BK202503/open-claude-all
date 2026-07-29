package com.example.pricing

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

class PriceAggregator(
    private val scope: CoroutineScope,
    private val remote: PriceFeed,
) {

    suspend fun latestPrices(symbols: List<String>): Map<String, Double> {
        val result = mutableMapOf<String, Double>()
        for (symbol in symbols) {
            scope.launch {
                result[symbol] = remote.fetchPrice(symbol)
            }
        }
        return result
    }
}

interface PriceFeed {
    suspend fun fetchPrice(symbol: String): Double
}
