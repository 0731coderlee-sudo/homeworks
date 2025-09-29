### 在polygon主网发行自己的nft token
nft deployed log```
[⠊] Compiling...
No files changed, compilation skipped
Deployer: 0xA29a00E345A115EbC11D4724EC1133CA691d2B2a
Deployed to: 0x28Ad11E21E9f8E3A1a4a6Cd59B142f56D311c85b
Transaction hash: 0xfe385fd7c29078a105171b58f668b04c7fbbc579113c37702bc04ab144b029ec
Contract source code already verified
```

ttcoin deployed log```
Deployer: 0xA29a00E345A115EbC11D4724EC1133CA691d2B2a
Deployed to: 0x0e125FaeAACf3dce479A4Bb03454538934820125
Transaction hash: 0x093b13c0b8073b6fa0a5688204a327ef49c716583369444d3535ddfa154e7539
Contract successfully verified
```

NFTMarket deployed log```
No files changed, compilation skipped
Deployer: 0xA29a00E345A115EbC11D4724EC1133CA691d2B2a
Deployed to: 0x434FD3aea004824446D2AB39F7CD4eA9C06B848C
Transaction hash: 0xb95e51768668f02a494966299f722f6fc451e16313e1afface64a24a4f3270d2
Contract successfully verified
```

使用ttcoin买卖nft功能 polygon主网测试:
```
买家地址: 0x291943449454DcCdC6344e0220E60ebA83a183F2            持有 10000000000000000000000 ttc
卖家地址: 0xA29a00E345A115EbC11D4724EC1133CA691d2B2a            持有nft tokenid: 168,169 并上架

NFT       合约地址：0x28Ad11E21E9f8E3A1a4a6Cd59B142f56D311c85b
NFTMarket 合约地址：0x434FD3aea004824446D2AB39F7CD4eA9C06B848C

卖家先 approve NFTMarket 合约操作 NFT（approve(market, tokenId)）:
approve(0x434FD3aea004824446D2AB39F7CD4eA9C06B848C,168)
调用 NFTMarket 的 list(nft, tokenId, price)，上架 NFT 并设定价格 :
list(0x28Ad11E21E9f8E3A1a4a6Cd59B142f56D311c85b,168,1000000000000000000000) 
//list-txhash: https://polygonscan.com/tx/0x278281ced24c7b1ebca52f2ac8d16c710ca78a494ec961f869696832dac68754

买家购买 NFT（两种方式）:
普通购买:
买家 approve ttcoin 给 NFTMarket 合约（approve(market, price)）,调用 NFTMarket 的 buyNFT(nft, tokenId)，支付 ttcoin，获得 NFT。
approve(0x434FD3aea004824446D2AB39F7CD4eA9C06B848C, 1000000000000000000000)
### https://polygonscan.com/tx/0x59a577a743bef3919aa23bb86575f673d588b9bca2ea62756d928b1b86403d2c

buyNFT(0x28Ad11E21E9f8E3A1a4a6Cd59B142f56D311c85b, 168)
### https://polygonscan.com/tx/0x40b98304583b1b3570278d960ca8abf79adc6fbe6ee09c0a1b120e7b02fbc46a

方式二：钩子购买
买家直接调用 ttcoin 的 transferWithCallback(market, price, abi.encode(nft, tokenId))，自动完成购买。
transferWithCallback(0x434FD3aea004824446D2AB39F7CD4eA9C06B848C, 1000000000000000000000,0x00000000000000000000000028ad11e21e9f8e3a1a4a6cd59b142f56d311c85b00000000000000000000000000000000000000000000000000000000000000a9)

tx:
https://polygonscan.com/tx/0xc0ee9707e447447a61a8458f3932474201f2ca9dc4914dd711566fa4b585835f
```
