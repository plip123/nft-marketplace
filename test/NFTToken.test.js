const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");



describe("NFTToken Test", () => {
    let nftToken;
    let admin;
    let alice;
    let bob;
    let random;


    before(async () => {
        [admin, alice, bob, random] = await ethers.getSigners();
        const NFTToken = await ethers.getContractFactory("NFTToken");

        nftToken = await NFTToken.deploy();
        await nftToken.deployed();
    });


    describe("Token", () => {
        it("should create a new token", async () => {
            await nftToken.createToken("token", 1, alice.address);
            expect(Number(await nftToken.balanceOf(alice.address, 0))).to.gt(0);
        });

        it("should be able to get the name of the token created", async () => {
            expect(await nftToken.tokens(0)).to.equal("token");
        });

        it("should not be able to transfer tokens without being approved", async () => {
            expect(await nftToken.isApprovedForAll(alice.address, admin.address)).to.equal(false);
        });

        it("should approve the approval to use tokens", async () => {
            await nftToken.connect(alice).setApprovalForAll(admin.address, true);
            expect(await nftToken.isApprovedForAll(alice.address, admin.address)).to.equal(true);
        });
    });
});