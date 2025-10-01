### 在polygon主网发行自己的nft token 1.0
- nft deployed log
    Deployed to: 0x28Ad11E21E9f8E3A1a4a6Cd59B142f56D311c85b
- ttcoin deployed log
    Deployed to: 0x0e125FaeAACf3dce479A4Bb03454538934820125
- NFTMarket deployed log
    Deployed to: 0x434FD3aea004824446D2AB39F7CD4eA9C06B848C

### polygon主网测试:
```
1.部署 xtcoin 合约: 
contract:  0x66195151E0882500CB594B1cd40613CB8937F8e7
调用:deploy(1000,xtcoin,xtc)
2.部署 nft 合约:
contract: 0xec59021c1Bf0A4e6aCF8d9B09480ea1AACA91e2d 
调用:deploy
(xtnft,xtnft,ipfs://bafybeibg3k3zgdr46nlvgm6kdncwl43h7s53fmrgv2xgj2eo5rdtqaqll4/metadata/)
mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,1)

部署 market 合约:
contract: 0x4b78DcD21Edb2A51881Cb4B0328fFfa3A8dA9FB0

卖家: 0xA29a00E345A115EbC11D4724EC1133CA691d2B2a 
买家: 0x291943449454DcCdC6344e0220E60ebA83a183F2  9000000000000000000 xtc

卖家授权 market 使用自己的nft:
然后卖家上架自己的nft:  listwithtoken 指定xtcoin:

卖家上架nft:
listwithtoken(0xec59021c1Bf0A4e6aCF8d9B09480ea1AACA91e2d,1,5000000000000000000,0x66195151E0882500CB594B1cd40613CB8937F8e7)

最后买家使用xtcoin购买指定nft:
transferwithcall:

0x4b78DcD21Edb2A51881Cb4B0328fFfa3A8dA9FB0,5000000000000000000,0x000000000000000000000000ec59021c1bf0a4e6acf8d9b09480ea1aaca91e2d0000000000000000000000000000000000000000000000000000000000000001
```


### changelog
- 修复了nft元数据存储的问题,现在opensea等平台可以正常解析出来图片
- 扩展了baseerc721的一些功能,增加了批量mint、mintWithTokenUrl、以及设置了一个接受付款的列表(支持兼容erc20标准的token)
- 新增了测试文件

### 实际效果

- 0x66195151E0882500CB594B1cd40613CB8937F8e7   erc20-token
- 0xec59021c1Bf0A4e6aCF8d9B09480ea1AACA91e2d   erc721
- 0x4b78DcD21Edb2A51881Cb4B0328fFfa3A8dA9FB0   nftmarket
- deployer and holder:
    0xA29a00E345A115EbC11D4724EC1133CA691d2B2a
- tx
    https://polygonscan.com/token/0xec59021c1bf0a4e6acf8d9b09480ea1aaca91e2d
- opensea
- https://opensea.io/collection/xtnft-902975224
- added:    不可变量fuzzing的一些局限性.md