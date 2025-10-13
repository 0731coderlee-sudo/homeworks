import { createPublicClient, createWalletClient, http, custom } from 'viem';
import { defineChain } from 'viem';

const RPC_URL = (import.meta as any).env?.VITE_RPC_URL || 'http://127.0.0.1:8545';

// 定义 Anvil 本地链配置
export const anvilLocal = defineChain({
  id: 31337,
  name: 'Anvil Local',
  network: 'anvil-local',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
});

export const publicClient = createPublicClient({
  chain: anvilLocal,
  transport: http(RPC_URL, { batch: true })
});

export function getInjected(): any | null {
  if (typeof window !== 'undefined' && (window as any).ethereum) return (window as any).ethereum;
  return null;
}

export async function ensureChain(injected: any) {
  const chainIdHex = await injected.request({ method: 'eth_chainId' });
  const current = parseInt(chainIdHex, 16);
  
  if (current !== anvilLocal.id) {
    try {
      // 先尝试切换到本地网络
      await injected.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0x' + anvilLocal.id.toString(16) }]
      });
    } catch (switchError: any) {
      // 如果切换失败（网络不存在），则尝试添加网络
      if (switchError.code === 4902) {
        await injected.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: '0x' + anvilLocal.id.toString(16),
            chainName: anvilLocal.name,
            nativeCurrency: anvilLocal.nativeCurrency,
            rpcUrls: [anvilLocal.rpcUrls.default.http[0]],
            blockExplorerUrls: null
          }]
        });
      } else {
        throw switchError;
      }
    }
  }
}

export async function getWalletClient(account?: `0x${string}`) {
  const injected = getInjected();
  if (!injected) throw new Error('未检测到浏览器钱包');
  await ensureChain(injected);
  return createWalletClient({
    chain: anvilLocal,
    transport: custom(injected),
    account
  });
}
