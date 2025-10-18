import { createPublicClient, createWalletClient, http } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import * as dotenv from 'dotenv';

dotenv.config();

// 新部署的合约地址
const ADDRESSES = {
  baseERC721: '0xD1689165740CD727fba08a9F721bB6fCa297fD1F' as const,
  v2Impl: '0x28AD573864Af6F3d66d033D16392AF09cEB88eA3' as const,
  proxy: '0x358D663742D3141188D0A2a4e871250e75835046' as const,
  v3Impl: '0xB473B952d9Abb655922eaCCe4DE0e66Ddf6a605C' as const,
  ttcoin: '0xd499Ac1FBfa849640Ec92d26a8bA67d39019360a' as const,
};

// Proxy ABI
const PROXY_ABI = [
  {
    type: 'function',
    name: 'implementation',
    inputs: [],
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'admin',
    inputs: [],
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
] as const;

// Market ABI
const MARKET_ABI = [
  {
    type: 'function',
    name: 'version',
    inputs: [],
    outputs: [{ type: 'string' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'upgradeTo',
    inputs: [{ name: 'newImplementation', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'initializeV3',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getNonce',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'DOMAIN_SEPARATOR',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'addSupportedToken',
    inputs: [{ name: 'tokenAddress', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'isTokenSupported',
    inputs: [{ name: 'tokenAddress', type: 'address' }],
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
] as const;

const account = privateKeyToAccount(process.env.privatekey as `0x${string}`);

const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(process.env.rpc),
});

const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http(process.env.rpc),
});

async function main() {
  const LINE = '='.repeat(70);

  console.log(LINE);
  console.log('NFTMarket V2 -> V3 Upgrade Test');
  console.log(LINE);
  console.log('Account:', account.address);
  console.log('Proxy:', ADDRESSES.proxy);
  console.log('V2 Implementation:', ADDRESSES.v2Impl);
  console.log('V3 Implementation:', ADDRESSES.v3Impl);
  console.log(LINE + '\n');

  try {
    // Step 1: Check current state
    console.log('[Step 1] Check Current State (V2)');
    console.log('-'.repeat(70));

    const currentImpl = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: PROXY_ABI,
      functionName: 'implementation',
    });

    console.log('Current Implementation:', currentImpl);

    const admin = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: PROXY_ABI,
      functionName: 'admin',
    });

    console.log('Admin:', admin);

    const currentVersion = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'version',
    });

    console.log('Current Version:', currentVersion);

    const owner = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'owner',
    });

    console.log('Owner:', owner);

    // Verify permissions
    if (owner.toLowerCase() !== account.address.toLowerCase()) {
      console.log('\nERROR: You are not the owner!');
      console.log('Required:', owner);
      console.log('Your address:', account.address);
      process.exit(1);
    }

    console.log('\nOK - Current state verified');
    console.log('  Version:', currentVersion);
    console.log('  Implementation:', currentImpl);
    console.log();

    // Step 2: Upgrade to V3
    console.log('[Step 2] Upgrade to V3');
    console.log('-'.repeat(70));

    console.log('Calling upgradeTo(' + ADDRESSES.v3Impl + ')...');

    const upgradeHash = await walletClient.writeContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'upgradeTo',
      args: [ADDRESSES.v3Impl],
    });

    console.log('Upgrade Tx:', upgradeHash);
    console.log('Waiting for confirmation...');

    const upgradeReceipt = await publicClient.waitForTransactionReceipt({
      hash: upgradeHash
    });

    console.log('OK - Upgraded at block:', upgradeReceipt.blockNumber.toString());
    console.log();

    // Step 3: Verify upgrade
    console.log('[Step 3] Verify Upgrade');
    console.log('-'.repeat(70));

    const newImpl = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: PROXY_ABI,
      functionName: 'implementation',
    });

    console.log('New Implementation:', newImpl);

    const newVersion = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'version',
    });

    console.log('New Version:', newVersion);

    // Check if upgrade was successful
    const upgradeSuccess =
      newImpl.toLowerCase() === ADDRESSES.v3Impl.toLowerCase() &&
      newVersion === '3.0.0';

    if (!upgradeSuccess) {
      console.log('\nERROR: Upgrade verification failed!');
      console.log('Expected Implementation:', ADDRESSES.v3Impl);
      console.log('Actual Implementation:', newImpl);
      console.log('Expected Version: 3.0.0');
      console.log('Actual Version:', newVersion);
      process.exit(1);
    }

    console.log('\nOK - Upgrade verified successfully!');
    console.log('  Version: 2.0.0 -> 3.0.0');
    console.log('  Implementation:', newImpl);
    console.log();

    // Step 4: Initialize V3
    console.log('[Step 4] Initialize V3 Features');
    console.log('-'.repeat(70));

    console.log('Calling initializeV3()...');

    const initHash = await walletClient.writeContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'initializeV3',
    });

    console.log('Init Tx:', initHash);
    console.log('Waiting for confirmation...');

    const initReceipt = await publicClient.waitForTransactionReceipt({
      hash: initHash
    });

    console.log('OK - V3 initialized at block:', initReceipt.blockNumber.toString());
    console.log();

    // Step 5: Test V3 features
    console.log('[Step 5] Test V3 New Features');
    console.log('-'.repeat(70));

    const nonce = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'getNonce',
      args: [account.address],
    });

    console.log('Your Nonce:', nonce.toString());

    const domainSeparator = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'DOMAIN_SEPARATOR',
    });

    console.log('Domain Separator:', domainSeparator);

    console.log('\nOK - V3 features working!');
    console.log();

    // Step 6: Configure payment token
    console.log('[Step 6] Configure Payment Token');
    console.log('-'.repeat(70));

    const isSupported = await publicClient.readContract({
      address: ADDRESSES.proxy,
      abi: MARKET_ABI,
      functionName: 'isTokenSupported',
      args: [ADDRESSES.ttcoin],
    });

    console.log('TTCoin supported:', isSupported);

    if (!isSupported) {
      console.log('Adding TTCoin to whitelist...');

      const addTokenHash = await walletClient.writeContract({
        address: ADDRESSES.proxy,
        abi: MARKET_ABI,
        functionName: 'addSupportedToken',
        args: [ADDRESSES.ttcoin],
      });

      console.log('Add Token Tx:', addTokenHash);
      await publicClient.waitForTransactionReceipt({ hash: addTokenHash });

      console.log('OK - TTCoin added to whitelist');
    } else {
      console.log('OK - TTCoin already whitelisted');
    }

    console.log();

    // Summary
    console.log(LINE);
    console.log('UPGRADE TEST COMPLETED SUCCESSFULLY!');
    console.log(LINE);
    console.log('\nSummary:');
    console.log('  [x] V2 state verified');
    console.log('  [x] Upgraded to V3');
    console.log('  [x] V3 features initialized');
    console.log('  [x] V3 functions tested');
    console.log('  [x] Payment token configured');

    console.log('\nContract Info:');
    console.log('  Proxy:', ADDRESSES.proxy);
    console.log('  V2 Impl:', ADDRESSES.v2Impl);
    console.log('  V3 Impl:', ADDRESSES.v3Impl);
    console.log('  Current Version:', newVersion);

    console.log('\nV3 New Features:');
    console.log('  - EIP-712 signature-based listing');
    console.log('  - Nonce-based replay protection');
    console.log('  - One-time NFT approval');
    console.log('  - Off-chain signature support');

    console.log('\nNext Steps:');
    console.log('  1. Update .env with new proxy address:');
    console.log('     NEW_PROXY=' + ADDRESSES.proxy);
    console.log('  2. Test signature listing:');
    console.log('     npm run test:signature');
    console.log('     (Update the proxy address in the script first)');

  } catch (error) {
    console.error('\nERROR:', error);
    if (error instanceof Error) {
      console.error('Message:', error.message);
    }
    process.exit(1);
  }
}

main()
  .then(() => {
    console.log('\nScript finished successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\nScript failed:', error);
    process.exit(1);
  });
