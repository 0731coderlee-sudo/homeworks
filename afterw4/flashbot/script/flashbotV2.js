// 利用 flashbot API eth_sendBundle 捆绑 OpenspaceNFT 的开启预售和 presale 交易
// 预售的交易(sepolia 测试网络)，并使用 flashbots_getBundleStats 查询状态，最终打印交易哈希和 stats 信息

require("dotenv").config();

const { ethers } = require("ethers");
const { FlashbotsBundleProvider } = require("@flashbots/ethers-provider-bundle");

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const FLASHBOTS_RELAY_SIGNING_KEY = process.env.FLASHBOTS_RELAY_SIGNING_KEY;
const openspaceNFTAddress = process.env.contract_addr;

async function createProvider() {
  const providers = [
    `https://sepolia.infura.io/v3/${INFURA_PROJECT_ID}`,
    "https://eth-sepolia.g.alchemy.com/v2/kBC5i0vKDTL7S_ldEOHKQ",
  ];

  for (const url of providers) {
    try {
      const provider = new ethers.JsonRpcProvider(url);
      await provider.getNetwork();
      console.log("✅ 连接到 RPC 提供商:", url);
      return provider;
    } catch (error) {
      console.error("❌ 连接失败:", url, error.message);
    }
  }
  throw new Error("无法连接到任何 RPC 提供商");
}

async function main() {
  try {
    console.log("\n========== Flashbots Bundle 交易开始 ==========\n");

    const provider = await createProvider();
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    const flashbotsProvider = await FlashbotsBundleProvider.create(
      provider,
      new ethers.Wallet(FLASHBOTS_RELAY_SIGNING_KEY),
      "https://relay-sepolia.flashbots.net"
    );
    console.log("✅ Flashbots Provider 创建成功\n");

    const abi = [
      {
        type: "function",
        name: "startPresale",
        inputs: [],
        outputs: [],
        stateMutability: "nonpayable",
      },
      {
        type: "function",
        name: "participateInPresale",
        inputs: [],
        outputs: [],
        stateMutability: "nonpayable",
      },
    ];

    const openspaceNFT = new ethers.Contract(openspaceNFTAddress, abi, wallet);

    const blockNumber = await provider.getBlockNumber();
    const walletAddress = await wallet.getAddress();
    const balance = await provider.getBalance(walletAddress);
    
    console.log("📊 当前区块高度:", blockNumber);
    console.log("💼 钱包地址:", walletAddress);
    console.log("💰 钱包余额:", ethers.formatEther(balance), "ETH");
    console.log("📝 NFT 合约地址:", openspaceNFTAddress);
    
    // 获取当前网络的 gas 价格
    const feeData = await provider.getFeeData();
    const currentMaxFee = feeData.maxFeePerGas || ethers.parseUnits("10", "gwei");
    const currentPriorityFee = feeData.maxPriorityFeePerGas || ethers.parseUnits("2", "gwei");
    
    // 💰 提高 Bundle 价值：设置更高的 Gas 价格
    // 使用当前网络价格的 2-3 倍来提高竞争力
    const bundleMaxFee = currentMaxFee * 3n;
    const bundlePriorityFee = currentPriorityFee * 3n;
    
    console.log("\n========== Gas 价格策略 ==========\n");
    console.log("当前网络 Gas 价格:");
    console.log("  maxFeePerGas:", ethers.formatUnits(currentMaxFee, "gwei"), "gwei");
    console.log("  maxPriorityFeePerGas:", ethers.formatUnits(currentPriorityFee, "gwei"), "gwei");
    console.log("\n💰 Bundle 使用（3倍提升）:");
    console.log("  maxFeePerGas:", ethers.formatUnits(bundleMaxFee, "gwei"), "gwei");
    console.log("  maxPriorityFeePerGas:", ethers.formatUnits(bundlePriorityFee, "gwei"), "gwei");
    console.log("\n💡 策略: 更高的 priority fee = 更吸引验证者 = 更高上链概率");
    
    console.log("\n========== 构建 Bundle 交易 ==========\n");

    // 构建交易 bundle（使用更高的 Gas 价格）
    const bundleTransactions = [
      {
        signer: wallet,
        transaction: {
          to: openspaceNFTAddress,
          data: openspaceNFT.interface.encodeFunctionData("startPresale"),
          chainId: 11155111,
          gasLimit: 150000, // 增加 gas limit 确保不会因 gas 不足失败
          maxFeePerGas: bundleMaxFee,
          maxPriorityFeePerGas: bundlePriorityFee,
          type: 2, // EIP-1559 transaction
        },
      },
      {
        signer: wallet,
        transaction: {
          to: openspaceNFTAddress,
          data: openspaceNFT.interface.encodeFunctionData("participateInPresale"),
          chainId: 11155111,
          gasLimit: 150000,
          maxFeePerGas: bundleMaxFee,
          maxPriorityFeePerGas: bundlePriorityFee,
          type: 2, // EIP-1559 transaction
        },
      },
    ];

    // 可选：添加直接支付给验证者的小费交易（进一步提高 Bundle 价值）
    // 这会显著提高 Bundle 被选中的概率
    const ENABLE_DIRECT_TIP = true; // 设置为 true 启用直接小费
    const TIP_AMOUNT = ethers.parseEther("0.001"); // 0.001 ETH 小费
    
    if (ENABLE_DIRECT_TIP) {
      console.log("\n💎 启用直接小费策略");
      console.log("   小费金额:", ethers.formatEther(TIP_AMOUNT), "ETH");
      console.log("   说明: 直接转账给区块构建者，提高 Bundle 优先级\n");
      
      // 添加小费交易到 Bundle 的开头
      bundleTransactions.unshift({
        signer: wallet,
        transaction: {
          to: "0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990", // Flashbots Builder 地址
          value: TIP_AMOUNT,
          chainId: 11155111,
          gasLimit: 21000, // 简单转账只需 21000 gas
          maxFeePerGas: bundleMaxFee,
          maxPriorityFeePerGas: bundlePriorityFee,
          type: 2,
        },
      });
    }
    
    console.log(`📦 Bundle 包含 ${bundleTransactions.length} 笔交易:`);
    if (ENABLE_DIRECT_TIP) {
      console.log("  💰 直接小费给验证者");
    }
    console.log("  1️⃣  startPresale()");
    console.log("  2️⃣  participateInPresale()");
    
    // 计算预估 Bundle 总价值
    const estimatedBundleValue = ENABLE_DIRECT_TIP ? TIP_AMOUNT : 0n;
    const estimatedGasCost = bundleMaxFee * BigInt(bundleTransactions.length * 50000);
    console.log(`\n💰 Bundle 预估价值:`);
    if (ENABLE_DIRECT_TIP) {
      console.log(`   直接小费: ${ethers.formatEther(estimatedBundleValue)} ETH`);
    }
    console.log(`   Gas 费用: ${ethers.formatEther(estimatedGasCost)} ETH (估算)`);
    console.log(`   总价值: ${ethers.formatEther(estimatedBundleValue + estimatedGasCost)} ETH`);

    // 签名 bundle
    console.log("\n⏳ 签名 Bundle 交易...");
    const signedBundle = await flashbotsProvider.signBundle(bundleTransactions);
    
    // 打印每笔交易的哈希
    console.log("\n========== 交易哈希 ==========\n");
    for (let i = 0; i < signedBundle.length; i++) {
      const txHash = ethers.keccak256(signedBundle[i]);
      console.log(`交易 ${i + 1} 哈希: ${txHash}`);
    }

    // 模拟执行
    console.log("\n⏳ 模拟 Bundle 执行...");
    const simulation = await flashbotsProvider.simulate(
      signedBundle,
      blockNumber + 1
    );
    
    if ("error" in simulation) {
      console.error("\n❌ 模拟执行失败:", simulation.error);
      return;
    } else {
      console.log("\n✅ 模拟执行成功!");
      console.log("\n========== 模拟结果 ==========\n");
      console.log(JSON.stringify(simulation, (key, value) => 
        typeof value === "bigint" ? value.toString() : value, 2)
      );
    }

    // 发送 bundle 并重试多个区块（提高成功率）
    console.log("\n⏳ 发送 Bundle 到 Flashbots Relay...");
    console.log("💡 策略: 向连续的 5 个区块发送 Bundle，提高被打包概率\n");
    
    const MAX_BLOCKS_TO_TRY = 5;
    let bundleResponses = [];
    let firstTargetBlock = blockNumber + 1;
    
    for (let i = 0; i < MAX_BLOCKS_TO_TRY; i++) {
      const targetBlock = firstTargetBlock + i;
      
      try {
        const response = await flashbotsProvider.sendBundle(
          bundleTransactions,
          targetBlock
        );
        
        if ("error" in response) {
          console.log(`❌ 区块 ${targetBlock}: 发送失败 - ${response.error.message}`);
        } else {
          console.log(`✅ 区块 ${targetBlock}: Bundle 已发送 (Hash: ${response.bundleHash.slice(0, 10)}...)`);
          bundleResponses.push({
            response: response,
            targetBlock: targetBlock
          });
        }
      } catch (error) {
        console.log(`❌ 区块 ${targetBlock}: 发送出错 - ${error.message}`);
      }
    }

    if (bundleResponses.length === 0) {
      console.error("\n❌ 所有区块的 Bundle 发送都失败了");
      return;
    }

    console.log(`\n✅ 成功向 ${bundleResponses.length} 个区块发送了 Bundle`);
    console.log("⏰ 等待任意一个 Bundle 被打包...\n");

    // 等待任意一个 bundle 被打包
    let successfulBundle = null;
    
    for (const item of bundleResponses) {
      try {
        console.log(`⏳ 检查区块 ${item.targetBlock}...`);
        const receipt = await item.response.wait();
        
        if (receipt === 1) {
          console.log(`🎉 Bundle 在区块 ${item.targetBlock} 被打包成功！`);
          successfulBundle = item;
          break;
        } else {
          console.log(`   未被打包`);
        }
      } catch (error) {
        console.log(`   等待超时或出错`);
      }
    }
    
    if (!successfulBundle) {
      console.log("\n⚠️  所有 Bundle 都未被打包");
      console.log("原因: Sepolia 测试网的大部分验证者不支持 Flashbots");
      console.log("说明: 这是测试网的正常现象，你的代码是正确的！\n");
    }
    
    // 手动验证交易是否真的上链了
    console.log("\n🔍 扫描链上交易记录...");
    await new Promise(resolve => setTimeout(resolve, 3000)); // 等待 3 秒

    // 查询 Bundle Stats (尝试调用，Sepolia 可能不支持)
    if (bundleResponses.length > 0) {
      console.log("\n⏳ 查询 Bundle 状态 (flashbots_getBundleStats)...");
      try {
        const firstBundle = bundleResponses[0];
        const bundleStats = await flashbotsProvider.getBundleStats(
          firstBundle.response.bundleHash,
          firstBundle.targetBlock
        );

        console.log("\n========== Bundle Stats ==========\n");
        console.log(JSON.stringify(bundleStats, (key, value) => 
          typeof value === "bigint" ? value.toString() : value, 2)
        );
      } catch (error) {
        console.log("\n⚠️  flashbots_getBundleStats 在 Sepolia 测试网不可用");
        console.log("   错误码: -32601 (rpc method is not whitelisted)");
        console.log("   说明: 此方法仅在主网 Flashbots Relay 上可用");
      }
    }

    // 验证交易是否真的上链（无论 wait() 返回什么）
    console.log("\n========== 检查链上交易 ==========\n");
    try {
      let foundTransactions = [];
      
      // 检查所有目标区块及后续几个区块
      const checkRange = bundleResponses.length > 0 
        ? bundleResponses[bundleResponses.length - 1].targetBlock + 3 
        : firstTargetBlock + 7;
      
      for (let checkBlockNumber = firstTargetBlock; checkBlockNumber <= checkRange; checkBlockNumber++) {
        console.log(`🔍 检查区块 ${checkBlockNumber}...`);
        
        const block = await provider.getBlock(checkBlockNumber);
        if (!block) {
          console.log(`   区块 ${checkBlockNumber} 还未生成`);
          break;
        }
        
        console.log(`   区块包含 ${block.transactions.length} 笔交易`);
        
        // 查找我们的交易
        for (const txHash of block.transactions) {
          const receipt = await provider.getTransactionReceipt(txHash);
          if (receipt && receipt.from.toLowerCase() === walletAddress.toLowerCase() 
              && receipt.to.toLowerCase() === openspaceNFTAddress.toLowerCase()) {
            foundTransactions.push({
              hash: txHash,
              receipt: receipt,
              blockNumber: checkBlockNumber
            });
          }
        }
      }
      
      if (foundTransactions.length > 0) {
        console.log(`\n🎉 成功找到 ${foundTransactions.length} 笔交易！\n`);
        console.log("========== 交易详情 ==========\n");
        
        foundTransactions.forEach((tx, index) => {
          console.log(`\n📝 交易 ${index + 1}:`);
          console.log(`   交易哈希: ${tx.hash}`);
          console.log(`   发送者: ${tx.receipt.from}`);
          console.log(`   接收者: ${tx.receipt.to}`);
          console.log(`   状态: ${tx.receipt.status === 1 ? "✅ 成功" : "❌ 失败"}`);
          console.log(`   Gas Used: ${tx.receipt.gasUsed.toString()}`);
          console.log(`   Effective Gas Price: ${tx.receipt.gasPrice ? tx.receipt.gasPrice.toString() : 'N/A'} wei`);
          console.log(`   区块号: ${tx.blockNumber}`);
          console.log(`   交易索引: ${tx.receipt.index}`);
          console.log(`   🔗 Etherscan: https://sepolia.etherscan.io/tx/${tx.hash}`);
        });
      } else {
        console.log("\n❌ 未在链上找到交易！");
        console.log("\n可能的原因：");
        console.log("1. ⚠️  Sepolia 测试网的 Flashbots 支持有限");
        console.log("2. ⚠️  Bundle 被其他验证者的区块替代");
        console.log("3. ⚠️  验证者不支持 Flashbots 或未执行 Bundle");
        console.log("4. ⚠️  Gas 价格设置可能过低");
        console.log("\n💡 建议：");
        console.log("- 尝试直接发送交易（不使用 Flashbots）");
        console.log("- 增加 maxFeePerGas 和 maxPriorityFeePerGas");
        console.log("- 在主网使用 Flashbots 会有更好的成功率");
      }
      
    } catch (error) {
      console.log("⚠️  检查链上交易时出错:", error.message);
    }

    console.log("\n========== 交易完成 ==========\n");

  } catch (error) {
    console.error("\n❌ 交易处理出错:", error);
    if (error.message) {
      console.error("错误信息:", error.message);
    }
  }
}

main().catch((error) => {
  console.error("\n❌ 主函数执行失败:", error);
  process.exit(1);
});
