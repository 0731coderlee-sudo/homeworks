import React, { useState } from 'react';
import { useWallet } from '../features/wallet/useWallet';

export function WalletConnect() {
  const { account, connect, connecting, error } = useWallet();
  const [copied, setCopied] = useState(false);

  if (account) {
    const short = account.slice(0, 6) + '…' + account.slice(-4);
    return (
      <div className="flex gap-8" style={{ alignItems: 'center' }}>
        <span className="small-address" title={account}>{short}</span>
        <button
          className="copy-btn"
          onClick={() => { navigator.clipboard.writeText(account); setCopied(true); setTimeout(()=>setCopied(false), 1400); }}
        >{copied ? '已复制' : '复制'}</button>
      </div>
    );
  }

  return (
    <div className="flex gap-8" style={{ alignItems: 'center' }}>
      <button className="btn btn-primary" disabled={connecting} onClick={connect}>{connecting ? '连接中…' : '连接钱包'}</button>
      {error && <span className="badge err">{error}</span>}
    </div>
  );
}
