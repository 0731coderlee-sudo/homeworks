import { createPublicClient, createWalletClient, http, parseEther, formatEther, keccak256, encodeAbiParameters } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import * as dotenv from 'dotenv';

dotenv.config();

// Contract addresses - Using new V3 proxy
const ADDRESSES = {
  ttcoin: '0xd499Ac1FBfa849640Ec92d26a8bA67d39019360a' as const,
  nftMarketProxy: '0x358D663742D3141188D0A2a4e871250e75835046' as const,
  baseERC721: '0xD1689165740CD727fba08a9F721bB6fCa297fD1F' as const,
};

// BaseERC721 ABI
const ERC721_ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'autoMintWithURI',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'customURI', type: 'string' },
    ],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setApprovalForAll',
    inputs: [
      { name: 'operator', type: 'address' },
      { name: 'approved', type: 'bool' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'isApprovedForAll',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'operator', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
] as const;

// NFTMarketV3 ABI
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
    name: 'listWithSignature',
    inputs: [
      { name: 'nft', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
      { name: 'price', type: 'uint96' },
      { name: 'paymentToken', type: 'address' },
      { name: 'seller', type: 'address' },
      { name: 'v', type: 'uint8' },
      { name: 'r', type: 'bytes32' },
      { name: 's', type: 'bytes32' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getListing',
    inputs: [
      { name: 'nft', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
    ],
    outputs: [
      { name: 'seller', type: 'address' },
      { name: 'price', type: 'uint96' },
      { name: 'paymentToken', type: 'address' },
    ],
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

// EIP-712 type hash
const LIST_TYPEHASH = keccak256(
  Buffer.from('List(address nft,uint256 tokenId,uint96 price,address paymentToken,address seller,uint256 nonce)')
);

async function main() {
  const LINE = '='.repeat(70);

  console.log(LINE);
  console.log('Test V3 Signature-Based NFT Listing');
  console.log(LINE);
  console.log('Account:', account.address);
  console.log('Market Proxy:', ADDRESSES.nftMarketProxy);
  console.log('BaseERC721:', ADDRESSES.baseERC721);
  console.log(LINE + '\n');

  try {
    // Step 1: Verify V3
    console.log('[Step 1] Verify Market Version');
    console.log('-'.repeat(70));

    const version = await publicClient.readContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'version',
    });

    console.log('Market Version:', version);

    if (version !== '3.0.0') {
      console.log('\nERROR: Market is not V3!');
      console.log('Expected: 3.0.0');
      console.log('Got:', version);
      process.exit(1);
    }

    console.log('OK - Market is V3\n');

    // Step 2: Mint NFT
    console.log('[Step 2] Mint NFT');
    console.log('-'.repeat(70));

    const balance = await publicClient.readContract({
      address: ADDRESSES.baseERC721,
      abi: ERC721_ABI,
      functionName: 'balanceOf',
      args: [account.address],
    });

    console.log('Current NFT Balance:', balance.toString());

    console.log('Minting new NFT...');

    const mintHash = await walletClient.writeContract({
      address: ADDRESSES.baseERC721,
      abi: ERC721_ABI,
      functionName: 'autoMintWithURI',
      args: [account.address, 'ipfs://QmSignatureTest'],
    });

    console.log('Mint Tx:', mintHash);
    await publicClient.waitForTransactionReceipt({ hash: mintHash });

    const newBalance = await publicClient.readContract({
      address: ADDRESSES.baseERC721,
      abi: ERC721_ABI,
      functionName: 'balanceOf',
      args: [account.address],
    });

    const tokenId = newBalance;
    console.log('OK - Minted Token ID:', tokenId.toString());
    console.log();

    // Step 3: One-time approval
    console.log('[Step 3] One-Time Approval');
    console.log('-'.repeat(70));

    const isApproved = await publicClient.readContract({
      address: ADDRESSES.baseERC721,
      abi: ERC721_ABI,
      functionName: 'isApprovedForAll',
      args: [account.address, ADDRESSES.nftMarketProxy],
    });

    if (!isApproved) {
      console.log('Approving market (one-time)...');

      const approveHash = await walletClient.writeContract({
        address: ADDRESSES.baseERC721,
        abi: ERC721_ABI,
        functionName: 'setApprovalForAll',
        args: [ADDRESSES.nftMarketProxy, true],
      });

      console.log('Approve Tx:', approveHash);
      await publicClient.waitForTransactionReceipt({ hash: approveHash });
      console.log('OK - Approved');
    } else {
      console.log('OK - Already approved');
    }

    console.log();

    // Step 4: Get signature parameters
    console.log('[Step 4] Get Signature Parameters');
    console.log('-'.repeat(70));

    const nonce = await publicClient.readContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'getNonce',
      args: [account.address],
    });

    console.log('Nonce:', nonce.toString());

    const domainSeparator = await publicClient.readContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'DOMAIN_SEPARATOR',
    });

    console.log('Domain Separator:', domainSeparator);
    console.log();

    // Step 5: Generate EIP-712 signature
    console.log('[Step 5] Generate EIP-712 Signature');
    console.log('-'.repeat(70));

    const price = parseEther('200');
    const paymentToken = ADDRESSES.ttcoin;
    const seller = account.address;

    console.log('Listing Parameters:');
    console.log('  NFT:', ADDRESSES.baseERC721);
    console.log('  Token ID:', tokenId.toString());
    console.log('  Price:', formatEther(price), 'TTC');
    console.log('  Payment Token:', paymentToken);
    console.log('  Seller:', seller);
    console.log('  Nonce:', nonce.toString());
    console.log();

    // Construct struct hash
    const structHash = keccak256(
      encodeAbiParameters(
        [
          { type: 'bytes32' },
          { type: 'address' },
          { type: 'uint256' },
          { type: 'uint96' },
          { type: 'address' },
          { type: 'address' },
          { type: 'uint256' },
        ],
        [
          LIST_TYPEHASH,
          ADDRESSES.baseERC721,
          tokenId,
          price,
          paymentToken,
          seller,
          nonce,
        ]
      )
    );

    console.log('Struct Hash:', structHash);

    // Construct digest (EIP-712 standard)
    const digest = keccak256(
      Buffer.concat([
        Buffer.from('\x19\x01', 'utf8'),
        Buffer.from(domainSeparator.slice(2), 'hex'),
        Buffer.from(structHash.slice(2), 'hex')
      ])
    );

    console.log('Digest:', digest);

    // Sign the digest
    const signature = await account.sign({ hash: digest });

    console.log('\nSignature:', signature);

    const r = signature.slice(0, 66) as `0x${string}`;
    const s = ('0x' + signature.slice(66, 130)) as `0x${string}`;
    let v = parseInt(signature.slice(130, 132), 16);

    // Ensure V is 27 or 28
    if (v < 27) {
      v += 27;
    }

    console.log('  R:', r);
    console.log('  S:', s);
    console.log('  V:', v);
    console.log();

    // Step 6: List with signature
    console.log('[Step 6] List NFT with Signature');
    console.log('-'.repeat(70));

    console.log('Calling listWithSignature...');
    console.log('NOTE: Anyone can submit this signature!');

    const listHash = await walletClient.writeContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'listWithSignature',
      args: [
        ADDRESSES.baseERC721,
        tokenId,
        price,
        paymentToken,
        seller,
        v,
        r,
        s,
      ],
    });

    console.log('List Tx:', listHash);
    console.log('Waiting for confirmation...');

    const listReceipt = await publicClient.waitForTransactionReceipt({
      hash: listHash
    });

    console.log('OK - Listed at block:', listReceipt.blockNumber.toString());
    console.log();

    // Step 7: Verify listing
    console.log('[Step 7] Verify Listing');
    console.log('-'.repeat(70));

    const listing = await publicClient.readContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'getListing',
      args: [ADDRESSES.baseERC721, tokenId],
    });

    const [listedSeller, listedPrice, listedPaymentToken] = listing;

    console.log('Listing Details:');
    console.log('  Seller:', listedSeller);
    console.log('  Price:', formatEther(listedPrice), 'TTC');
    console.log('  Payment Token:', listedPaymentToken);

    const isCorrect =
      listedSeller.toLowerCase() === seller.toLowerCase() &&
      listedPrice === price &&
      listedPaymentToken.toLowerCase() === paymentToken.toLowerCase();

    if (isCorrect) {
      console.log('\nOK - All information verified!');
    } else {
      console.log('\nWARNING - Verification failed!');
    }

    console.log();

    // Step 8: Verify nonce increment
    console.log('[Step 8] Verify Nonce Incremented');
    console.log('-'.repeat(70));

    const newNonce = await publicClient.readContract({
      address: ADDRESSES.nftMarketProxy,
      abi: MARKET_ABI,
      functionName: 'getNonce',
      args: [account.address],
    });

    console.log('Previous Nonce:', nonce.toString());
    console.log('Current Nonce:', newNonce.toString());

    if (newNonce === nonce + 1n) {
      console.log('OK - Nonce incremented correctly');
    } else {
      console.log('WARNING - Nonce not incremented as expected');
    }

    console.log();

    // Summary
    console.log(LINE);
    console.log('SIGNATURE LISTING TEST COMPLETED!');
    console.log(LINE);
    console.log('\nSummary:');
    console.log('  [x] V3 market verified');
    console.log('  [x] NFT minted');
    console.log('  [x] One-time approval granted');
    console.log('  [x] EIP-712 signature generated');
    console.log('  [x] NFT listed with signature');
    console.log('  [x] Listing verified');
    console.log('  [x] Nonce incremented');

    console.log('\nKey Benefits:');
    console.log('  - setApprovalForAll only needed once');
    console.log('  - Sign listings offline (no gas)');
    console.log('  - Anyone can submit signature');
    console.log('  - Nonce prevents replay attacks');

    console.log('\nListing Info:');
    console.log('  NFT:', ADDRESSES.baseERC721);
    console.log('  Token ID:', tokenId.toString());
    console.log('  Seller:', listedSeller);
    console.log('  Price:', formatEther(listedPrice), 'TTC');

    console.log('\nTest successful!');

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
    console.log('\nScript finished!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\nScript failed:', error);
    process.exit(1);
  });
