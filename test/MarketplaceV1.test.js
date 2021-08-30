const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("MarketplaceV1", () => {
    let marketplace;
    let admin;
    let alice;
    let bob;
    let random;

    before(async () => {
        [admin, alice, bob, random] = await ethers.getSigners();
        const Marketplace = await ethers.getContractFactory("MarketplaceV1");


        marketplace = await upgrades.deployProxy(Marketplace, [admin.address, admin.address]);
    });


    describe("Admin", () => {
        it("should not change the fee amount", async () => {
            let errStatus = false
            try {
                await marketplace.connect(alice).setFee(2);
            } catch(e) {
                assert(e.toString().includes('You are not the admin'));
                errStatus = true;
            }
            assert(errStatus, 'No mistake was made when a non-admin user tried to change the fee amount.');
        });


        it("should not change the recipient fee", async () => {
            let errStatus = false
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
            let errStatus = false
            try {
                await marketplace.connect(alice).sellItem(0, 0, 0);
            } catch(e) {
                assert(e.toString().includes('Price must be greater than 0'));
                errStatus = true;
            }
            assert(errStatus, 'No mistake was made when a non-admin user tried to change the fee amount.')
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