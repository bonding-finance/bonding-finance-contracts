const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");
const { numToBN } = require("../util");

describe("Perpetual bond vault", function () {
    async function deployFixture() {
        const accounts = await ethers.getSigners();
        const Factory = await ethers.getContractFactory("PerpetualBondFactory");
        const factory = await Factory.deploy();
        const StETH = await ethers.getContractFactory("stETH");
        const stETH = await StETH.deploy(0);
        const LpToken = await ethers.getContractFactory("LpToken");
        const lpToken = await LpToken.deploy(0);

        return { factory, stETH, lpToken, accounts };
    }

    async function createVault() {
        const { factory, stETH, lpToken, accounts } = await loadFixture(deployFixture);
        await factory.createVault(stETH.address);
        const vaultAddress = await factory.getVault(stETH.address);
        const Vault = await ethers.getContractFactory("PerpetualBondVault");
        const vault = Vault.attach(vaultAddress);
        const BondToken = await ethers.getContractFactory("PerpetualBondToken");
        const dToken = BondToken.attach(await vault.dToken());
        const yToken = BondToken.attach(await vault.yToken());
        const Staking = await ethers.getContractFactory("PerpetualBondStaking");
        const staking = await Staking.deploy(vault.address, lpToken.address);
        const [owner, other, feeTo] = accounts;
        for (const account of [owner, other]) {
            await stETH.connect(account).mint(account.address, numToBN(100));
            await stETH.connect(account).approve(vaultAddress, constants.MaxUint256);
            await dToken.connect(account).approve(vaultAddress, constants.MaxUint256);
            await yToken.connect(account).approve(staking.address, constants.MaxUint256);
        }

        return { owner, other, feeTo, factory, stETH, lpToken, vault, dToken, yToken, staking };
    }

    describe("Mint", function () {
        describe("Validations", function () {
            it("Should revert if amount > balance", async function () {
                const { vault } = await createVault();
                await expect(vault.mint(numToBN(101))).to.be.reverted;
            });

            it("Should not allow mint except by vault", async function () {
                const { owner, yToken } = await createVault();
                await expect(yToken.mint(owner.address, 1)).to.be.revertedWith("!vault");
            });

            it("Should return early if amount is 0", async function () {
                const { vault } = await createVault();
                await expect(vault.mint(0)).to.not.emit(vault, "Mint");
            });
        });

        describe("Success", function () {
            it("Should mint yToken", async function () {
                const { stETH, owner, vault, dToken, yToken } = await createVault();
                await vault.mint(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(10));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(90));
                expect(await dToken.balanceOf(owner.address)).to.equal(numToBN(10));
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
            });

            it("Should mint yToken with fee", async function () {
                const { factory, stETH, owner, vault, dToken, yToken } = await createVault();
                await factory.setFee(100);
                await vault.mint(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(9.9));
                expect(await vault.fees()).to.equal(numToBN(0.1));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(90));
                expect(await dToken.balanceOf(owner.address)).to.equal(numToBN(9.9));
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(9.9));
            });
        });

        describe("Events", function () {
            it("Should emit Mint", async function () {
                const { owner, vault } = await createVault();
                await expect(vault.mint(numToBN(10)))
                    .to.emit(vault, "Mint")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Redeem", function () {
        describe("Validations", function () {
            it("Should revert amount > balance", async function () {
                const { vault } = await createVault();
                await vault.mint(numToBN(10));
                await expect(vault.redeem(numToBN(11))).to.be.reverted;
            });

            it("Should not allow burn except by vault", async function () {
                const { owner, yToken } = await createVault();
                await expect(yToken.burn(owner.address, 1)).to.be.revertedWith("!vault");
            });

            it("Should return early if amount is 0", async function () {
                const { vault } = await createVault();
                await expect(vault.redeem(0)).to.not.emit(vault, "Redeem");
            });
        });

        describe("Success", function () {
            it("Should redeem yToken", async function () {
                const { stETH, owner, vault, dToken, yToken } = await createVault();
                await vault.mint(numToBN(10));
                await vault.redeem(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(0));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(100));
                expect(await dToken.balanceOf(owner.address)).to.equal(0);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
            });

            it("Should redeem yToken with fee", async function () {
                const { factory, stETH, owner, other, vault, dToken, yToken } = await createVault();
                await vault.mint(numToBN(10));
                await factory.setFeeTo(other.address);
                await factory.setFee(100);
                await vault.redeem(numToBN(10));
                expect(await vault.totalDeposits()).to.equal(numToBN(0));
                expect(await vault.fees()).to.equal(numToBN(0.1));
                expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(99.9));
                expect(await dToken.balanceOf(owner.address)).to.equal(0);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Redeem", async function () {
                const { owner, vault } = await createVault();
                await vault.mint(numToBN(10));
                await expect(vault.redeem(numToBN(10)))
                    .to.emit(vault, "Redeem")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Pending yield", function () {
        it("Should be 0 when total deposits is 0", async function () {
            const { vault } = await createVault();
            expect(await vault.pendingRewards()).to.equal(0);
        });

        it("Should be 0 when balance = total deposits", async function () {
            const { vault } = await createVault();
            await vault.mint(numToBN(10));
            expect(await vault.pendingRewards()).to.equal(0);
        });

        it("Should be 1 when balance + 1", async function () {
            const { stETH, vault } = await createVault();
            await vault.mint(numToBN(10));
            await stETH.mint(vault.address, numToBN(1));
            expect(await vault.pendingRewards()).to.equal(numToBN(1));
        });

        it("Should ignore fees", async function () {
            const { factory, other, stETH, vault } = await createVault();
            await factory.setFee(100);
            await factory.setFeeTo(other.address);
            await vault.mint(numToBN(10));
            await stETH.mint(vault.address, numToBN(1));
            expect(await vault.pendingRewards()).to.equal(numToBN(1));
            await factory.collectFees(vault.address);
            expect(await vault.pendingRewards()).to.equal(numToBN(1));
        });
    });

    describe("Harvest", function () {
        describe("Validations", function () {
            it("Should return early if no pending rewards", async function () {
                const { vault } = await createVault();
                await expect(vault.harvest()).to.not.emit(vault, "Harvest");
            });

            it("Should return early if staking is 0", async function () {
                const { vault } = await createVault();
                await vault.mint(numToBN(10));
                await expect(vault.harvest()).to.not.emit(vault, "Harvest");
            });
        });

        describe("Success", function () {
            it("Should harvest", async function () {
                const { factory, stETH, yToken, vault, staking } = await createVault();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await vault.pendingRewards()).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Harvest", async function () {
                const { factory, stETH, yToken, vault, staking } = await createVault();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest()).to.emit(vault, "Harvest").withArgs(numToBN(1));
            });
        });
    });

    describe("Set staking", function () {
        describe("Validations", function () {
            it("Should revert if msg.sender != factory", async function () {
                const { vault } = await createVault();
                await expect(vault.setStaking(constants.AddressZero)).to.be.revertedWith(
                    "!factory"
                );
            });

            it("Should revert if invalid staking address", async function () {
                const { factory, vault } = await createVault();
                await expect(factory.setStaking(vault.address, vault.address)).to.be.revertedWith(
                    "function selector was not recognized and there's no fallback function"
                );
            });

            it("Should revert if incorrect staking vault address", async function () {
                const { factory, vault, lpToken } = await createVault();
                await factory.createVault(lpToken.address);
                const vaultAddress = await factory.getVault(lpToken.address);
                const Staking = await ethers.getContractFactory("PerpetualBondStaking");
                const staking = await Staking.deploy(vaultAddress, constants.AddressZero);
                await expect(factory.setStaking(vault.address, staking.address)).to.be.revertedWith(
                    "!valid"
                );
            });
        });
    });

    describe("Collect fees", function () {
        describe("Validations", function () {
            it("Should revert if msg.sender != factory", async function () {
                const { other, vault } = await createVault();
                await expect(vault.connect(other).collectFees(other.address)).to.be.revertedWith(
                    "!factory"
                );
            });

            it("Should revert if feeTo is 0", async function () {
                const { factory, stETH, vault } = await createVault();
                await stETH.mint(vault.address, numToBN(1));
                await expect(factory.collectFees(vault.address)).to.be.revertedWith("feeTo is 0");
            });

            it("Should return early if fees is 0", async function () {
                const { feeTo, factory, vault } = await createVault();
                await factory.setFeeTo(feeTo.address);
                await expect(factory.collectFees(vault.address)).to.not.emit(vault, "CollectFees");
            });
        });

        describe("Success", function () {
            it("Should collect fees", async function () {
                const { feeTo, factory, stETH, vault } = await createVault();
                await factory.setFeeTo(feeTo.address);
                await factory.setFee(100);
                await vault.mint(numToBN(10));
                await factory.collectFees(vault.address);
                expect(await stETH.balanceOf(feeTo.address)).to.equal(numToBN(0.1));
                expect(await vault.fees()).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit CollectFees", async function () {
                const { feeTo, factory, stETH, vault } = await createVault();
                await factory.setFeeTo(feeTo.address);
                await factory.setFee(100);
                await vault.mint(numToBN(10));
                await expect(factory.collectFees(vault.address))
                    .to.emit(vault, "CollectFees")
                    .withArgs(feeTo.address, numToBN(0.1));
            });
        });
    });
});
