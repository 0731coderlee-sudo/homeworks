import React from 'react';
import { useNftMarketEvents } from '../features/nftMarket/useNftMarketEvents';

export function NftMarketEvents() {
  const { events, error, formatPrice } = useNftMarketEvents(80);
  return (
    <div className="card" style={{ marginTop: 24 }}>
      <div className="card-header">
        <div className="card-title">NFT Market Events</div>
        <div className="badge">Live</div>
      </div>
      {error && <div className="status err">{error}</div>}
      <ul className="list scroll-area" style={{ maxHeight: 260 }}>
        {events.length === 0 && <li className="muted">暂无事件</li>}
        {events.map((e, i) => {
          const actor = 'seller' in e ? e.seller : e.buyer;
          const txUrl = e.txHash ? `https://polygonscan.com/tx/${e.txHash}` : undefined;
          const nftUrl = `https://polygonscan.com/address/${e.nft}`;
          return (
            <li key={i} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <div>
                <span style={{ color: e.type === 'Listed' ? '#38bdf8' : '#4ade80' }}>{e.type}</span>
                <span style={{ marginLeft: 8 }}>NFT: <a href={nftUrl} target="_blank" rel="noreferrer"><code>{e.nft.slice(0,6)}…{e.nft.slice(-4)}</code></a></span>
                <span style={{ marginLeft: 8 }}>TokenID: {e.tokenId.toString()}</span>
                <span style={{ marginLeft: 8 }}>Price: {formatPrice(e.price)}</span>
              </div>
              <div className="muted" style={{ fontSize: 11 }}>
                {e.type === 'Listed' ? 'Seller' : 'Buyer'}: {actor.slice(0,6)}…{actor.slice(-4)} · Tx: {txUrl ? <a href={txUrl} target="_blank" rel="noreferrer">{e.txHash?.slice(0,10)}…</a> : '—'}
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
