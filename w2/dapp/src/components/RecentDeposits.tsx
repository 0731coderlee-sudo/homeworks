import React from 'react';
import { useRecentDeposits } from '../features/tokenBank/useRecentDeposits';
import { formatToken } from '../utils/format';

export function RecentDeposits() {
  const { records, loading, error, refresh } = useRecentDeposits(true);
  return (
    <div className="card">
      <div className="card-header">
        <div className="card-title">Recent Deposits</div>
        <button className="btn btn-outline" disabled={loading} onClick={refresh}>{loading ? '…' : '刷新'}</button>
      </div>
      {error && <div className="status err">{error}</div>}
      {!records.length && !loading && <div className="muted">暂无记录</div>}
      <ul className="list scroll-area" style={{ marginTop: 4 }}>
        {records.map((r, idx) => (
          <li key={idx}>
            <code>{r.user.slice(0, 6)}…{r.user.slice(-4)}</code>
            <span style={{ marginLeft: 8, color: '#4ade80' }}>+{formatToken(r.amount)}</span>
            <span className="muted" style={{ marginLeft: 8 }}>{new Date(Number(r.timestamp) * 1000).toLocaleTimeString()}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}