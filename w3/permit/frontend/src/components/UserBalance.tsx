import { useState, useEffect } from 'react';
import { publicClient } from '../lib/viemClients';
import { TOKEN_ADDRESS, erc20Abi } from '../features/tokenBank/constants';
import { formatUnits } from 'viem';

interface UserBalanceProps {
  account: `0x${string}` | null;
}

export function UserBalance({ account }: UserBalanceProps) {
  const [ethBalance, setEthBalance] = useState<bigint | null>(null);
  const [tokenBalance, setTokenBalance] = useState<bigint | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!account) {
      setEthBalance(null);
      setTokenBalance(null);
      return;
    }

    const fetchBalances = async () => {
      setLoading(true);
      try {
        const [eth, token] = await Promise.all([
          publicClient.getBalance({ address: account }),
          publicClient.readContract({
            address: TOKEN_ADDRESS,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [account]
          })
        ]);
        setEthBalance(eth);
        setTokenBalance(token as bigint);
      } catch (error) {
        console.error('获取余额失败:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchBalances();
    // 每30秒更新一次余额
    const interval = setInterval(fetchBalances, 30000);
    return () => clearInterval(interval);
  }, [account]);

  if (!account) return null;

  return (
    <div className="card">
      <div className="card-header">
        <h3 className="card-title">💰 钱包余额</h3>
        <div className="badge">
          {account.slice(0, 6)}...{account.slice(-4)}
        </div>
      </div>
      
      <div className="flex flex-col gap-12">
        <div className="flex justify-between">
          <span className="text-dim">ETH 余额:</span>
          <span className="font-mono">
            {loading ? '...' : ethBalance ? `${parseFloat(formatUnits(ethBalance, 18)).toFixed(4)} ETH` : '0 ETH'}
          </span>
        </div>
        
        <div className="flex justify-between">
          <span className="text-dim">TTC 余额:</span>
          <span className="font-mono">
            {loading ? '...' : tokenBalance ? `${parseFloat(formatUnits(tokenBalance, 18)).toLocaleString()} TTC` : '0 TTC'}
          </span>
        </div>
      </div>
    </div>
  );
}