import { parseUnits } from 'viem';
import { publicClient, getWalletClient } from '../../lib/viemClients';
import { NFT_MARKET_ADDRESS, nftMarketAbi } from './constants';
import { TOKEN_ADDRESS, erc20Abi } from '../tokenBank/constants';
import { signPermit, getTokenNonce, getDefaultDeadline } from '../../utils/permit';

/**
 * 检查用户是否在 NFT 购买白名单中
 */
export async function checkWhitelist(userAddress: `0x${string}`) {
  try {
    const isWhitelisted = await publicClient.readContract({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      functionName: 'isWhitelisted',
      args: [userAddress],
    });
    return isWhitelisted as boolean;
  } catch (error) {
    console.error('检查白名单失败:', error);
    return false;
  }
}

/**
 * 获取 NFT 上架信息
 */
export async function getNFTListing(nftAddress: `0x${string}`, tokenId: bigint) {
  try {
    const listing = await publicClient.readContract({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      functionName: 'getListing',
      args: [nftAddress, tokenId],
    });
    
    const [seller, price, paymentToken] = listing as [string, bigint, string];
    return {
      seller: seller as `0x${string}`,
      price,
      paymentToken: paymentToken as `0x${string}`,
      isListed: price > 0n
    };
  } catch (error) {
    console.error('获取NFT信息失败:', error);
    return null;
  }
}

/**
 * 使用 Permit 签名购买 NFT（仅限白名单用户）
 */
export async function permitBuyNFT(
  nftAddress: `0x${string}`,
  tokenId: bigint,
  account: `0x${string}`
) {
  // 1. 检查是否在白名单中
  const isWhitelisted = await checkWhitelist(account);
  if (!isWhitelisted) {
    throw new Error('您不在 NFT 购买白名单中，无法使用 Permit 购买功能');
  }

  // 2. 获取 NFT 上架信息
  const listing = await getNFTListing(nftAddress, tokenId);
  if (!listing || !listing.isListed) {
    throw new Error('NFT 未上架');
  }

  // 3. 检查是否只支持 TTCoin
  if (listing.paymentToken.toLowerCase() !== TOKEN_ADDRESS.toLowerCase()) {
    throw new Error('此 NFT 不支持 TTCoin Permit 购买');
  }

  const walletClient = await getWalletClient(account);

  // 4. 读取代币名称（用于 EIP-712 domain）
  const tokenName = await publicClient.readContract({
    address: TOKEN_ADDRESS,
    abi: erc20Abi,
    functionName: 'name',
    args: [],
  }) as string;

  // 5. 读取当前 nonce
  const nonce = await getTokenNonce(TOKEN_ADDRESS, account, erc20Abi);

  // 6. 设置 deadline（1小时后过期）
  const deadline = getDefaultDeadline();

  // 7. 请求用户签名（弹出 MetaMask 签名窗口）
  const { v, r, s } = await signPermit(
    walletClient,
    TOKEN_ADDRESS,
    tokenName,
    account,
    NFT_MARKET_ADDRESS, // 授权给 NFTMarket 合约
    listing.price,
    nonce,
    deadline
  );

  // 8. 调用 NFTMarket.permitBuy
  const hash = await walletClient.writeContract({
    address: NFT_MARKET_ADDRESS,
    abi: nftMarketAbi,
    functionName: 'permitBuy',
    args: [nftAddress, tokenId, account, deadline, v, r, s],
    account,
  });

  return hash;
}

/**
 * 普通购买 NFT（需要预先授权）
 */
export async function buyNFT(
  nftAddress: `0x${string}`,
  tokenId: bigint,
  account: `0x${string}`
) {
  const walletClient = await getWalletClient(account);

  const hash = await walletClient.writeContract({
    address: NFT_MARKET_ADDRESS,
    abi: nftMarketAbi,
    functionName: 'buyNFT',
    args: [nftAddress, tokenId],
    account,
  });

  return hash;
}