const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");

describe("esBND", function () {
    async function deployFixture() {
        const vestingDuration = 365 * 24 * 60 * 60;
        const [owner, other] = await ethers.getSigners();
        const EsBND = await ethers.getContractFactory("EscrowedBondingToken");
        const esBND = await EsBND.deploy(vestingDuration);
        const BND = await ethers.getContractFactory("BondingToken");
        const bnd = BND.attach(await esBND.bondingToken());
        await esBND.approve(esBND.address, constants.MaxUint256);

        return { esBND, bnd, vestingDuration, owner, other };
    }

    describe("Deployment", function () {
        it("Should have correct initial values", async function () {
            const { esBND, vestingDuration, owner } = await loadFixture(deployFixture);
            expect(await esBND.owner()).to.equal(owner.address);
            expect(await esBND.vestingDuration()).to.equal(vestingDuration);
            expect(await esBND.bondingToken()).to.not.equal(constants.AddressZero);
        });
    });

    describe("setMinter", function () {
        describe("Validations", function () {
            it("Should only allow owner", async function () {
                const { esBND, other } = await loadFixture(deployFixture);
                await expect(
                    esBND.connect(other).setMinter(other.address, true)
                ).to.be.revertedWith("UNAUTHORIZED");
            });
        });

        describe("Success", function () {
            it("Should set minter", async function () {
                const { esBND, owner, other } = await loadFixture(deployFixture);
                await esBND.connect(owner).setMinter(other.address, true);
                expect(await esBND.minters(other.address)).to.equal(true);
            });
        });
    });

    describe("mint", function () {
        describe("Validations", function () {
            it("Should only allow minter", async function () {
                const { esBND, other } = await loadFixture(deployFixture);
                await expect(esBND.connect(other).mint(other.address, 1)).to.be.revertedWith(
                    "!minter"
                );
            });
        });

        describe("Success", function () {
            it("Should mint", async function () {
                const { esBND, owner, other } = await loadFixture(deployFixture);
                await esBND.setMinter(owner.address, true);
                await esBND.connect(owner).mint(other.address, 100);
                expect(await esBND.balanceOf(other.address)).to.equal(100);
                expect(await esBND.totalSupply()).to.equal(100);
            });
        });
    });

    describe("vest", function () {
        it("Should vest", async function () {
            const { esBND, owner } = await loadFixture(deployFixture);
            await esBND.setMinter(owner.address, true);
            await esBND.mint(owner.address, 100);
            await esBND.vest(100);
            const vestingInfo = await esBND.vestingInfo(owner.address);
            expect(vestingInfo.lastVestingTime).to.equal(await time.latest());
            expect(vestingInfo.cumulativeClaimAmount).to.equal(0);
            expect(vestingInfo.claimedAmount).to.equal(0);
            expect(vestingInfo.vestingAmount).to.equal(100);
        });
    });

    describe("claimable", function () {
        it("Should be correct claimable amount", async function () {
            const { esBND, owner } = await loadFixture(deployFixture);
            await esBND.setMinter(owner.address, true);
            await esBND.mint(owner.address, 100);
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

    describe("claim", function () {
        it("Should claim correct amount", async function () {
            const { esBND, bnd, owner } = await loadFixture(deployFixture);
            await esBND.setMinter(owner.address, true);
            await esBND.mint(owner.address, 100);
            await esBND.vest(100);
            const ONE_QUARTER_YEAR = (365 * 24 * 60 * 60) / 4;
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.claim();
            expect(await esBND.balanceOf(esBND.address)).to.equal(75);
            expect(await bnd.balanceOf(owner.address)).to.equal(25);
            await time.increase(ONE_QUARTER_YEAR);
            await esBND.claim();
            expect(await esBND.balanceOf(esBND.address)).to.equal(50);
            expect(await bnd.balanceOf(owner.address)).to.equal(50);
        });
    });
});
