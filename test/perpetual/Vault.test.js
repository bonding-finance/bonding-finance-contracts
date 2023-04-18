const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");
const { numToBN } = require("../util");

describe("Perpetual Bonds", function () {
    async function deployFixture() {
        const accounts = await ethers.getSigners();
        const Factory = await ethers.getContractFactory("PerpetualBondFactory");
        const factory = await Factory.deploy();
        const StETH = await ethers.getContractFactory("stETH");
        const stETH = await StETH.deploy(0);

        return { factory, stETH, accounts };
    }

    async function createBond() {
        const { factory, stETH, accounts } = await loadFixture(deployFixture);
        await factory.createBond(stETH.address);
        const bondAddress = await factory.getBond(stETH.address);
        const Vault = await ethers.getContractFactory("PerpetualBondVault");
        const vault = Vault.attach(bondAddress);
        const BondToken = await ethers.getContractFactory("PerpetualBondToken");
        const dToken = BondToken.attach(await vault.dToken());
        const yToken = BondToken.attach(await vault.yToken());
        const Staking = await ethers.getContractFactory("PerpetualBondStaking");
        const staking = Staking.attach(await vault.staking());
        const [owner, other] = accounts;
        for (const account of [owner, other]) {
            await stETH.connect(account).mint(account.address, numToBN(100));
            await stETH.connect(account).approve(bondAddress, constants.MaxUint256);
            await dToken.connect(account).approve(bondAddress, constants.MaxUint256);
            await yToken.connect(account).approve(staking.address, constants.MaxUint256);
        }

        return { owner, other, factory, stETH, vault, dToken, yToken, staking };
    }

    describe("Mint", function () {
        describe("Validations", function () {
            it("Should revert if amount > balance", async function () {
                const { vault } = await createBond();
                await expect(vault.mint(numToBN(101))).to.be.reverted;
            });

            it("Should not allow mint except by vault", async function () {
                const { owner, yToken } = await createBond();
                await expect(yToken.mint(owner.address, 1)).to.be.revertedWith("!vault");
            });
        });

        describe("Success", function () {
            it("Should mint yToken", async function () {
                const { stETH, owner, vault, dToken, yToken } = await createBond();
                await vault.mint(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(10));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(90));
                expect(await dToken.balanceOf(owner.address)).to.equal(numToBN(10));
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
            });

            it("Should mint yToken with fee", async function () {
                const { factory, stETH, owner, other, vault, dToken, yToken } =
                    await createBond();
                await factory.setFeeTo(other.address);
                await factory.setFee(100);
                await vault.mint(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(9.9));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(90));
                expect(await stETH.balanceOf(other.address)).to.equal(numToBN(100.1));
                expect(await dToken.balanceOf(owner.address)).to.equal(numToBN(9.9));
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(9.9));
            });
        });

        describe("Events", function () {
            it("Should emit Mint", async function () {
                const { owner, vault } = await createBond();
                await expect(vault.mint(numToBN(10)))
                    .to.emit(vault, "Mint")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Redeem", function () {
        describe("Validations", function () {
            it("Should revert amount > balance", async function () {
                const { vault } = await createBond();
                await vault.mint(numToBN(10));
                await expect(vault.redeem(numToBN(11))).to.be.reverted;
            });

            it("Should not allow burn except by vault", async function () {
                const { owner, yToken } = await createBond();
                await expect(yToken.burn(owner.address, 1)).to.be.revertedWith("!vault");
            });
        });

        describe("Success", function () {
            it("Should redeem yToken", async function () {
                const { stETH, owner, vault, dToken, yToken } = await createBond();
                await vault.mint(numToBN(10));
                await vault.redeem(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(0));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(100));
                expect(await dToken.balanceOf(owner.address)).to.equal(0);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
            });

            it("Should redeem yToken with fee", async function () {
                const { factory, stETH, owner, other, vault, dToken, yToken } =
                    await createBond();
                await vault.mint(numToBN(10));
                await factory.setFeeTo(other.address);
                await factory.setFee(100);
                await vault.redeem(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(0));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(99.9));
                expect(await stETH.balanceOf(other.address)).to.equal(numToBN(100.1));
                expect(await dToken.balanceOf(owner.address)).to.equal(0);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Redeem", async function () {
                const { owner, vault } = await createBond();
                await vault.mint(numToBN(10));
                await expect(vault.redeem(numToBN(10)))
                    .to.emit(vault, "Redeem")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Pending yield", function () {
        it("Should be 0 when total deposits is 0", async function () {
            const { vault } = await createBond();
            expect(await vault.pendingRewards()).to.equal(0);
        });

        it("Should be 0 when balance = total deposits", async function () {
            const { vault } = await createBond();
            await vault.mint(numToBN(10));
            expect(await vault.pendingRewards()).to.equal(0);
        });

        it("Should be 1 when balance + 1", async function () {
            const { stETH, vault } = await createBond();
            await vault.mint(numToBN(10));
            await stETH.mint(vault.address, numToBN(1));
            expect(await vault.pendingRewards()).to.equal(numToBN(1));
        });
    });

    describe("Harvest", function () {
        describe("Validations", function () {
            it("Should not change if nothing staked", async function () {
                const { stETH, vault } = await createBond();
                await vault.mint(numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest()).to.be.revertedWith("totalStaked is 0");
            });

            it("Should not change accRewardsPerShare if pending rewards is 0", async function () {
                const { vault } = await createBond();
                await expect(vault.harvest()).to.not.emit(vault, "Harvest");
            });
        });

        describe("Success", function () {
            it("Should harvest", async function () {
                const { stETH, vault, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await vault.pendingRewards()).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Harvest", async function () {
                const { stETH, vault, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest())
                    .to.emit(vault, "Harvest")
                    .withArgs(numToBN(1));
            });
        });
    });
});
