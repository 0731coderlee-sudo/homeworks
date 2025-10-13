import { parseUnits } from 'viem';
import { getWalletClient, publicClient } from '../../lib/viemClients';
import { TOKEN_ADDRESS, TOKEN_BANK_ADDRESS, erc20Abi, tokenBankAbi, TOKEN_DECIMALS } from './constants';
import { signPermit, getTokenNonce, getDefaultDeadline } from '../../utils/permit';

export async function deposit(amountStr: string, account: `0x${string}`) {
  if (!amountStr) throw new Error('请输入金额');
  const value = parseUnits(amountStr, TOKEN_DECIMALS);
  const walletClient = await getWalletClient(account);
  // 读取当前 allowance
  let allowance: bigint = 0n;
  try {
    allowance = await publicClient.readContract({
      address: TOKEN_ADDRESS,
      abi: erc20Abi,
      functionName: 'allowance',
      args: [account, TOKEN_BANK_ADDRESS]
    }) as bigint;
  } catch (e) {
    // 忽略读取失败，按 0 处理
    allowance = 0n;
  }

  // 仅在 allowance 不足时调用 approve，避免多余交易
  if (allowance < value) {
    const approveHash = await walletClient.writeContract({
      address: TOKEN_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve',
      args: [TOKEN_BANK_ADDRESS, value],
      account,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
  }

  // deposit 调用
  const depositHash = await walletClient.writeContract({
    address: TOKEN_BANK_ADDRESS,
    abi: tokenBankAbi,
    functionName: 'deposit',
    args: [value],
    account,
  });
  return depositHash;
}

export async function withdraw(amountStr: string, account: `0x${string}`) {
  if (!amountStr) throw new Error('请输入金额');
  const value = parseUnits(amountStr, TOKEN_DECIMALS);
  const walletClient = await getWalletClient(account);
  const hash = await walletClient.writeContract({
    address: TOKEN_BANK_ADDRESS,
    abi: tokenBankAbi,
    functionName: 'withdraw',
    args: [value],
    account,
  });
  return hash;
}

/**
 * 使用 EIP-2612 Permit 签名进行一键存款
 * @param amountStr 存款金额（字符串形式）
 * @param account 用户账户地址
 * @returns 交易哈希
 */
export async function permitDeposit(amountStr: string, account: `0x${string}`) {
  if (!amountStr) throw new Error('请输入金额');
  const value = parseUnits(amountStr, TOKEN_DECIMALS);
  const walletClient = await getWalletClient(account);

  // 1. 读取代币名称（用于 EIP-712 domain）
  const tokenName = await publicClient.readContract({
    address: TOKEN_ADDRESS,
    abi: erc20Abi,
    functionName: 'name',
  }) as string;

  // 2. 读取当前 nonce
  const nonce = await getTokenNonce(TOKEN_ADDRESS, account, erc20Abi);

  // 3. 设置 deadline（1小时后过期）
  const deadline = getDefaultDeadline();

  // 4. 请求用户签名（弹出 MetaMask 签名窗口）
  const { v, r, s } = await signPermit(
    walletClient,
    TOKEN_ADDRESS,
    tokenName,
    account,
    TOKEN_BANK_ADDRESS,
    value,
    nonce,
    deadline
  );

  // 5. 调用 TokenBank.permitDeposit 一键存款
  const hash = await walletClient.writeContract({
    address: TOKEN_BANK_ADDRESS,
    abi: tokenBankAbi,
    functionName: 'permitDeposit',
    args: [account, value, deadline, v, r, s],
    account,
  });

  return hash;
}
