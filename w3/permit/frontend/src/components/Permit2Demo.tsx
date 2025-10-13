import React, { useState, useEffect } from 'react'
import { useWallet } from '../features/wallet/useWallet'
import { parseUnits, formatUnits } from 'viem'
import { publicClient, getWalletClient } from '../lib/viemClients'
import {
  PERMIT2_ADDRESS,
  generateNonce,
  generateDeadline,
  signPermit2Message,
  checkPermit2Allowance,
  approvePermit2,
  type Permit2Message,
} from '../utils/permit2'

const TOKEN_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
const BANK_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

const BANK_ABI = [
  {
    name: 'depositWithPermit2',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
      { name: 'signature', type: 'bytes' },
    ],
    outputs: [],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_user', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

export function Permit2Demo() {
  const { account } = useWallet()
  const [amount, setAmount] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [status, setStatus] = useState('')
  const [tokenBalance, setTokenBalance] = useState('0')
  const [bankBalance, setBankBalance] = useState('0')

  const refreshBalance = async () => {
    if (!account) return
    try {
      const tokenBal = (await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [account],
      })) as bigint
      setTokenBalance(formatUnits(tokenBal, 18))

      const bankBal = (await publicClient.readContract({
        address: BANK_ADDRESS,
        abi: BANK_ABI,
        functionName: 'balanceOf',
        args: [account],
      })) as bigint
      setBankBalance(formatUnits(bankBal, 18))
    } catch (error) {
      console.error('Failed to refresh balance:', error)
    }
  }

  const handlePermit2Deposit = async () => {
    if (!account || !amount) {
      setStatus('请输入存款金额')
      return
    }
    setIsLoading(true)
    setStatus('正在处理...')
    try {
      const walletClient = await getWalletClient()
      const amountBigInt = parseUnits(amount, 18)
      setStatus('1/4: 检查 Permit2 授权...')
      const allowance = await checkPermit2Allowance(publicClient, TOKEN_ADDRESS, account)
      if (allowance < amountBigInt) {
        setStatus('2/4: 授权 Permit2 合约...')
        const approveHash = await approvePermit2(walletClient, account, TOKEN_ADDRESS, amountBigInt * 2n)
        setStatus('等待授权确认...')
        await publicClient.waitForTransactionReceipt({ hash: approveHash })
      }
      setStatus('3/4: 请签名 Permit2 消息...')
      const nonce = generateNonce()
      const deadline = generateDeadline()
      const message: Permit2Message = {
        permitted: { token: TOKEN_ADDRESS, amount: amountBigInt },
        spender: BANK_ADDRESS,
        nonce,
        deadline,
      }
      const signature = await signPermit2Message(walletClient, account, message)
      setStatus('4/4: 执行存款...')
      const hash = await walletClient.writeContract({
        account,
        address: BANK_ADDRESS,
        abi: BANK_ABI,
        functionName: 'depositWithPermit2',
        args: [account, amountBigInt, nonce, deadline, signature],
      })
      setStatus('等待交易确认...')
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      if (receipt.status === 'success') {
        setStatus(`✅ 存款成功！交易哈希: ${hash}`)
        setAmount('')
        await refreshBalance()
      } else {
        setStatus('❌ 交易失败')
      }
    } catch (error: any) {
      console.error('Permit2 deposit failed:', error)
      setStatus(`❌ 存款失败: ${error.message || '未知错误'}`)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    if (account) {
      refreshBalance()
    }
  }, [account])

  if (!account) {
    return (
      <div style={{ padding: '20px', border: '1px solid #ccc', margin: '20px 0' }}>
        <h2>🔐 Permit2 签名存款</h2>
        <p>请先连接钱包</p>
      </div>
    )
  }

  return (
    <div style={{ padding: '20px', border: '1px solid #ccc', margin: '20px 0' }}>
      <h2>🔐 Permit2 签名存款</h2>
      <div style={{ marginBottom: '15px' }}><strong>用户地址:</strong> {account}</div>
      <div style={{ marginBottom: '15px' }}><strong>TTCoin 余额:</strong> {tokenBalance} TTC</div>
      <div style={{ marginBottom: '15px' }}>
        <strong>银行余额:</strong> {bankBalance} TTC
        <button onClick={refreshBalance} style={{ marginLeft: '10px' }}>🔄 刷新</button>
      </div>
      <div style={{ marginBottom: '15px' }}>
        <label>
          存款金额:
          <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="输入存款金额" disabled={isLoading} style={{ marginLeft: '10px', padding: '5px', width: '200px' }} />
        </label>
      </div>
      <button onClick={handlePermit2Deposit} disabled={isLoading} style={{ padding: '10px 20px' }}>
        {isLoading ? '处理中...' : '使用 Permit2 存款'}
      </button>
      {status && <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#f0f0f0' }}>{status}</div>}
      <div style={{ marginTop: '20px', fontSize: '14px', color: '#666' }}>
        <p><strong>说明：</strong></p>
        <ul>
          <li>Permit2 地址: {PERMIT2_ADDRESS}</li>
          <li>首次使用需要授权 Permit2 合约</li>
          <li>每次存款需要签名一次（无需 gas）</li>
        </ul>
      </div>
    </div>
  )
}
