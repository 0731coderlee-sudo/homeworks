import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'

// const privateKey = generatePrivateKey()

export const privateKey =
  '0x76fe3ef24ff48d589eda3a5f3dc494d42d6e279a6a0d1bea65b1417324a0ab97'
export const account = privateKeyToAccount(privateKey)

export const rpc_url = 'https://eth-sepolia.g.alchemy.com/v2/kBC5i0vKDTL7S_ldEOHKQ'
