const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");
const { numToBN } = require("../util");

describe("esBND", function () {
    async function deployFixture() {
        const vestingDuration = 365 * 24 * 60 * 60;
        const [owner, other] = await ethers.getSigners();
        const EsBND = await ethers.getContractFactory("EscrowedBondingFinanceToken");
        const esBND = await EsBND.deploy(vestingDuration);
        const BND = await ethers.getContractFactory("BondingFinanceToken");
        const bnd = BND.attach(await esBND.bnd());
        await esBND.approve(esBND.address, constants.MaxUint256);

        return { esBND, bnd, vestingDuration, owner, other };
    }

    describe("Deployment", function () {
        it("Should have correct initial values", async function () {
            const { esBND, bnd, vestingDuration, owner } = await loadFixture(deployFixture);
            expect(await esBND.owner()).to.equal(owner.address);
            expect(await esBND.vestingDuration()).to.equal(vestingDuration);
            expect(await esBND.bnd()).to.not.equal(constants.AddressZero);
            expect(await esBND.balanceOf(owner.address)).to.equal(numToBN(1_000_000));
            expect(await bnd.balanceOf(esBND.address)).to.equal(numToBN(1_000_000));
        });
    });

    describe("Set transferer", function () {
        describe("Validations", function () {
            it("Should only allow owner", async function () {
                const { esBND, other } = await loadFixture(deployFixture);
                await expect(
                    esBND.connect(other).setTransferer(other.address, true)
                ).to.be.revertedWith("UNAUTHORIZED");
            });
        });

        describe("Success", function () {
            it("Should set transferer", async function () {
                const { esBND, owner, other } = await loadFixture(deployFixture);
                await esBND.connect(owner).setTransferer(other.address, true);
                expect(await esBND.transferers(other.address)).to.equal(true);
            });
        });
    });

    describe("Transfers", function () {
        describe("Validations", function () {
            it("Should only allow transferer", async function () {
                const { esBND, other } = await loadFixture(deployFixture);
                await expect(esBND.connect(other).transfer(other.address, 1)).to.be.revertedWith(
                    "!transferer"
                );
                await expect(
                    esBND.connect(other).transferFrom(other.address, other.address, 1)
                ).to.be.revertedWith("!transferer");
            });
        });

        describe("Success", function () {
            it("Should transfer", async function () {
                const { esBND, owner, other } = await loadFixture(deployFixture);
                await esBND.setTransferer(owner.address, true);
                await esBND.connect(owner).transfer(other.address, numToBN(1_000_000));
                expect(await esBND.balanceOf(other.address)).to.equal(numToBN(1_000_000));
                expect(await esBND.balanceOf(owner.address)).to.equal(0);
            });

            it("Should transferFrom", async function () {
                const { esBND, owner, other } = await loadFixture(deployFixture);
                await esBND.connect(other).approve(owner.address, numToBN(1_000_000));
                await esBND.setTransferer(owner.address, true);
                await esBND.connect(owner).transfer(other.address, numToBN(1_000_000));
                await esBND
                    .connect(owner)
                    .transferFrom(other.address, owner.address, numToBN(1_000_000));
                expect(await esBND.balanceOf(other.address)).to.equal(0);
                expect(await esBND.balanceOf(owner.address)).to.equal(numToBN(1_000_000));
            });
        });
    });

    describe("Vest", function () {
        it("Should vest", async function () {
            const { esBND, owner } = await loadFixture(deployFixture);
            await esBND.vest(100);
            const vestingInfo = await esBND.vestingInfo(owner.address);
            expect(vestingInfo.lastVestingTime).to.equal(await time.latest());
            expect(vestingInfo.cumulativeClaimAmount).to.equal(0);
            expect(vestingInfo.claimedAmount).to.equal(0);
            expect(vestingInfo.vestingAmount).to.equal(100);
        });
    });

    describe("Claimable", function () {
        it("Should be correct claimable amount", async function () {
            const { esBND, owner } = await loadFixture(deployFixture);
            await esBND.vest(100);
            expect(await esBND.claimable(owner.address)).to.equal(0);
            const ONE_QUARTER_YEAR = (365 * 24 * 60 * 60) / 4;
            await time.increase(ONE_QUARTER_YEAR);
            expect(await esBND.claimable(owner.address)).to.equal(25);
            await time.increase(ONE_QUARTER_YEAR);
            expect(await esBND.claimable(owner.address)).to.equal(50);
            await time.increase(ONE_QUARTER_YEAR);
            expect(await esBND.claimable(owner.address)).to.equal(75);
            await time.increase(ONE_QUARTER_YEAR);
            expect(await esBND.claimable(owner.address)).to.equal(100);
            await time.increase(ONE_QUARTER_YEAR);
            expect(await esBND.claimable(owner.address)).to.equal(100);
        });
    });

    describe("Claim", function () {
        it("Should claim correct amount", async function () {
            const { esBND, bnd, owner } = await loadFixture(deployFixture);
            await esBND.vest(100);
            const ONE_QUARTER_YEAR = (365 * 24 * 60 * 60) / 4;
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.vest(0);
            expect(await bnd.balanceOf(owner.address)).to.equal(25);
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.vest(0);
            expect(await bnd.balanceOf(owner.address)).to.equal(50);
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.vest(0);
            expect(await bnd.balanceOf(owner.address)).to.equal(75);
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.vest(0);
            expect(await bnd.balanceOf(owner.address)).to.equal(100);
        });
    });
});
