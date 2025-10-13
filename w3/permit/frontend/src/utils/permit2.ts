import { type Address, type Hex, type WalletClient, type PublicClient } from 'viem'

// Permit2 合约地址
export const PERMIT2_ADDRESS: Address = '0x5FbDB2315678afecb367f032d93F642f64180aa3'

// EIP-712 域定义
export const PERMIT2_DOMAIN = {
  name: 'Permit2',
  chainId: 31337, // Anvil 本地链
  verifyingContract: PERMIT2_ADDRESS,
} as const

// EIP-712 类型定义
export const PERMIT2_TYPES = {
  PermitTransferFrom: [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'spender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
  TokenPermissions: [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
  ],
} as const

// Permit2 消息接口
export interface Permit2Message {
  permitted: {
    token: Address
    amount: bigint
  }
  spender: Address
  nonce: bigint
  deadline: bigint
}

/**
 * 生成随机 nonce
 */
export function generateNonce(): bigint {
  return BigInt(Math.floor(Math.random() * 1000000000))
}

/**
 * 生成 deadline（当前时间 + 1小时）
 */
export function generateDeadline(): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + 3600)
}

/**
 * 签名 Permit2 消息
 */
export async function signPermit2Message(
  walletClient: WalletClient,
  account: Address,
  message: Permit2Message
): Promise<Hex> {
  const signature = await walletClient.signTypedData({
    account,
    domain: PERMIT2_DOMAIN,
    types: PERMIT2_TYPES,
    primaryType: 'PermitTransferFrom',
    message,
  })

  return signature
}

/**
 * 检查用户对 Permit2 的授权额度
 */
export async function checkPermit2Allowance(
  publicClient: PublicClient,
  tokenAddress: Address,
  owner: Address
): Promise<bigint> {
  try {
    const allowance = await publicClient.readContract({
      address: tokenAddress,
      abi: [
        {
          name: 'allowance',
          type: 'function',
          stateMutability: 'view',
          inputs: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
          ],
          outputs: [{ name: '', type: 'uint256' }],
        },
      ],
      functionName: 'allowance',
      args: [owner, PERMIT2_ADDRESS],
    })
    return allowance as bigint
  } catch (error) {
    console.error('Failed to check Permit2 allowance:', error)
    return 0n
  }
}

/**
 * 授权 Permit2 合约
 */
export async function approvePermit2(
  walletClient: WalletClient,
  account: Address,
  tokenAddress: Address,
  amount: bigint
): Promise<Hex> {
  const hash = await walletClient.writeContract({
    account,
    address: tokenAddress,
    abi: [
      {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
          { name: 'spender', type: 'address' },
          { name: 'amount', type: 'uint256' },
        ],
        outputs: [{ name: '', type: 'bool' }],
      },
    ],
    functionName: 'approve',
    args: [PERMIT2_ADDRESS, amount],
  })

  return hash
}