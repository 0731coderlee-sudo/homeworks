import tokenBankAbiJson from '../../../abi/tokenbank.abi.json' with { type: 'json' };
import ttcoinAbiJson from '../../../abi/ttcoin.abi.json' with { type: 'json' };

export const TOKEN_BANK_ADDRESS = '0x9e38C9cBf310c27aFc1c141a7CE5a10959f073d2';
export const TOKEN_ADDRESS = '0x66195151E0882500CB594B1cd40613CB8937F8e7';
export const TOKEN_DECIMALS = 18;

export const tokenBankAbi = tokenBankAbiJson as any;
export const erc20Abi = ttcoinAbiJson as any;
