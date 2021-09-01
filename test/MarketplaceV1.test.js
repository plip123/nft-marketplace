const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");



describe("MarketplaceV1", () => {
    let marketplace;
    let nftToken;
    let admin;
    let alice;
    let bob;
    let random;
    const zeroAddress = ethers.constants.AddressZero;
    const etherAddress = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";


    before(async () => {
        [admin, alice, bob, random] = await ethers.getSigners();
        const Marketplace = await ethers.getContractFactory("MarketplaceV1");
        const NFTToken = await ethers.getContractFactory("NFTToken");

        nftToken = await NFTToken.deploy();
        await nftToken.deployed();
        marketplace = await upgrades.deployProxy(Marketplace, [admin.address, admin.address]);
    });


    describe("Admin", () => {
        it("should not change the fee amount", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).setFee(2);
            } catch(e) {
                assert(e.toString().includes('You are not the admin'));
                errStatus = true;
            }
            assert(errStatus, 'No mistake was made when a non-admin user tried to change the fee amount.');
        });


        it("should not change the recipient fee", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).setRecipientFee(alice.address);
            } catch(e) {
                assert(e.toString().includes('You are not the admin'));
                errStatus = true;
            }
            assert(errStatus, 'No mistake was made when a non-admin user tried to change the recipient fee.');
        });


        it("should change the fee amount", async () => {
            await marketplace.connect(admin).setFee(2);
            const [_, fee] = await marketplace.connect(admin).getFeeConfig();
            expect(2).to.equal(Number(fee));
        });


        it("should change the fee recipient", async () => {
            await marketplace.connect(admin).setRecipientFee(random.address);
            const [contractAdmin, _] = await marketplace.connect(admin).getFeeConfig();
            expect(random.address).to.equal(contractAdmin);
        });
    });

    describe("Sell", () => {
        it("should not sell item if price is less than 1", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 1, 0, 0);
            } catch(e) {
                assert(e.toString().includes('Price must be greater than 0'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user enters a price less than 1.');
        });


        it("should not sell item if quantity is less than 1", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 1, 1, 0);
            } catch(e) {
                assert(e.toString().includes('Can not sell 0 tokens'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user enters a quantity less than 1.');
        });


        it("should not be able to sell a token if you do not have enough tokens", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 0, 1, 2);
            } catch(e) {
                assert(e.toString().includes('You do not have enough tokens'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user tries to sell more tokens than they owns.');
        });


        it("should publish an offer", async () => {
            await nftToken.createToken("Test", 1, alice.address);
            await nftToken.connect(alice).setApprovalForAll(marketplace.address, true);
            //await marketplace.connect(alice).sellItem(nftToken.address, 0, 1, 1);
        });
    });

    describe("Buy", () => {
        it("", async () => {
            
        });
    });

    describe("Cancel Offer", () => {
        it("", async () => {
            
        });
    });
});