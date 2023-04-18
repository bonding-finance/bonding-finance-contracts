const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");
const { numToBN } = require("../util");

describe("Perpetual bond factory", function () {
    async function deployFixture() {
        const [owner, other] = await ethers.getSigners();
        const Factory = await ethers.getContractFactory("PerpetualBondFactory");
        const factory = await Factory.deploy();
        const StETH = await ethers.getContractFactory("stETH");
        const stETH = await StETH.deploy(numToBN(100));
        const LpToken = await ethers.getContractFactory("LpToken");
        const lpToken = await LpToken.deploy(0);

        return { factory, stETH, lpToken, owner, other };
    }

    describe("Deployment", function () {
        it("Should set right owner", async function () {
            const { factory, owner } = await loadFixture(deployFixture);
            expect(await factory.owner()).to.equal(owner.address);
        });
    });

    describe("setFeeTo", function () {
        it("Should revert if !owner", async function () {
            const { factory, other } = await loadFixture(deployFixture);
            await expect(factory.connect(other).setFeeTo(other.address)).to.be.revertedWith(
                "UNAUTHORIZED"
            );
        });
        it("Should set feeTo", async function () {
            const { factory, other } = await loadFixture(deployFixture);
            await factory.setFeeTo(other.address);
            expect((await factory.feeInfo()).feeTo).to.equal(other.address);
        });
    });

    describe("setFee", function () {
        it("Should revert if !owner", async function () {
            const { factory, other } = await loadFixture(deployFixture);
            await expect(factory.connect(other).setFee(1)).to.be.revertedWith("UNAUTHORIZED");
        });

        it("Should revert if fee > 100", async function () {
            const { factory } = await loadFixture(deployFixture);
            await expect(factory.setFee(101)).to.be.revertedWith("Fee > 100");
        });

        it("Should set feeTo", async function () {
            const { factory } = await loadFixture(deployFixture);
            await factory.setFee(1);
            expect((await factory.feeInfo()).fee).to.equal(1);
        });
    });

    describe("Create perpetual bond", function () {
        describe("Validations", function () {
            it("Should revert if !owner", async function () {
                const { factory, other } = await loadFixture(deployFixture);
                await expect(
                    factory.connect(other).createBond(constants.AddressZero)
                ).to.be.revertedWith("UNAUTHORIZED");
            });

            it("Should revert if token address is 0", async function () {
                const { factory } = await loadFixture(deployFixture);
                await expect(factory.createBond(constants.AddressZero)).to.be.reverted;
            });
            it("Should revert if perpetual bond exists", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await factory.createBond(stETH.address);
                await expect(factory.createBond(stETH.address)).to.be.revertedWith("Bond exists");
            });
        });

        describe("Success", function () {
            it("Should create perpetual bond", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await factory.createBond(stETH.address);
                const vaultAddress = await factory.getBond(stETH.address);
                const Vault = await ethers.getContractFactory("PerpetualBondVault");
                const vault = Vault.attach(vaultAddress);
                expect(await factory.allBondsLength()).to.equal(1);
                expect(await factory.getBond(stETH.address)).to.equal(vault.address);
                expect(await vault.factory()).to.equal(factory.address);
                expect(await vault.token()).to.equal(stETH.address);
                expect(await vault.dToken()).to.not.equal(constants.AddressZero);
                expect(await vault.yToken()).to.not.equal(constants.AddressZero);
                expect(await vault.staking()).to.equal(constants.AddressZero);
                const BondToken = await ethers.getContractFactory("PerpetualBondToken");
                const dToken = BondToken.attach(await vault.dToken());
                const yToken = BondToken.attach(await vault.yToken());
                expect(await dToken.name()).to.equal(`${await stETH.symbol()} Deposit`);
                expect(await dToken.symbol()).to.equal(`${await stETH.symbol()}-D`);
                expect(await yToken.name()).to.equal(`${await stETH.symbol()} Yield`);
                expect(await yToken.symbol()).to.equal(`${await stETH.symbol()}-Y`);
            });
        });

        describe("Events", function () {
            it("Should emit BondCreated", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await expect(factory.createBond(stETH.address))
                    .to.emit(factory, "BondCreated")
                    .withArgs(stETH.address, await factory.getBond(stETH.address));
            });
        });
    });
});
