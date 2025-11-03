-- Azuki NFT OpenSea 交易量查询
-- 合约地址: 0xED5AF388653567Af2F388E6224dC7C4b3241C544
-- 区块链: Ethereum
-- 时间范围: 最近 30 天（可根据需要调整）

SELECT 
    DATE_TRUNC('day', block_time) AS date,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT seller) AS unique_sellers,
    COUNT(DISTINCT buyer) AS unique_buyers,
    SUM(amount_usd) AS total_volume_usd,
    SUM(number_of_items) AS total_items_sold,
    AVG(amount_usd) AS avg_price_usd,
    MIN(amount_usd) AS min_price_usd,
    MAX(amount_usd) AS max_price_usd
FROM nft.trades
WHERE nft_contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
    AND blockchain = 'ethereum'
    AND project = 'opensea'
    AND block_time >= NOW() - interval '30' day
GROUP BY DATE_TRUNC('day', block_time)
ORDER BY date DESC;