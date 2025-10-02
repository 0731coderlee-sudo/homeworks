import { parseUnits } from 'viem';
import { getWalletClient, publicClient } from '../../lib/viemClients';
import { TOKEN_ADDRESS, TOKEN_BANK_ADDRESS, erc20Abi, tokenBankAbi, TOKEN_DECIMALS } from './constants';

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
