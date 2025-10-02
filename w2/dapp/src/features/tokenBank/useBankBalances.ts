import { useState, useEffect, useCallback } from 'react';
import { publicClient } from '../../lib/viemClients';
import { TOKEN_BANK_ADDRESS, tokenBankAbi, TOKEN_ADDRESS, erc20Abi } from './constants';

export function useBankBalances(account: `0x${string}` | null) {
  const [bankBalance, setBankBalance] = useState<bigint | null>(null);
  const [walletTokenBalance, setWalletTokenBalance] = useState<bigint | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!account) return;
    setLoading(true);
    setError(null);
    try {
      const [b, t] = await Promise.all([
        publicClient.readContract({ address: TOKEN_BANK_ADDRESS, abi: tokenBankAbi, functionName: 'balanceOf', args: [account] }),
        publicClient.readContract({ address: TOKEN_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [account] })
      ]);
      setBankBalance(b as bigint);
      setWalletTokenBalance(t as bigint);
    } catch (e: any) {
      setError(e.message || '读取失败');
    } finally {
      setLoading(false);
    }
  }, [account]);

  useEffect(() => { refresh(); }, [refresh]);

  return { bankBalance, walletTokenBalance, loading, error, refresh };
}
