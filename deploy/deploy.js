const { ethers, upgrades } = require("hardhat");

async function main() {
// Deploying Marketplace
const MarketplaceV1 = await ethers.getContractFactory("MarketplaceV1");
const instance = await upgrades.deployProxy(MarketplaceV1);
await instance.deployed();

// Deploying Swapper
const ToolV1 = await ethers.getContractFactory("ToolV1");
const instance = await upgrades.deployProxy(ToolV1, ["0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"]);
await instance.deployed();
}

main();