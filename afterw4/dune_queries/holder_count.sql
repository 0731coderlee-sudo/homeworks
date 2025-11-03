-- Azuki NFT 持有者总数查询
-- 合约地址: 0xED5AF388653567Af2F388E6224dC7C4b3241C544
-- 区块链: Ethereum

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
)

SELECT 
    COUNT(*) AS total_holders
FROM balances
WHERE balance > 0;