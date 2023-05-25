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

    describe("setPaused", function () {
        it("Should revert if !owner", async function () {
            const { factory, other, stETH } = await loadFixture(deployFixture);
            await factory.createVault(stETH.address);
            await expect(factory.connect(other).setPaused(true)).to.be.revertedWith(
                "UNAUTHORIZED"
            );
        });

        it("Should pause", async function () {
            const { factory, stETH } = await loadFixture(deployFixture);
            await factory.createVault(stETH.address);
            const vaultAddress = await factory.getVault(stETH.address);
            const Vault = await ethers.getContractFactory("PerpetualBondVault");
            const vault = Vault.attach(vaultAddress);
            await factory.setPaused(true);
            await expect(vault.deposit(0)).to.be.revertedWith("paused");
            await expect(vault.redeem(0)).to.be.revertedWith("paused");
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

    describe("Set fees", function () {
        describe("Validations", function () {
            it("Should revert if !owner", async function () {
                const { factory, other } = await loadFixture(deployFixture);
                await expect(factory.connect(other).setVaultFee(1)).to.be.revertedWith(
                    "UNAUTHORIZED"
                );
            });

            it("Should revert if fee > 100", async function () {
                const { factory } = await loadFixture(deployFixture);
                await expect(factory.setVaultFee(101)).to.be.revertedWith("Fee > 100");
                await expect(factory.setSurplusFee(10001)).to.be.revertedWith("Fee > 10000");
            });
        });

        describe("Success", function () {
            it("Should set fees", async function () {
                const { factory } = await loadFixture(deployFixture);
                await factory.setVaultFee(1);
                await factory.setSurplusFee(1);
                expect((await factory.feeInfo()).vaultFee).to.equal(1);
                expect((await factory.feeInfo()).surplusFee).to.equal(1);
            });
        });
    });

    describe("Create perpetual bond", function () {
        describe("Validations", function () {
            it("Should revert if !owner", async function () {
                const { factory, other } = await loadFixture(deployFixture);
                await expect(
                    factory.connect(other).createVault(constants.AddressZero)
                ).to.be.revertedWith("UNAUTHORIZED");
            });

            it("Should revert if token address is 0", async function () {
                const { factory } = await loadFixture(deployFixture);
                await expect(factory.createVault(constants.AddressZero)).to.be.reverted;
            });
            it("Should revert if perpetual bond exists", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await factory.createVault(stETH.address);
                await expect(factory.createVault(stETH.address)).to.be.revertedWith("Vault exists");
            });
        });

        describe("Success", function () {
            it("Should create perpetual bond", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await factory.createVault(stETH.address);
                const vaultAddress = await factory.getVault(stETH.address);
                const Vault = await ethers.getContractFactory("PerpetualBondVault");
                const vault = Vault.attach(vaultAddress);
                expect(await factory.allVaultsLength()).to.equal(1);
                expect(await factory.getVault(stETH.address)).to.equal(vault.address);
                expect(await vault.factory()).to.equal(factory.address);
                expect(await vault.token()).to.equal(stETH.address);
                expect(await vault.dToken()).to.not.equal(constants.AddressZero);
                expect(await vault.yToken()).to.not.equal(constants.AddressZero);
                expect(await vault.staking()).to.equal(constants.AddressZero);
                const BondToken = await ethers.getContractFactory("BondToken");
                const dToken = BondToken.attach(await vault.dToken());
                const yToken = BondToken.attach(await vault.yToken());
                expect(await dToken.name()).to.equal(`${await stETH.symbol()} Deposit Token`);
                expect(await dToken.symbol()).to.equal(`${await stETH.symbol()}-D`);
                expect(await yToken.name()).to.equal(`${await stETH.symbol()} Yield Token`);
                expect(await yToken.symbol()).to.equal(`${await stETH.symbol()}-Y`);
            });
        });

        describe("Events", function () {
            it("Should emit VaultCreated", async function () {
                const { factory, stETH } = await loadFixture(deployFixture);
                await expect(factory.createVault(stETH.address))
                    .to.emit(factory, "VaultCreated")
                    .withArgs(stETH.address, await factory.getVault(stETH.address));
            });
        });
    });
});
