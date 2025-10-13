import React, { useState } from 'react';
import { useWallet } from '../features/wallet/useWallet';
import { useBankBalances } from '../features/tokenBank/useBankBalances';
import { deposit, withdraw, permitDeposit } from '../features/tokenBank/actions';
import { formatToken } from '../utils/format';

export function BankPanel() {
  const { account, refreshAccount } = useWallet();
  const { bankBalance, walletTokenBalance, refresh, loading } = useBankBalances(account);
  const [amount, setAmount] = useState('');
  const [status, setStatus] = useState('');
  const [pending, setPending] = useState(false);

  async function doDeposit() {
    if (!account) return;
    setPending(true); setStatus('执行 approve + deposit ...');
    try {
      const hash = await deposit(amount, account);
      setStatus('Success: ' + hash);
      setAmount('');
      await refresh();
    } catch (e: any) {
      setStatus(e.message || '失败');
    } finally { setPending(false); }
  }

  async function doPermitDeposit() {
    if (!account) return;
    setPending(true); setStatus('请在钱包中签名授权...');
    try {
      const hash = await permitDeposit(amount, account);
      setStatus('Success: ' + hash);
      setAmount('');
      await refresh();
    } catch (e: any) {
      setStatus(e.message || '失败');
    } finally { setPending(false); }
  }

  async function doWithdraw() {
    if (!account) return;
    setPending(true); setStatus('执行 withdraw ...');
    try {
      const hash = await withdraw(amount, account);
      setStatus('Success: ' + hash);
      setAmount('');
      await refresh();
    } catch (e: any) {
      setStatus(e.message || '失败');
    } finally { setPending(false); }
  }

  const maxFill = () => {
    if (walletTokenBalance != null) {
      // 使用 formatToken 但去掉千分位，仅做快速填充（保留全部精度由合约 BigInt 处理）
      setAmount((walletTokenBalance / 10n**18n).toString());
    }
  };

  const statusClass = status.startsWith('Success') ? 'status ok' : (status.includes('失败') || status.toLowerCase().includes('error')) ? 'status err' : 'status';

  return (
    <div className="card">
      <div className="card-header">
        <div className="card-title">TokenBank 账户</div>
        <div className="badge ok">Anvil Local</div>
      </div>
      <div className="muted" style={{ marginBottom: 12 }}>
        已存入 (Bank): <strong>{formatToken(bankBalance)}</strong> · 钱包余额: <strong>{formatToken(walletTokenBalance)}</strong>
      </div>
      <div className="flex gap-8" style={{ alignItems: 'center', marginBottom: 10 }}>
        <input className="input" placeholder="数量 (TTC)" value={amount} onChange={e => setAmount(e.target.value.trim())} />
        <button className="btn" type="button" onClick={maxFill} disabled={walletTokenBalance==null}>Max</button>
      </div>
      <div className="muted" style={{ fontSize: '11px', marginBottom: 8 }}>
        💡 Permit 存款需要两次签名：1️⃣ 离线授权签名（无 gas） + 2️⃣ 存款交易签名
      </div>
      <div className="flex gap-8" style={{ flexWrap: 'wrap' }}>
        <button className="btn btn-primary" disabled={pending || !amount} onClick={doPermitDeposit}>
          🔐 Permit 存款
        </button>
        <button className="btn" disabled={pending || !amount} onClick={doDeposit}>
          存款 (传统)
        </button>
        <button className="btn" disabled={pending || !amount} onClick={doWithdraw}>提现</button>
        <button className="btn btn-outline" disabled={loading} onClick={async () => { await refreshAccount(); await refresh(); }}>刷新</button>
      </div>
      <div className="muted" style={{ fontSize: '12px', marginTop: '8px' }}>
        💡 提示：Permit 存款无需预先 approve，节省 Gas 费用
      </div>
      {status && <div className={statusClass}>{status}</div>}
    </div>
  );
}
