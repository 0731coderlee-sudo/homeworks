// React wallet context provider & hook
import { useEffect, useState, useCallback, useContext, createContext, PropsWithChildren } from 'react';
import { getInjected } from '../../lib/viemClients';

interface WalletContextValue {
  account: `0x${string}` | null;
  connecting: boolean;
  error: string | null;
  connect: () => Promise<void>;
  refreshAccount: () => Promise<void>;
}

const WalletContext = createContext<WalletContextValue | null>(null);

export function WalletProvider({ children }: PropsWithChildren) {
  const [account, setAccount] = useState<`0x${string}` | null>(null);
  const [connecting, setConnecting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refreshAccount = useCallback(async () => {
    const injected = getInjected();
    if (!injected) return;
    try {
      const accs = await injected.request({ method: 'eth_accounts' }) as string[];
      if (accs?.length) setAccount(accs[0] as `0x${string}`);
    } catch (_) {
      // ignore
    }
  }, []);

  const connect = useCallback(async () => {
    const injected = getInjected();
    if (!injected) {
      setError('未找到钱包扩展');
      return;
    }
    setConnecting(true);
    setError(null);
    try {
      const accs = await injected.request({ method: 'eth_requestAccounts' }) as string[];
      if (accs?.length) setAccount(accs[0] as `0x${string}`);
    } catch (e: any) {
      setError(e.message || '连接失败');
    } finally {
      setConnecting(false);
    }
  }, []);

  useEffect(() => {
    const injected = getInjected();
    if (!injected) return;
    const handleAccounts = (accs: string[]) => {
      setAccount(accs.length ? accs[0] as `0x${string}` : null);
    };
    injected.on?.('accountsChanged', handleAccounts);
    refreshAccount();
    return () => injected.removeListener?.('accountsChanged', handleAccounts);
  }, [refreshAccount]);

  const value: WalletContextValue = { account, connecting, error, connect, refreshAccount };
  return (<WalletContext.Provider value={value}>{children}</WalletContext.Provider>);
}

export function useWallet() {
  const ctx = useContext(WalletContext);
  if (!ctx) throw new Error('useWallet 必须在 <WalletProvider> 内使用');
  return ctx;
}
