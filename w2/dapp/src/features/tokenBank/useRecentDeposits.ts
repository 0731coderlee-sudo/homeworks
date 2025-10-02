import { useEffect, useState, useCallback } from 'react';
import { publicClient } from '../../lib/viemClients';
import { TOKEN_BANK_ADDRESS, tokenBankAbi } from './constants';

export interface RecentDepositRecord {
  user: `0x${string}`;
  amount: bigint;
  timestamp: bigint;
}

export function useRecentDeposits(auto = true) {
  const [records, setRecords] = useState<RecentDepositRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchRecent = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const data = await publicClient.readContract({
        address: TOKEN_BANK_ADDRESS,
        abi: tokenBankAbi,
        functionName: 'getRecentDeposits',
        args: []
      }) as any[];
      const mapped = (data || []).map(r => ({
        user: r.user as `0x${string}`,
        amount: r.amount as bigint,
        timestamp: r.timestamp as bigint
      }));
      setRecords(mapped);
    } catch (e: any) {
      setError(e.message || '获取 recentDeposits 失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { if (auto) fetchRecent(); }, [auto, fetchRecent]);

  // 简单事件监听（仅追加，不保证与合约内部辅助数组完全一致，仍以主动 fetch 为准）
  useEffect(() => {
    const unwatch = publicClient.watchContractEvent({
      address: TOKEN_BANK_ADDRESS,
      abi: tokenBankAbi,
      eventName: 'Deposit',
      onLogs(logs) {
        if (!logs?.length) return;
        setRecords(prev => {
          const appended = [...prev];
            for (const lg of logs) {
              const anyLog: any = lg as any;
              const user = anyLog.args?.user as `0x${string}`;
              const amount = anyLog.args?.amount as bigint;
              appended.unshift({ user, amount, timestamp: BigInt(Math.floor(Date.now()/1000)) });
            }
          return appended.slice(0, 100); // 保留前 100 条
        });
      },
      onError(err) {
        // 静默
        console.debug('Deposit event watch error', err);
      }
    });
    return () => { unwatch?.(); };
  }, []);

  return { records, loading, error, refresh: fetchRecent };
}