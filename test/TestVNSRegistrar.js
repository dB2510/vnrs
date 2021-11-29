const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require("crypto");

const increaseTimeInSeconds = async (seconds, mine = false) => {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  if (mine) {
    await ethers.provider.send("evm_mine", []);
  }
};

describe("Vanity Name Registration Service", function () {
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
    ).to.be.reverted;
  });

  it("Should be able to withdraw funds if name is expired", async function () {
    const salt = crypto.randomBytes(32);
    const commitment = await vns.connect(user2).createCommitment("dhruv", salt);
    console.log("My commitment: " + commitment);

    await vns.connect(user2).commit(commitment);

    await increaseTimeInSeconds(100, true);

    let initialBalance = await ethers.provider.getBalance(user2.address);
    console.log("Initial Balance", initialBalance);

    await expect(
      vns
        .connect(user2)
        .register("dhruv", salt, { value: ethers.utils.parseEther("5") })
    )
      .to.emit(vns, "Registered")
      .withArgs("dhruv", ethers.utils.parseEther("5"), user2.address);

    await increaseTimeInSeconds(30 * 24 * 60 * 60, true);
    await vns.connect(user2).withdraw("dhruv");

    let finalBalance = await ethers.provider.getBalance(user2.address);
    console.log("Final Balance", finalBalance);
    
    expect(initialBalance.eq(finalBalance));
  });

  it("Owner can renew name", async function () {
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
  
    let hashedName = await ethers.utils.keccak256(ethers.utils.toUtf8Bytes("dhruv"));
    let previousEndDate = await vns.nameLock(hashedName);
    
    await expect(vns.connect(user1).renewName("dhruv")).to.emit(vns, "Renewed").withArgs(
      "dhruv", 
      previousEndDate.endDate.add(ethers.BigNumber.from(30 * 24 * 60 * 60)));
  });

});
