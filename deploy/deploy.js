const { ethers, upgrades } = require("hardhat");

async function main() {
// Deploying
const MarketplaceV1 = await ethers.getContractFactory("MarketplaceV1");
const instance = await upgrades.deployProxy(MarketplaceV1);
await instance.deployed();
}

main();