import { createPublicClient, http, keccak256, encodeAbiParameters, recoverAddress } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import * as dotenv from 'dotenv';

dotenv.config();

const ADDRESSES = {
  nftMarketProxy: '0x358D663742D3141188D0A2a4e871250e75835046' as const,
  baseERC721: '0xD1689165740CD727fba08a9F721bB6fCa297fD1F' as const,
  ttcoin: '0xd499Ac1FBfa849640Ec92d26a8bA67d39019360a' as const,
};

const account = privateKeyToAccount(process.env.privatekey as `0x${string}`);

const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(process.env.rpc),
});

const MARKET_ABI = [
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
] as const;

const LIST_TYPEHASH = keccak256(
  Buffer.from('List(address nft,uint256 tokenId,uint96 price,address paymentToken,address seller,uint256 nonce)')
);

async function main() {
  console.log('='.repeat(70));
  console.log('Signature Debug Tool');
  console.log('='.repeat(70));
  console.log('Account:', account.address);
  console.log();

  // Get domain separator from contract
  const domainSeparator = await publicClient.readContract({
    address: ADDRESSES.nftMarketProxy,
    abi: MARKET_ABI,
    functionName: 'DOMAIN_SEPARATOR',
  });

  console.log('Domain Separator (from contract):', domainSeparator);

  // Calculate domain separator locally
  const localDomainSeparator = keccak256(
    encodeAbiParameters(
      [
        { type: 'bytes32' },
        { type: 'bytes32' },
        { type: 'bytes32' },
        { type: 'uint256' },
        { type: 'address' },
      ],
      [
        keccak256(Buffer.from('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
        keccak256(Buffer.from('NFTMarketV3')),
        keccak256(Buffer.from('3.0.0')),
        BigInt(11155111), // Sepolia chainId
        ADDRESSES.nftMarketProxy,
      ]
    )
  );

  console.log('Domain Separator (calculated):  ', localDomainSeparator);
  console.log('Match:', domainSeparator === localDomainSeparator ? 'YES' : 'NO');
  console.log();

  // Get nonce
  const nonce = await publicClient.readContract({
    address: ADDRESSES.nftMarketProxy,
    abi: MARKET_ABI,
    functionName: 'getNonce',
    args: [account.address],
  });

  console.log('Nonce:', nonce.toString());
  console.log();

  // Test parameters
  const tokenId = 2n;
  const price = 200000000000000000000n; // 200 TTC
  const paymentToken = ADDRESSES.ttcoin;
  const seller = account.address;

  console.log('Test Parameters:');
  console.log('  NFT:', ADDRESSES.baseERC721);
  console.log('  Token ID:', tokenId.toString());
  console.log('  Price:', price.toString());
  console.log('  Payment Token:', paymentToken);
  console.log('  Seller:', seller);
  console.log('  Nonce:', nonce.toString());
  console.log();

  console.log('LIST_TYPEHASH:', LIST_TYPEHASH);
  console.log();

  // Calculate struct hash
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
  console.log();

  // Calculate digest
  const digest = keccak256(
    encodeAbiParameters(
      [{ type: 'bytes32' }, { type: 'bytes32' }],
      [
        keccak256(Buffer.from('\x19\x01')),
        keccak256(encodeAbiParameters(
          [{ type: 'bytes32' }, { type: 'bytes32' }],
          [domainSeparator, structHash]
        ))
      ]
    )
  );

  console.log('Digest (Method 1):', digest);

  // Try alternative digest calculation (correct way for EIP-712)
  const digest2 = keccak256(
    Buffer.concat([
      Buffer.from('\x19\x01', 'utf8'),
      Buffer.from(domainSeparator.slice(2), 'hex'),
      Buffer.from(structHash.slice(2), 'hex')
    ])
  );

  console.log('Digest (Method 2):', digest2);
  console.log();

  // Sign with method 2
  const signature = await account.sign({ hash: digest2 });

  const r = signature.slice(0, 66) as `0x${string}`;
  const s = ('0x' + signature.slice(66, 130)) as `0x${string}`;
  let v = parseInt(signature.slice(130, 132), 16);

  console.log('Signature:');
  console.log('  Full:', signature);
  console.log('  R:', r);
  console.log('  S:', s);
  console.log('  V (raw):', v);

  // Adjust V if needed (should be 27 or 28)
  if (v < 27) {
    v += 27;
  }
  console.log('  V (adjusted):', v);
  console.log();

  // Recover signer
  const recovered = await recoverAddress({
    hash: digest2,
    signature: signature,
  });

  console.log('Signer Recovery:');
  console.log('  Expected:', account.address);
  console.log('  Recovered:', recovered);
  console.log('  Match:', recovered.toLowerCase() === account.address.toLowerCase() ? 'YES' : 'NO');
  console.log();

  console.log('Test Parameters for listWithSignature:');
  console.log('  nft:', ADDRESSES.baseERC721);
  console.log('  tokenId:', tokenId.toString());
  console.log('  price:', price.toString());
  console.log('  paymentToken:', paymentToken);
  console.log('  seller:', seller);
  console.log('  v:', v);
  console.log('  r:', r);
  console.log('  s:', s);
}

main().catch(console.error);
