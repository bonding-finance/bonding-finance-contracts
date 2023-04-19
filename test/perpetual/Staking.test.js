const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");
const { numToBN } = require("../util");

describe("Perpetual bond staking", function () {
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

    async function createBond() {
        const { factory, stETH, lpToken, accounts } = await loadFixture(deployFixture);
        await factory.createBond(stETH.address);
        const vaultAddress = await factory.getBond(stETH.address);
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
            await lpToken.connect(account).mint(account.address, numToBN(100));
            await lpToken.connect(account).approve(staking.address, constants.MaxUint256);
            await dToken.connect(account).approve(vaultAddress, constants.MaxUint256);
            await yToken.connect(account).approve(staking.address, constants.MaxUint256);
        }

        return {
            owner,
            other,
            feeTo,
            factory,
            stETH,
            lpToken,
            vault,
            dToken,
            yToken,
            staking,
        };
    }

    describe("Deployment", function () {
        it("Should have correct initial values", async function () {
            const { factory, vault, staking, lpToken } = await createBond();
            expect(await staking.factory()).to.equal(factory.address);
            expect(await staking.vault()).to.equal(vault.address);
            expect(await staking.yToken()).to.equal(await vault.yToken());
            expect(await staking.lpToken()).to.equal(lpToken.address);
            expect(await staking.rewardToken()).to.equal(await vault.token());
            expect(await staking.surplus()).to.equal(0);
        });
    });

    describe("Stake", function () {
        describe("Validations", function () {
            it("Should revert if token !valid", async function () {
                const { staking } = await createBond();
                await expect(staking.stake(constants.AddressZero, numToBN(1))).to.be.revertedWith(
                    "!valid"
                );
            });

            it("Should revert amount > balance", async function () {
                const { vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await expect(staking.stake(yToken.address, numToBN(11))).to.be.reverted;
            });
        });

        describe("Success", function () {
            it("Should stake yToken", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                const userInfo = await staking.userInfo(yToken.address, owner.address);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
                expect(userInfo.amount).to.equal(numToBN(10));
                expect(userInfo.rewardDebt).to.equal(0);
            });

            it("Should stake LP token", async function () {
                const { owner, factory, lpToken, vault, staking } = await createBond();
                await factory.setStaking(vault.address, staking.address);
                await staking.stake(lpToken.address, numToBN(10));
                const userInfo = await staking.userInfo(lpToken.address, owner.address);
                expect(await lpToken.balanceOf(owner.address)).to.equal(numToBN(90));
                expect(userInfo.amount).to.equal(numToBN(10));
                expect(userInfo.rewardDebt).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Stake", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await expect(staking.stake(yToken.address, numToBN(10)))
                    .to.emit(staking, "Stake")
                    .withArgs(owner.address, yToken.address, numToBN(10));
            });
        });
    });

    describe("Unstake", function () {
        describe("Validations", function () {
            it("Should revert if token !valid", async function () {
                const { staking } = await createBond();
                await expect(staking.unstake(constants.AddressZero, numToBN(1))).to.be.revertedWith(
                    "!valid"
                );
            });

            it("Should revert amount > deposits", async function () {
                const { vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await expect(staking.unstake(yToken.address, numToBN(11))).to.be.reverted;
            });
        });

        describe("Success", function () {
            it("Should unstake yToken", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await staking.unstake(yToken.address, numToBN(10));
                const userInfo = await staking.userInfo(yToken.address, owner.address);
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
                expect(userInfo.amount).to.equal(numToBN(0));
                expect(userInfo.rewardDebt).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Unstake", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await expect(staking.unstake(yToken.address, numToBN(10)))
                    .to.emit(staking, "Unstake")
                    .withArgs(owner.address, yToken.address, numToBN(10));
            });
        });
    });

    describe("Emergency withdraw", function () {
        describe("Success", function () {
            it("Should emergency withdraw", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await staking.emergencyWithdraw(yToken.address);
                const userInfo = await staking.userInfo(yToken.address, owner.address);
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
                expect(userInfo.amount).to.equal(numToBN(0));
                expect(userInfo.rewardDebt).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit EmergencyWithdraw", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await expect(staking.emergencyWithdraw(yToken.address))
                    .to.emit(staking, "EmergencyWithdraw")
                    .withArgs(owner.address, yToken.address, numToBN(10));
            });
        });
    });

    describe("Pending rewards", function () {
        describe("Validations", function () {
            it("Should be 0 when no rewards", async function () {
                const { owner, vault, yToken, staking } = await createBond();
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(0);
            });

            it("Should be 0 when token is invalid", async function () {
                const { owner, staking } = await createBond();
                expect(await staking.pendingRewards(constants.AddressZero, owner.address)).to.equal(
                    0
                );
            });
        });

        describe("Success", function () {
            it("Should get all rewards when solo staking", async function () {
                const { factory, owner, stETH, yToken, vault, staking } = await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(1)
                );
            });

            it("Should get half rewards if half total supply is staked", async function () {
                const { factory, owner, stETH, vault, yToken, lpToken, staking } =
                    await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(5));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(0.5)
                );
                expect(await staking.surplus()).to.equal(numToBN(0.5));
            });

            it("Should give half rewards to yToken and LP stakers", async function () {
                const { owner, factory, yToken, lpToken, stETH, vault, staking } =
                    await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.connect(owner).mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(5));
                await staking.stake(lpToken.address, numToBN(5));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(0.5)
                );
                expect(await staking.pendingRewards(lpToken.address, owner.address)).to.equal(
                    numToBN(0.5)
                );
            });
        });
    });

    describe("Distribute", function () {
        describe("Validations", function () {
            it("Should revert if msg.sender != distributor", async function () {
                const { staking, owner } = await createBond();
                await expect(staking.connect(owner).distribute()).to.be.revertedWith("!vault");
            });
        });

        describe("Success", function () {
            it("Should distribute only to bond stakers", async function () {
                const { owner, factory, stETH, vault, yToken, lpToken, staking } =
                    await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(1)
                );
                expect(await staking.pendingRewards(owner.address, lpToken.address)).to.equal(0);
                expect(await staking.surplus()).to.equal(0);
            });

            it("Should distribute only to bond stakers and protocol", async function () {
                const { owner, factory, stETH, vault, yToken, lpToken, staking } =
                    await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(8));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(0.8)
                );
                expect(await staking.pendingRewards(owner.address, lpToken.address)).to.equal(0);
                expect(await staking.surplus()).to.equal(numToBN(0.2));
            });

            it("Should distribute only to bond stakers and lp stakers", async function () {
                const { owner, factory, stETH, vault, yToken, lpToken, staking } =
                    await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(8));
                await staking.stake(lpToken.address, numToBN(2));

                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                expect(await staking.pendingRewards(yToken.address, owner.address)).to.equal(
                    numToBN(0.8)
                );
                expect(await staking.pendingRewards(lpToken.address, owner.address)).to.equal(
                    numToBN(0.2)
                );
                expect(await staking.surplus()).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Distribute", async function () {
                const { factory, stETH, vault, yToken, lpToken, staking } = await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(10));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest())
                    .to.emit(staking, "Distribute")
                    .withArgs(yToken.address, numToBN(1));

                await staking.unstake(yToken.address, numToBN(2));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest())
                    .to.emit(staking, "Distribute")
                    .withArgs(yToken.address, numToBN(0.8))
                    .to.emit(staking, "Distribute")
                    .withArgs(factory.address, numToBN(0.2));

                await staking.stake(lpToken.address, numToBN(2));
                await stETH.mint(vault.address, numToBN(1));
                await expect(vault.harvest())
                    .to.emit(staking, "Distribute")
                    .withArgs(yToken.address, numToBN(0.8))
                    .to.emit(staking, "Distribute")
                    .withArgs(lpToken.address, numToBN(0.2));
            });
        });
    });

    describe("Collect surplus", function () {
        describe("Validations", function () {
            it("Should revert if msg.sender != factory", async function () {
                const { other, staking } = await createBond();
                await expect(
                    staking.connect(other).collectSurplus(other.address)
                ).to.be.revertedWith("!factory");
            });

            it("Should revert if feeTo is 0", async function () {
                const { factory, staking, stETH, vault } = await createBond();
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                await expect(factory.collectSurplus(staking.address)).to.be.revertedWith(
                    "feeTo is 0"
                );
            });

            it("Should return early if surplus is 0", async function () {
                const { factory, staking, feeTo } = await createBond();
                await factory.setFeeTo(feeTo.address);
                await expect(factory.collectSurplus(staking.address)).to.not.emit(
                    staking,
                    "CollectSurplus"
                );
            });
        });

        describe("Success", function () {
            it("Should collect surplus", async function () {
                const { feeTo, factory, stETH, vault, yToken, staking } = await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(8));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                await factory.setFeeTo(feeTo.address);
                await factory.collectSurplus(staking.address);
                expect(await stETH.balanceOf(feeTo.address)).to.equal(numToBN(0.2));
                expect(await staking.surplus()).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit CollectSurplus", async function () {
                const { feeTo, factory, stETH, vault, yToken, staking } = await createBond();
                await factory.setStaking(vault.address, staking.address);
                await vault.mint(numToBN(10));
                await staking.stake(yToken.address, numToBN(8));
                await stETH.mint(vault.address, numToBN(1));
                await vault.harvest();
                await factory.setFeeTo(feeTo.address);
                await expect(factory.collectSurplus(staking.address))
                    .to.emit(staking, "CollectSurplus")
                    .withArgs(feeTo.address, numToBN(0.2));
            });
        });
    });
});
