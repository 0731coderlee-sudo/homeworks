import { useEffect, useState, useCallback } from 'react';
import { publicClient } from '../../lib/viemClients';
import { NFT_MARKET_ADDRESS, nftMarketAbi, NFT_MARKET_PRICE_DECIMALS } from './constants';
import { formatToken } from '../../utils/format';

export interface MarketEventBase {
  nft: `0x${string}`;
  tokenId: bigint;
  price: bigint;
  paymentToken: `0x${string}`;
  txHash?: `0x${string}`;
  timestamp: number; // ms
}
export interface ListedEvent extends MarketEventBase { type: 'Listed'; seller: `0x${string}`; }
export interface BoughtEvent extends MarketEventBase { type: 'Bought'; buyer: `0x${string}`; }
export type MarketEvent = ListedEvent | BoughtEvent;

export function useNftMarketEvents(limit = 50) {
  const [events, setEvents] = useState<MarketEvent[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [initialized, setInitialized] = useState(false);

  const addEvents = useCallback((incoming: MarketEvent[]) => {
    setEvents(prev => {
      const merged = [...incoming, ...prev];
      return merged.slice(0, limit);
    });
  }, [limit]);

  // 历史扫描：抓取最近若干区块内的 Listed / Bought 事件（例如最近 30_000 区块）
  useEffect(() => {
    if (initialized) return; // 只执行一次
    (async () => {
      try {
        setLoading(true);
        const latest = await publicClient.getBlockNumber();
  const span = 10n; // 仅回溯最近 10 个区块
        const fromBlock = latest > span ? latest - span : 0n;
        const listedFragment = (nftMarketAbi as any[]).find(i => i.type==='event' && i.name==='Listed');
        const boughtFragment = (nftMarketAbi as any[]).find(i => i.type==='event' && i.name==='Bought');
        if (!listedFragment && !boughtFragment) {
          setInitialized(true); setLoading(false); return;
        }
  let batchSize = 10n; // 初始批量（不超过 span）
        const minBatch = 256n; // 最小批量
        let cursor = fromBlock;
        const hist: MarketEvent[] = [];
        const maxTotal = limit * 3;

        while (cursor <= latest) {
          let attemptSuccess = false;
          let attemptBatch = batchSize;
          let to: bigint = cursor + attemptBatch - 1n > latest ? latest : cursor + attemptBatch - 1n;
          let safetyRetry = 0;

            // 自适应：如果出错且范围过大 -> 减半继续（不前进 cursor）
          while (!attemptSuccess && safetyRetry < 10) {
            to = cursor + attemptBatch - 1n > latest ? latest : cursor + attemptBatch - 1n;
            try {
              const [listedLogs, boughtLogs] = await Promise.all([
                listedFragment ? publicClient.getLogs({ address: NFT_MARKET_ADDRESS, events: [listedFragment], fromBlock: cursor, toBlock: to }) : Promise.resolve([]),
                boughtFragment ? publicClient.getLogs({ address: NFT_MARKET_ADDRESS, events: [boughtFragment], fromBlock: cursor, toBlock: to }) : Promise.resolve([])
              ]);
              // 处理结果
              for (const l of listedLogs) {
                const anyLog: any = l as any;
                hist.push({
                  type: 'Listed',
                  nft: anyLog.args.nft,
                  tokenId: anyLog.args.tokenId,
                  seller: anyLog.args.seller,
                  price: anyLog.args.price,
                  paymentToken: anyLog.args.paymentToken,
                  txHash: l.transactionHash as `0x${string}`,
                  timestamp: Date.now(),
                });
              }
              for (const l of boughtLogs) {
                const anyLog: any = l as any;
                hist.push({
                  type: 'Bought',
                  nft: anyLog.args.nft,
                  tokenId: anyLog.args.tokenId,
                  buyer: anyLog.args.buyer,
                  price: anyLog.args.price,
                  paymentToken: anyLog.args.paymentToken,
                  txHash: l.transactionHash as `0x${string}`,
                  timestamp: Date.now(),
                });
              }
              attemptSuccess = true;
              // 若成功且之前曾经缩小批量，可以尝试逐步放大（简单策略：每次成功稍微+500，直到 4000）
              if (batchSize < 4000n) batchSize = batchSize + 500n > 4000n ? 4000n : batchSize + 500n;
            } catch (chunkErr: any) {
              if (/range|block range|too large/i.test(chunkErr?.message || '')) {
                // 减半批量
                attemptBatch = attemptBatch / 2n;
                if (attemptBatch < minBatch) {
                  console.warn('最小批量仍失败，跳过该区块段', cursor.toString(), '-', to.toString());
                  break; // 跳过该段防死循环
                }
                console.debug(`区块范围过大，缩小批量至 ${attemptBatch}`);
              } else {
                console.debug('历史区块片段获取失败(非范围错误)', chunkErr);
                break; // 其他错误不重试
              }
            }
            safetyRetry++;
          }

          // 前进 cursor（如果失败也要避免死循环；失败走最小步长）
          const advance = attemptSuccess ? (to - cursor + 1n) : (attemptBatch || minBatch);
          cursor += advance;

            if (hist.length > maxTotal) break;
        }
        // 排序：先按 txHash 作为近似，再可扩展获取 block/time 精确排序
        hist.reverse(); // 使较新的靠前（因为我们按从低到高扫描）
        if (hist.length) addEvents(hist);
        setInitialized(true);
      } catch (e: any) {
        setError(e.message || '历史事件扫描失败');
      } finally {
        setLoading(false);
      }
    })();
  }, [initialized, addEvents]);

  // 实时监听
  useEffect(() => {
    setError(null);
    const unwatchListed = publicClient.watchContractEvent({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'Listed',
      onLogs: logs => {
        const mapped: MarketEvent[] = logs.map(l => {
          const anyLog: any = l as any;
          const evt: ListedEvent = {
            type: 'Listed',
            nft: anyLog.args.nft,
            tokenId: anyLog.args.tokenId,
            seller: anyLog.args.seller,
            price: anyLog.args.price,
            paymentToken: anyLog.args.paymentToken,
            txHash: l.transactionHash as `0x${string}`,
            timestamp: Date.now(),
          };
          console.log('[NFTMarket][Listed]', evt);
          return evt;
        });
        if (mapped.length) addEvents(mapped);
      },
      onError: (e) => console.debug('watch Listed error', e)
    });

    const unwatchBought = publicClient.watchContractEvent({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'Bought',
      onLogs: logs => {
        const mapped: MarketEvent[] = logs.map(l => {
          const anyLog: any = l as any;
          const evt: BoughtEvent = {
            type: 'Bought',
            nft: anyLog.args.nft,
            tokenId: anyLog.args.tokenId,
            buyer: anyLog.args.buyer,
            price: anyLog.args.price,
            paymentToken: anyLog.args.paymentToken,
            txHash: l.transactionHash as `0x${string}`,
            timestamp: Date.now(),
          };
          console.log('[NFTMarket][Bought]', evt);
          return evt;
        });
        if (mapped.length) addEvents(mapped);
      },
      onError: (e) => console.debug('watch Bought error', e)
    });

    return () => { unwatchListed?.(); unwatchBought?.(); };
  }, [addEvents]);

  // 可扩展: 初始历史扫描（暂时省略，可按需要添加 getLogs）

  return { events, error, loading, formatPrice: (v: bigint) => formatToken(v, NFT_MARKET_PRICE_DECIMALS, 6) };
}
