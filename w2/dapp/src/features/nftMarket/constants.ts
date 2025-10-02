import nftMarketAbiJson from '../../../abi/nftmarket.abi.json' with { type: 'json' };

export const NFT_MARKET_ADDRESS = '0x4b78DcD21Edb2A51881Cb4B0328fFfa3A8dA9FB0';
export const nftMarketAbi = nftMarketAbiJson as any;
// 假设使用同一 ERC20 18 decimals 计价，如需区分可扩展
export const NFT_MARKET_PRICE_DECIMALS = 18;
