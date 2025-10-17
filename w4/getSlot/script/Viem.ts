import { createPublicClient, http, keccak256, pad } from 'viem';
import { foundry } from 'viem/chains';
import { getStorageAt } from 'viem/actions';

/**
 * Viem Storage Reader for Dynamic Arrays
 *
 * This script demonstrates how to read Solidity dynamic array data directly from blockchain storage.
 *
 * Solidity Storage Layout Rules:
 * 1. Dynamic arrays store their LENGTH at the declared slot
 * 2. Array elements are stored at: keccak256(slot) + index
 * 3. Structs occupy consecutive slots based on their fields
 */

// Create a Viem client connected to local Anvil testnet
const client = createPublicClient({
  chain: foundry,
  transport: http('http://127.0.0.1:8545'),
});

// The contract address we're reading from
const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const;

// Storage slot where the _locks array is declared in the contract
// In Solidity, this is determined by the order of state variables
const LOCKS_ARRAY_SLOT = 0;

// Define the structure we're reading (matches the Solidity LockInfo struct)
interface LockInfo {
  user: string;      // address (20 bytes)
  startTime: bigint; // uint256 (32 bytes)
  amount: bigint;    // uint256 (32 bytes)
}

/**
 * Reads the length of the _locks dynamic array
 *
 * For dynamic arrays in Solidity:
 * - The array's declared slot stores the array length
 * - The actual elements are stored elsewhere (see getElementSlot)
 */
async function getLocksLength(): Promise<bigint> {
  const lengthHex = await getStorageAt(client, {
    address: contractAddress,
    slot: LOCKS_ARRAY_SLOT,
  });
  return BigInt(lengthHex!);
}

/**
 * Calculates the storage slot for a dynamic array element
 *
 * Solidity Storage Formula for Dynamic Arrays:
 * - Element[i] is stored at: keccak256(abi.encode(arraySlot)) + i
 *
 * @param index - The index of the array element (0-based)
 * @returns The storage slot where the element starts
 */
function getElementSlot(index: number): bigint {
  // Pad the array slot to 32 bytes (required for keccak256)
  const paddedSlot = pad('0x' + LOCKS_ARRAY_SLOT.toString(16), { size: 32 });

  // Hash the padded slot to get the base location of array elements
  const baseSlot = BigInt(keccak256(paddedSlot));

  // Add the index to get the specific element's slot
  // Note: If the element is a struct, this is just the FIRST slot of that struct
  return baseSlot + BigInt(index);
}

/**
 * Reads all LockInfo elements from the _locks array
 *
 * Each LockInfo struct occupies 3 consecutive storage slots:
 * - Slot 0: user (address, stored in lower 20 bytes)
 * - Slot 1: startTime (uint256)
 * - Slot 2: amount (uint256)
 */
async function getAllLocks(): Promise<LockInfo[]> {
  // First, get the number of elements in the array
  const length = await getLocksLength();
  console.log(`Found ${length} lock(s) in the array\n`);

  const locks: LockInfo[] = [];

  // Iterate through each element in the array
  for (let i = 0; i < Number(length); i++) {
    // Calculate the starting slot for this array element
    const elementStartSlot = getElementSlot(i);

    // Read the 3 consecutive slots that make up the LockInfo struct
    const userHex = await getStorageAt(client, {
      address: contractAddress,
      slot: elementStartSlot
    });

    const startTimeHex = await getStorageAt(client, {
      address: contractAddress,
      slot: elementStartSlot + 1n
    });

    const amountHex = await getStorageAt(client, {
      address: contractAddress,
      slot: elementStartSlot + 2n
    });

    // Parse and format the data
    locks.push({
      user: '0x' + userHex!.slice(-40),  // Extract the last 20 bytes (40 hex chars) for address
      startTime: BigInt(startTimeHex!),
      amount: BigInt(amountHex!),
    });
  }

  return locks;
}

// Execute and display the results
getAllLocks().then((locks) => {
  console.log('=== Locks Array Data ===\n');
  locks.forEach((lock, index) => {
    console.log(`Lock #${index}:`);
    console.log(`  User:      ${lock.user}`);
    console.log(`  StartTime: ${lock.startTime}`);
    console.log(`  Amount:    ${lock.amount}\n`);
  });
}).catch((error) => {
  console.error('Error reading locks:', error);
});