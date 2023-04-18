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
        const PerpetualBond = await ethers.getContractFactory("PerpetualBondVault");
        const perpetualBond = PerpetualBond.attach(bondAddress);
        const BondToken = await ethers.getContractFactory("PerpetualBondToken");
        const dToken = BondToken.attach(await perpetualBond.dToken());
        const yToken = BondToken.attach(await perpetualBond.yToken());
        const Staking = await ethers.getContractFactory("PerpetualBondStaking");
        const staking = Staking.attach(await perpetualBond.staking());
        const [owner, other] = accounts;
        for (const account of [owner, other]) {
            await stETH.connect(account).mint(account.address, numToBN(100));
            await stETH.connect(account).approve(bondAddress, constants.MaxUint256);
            await dToken.connect(account).approve(bondAddress, constants.MaxUint256);
            await yToken.connect(account).approve(staking.address, constants.MaxUint256);
        }

        return { owner, other, factory, stETH, perpetualBond, dToken, yToken, staking };
    }

    describe("Deployment", function () {
        it("Should have correct initial values", async function () {
            const { perpetualBond, staking } = await createBond();
            expect(await staking.vault()).to.equal(perpetualBond.address);
            expect(await staking.yToken()).to.equal(await perpetualBond.yToken());
            expect(await staking.reward()).to.equal(await perpetualBond.token());
        });
    });

    describe("Stake", function () {
        describe("Validations", function () {
            it("Should revert amount > balance", async function () {
                const { perpetualBond, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await expect(staking.stake(numToBN(11))).to.be.reverted;
            });
        });

        describe("Success", function () {
            it("Should stake yToken", async function () {
                const { owner, perpetualBond, yToken, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await staking.stake(numToBN(10));
                const userInfo = await staking.userInfo(owner.address);
                expect(await yToken.balanceOf(owner.address)).to.equal(0);
                expect(userInfo.amount).to.equal(numToBN(10));
                expect(userInfo.rewardDebt).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Stake", async function () {
                const { owner, perpetualBond, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await expect(staking.stake(numToBN(10)))
                    .to.emit(staking, "Stake")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Unstake", function () {
        describe("Validations", function () {
            it("Should revert amount > deposits", async function () {
                const { perpetualBond, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await expect(staking.unstake(numToBN(11))).to.be.reverted;
            });
        });

        describe("Success", function () {
            it("Should unstake yToken", async function () {
                const { owner, perpetualBond, yToken, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await staking.unstake(numToBN(10));
                const userInfo = await staking.userInfo(owner.address);
                expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
                expect(userInfo.amount).to.equal(numToBN(0));
                expect(userInfo.rewardDebt).to.equal(0);
            });
        });

        describe("Events", function () {
            it("Should emit Unstake", async function () {
                const { owner, perpetualBond, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await expect(staking.unstake(numToBN(10)))
                    .to.emit(staking, "Unstake")
                    .withArgs(owner.address, numToBN(10));
            });
        });
    });

    describe("Pending rewards", function () {
        it("Should be 0 when no rewards", async function () {
            const { owner, perpetualBond, staking } = await createBond();
            await perpetualBond.mint(numToBN(10));
            await staking.stake(numToBN(10));
            expect(await staking.pendingRewards(owner.address)).to.equal(0);
        });

        describe("Success", function () {
            it("Should get all rewards when solo staking", async function () {
                const { owner, stETH, perpetualBond, staking } = await createBond();
                await perpetualBond.mint(numToBN(10));
                await staking.stake(numToBN(10));
                await stETH.mint(perpetualBond.address, numToBN(1));
                await perpetualBond.harvest();
                expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1));
            });

            it("Should have right reward amounts w/ > 1 stakers", async function () {
                const { owner, other, stETH, perpetualBond, staking } = await createBond();
                await perpetualBond.connect(owner).mint(numToBN(10));
                await staking.connect(owner).stake(numToBN(10));
                await stETH.mint(perpetualBond.address, numToBN(1));
                await perpetualBond.harvest();
                expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1));
                await perpetualBond.connect(other).mint(numToBN(10));
                await staking.connect(other).stake(numToBN(10));
                expect(await staking.pendingRewards(other.address)).to.equal(0);
                await stETH.mint(perpetualBond.address, numToBN(1));
                await perpetualBond.harvest();
                expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1.5));
                expect(await staking.pendingRewards(other.address)).to.equal(numToBN(0.5));
            });
        });
    });

    describe("accRewardsPerShare", function () {
        it("Should be correct", async function () {
            const { owner, other, stETH, perpetualBond, staking } = await createBond();
            await perpetualBond.connect(owner).mint(numToBN(10));
            await staking.connect(owner).stake(numToBN(10));
            await stETH.mint(perpetualBond.address, numToBN(1));
            await perpetualBond.harvest();
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.1));
            await perpetualBond.connect(other).mint(numToBN(10));
            await staking.connect(other).stake(numToBN(10));
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.1));
            await stETH.mint(perpetualBond.address, numToBN(1));
            await perpetualBond.harvest();
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.15));
        });
    });

    describe("Distribute", function () {
        it("Should revert if msg.sender != distributor", async function () {
            const { staking, owner } = await createBond();
            await expect(staking.connect(owner).distribute()).to.be.revertedWith("!vault");
        });
    });

    describe("Collect yield", function () {
        it("Success", async function () {
            const { owner, other, stETH, perpetualBond, staking, dToken, yToken } =
                await createBond();
            await perpetualBond.connect(owner).mint(numToBN(10));
            // P1: stake 5 ETH
            await staking.connect(owner).stake(numToBN(5));
            // + 1 ETH
            await stETH.mint(perpetualBond.address, numToBN(1));
            await perpetualBond.harvest();
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.2));
            expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1));
            // P1: stake 5 ETH (10 - 0)
            await staking.connect(owner).stake(numToBN(5));
            await perpetualBond.harvest();

            await perpetualBond.connect(other).mint(numToBN(10));
            // P2: stake 10 ETH (10 - 10)
            await staking.connect(other).stake(numToBN(10));
            // + 1 ETH
            await stETH.mint(perpetualBond.address, numToBN(1));
            await perpetualBond.harvest();
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.25));
            expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(0.5));
            expect(await staking.pendingRewards(other.address)).to.equal(numToBN(0.5));
            await staking.connect(owner).stake(0);
            await staking.connect(other).stake(0);
            expect(await staking.pendingRewards(owner.address)).to.equal(0);
            expect(await staking.pendingRewards(other.address)).to.equal(0);
            expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(91.5));
            expect(await stETH.balanceOf(other.address)).to.equal(numToBN(90.5));

            await staking.connect(owner).unstake(numToBN(5));
            await stETH.mint(perpetualBond.address, numToBN(3));
            await perpetualBond.harvest();
            expect(await yToken.balanceOf(staking.address)).to.equal(numToBN(15));
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.45));

            expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1));
            expect(await staking.pendingRewards(other.address)).to.equal(numToBN(2));

            await staking.connect(owner).stake(0);
            expect(await staking.pendingRewards(owner.address)).to.equal(0);
            await stETH.mint(perpetualBond.address, numToBN(3));
            await perpetualBond.harvest();
            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.65));
            expect(await staking.pendingRewards(owner.address)).to.equal(numToBN(1));
            expect(await staking.pendingRewards(other.address)).to.equal(numToBN(4));

            await staking.connect(owner).unstake(numToBN(5));
            await staking.connect(other).unstake(numToBN(5));
            expect(await staking.pendingRewards(owner.address)).to.equal(0);
            expect(await staking.pendingRewards(other.address)).to.equal(0);
            expect(await yToken.balanceOf(staking.address)).to.equal(numToBN(5));
            await staking.connect(other).unstake(numToBN(5));
            expect(await yToken.balanceOf(staking.address)).to.equal(0);
            expect(await stETH.balanceOf(staking.address)).to.equal(0);

            expect(await staking.accRewardsPerShare()).to.equal(numToBN(0.65));
            expect(await yToken.balanceOf(owner.address)).to.equal(numToBN(10));
            expect(await dToken.balanceOf(owner.address)).to.equal(numToBN(10));
            expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(93.5));
            await perpetualBond.connect(owner).redeem(numToBN(10));
            expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(103.5));

            expect(await yToken.balanceOf(other.address)).to.equal(numToBN(10));
            expect(await dToken.balanceOf(other.address)).to.equal(numToBN(10));
            expect(await stETH.balanceOf(other.address)).to.equal(numToBN(94.5));
            await perpetualBond.connect(other).redeem(numToBN(10));
            expect(await stETH.balanceOf(other.address)).to.equal(numToBN(104.5));
        });
    });

    describe("Test all actions", function () {
        it("Success", async function () {
            const { owner, other, stETH, perpetualBond, staking } = await createBond();
            await perpetualBond.connect(owner).mint(numToBN(10));
            await staking.connect(owner).stake(numToBN(5));
            await stETH.mint(perpetualBond.address, numToBN(1));
            await stETH.mint(staking.address, numToBN(1));
            await staking.connect(owner).stake(numToBN(5));
            await perpetualBond.connect(other).mint(numToBN(10));
            await staking.connect(other).stake(numToBN(10));
            await stETH.mint(perpetualBond.address, numToBN(1));
            await stETH.mint(perpetualBond.address, numToBN(0.5));
            await staking.connect(owner).stake(0);
            await staking.connect(other).stake(0);
            await staking.connect(owner).unstake(numToBN(5));
            await stETH.mint(perpetualBond.address, numToBN(3));
            await staking.connect(owner).stake(0);
            await stETH.mint(perpetualBond.address, numToBN(3));
            await stETH.mint(staking.address, numToBN(3));
            await staking.connect(owner).unstake(numToBN(5));
            await staking.connect(other).unstake(numToBN(5));
            await staking.connect(other).unstake(numToBN(5));
            await perpetualBond.connect(owner).redeem(numToBN(10));
            await perpetualBond.connect(other).redeem(numToBN(10));
            await perpetualBond.connect(owner).mint(numToBN(2));
            await staking.connect(owner).stake(numToBN(1));
            await perpetualBond.connect(other).mint(numToBN(2));
            await staking.connect(other).stake(numToBN(2));
            await stETH.mint(perpetualBond.address, numToBN(0.3));
            await stETH.mint(staking.address, numToBN(0.3));
            await staking.connect(owner).unstake(numToBN(1));
            await staking.connect(other).unstake(numToBN(2));
            expect(await stETH.balanceOf(owner.address)).to.equal(numToBN(103.95));
            expect(await stETH.balanceOf(other.address)).to.equal(numToBN(105.15));
        });
    });
});
