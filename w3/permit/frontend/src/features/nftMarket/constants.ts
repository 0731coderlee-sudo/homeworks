import nftMarketAbiJson from '../../../abi/nftmarket.abi.json' with { type: 'json' };

export const NFT_MARKET_ADDRESS = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9';
export const nftMarketAbi = nftMarketAbiJson as any;
// 假设使用同一 ERC20 18 decimals 计价，如需区分可扩展
export const NFT_MARKET_PRICE_DECIMALS = 18;
