// 直接发送交易（不使用 Flashbots）- 用于测试网验证功能
require("dotenv").config();

const { ethers } = require("ethers");

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
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
    console.log("\n========== 直接发送交易（不使用 Flashbots）==========\n");

    const provider = await createProvider();
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

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

    // 获取当前 gas 价格
    const feeData = await provider.getFeeData();
    console.log("\n⛽ 当前 Gas 价格:");
    console.log("   maxFeePerGas:", ethers.formatUnits(feeData.maxFeePerGas || 0n, "gwei"), "gwei");
    console.log("   maxPriorityFeePerGas:", ethers.formatUnits(feeData.maxPriorityFeePerGas || 0n, "gwei"), "gwei");

    console.log("\n========== 发送交易 1: startPresale() ==========\n");

    // 交易 1: startPresale
    const tx1 = await openspaceNFT.startPresale({
      maxFeePerGas: feeData.maxFeePerGas,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
    });

    console.log("✅ 交易 1 已发送!");
    console.log("   交易哈希:", tx1.hash);
    console.log("   🔗 Etherscan: https://sepolia.etherscan.io/tx/" + tx1.hash);
    console.log("\n⏳ 等待确认...");

    const receipt1 = await tx1.wait();
    console.log("✅ 交易 1 已确认!");
    console.log("   区块号:", receipt1.blockNumber);
    console.log("   状态:", receipt1.status === 1 ? "✅ 成功" : "❌ 失败");
    console.log("   Gas Used:", receipt1.gasUsed.toString());

    console.log("\n⏳ 等待 2 秒后发送第二笔交易...\n");
    await new Promise(resolve => setTimeout(resolve, 2000));

    console.log("========== 发送交易 2: participateInPresale() ==========\n");

    // 交易 2: participateInPresale
    const tx2 = await openspaceNFT.participateInPresale({
      maxFeePerGas: feeData.maxFeePerGas,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
    });

    console.log("✅ 交易 2 已发送!");
    console.log("   交易哈希:", tx2.hash);
    console.log("   🔗 Etherscan: https://sepolia.etherscan.io/tx/" + tx2.hash);
    console.log("\n⏳ 等待确认...");

    const receipt2 = await tx2.wait();
    console.log("✅ 交易 2 已确认!");
    console.log("   区块号:", receipt2.blockNumber);
    console.log("   状态:", receipt2.status === 1 ? "✅ 成功" : "❌ 失败");
    console.log("   Gas Used:", receipt2.gasUsed.toString());

    console.log("\n========== 交易汇总 ==========\n");
    console.log("📝 交易 1 (startPresale):");
    console.log("   哈希:", tx1.hash);
    console.log("   区块:", receipt1.blockNumber);
    console.log("   状态:", receipt1.status === 1 ? "✅ 成功" : "❌ 失败");

    console.log("\n📝 交易 2 (participateInPresale):");
    console.log("   哈希:", tx2.hash);
    console.log("   区块:", receipt2.blockNumber);
    console.log("   状态:", receipt2.status === 1 ? "✅ 成功" : "❌ 失败");

    console.log("\n🎉 所有交易完成！\n");

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

