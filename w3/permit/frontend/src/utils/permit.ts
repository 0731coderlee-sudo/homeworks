// EIP-2612 Permit 签名工具函数
import { type WalletClient, type Address } from 'viem';
import { publicClient } from '../lib/viemClients';

/**
 * EIP-712 Domain 类型定义
 */
export interface EIP712Domain {
  name: string;
  version: string;
  chainId: number;
  verifyingContract: Address;
}

/**
 * Permit 签名数据
 */
export interface PermitData {
  owner: Address;
  spender: Address;
  value: bigint;
  nonce: bigint;
  deadline: bigint;
}

/**
 * 签名结果
 */
export interface PermitSignature {
  v: number;
  r: `0x${string}`;
  s: `0x${string}`;
  deadline: bigint;
}

/**
 * 生成 Permit 签名
 * @param walletClient Viem 钱包客户端
 * @param tokenAddress 代币合约地址
 * @param tokenName 代币名称
 * @param owner 代币所有者地址
 * @param spender 被授权地址
 * @param value 授权金额
 * @param nonce 当前 nonce
 * @param deadline 签名过期时间（秒级时间戳）
 * @returns 签名结果 { v, r, s, deadline }
 */
export async function signPermit(
  walletClient: WalletClient,
  tokenAddress: Address,
  tokenName: string,
  owner: Address,
  spender: Address,
  value: bigint,
  nonce: bigint,
  deadline: bigint
): Promise<PermitSignature> {
  // 1. 构造 EIP-712 Domain
  const domain: EIP712Domain = {
    name: tokenName,
    version: '1',
    chainId: walletClient.chain!.id,
    verifyingContract: tokenAddress,
  };

  // 2. 定义 Permit 类型
  const types = {
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  };

  // 3. 准备签名数据
  const message: PermitData = {
    owner,
    spender,
    value,
    nonce,
    deadline,
  };

  // 4. 请求用户签名（会弹出 MetaMask 签名窗口）
  const signature = await walletClient.signTypedData({
    account: owner,
    domain,
    types,
    primaryType: 'Permit',
    message,
  });

  // 5. 解析签名为 v, r, s
  const r = `0x${signature.slice(2, 66)}` as `0x${string}`;
  const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
  const v = parseInt(signature.slice(130, 132), 16);

  return { v, r, s, deadline };
}

/**
 * 读取代币的当前 nonce
 * @param tokenAddress 代币合约地址
 * @param owner 所有者地址
 * @param abi 代币 ABI
 * @returns nonce 值
 */
export async function getTokenNonce(
  tokenAddress: Address,
  owner: Address,
  abi: any
): Promise<bigint> {
  const nonce = await publicClient.readContract({
    address: tokenAddress,
    abi,
    functionName: 'nonces',
    args: [owner],
  });
  return nonce as bigint;
}

/**
 * 生成默认的 deadline（当前时间 + 1 小时）
 * @returns deadline（秒级时间戳）
 */
export function getDefaultDeadline(): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + 3600);
}
