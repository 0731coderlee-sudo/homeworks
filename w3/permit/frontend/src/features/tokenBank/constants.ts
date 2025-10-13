import tokenBankAbiJson from '../../../abi/tokenbank.abi.json' with { type: 'json' };
import ttcoinAbiJson from '../../../abi/ttcoin.abi.json' with { type: 'json' };

export const TOKEN_BANK_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';
export const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
export const TOKEN_DECIMALS = 18;

// 提取 ABI 数组
export const tokenBankAbi = (tokenBankAbiJson as any).abi;
export const erc20Abi = (ttcoinAbiJson as any).abi;
