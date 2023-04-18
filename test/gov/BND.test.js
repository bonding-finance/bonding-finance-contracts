const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { constants } = ethers;
const { expect } = require("chai");

describe("BND", function () {
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
            const { esBND, bnd, vestingDuration, owner } = await loadFixture(deployFixture);
            expect(await bnd.esBND()).to.equal(esBND.address);
        });
    });

    describe("mint", function () {
        describe("Validations", function () {
            it("Should only allow minter", async function () {
                const { bnd, owner } = await loadFixture(deployFixture);
                await expect(bnd.mint(owner.address, 1)).to.be.revertedWith("!esBND");
            });
        });
    });
});
