import { createPublicClient, createWalletClient, http, custom } from 'viem';
import { polygon } from 'viem/chains';

const RPC_URL = (import.meta as any).env?.VITE_RPC_URL || 'https://polygon-rpc.com';

export const publicClient = createPublicClient({
  chain: polygon,
  transport: http(RPC_URL, { batch: true })
});

export function getInjected(): any | null {
  if (typeof window !== 'undefined' && (window as any).ethereum) return (window as any).ethereum;
  return null;
}

export async function ensureChain(injected: any) {
  const chainIdHex = await injected.request({ method: 'eth_chainId' });
  const current = parseInt(chainIdHex, 16);
  if (current !== polygon.id) {
    await injected.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0x' + polygon.id.toString(16) }]
    });
  }
}

export async function getWalletClient(account?: `0x${string}`) {
  const injected = getInjected();
  if (!injected) throw new Error('未检测到浏览器钱包');
  await ensureChain(injected);
  return createWalletClient({
    chain: polygon,
    transport: custom(injected),
    account
  });
}
