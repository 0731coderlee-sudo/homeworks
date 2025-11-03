-- Azuki NFT 持有人名单查询
-- 合约地址: 0xED5AF388653567Af2F388E6224dC7C4b3241C544
-- 区块链: Ethereum
-- 返回：持有人地址和持有的 NFT 数量，按持有数量降序排列

WITH transfers AS (
    SELECT 
        "from" AS address,
        -1 AS value
    FROM nft.transfers
    WHERE contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
        AND blockchain = 'ethereum'
    
    UNION ALL
    
    SELECT 
        "to" AS address,
        1 AS value
    FROM nft.transfers
    WHERE contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
        AND blockchain = 'ethereum'
),

balances AS (
    SELECT 
        address,
        SUM(value) AS balance
    FROM transfers
    GROUP BY address
    HAVING SUM(value) > 0
)

SELECT 
    address AS holder_address,
    balance AS nft_count
FROM balances
ORDER BY balance DESC;

