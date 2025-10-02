import React from 'react';
import { WalletConnect } from './components/WalletConnect';
import { BankPanel } from './components/BankPanel';
import { RecentDeposits } from './components/RecentDeposits';
import { NftMarketEvents } from './components/NftMarketEvents';
import { WalletProvider } from './features/wallet/useWallet';

export function App() {
  return (
    <WalletProvider>
      <header className="header">
        <div className="logo">TokenBank</div>
        <WalletConnect />
      </header>
      <main className="container">
        <div className="grid grid-cols-2">
          <BankPanel />
          <RecentDeposits />
        </div>
        <NftMarketEvents />
        <hr className="separator" />
        <details>
          <summary>调试信息 (Debug)</summary>
          <p className="muted">如需添加事件扫描与 depositor 列表，可继续扩展 hooks。</p>
        </details>
        <div className="footer">© 2025 TokenBank Demo · Polygon</div>
      </main>
    </WalletProvider>
  );
}
