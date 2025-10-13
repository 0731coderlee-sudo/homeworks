import { useState, useEffect } from 'react';
import { useWallet } from '../features/wallet/useWallet';
import { checkWhitelist, permitBuyNFT, buyNFT, getNFTListing } from '../features/nftMarket/actions';
import { formatToken } from '../utils/format';
import { NFT_CONTRACT_ADDRESS } from '../features/nft/constants';

interface NFTListing {
  nftAddress: `0x${string}`;
  tokenId: bigint;
  seller: `0x${string}`;
  price: bigint;
  paymentToken: `0x${string}`;
  isListed: boolean;
}

export function NFTMarket() {
  const { account } = useWallet();
  const [listings, setListings] = useState<NFTListing[]>([]);
  const [isWhitelisted, setIsWhitelisted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [buyingId, setBuyingId] = useState<string | null>(null);

  const NFT_CONTRACT = NFT_CONTRACT_ADDRESS;

  // 加载 NFT 列表和用户白名单状态
  const loadData = async () => {
    if (!account) return;
    
    setLoading(true);
    setError(null);
    try {
      // 检查白名单状态
      const whitelisted = await checkWhitelist(account);
      setIsWhitelisted(whitelisted);

      // 获取已知的 NFT 列表（TokenID 1-5），只显示已上架的
      const nftListings: NFTListing[] = [];
      for (let tokenId = 1; tokenId <= 5; tokenId++) {
        const listing = await getNFTListing(NFT_CONTRACT, BigInt(tokenId));
        if (listing && listing.isListed && listing.price > 0) {
          nftListings.push({
            nftAddress: NFT_CONTRACT,
            tokenId: BigInt(tokenId),
            seller: listing.seller,
            price: listing.price,
            paymentToken: listing.paymentToken,
            isListed: listing.isListed
          });
        }
      }
      setListings(nftListings);
    } catch (err: any) {
      setError(err.message || '加载数据失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [account]);

  const handlePermitBuy = async (nftAddress: `0x${string}`, tokenId: bigint) => {
    if (!account) return;
    
    const key = `${nftAddress}-${tokenId}`;
    setBuyingId(key);
    setError(null);
    
    try {
      const hash = await permitBuyNFT(nftAddress, tokenId, account);
      console.log('Permit购买成功:', hash);
      setError('✅ Permit购买成功！正在更新列表...');
      
      // 等待交易确认后刷新数据
      setTimeout(() => {
        loadData();
        setError(null);
      }, 2000);
    } catch (err: any) {
      setError(err.message || 'Permit购买失败');
    } finally {
      setBuyingId(null);
    }
  };

  const handleBuy = async (nftAddress: `0x${string}`, tokenId: bigint) => {
    if (!account) return;
    
    const key = `${nftAddress}-${tokenId}`;
    setBuyingId(key);
    setError(null);
    
    try {
      const hash = await buyNFT(nftAddress, tokenId, account);
      console.log('购买成功:', hash);
      setError('✅ 购买成功！正在更新列表...');
      
      // 等待交易确认后刷新数据
      setTimeout(() => {
        loadData();
        setError(null);
      }, 2000);
    } catch (err: any) {
      setError(err.message || '购买失败');
    } finally {
      setBuyingId(null);
    }
  };

  if (!account) {
    return (
      <div className="card" style={{ marginTop: 24 }}>
        <div className="card-header">
          <h3 className="card-title">🎨 NFT 市场</h3>
        </div>
        <div className="muted">请先连接钱包查看 NFT 市场</div>
      </div>
    );
  }

  return (
    <div className="card" style={{ marginTop: 24 }}>
      <div className="card-header">
        <h3 className="card-title">🎨 NFT 市场</h3>
        <div className="flex gap-8">
          {isWhitelisted && <div className="badge ok">🔐 白名单用户</div>}
          <div className="badge">TestNFT</div>
        </div>
      </div>

      {error && (
        <div className={`status ${error.startsWith('✅') ? 'ok' : 'err'}`}>
          {error}
        </div>
      )}
      
      {loading ? (
        <div className="muted">加载中...</div>
      ) : (
        <>
          <div className="muted" style={{ marginBottom: 16 }}>
            {isWhitelisted ? (
              '✅ 您可以使用 Permit 一键购买（1次签名 + 1次交易）'
            ) : (
              '⚠️ 您不在白名单中，只能使用传统购买方式（需要先授权代币）'
            )}
          </div>

          {listings.length === 0 ? (
            <div className="muted" style={{ textAlign: 'center', padding: '40px 0' }}>
              🏪 暂无已上架的 NFT
            </div>
          ) : (
            <div className="nft-grid">
              {listings.map((listing) => {
              const key = `${listing.nftAddress}-${listing.tokenId}`;
              const isBuying = buyingId === key;
              const isOwner = listing.seller.toLowerCase() === account.toLowerCase();
              
              return (
                <div key={key} className="nft-card">
                  <div style={{ marginBottom: '8px' }}>
                    <h4 style={{ margin: '0 0 4px 0', fontSize: '14px' }}>TestNFT #{listing.tokenId.toString()}</h4>
                    <div className="muted" style={{ fontSize: '11px' }}>
                      {listing.nftAddress.slice(0, 6)}...{listing.nftAddress.slice(-4)}
                    </div>
                  </div>

                  <div style={{ marginBottom: '8px' }}>
                    <div className="nft-price">
                      {formatToken(listing.price)} TTC
                    </div>
                  </div>

                  <div style={{ marginBottom: '8px' }}>
                    <div className="muted" style={{ fontSize: '11px' }}>
                      卖家: {listing.seller.slice(0, 6)}...{listing.seller.slice(-4)}
                    </div>
                  </div>

                  {isOwner ? (
                    <div className="badge">您的 NFT</div>
                  ) : (
                    <div className="flex gap-6">
                      {isWhitelisted && (
                        <button
                          className="btn btn-primary"
                          disabled={isBuying}
                          onClick={() => handlePermitBuy(listing.nftAddress, listing.tokenId)}
                          style={{ flex: 1, fontSize: '12px', padding: '6px 8px' }}
                        >
                          {isBuying ? '购买中...' : '🔐 Permit'}
                        </button>
                      )}
                      <button
                        className="btn"
                        disabled={isBuying}
                        onClick={() => handleBuy(listing.nftAddress, listing.tokenId)}
                        style={{ flex: 1, fontSize: '12px', padding: '6px 8px' }}
                      >
                        {isBuying ? '购买中...' : '💰 购买'}
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
            </div>
          )}
        </>
      )}
    </div>
  );
}