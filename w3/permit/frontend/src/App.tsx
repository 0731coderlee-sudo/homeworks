import React from 'react';
import { WalletConnect } from './components/WalletConnect';
import { BankPanel } from './components/BankPanel';
import { RecentDeposits } from './components/RecentDeposits';
import { NftMarketEvents } from './components/NftMarketEvents';
import { UserBalance } from './components/UserBalance';
import { NFTMarket } from './components/NFTMarket';
import { WalletProvider, useWallet } from './features/wallet/useWallet';

function AppContent() {
  const { account } = useWallet();
  
  return (
    <>
      <header className="header">
        <div className="logo">🏦 TokenBank</div>
        <WalletConnect />
      </header>
      <main className="container">
        {account && (
          <div style={{ marginBottom: '24px' }}>
            <UserBalance account={account} />
          </div>
        )}
        <div className="grid grid-cols-2">
          <BankPanel />
          <RecentDeposits />
        </div>
        <NFTMarket />
        <NftMarketEvents />
        <hr className="separator" />
        <details>
          <summary>📊 系统信息</summary>
          <div className="muted" style={{ marginTop: '12px' }}>
            <p>🌐 网络: Anvil Local (Chain ID: 31337)</p>
            <p>🔗 RPC: http://127.0.0.1:8545</p>
            <p>💰 支持 EIP-2612 离线签名授权存款</p>
          </div>
        </details>
        <div className="footer">© 2025 TokenBank Demo · Anvil Local Network</div>
      </main>
    </>
  );
}

export function App() {
  return (
    <WalletProvider>
      <AppContent />
    </WalletProvider>
  );
}
