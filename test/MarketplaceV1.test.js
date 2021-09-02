const { ethers, upgrades } = require("hardhat");
const {BN, expectEvent, time, expectRevert} = require('@openzeppelin/test-helpers');
const { expect } = require("chai");

const toWei = (value) => web3.utils.toWei(String(value));
const LINK = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const Uniswap = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

describe("MarketplaceV1", () => {
    let marketplace;
    let swapper;
    let uniswap;
    let nftToken;
    let admin;
    let alice;
    let bob;
    let random;
    let date;
    let link;
    let dai;


    before(async () => {
        [admin, alice, bob, random] = await ethers.getSigners();
        const Marketplace = await ethers.getContractFactory("MarketplaceV1");
        const Swapper = await ethers.getContractFactory("ToolV1");
        const NFTToken = await ethers.getContractFactory("NFTToken");
        uniswap = await ethers.getContractAt("IRouter", Uniswap);
        link = await ethers.getContractAt("IERC20", LINK);
        dai = await ethers.getContractAt("IERC20", DAI);
        date = time.duration.days(10);

        nftToken = await NFTToken.deploy();
        await nftToken.deployed();
        swapper = await upgrades.deployProxy(Swapper, [admin.address]);
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
                await marketplace.connect(alice).sellItem(nftToken.address, 1, 0, Number(date), 0);
            } catch(e) {
                assert(e.toString().includes('Price must be greater than 0'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user enters a price less than 1.');
        });


        it("should not sell item if quantity is less than 1", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 1, 1, Number(date), 0);
            } catch(e) {
                assert(e.toString().includes('Can not sell 0 tokens'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user enters a quantity less than 1.');
        });


        it("should not be able to sell a token if you do not have enough tokens", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 0, 1, Number(date), 2);
            } catch(e) {
                assert(e.toString().includes('You do not have enough tokens'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user tries to sell more tokens than they owns.');
        });


        it("should not sell if the date is less than one day", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 0, 1, 0, 1);
            } catch(e) {
                assert(e.toString().includes('Time must be greater than 0'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when a user tries to sell more tokens than they owns.');
        });


        it("should sell a product if the marketplace does not have permission to use the tokens", async () => {
            await nftToken.createToken("test", 10, alice.address);
            let errStatus = false;
            try {
                await marketplace.connect(alice).sellItem(nftToken.address, 0, 1, Number(date), 1);
            } catch(e) {
                assert(e.toString().includes('No permissions on tokens'));
                errStatus = true;
            }
            assert(errStatus, 'No error occurred when the marketplace is not approved to use the tokens.');
        });


        it("should publish an offer", async () => {
            await nftToken.connect(alice).setApprovalForAll(marketplace.address, true);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 0, 1, Number(date), 1))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 0, 1, 1);
        });
    });

    describe("Buy", () => {
        it("Should have a positive balance DAI and LINK", async () => {
            let beforeBalanceDAI = await dai.balanceOf(bob.address);
            let beforeBalanceLINK = await dai.balanceOf(bob.address);
            await swapper.connect(bob).swapETHToToken([50, 50], [LINK, DAI], {value: toWei("1")});
            let currentBalanceDAI = await dai.balanceOf(bob.address);
            let currentBalanceLINK = await dai.balanceOf(bob.address);
            expect(Number(currentBalanceDAI)).to.gt(Number(beforeBalanceDAI));
            expect(Number(currentBalanceLINK)).to.gt(Number(beforeBalanceLINK));

            beforeBalanceDAI = await dai.balanceOf(random.address);
            beforeBalanceLINK = await dai.balanceOf(random.address);
            await swapper.connect(random).swapETHToToken([50, 50], [LINK, DAI], {value: toWei("1")});
            currentBalanceDAI = await dai.balanceOf(random.address);
            currentBalanceLINK = await dai.balanceOf(random.address);
            expect(Number(currentBalanceDAI)).to.gt(Number(beforeBalanceDAI));
            expect(Number(currentBalanceLINK)).to.gt(Number(beforeBalanceLINK));
        });


        it("should publish an offer", async () => {
            await nftToken.createToken("test", 10, alice.address);
            await nftToken.connect(alice).setApprovalForAll(marketplace.address, true);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 0, 1, Number(date), 5))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 0, 1, 5);

            await nftToken.createToken("test2", 1, alice.address);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 1, 1, Number(date), 1))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 1, 1, 1);

            await nftToken.createToken("test3", 1, alice.address);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 2, 1, Number(date), 1))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 2, 1, 1);

            await nftToken.createToken("test4", 1, alice.address);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 3, 1, Number(date), 1))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 3, 1, 1);
        });


        it("You should not buy if you are the owner of the item", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(alice).buyItem(0, DAI, alice.address);
            } catch(e) {
                assert(e.toString().includes('You are the owner'));
                errStatus = true;
            }
            assert(errStatus, 'You were not wrong when the owner tried to buy your item.');
        });


        it("Buy with DAI", async () => {
            let beforeBalance = await dai.balanceOf(bob.address);
            let beforeBalanceNFT = await nftToken.balanceOf(bob.address, 0);
            await dai.connect(bob).approve(marketplace.address, String(beforeBalance));

            await expect(marketplace.connect(bob).buyItem(0, DAI, alice.address))
            .to.emit(marketplace, 'BuyItem')
            .withArgs(alice.address, bob.address, 0, 1, 5);
            let currentBalanceNFT = await nftToken.balanceOf(bob.address, 0);
            expect(Number(currentBalanceNFT)).to.gt(Number(beforeBalanceNFT));
        });


        it("Buy with LINK", async () => {
            let beforeBalance = await link.balanceOf(bob.address);
            let beforeBalanceNFT = await nftToken.balanceOf(bob.address, 1);
            await link.connect(bob).approve(marketplace.address, String(beforeBalance));

            await expect(marketplace.connect(bob).buyItem(1, LINK, alice.address))
            .to.emit(marketplace, 'BuyItem')
            .withArgs(alice.address, bob.address, 1, 1, 1);
            let currentBalanceNFT = await nftToken.balanceOf(bob.address, 1);
            expect(Number(currentBalanceNFT)).to.gt(Number(beforeBalanceNFT));
        });


        it("Buy with ETH", async () => {
            let beforeBalanceNFT = await nftToken.balanceOf(bob.address, 2);
            await expect(marketplace.connect(bob).buyItem(2, ETH, alice.address, {value: toWei("1")}))
            .to.emit(marketplace, 'BuyItem')
            .withArgs(alice.address, bob.address, 2, 1, 1);
            let currentBalanceNFT = await nftToken.balanceOf(bob.address, 2);
            expect(Number(currentBalanceNFT)).to.gt(Number(beforeBalanceNFT));
        });


        it("You should not purchase an invalid item", async () => {
            let errStatus = false;
            try {
                await marketplace.connect(random).buyItem(2, DAI, alice.address);
            } catch(e) {
                assert(e.toString().includes('Product not in stock'));
                errStatus = true;
            }
            assert(errStatus, 'You did not make a mistake when you tried to purchase an unavailable item.');
        });
    });

    describe("Cancel Offer", () => {
        it("should cancel the offer", async () => {
            await nftToken.connect(alice).setApprovalForAll(marketplace.address, true);
            await expect(marketplace.connect(alice).sellItem(nftToken.address, 0, 1, Number(date), 1))
            .to.emit(marketplace, 'SellItem')
            .withArgs(alice.address, 0, 1, 1);

            await expect(marketplace.connect(alice).cancelOffer(0))
            .to.emit(marketplace, 'CancelOffer')
            .withArgs(alice.address, 0);
        });
    });
});