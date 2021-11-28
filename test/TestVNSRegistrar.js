const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require("crypto");

const increaseTimeInSeconds = async (seconds, mine = false) => {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  if (mine) {
    await ethers.provider.send("evm_mine", []);
  }
};

describe("Register Vanity Name", function () {
  let user1, user2, user3;
  let vns;
  
  this.beforeEach(async () => {
    const VNSRegistrar = await ethers.getContractFactory("VNSRegistrar");
    vns = await VNSRegistrar.deploy();
    await vns.deployed();
    [user1, user2, user3] = await ethers.getSigners();
  });

  it("Should register the desired name", async function () {
    console.log("address of deployed contract: " + vns.address);

    const salt = crypto.randomBytes(32);
    const commitment = await vns.connect(user1).createCommitment("dhruv", salt);
    console.log("My commitment: " + commitment);

    await vns.connect(user1).commit(commitment);

    await increaseTimeInSeconds(100, true);

    await expect(
      vns
        .connect(user1)
        .register("dhruv", salt, { value: ethers.utils.parseEther("5") })
    )
      .to.emit(vns, "Registered")
      .withArgs("dhruv", ethers.utils.parseEther("5"), user1.address);
  });

  it("Shouldn't register domain without commitment", async function () {
    console.log("address of deployed contract: " + vns.address);

    const salt = crypto.randomBytes(32);

    await expect(
      vns
        .connect(user1)
        .register("dhruv", salt, { value: ethers.utils.parseEther("5") })
    )
      .to.be.reverted
  })
});
