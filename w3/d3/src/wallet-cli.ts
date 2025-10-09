import {
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  http,
  parseEther,
  formatEther,
  getAddress
} from 'viem'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import { erc20ABI } from '@wagmi/core'
import { rpc_url } from './constant'
import * as readline from 'readline'

// ERC20 ABI (简化版)
const erc20Abi = [
  {
    name: 'transfer',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'decimals',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }]
  },
  {
    name: 'symbol',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }]
  }
] as const

interface WalletState {
  privateKey?: string
  account?: any
  publicClient: any
  walletClient?: any
}

class ViemWalletCLI {
  private state: WalletState
  private rl: readline.Interface

  constructor() {
    this.state = {
      publicClient: createPublicClient({
        chain: sepolia,
        transport: http(rpc_url)
      })
    }
    
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    })
  }

  private question(prompt: string): Promise<string> {
    return new Promise((resolve) => {
      this.rl.question(prompt, resolve)
    })
  }

  // 1. 生成私钥
  async generatePrivateKey(): Promise<void> {
    console.log('\n🔑 生成新的私钥和账户...')
    
    this.state.privateKey = generatePrivateKey()
    this.state.account = privateKeyToAccount(this.state.privateKey as `0x${string}`)
    
    this.state.walletClient = createWalletClient({
      account: this.state.account,
      chain: sepolia,
      transport: http(rpc_url)
    })

    console.log(`✅ 私钥: ${this.state.privateKey}`)
    console.log(`✅ 地址: ${this.state.account.address}`)
    console.log('⚠️  请妥善保管私钥，不要泄露给任何人！')
  }

  // 导入钱包
  async importWallet(): Promise<void> {
    console.log('\n📥 导入现有钱包...')
    
    try {
      const privateKeyInput = await this.question('🔑 请输入私钥 (0x开头的64位十六进制): ')
      
      // 验证私钥格式
      if (!privateKeyInput.startsWith('0x') || privateKeyInput.length !== 66) {
        console.log('❌ 私钥格式错误！私钥应该是 0x 开头的 64 位十六进制字符串')
        return
      }
      
      // 验证是否为有效的十六进制
      const hexPattern = /^0x[0-9a-fA-F]{64}$/
      if (!hexPattern.test(privateKeyInput)) {
        console.log('❌ 私钥包含无效字符！只能包含 0-9 和 a-f')
        return
      }

      this.state.privateKey = privateKeyInput as `0x${string}`
      this.state.account = privateKeyToAccount(this.state.privateKey as `0x${string}`)
      
      this.state.walletClient = createWalletClient({
        account: this.state.account,
        chain: sepolia,
        transport: http(rpc_url)
      })

      console.log(`✅ 钱包导入成功!`)
      console.log(`✅ 地址: ${this.state.account.address}`)
      console.log('⚠️  请确保您拥有此私钥的合法使用权！')
      
    } catch (error) {
      console.log(`❌ 导入钱包失败: ${error}`)
    }
  }

  // 2. 查询余额
  async checkBalance(): Promise<void> {
    if (!this.state.account) {
      console.log('❌ 请先生成账户')
      return
    }

    console.log('\n💰 查询账户余额...')
    
    try {
      // 查询 ETH 余额
      const ethBalance = await this.state.publicClient.getBalance({
        address: this.state.account.address
      })
      
      console.log(`📊 ETH 余额: ${formatEther(ethBalance)} ETH`)
      console.log(`📊 地址: ${this.state.account.address}`)
      
      // 询问是否查询 ERC20 余额
      console.log('\n💡 常用测试代币地址 (Sepolia):')
      console.log('   USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238')
      console.log('   USDT: 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0')
      console.log('   LINK: 0x779877A7B0D9E8603169DdbD7836e478b4624789')
      const tokenAddress = await this.question('🪙 输入 ERC20 代币地址 (留空跳过): ')
      
      if (tokenAddress.trim()) {
        try {
          const contractAddress = getAddress(tokenAddress.trim())
          
          // 首先检查是否为合约地址
          const bytecode = await this.state.publicClient.getBytecode({
            address: contractAddress
          })
          
          if (!bytecode || bytecode === '0x') {
            console.log('❌ 输入的地址不是合约地址，请输入有效的 ERC20 代币合约地址')
            return
          }
          
          const tokenBalance = await this.state.publicClient.readContract({
            address: contractAddress,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [this.state.account.address]
          })
          
          const decimals = await this.state.publicClient.readContract({
            address: contractAddress,
            abi: erc20Abi,
            functionName: 'decimals'
          })
          
          const symbol = await this.state.publicClient.readContract({
            address: contractAddress,
            abi: erc20Abi,
            functionName: 'symbol'
          })
          
          const formattedBalance = Number(tokenBalance) / Math.pow(10, decimals)
          console.log(`🪙 ${symbol} 余额: ${formattedBalance} ${symbol}`)
        } catch (error: any) {
          if (error.message?.includes('returned no data')) {
            console.log('❌ 该合约不是标准的 ERC20 代币合约，或者不支持查询的函数')
          } else if (error.message?.includes('invalid address')) {
            console.log('❌ 无效的地址格式')
          } else {
            console.log(`❌ 查询代币余额失败: ${error.shortMessage || error.message}`)
          }
          console.log('💡 提示：请确保输入的是有效的 ERC20 代币合约地址')
        }
      }
    } catch (error) {
      console.log(`❌ 查询余额失败: ${error}`)
    }
  }

  // 3. 构建 ERC20 转账交易
  async buildERC20Transaction(): Promise<any> {
    if (!this.state.account || !this.state.walletClient) {
      console.log('❌ 请先生成账户')
      return null
    }

    console.log('\n🔄 构建 ERC20 转账交易...')
    
    try {
      console.log('\n💡 常用测试代币地址 (Sepolia):')
      console.log('   USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238')
      console.log('   USDT: 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0')
      console.log('   LINK: 0x779877A7B0D9E8603169DdbD7836e478b4624789')
      
      const tokenAddress = await this.question('🪙 ERC20 代币地址: ')
      const toAddress = await this.question('📬 接收方地址: ')
      const amountStr = await this.question('💵 转账数量: ')
      
      const contractAddress = getAddress(tokenAddress.trim())
      
      // 检查是否为合约地址
      const bytecode = await this.state.publicClient.getBytecode({
        address: contractAddress
      })
      
      if (!bytecode || bytecode === '0x') {
        console.log('❌ 输入的地址不是合约地址，请输入有效的 ERC20 代币合约地址')
        return null
      }
      
      // 获取代币 decimals
      const decimals = await this.state.publicClient.readContract({
        address: contractAddress,
        abi: erc20Abi,
        functionName: 'decimals'
      })
      
      // 计算实际转账金额 (考虑 decimals)
      const amount = BigInt(Number(amountStr) * Math.pow(10, decimals))
      
      // 编码函数调用数据
      const data = encodeFunctionData({
        abi: erc20Abi,
        functionName: 'transfer',
        args: [getAddress(toAddress.trim()), amount]
      })
      
      // 准备交易请求
      const request = await this.state.walletClient.prepareTransactionRequest({
        account: this.state.account,
        to: contractAddress,
        data,
        type: 'eip1559'
      })
      
      console.log('\n📋 交易详情:')
      console.log(`   代币地址: ${tokenAddress.trim()}`)
      console.log(`   接收方: ${toAddress.trim()}`)
      console.log(`   数量: ${amountStr}`)
      console.log(`   Gas 限制: ${request.gas}`)
      console.log(`   Max Fee: ${request.maxFeePerGas} wei`)
      console.log(`   Priority Fee: ${request.maxPriorityFeePerGas} wei`)
      
      return request
    } catch (error) {
      console.log(`❌ 构建交易失败: ${error}`)
      return null
    }
  }

  // 4. 签名交易
  async signTransaction(request: any): Promise<string | null> {
    if (!this.state.walletClient) {
      console.log('❌ 钱包客户端未初始化')
      return null
    }

    console.log('\n✍️ 签名交易...')
    
    try {
      const signature = await this.state.walletClient.signTransaction(request)
      console.log(`✅ 交易已签名`)
      console.log(`🔏 签名数据: ${signature.slice(0, 20)}...`)
      return signature
    } catch (error) {
      console.log(`❌ 签名失败: ${error}`)
      return null
    }
  }

  // 5. 发送交易
  async sendTransaction(signature: string): Promise<void> {
    if (!this.state.walletClient) {
      console.log('❌ 钱包客户端未初始化')
      return
    }

    console.log('\n🚀 发送交易到 Sepolia 网络...')
    
    try {
      const hash = await this.state.walletClient.sendRawTransaction({
        serializedTransaction: signature
      })
      
      console.log(`✅ 交易已发送!`)
      console.log(`🔗 交易哈希: ${hash}`)
      console.log(`🌐 区块浏览器: https://sepolia.etherscan.io/tx/${hash}`)
    } catch (error) {
      console.log(`❌ 发送交易失败: ${error}`)
    }
  }

  // 完整的 ERC20 转账流程
  async erc20TransferFlow(): Promise<void> {
    console.log('\n🎯 开始 ERC20 转账流程...')
    
    // 构建交易
    const request = await this.buildERC20Transaction()
    if (!request) return
    
    // 确认交易
    const confirm = await this.question('\n❓ 确认发送交易? (y/N): ')
    if (confirm.toLowerCase() !== 'y') {
      console.log('❌ 交易已取消')
      return
    }
    
    // 签名交易
    const signature = await this.signTransaction(request)
    if (!signature) return
    
    // 发送交易
    await this.sendTransaction(signature)
  }

  // 主菜单
  async showMenu(): Promise<void> {
    console.log('\n' + '='.repeat(50))
    console.log('🦄 Viem 命令行钱包')
    console.log('='.repeat(50))
    console.log('1. 生成新钱包')
    console.log('2. 导入钱包')
    console.log('3. 查询余额')
    console.log('4. ERC20 转账')
    console.log('5. 显示账户信息')
    console.log('6. 退出')
    console.log('='.repeat(50))
    
    const choice = await this.question('请选择操作 (1-6): ')
    
    switch (choice.trim()) {
      case '1':
        await this.generatePrivateKey()
        break
      case '2':
        await this.importWallet()
        break
      case '3':
        await this.checkBalance()
        break
      case '4':
        await this.erc20TransferFlow()
        break
      case '5':
        this.showAccountInfo()
        break
      case '6':
        console.log('👋 再见!')
        this.rl.close()
        return
      default:
        console.log('❌ 无效选择')
    }
    
    // 继续显示菜单
    await this.showMenu()
  }

  // 显示账户信息
  showAccountInfo(): void {
    if (!this.state.account) {
      console.log('❌ 未生成账户')
      return
    }
    
    console.log('\n👤 账户信息:')
    console.log(`   地址: ${this.state.account.address}`)
    console.log(`   私钥: ${this.state.privateKey}`)
    console.log(`   类型: ${this.state.account.type}`)
  }

  // 启动钱包
  async start(): Promise<void> {
    console.log('🚀 欢迎使用 Viem 命令行钱包!')
    console.log('📡 连接到 Sepolia 测试网络')
    await this.showMenu()
  }
}

// 启动钱包
const wallet = new ViemWalletCLI()
wallet.start().catch(console.error)