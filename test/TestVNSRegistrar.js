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
  let user1, user2, user3, user4, user5;
  let vns;

  this.beforeEach(async () => {
    const VNSRegistrar = await ethers.getContractFactory("VNSRegistrar");
    vns = await VNSRegistrar.deploy();
    await vns.deployed();
    [user1, user2, user3, user4, user5] = await ethers.getSigners();
  });

  it("Should register the desired name", async function () {
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

    await vns.connect(user2).commit(commitment);

    await increaseTimeInSeconds(100, true);

    
    await vns.connect(user2).register("dhruv", salt, { value: ethers.utils.parseEther("5") });

    let initialBalance = await ethers.provider.getBalance(user2.address);

    await increaseTimeInSeconds(30 * 24 * 60 * 60, true);
    await vns.connect(user2).withdraw("dhruv");

    let contractFinalBalance = await ethers.provider.getBalance(vns.address);
    expect(contractFinalBalance).to.equal(0);

    let finalBalance = await ethers.provider.getBalance(user2.address);

    expect(initialBalance.add(ethers.utils.parseEther("4"))).to.lte(finalBalance);
  });

  it("Shouldn't be able to withdraw funds if name is not expired", async function () {
    const salt = crypto.randomBytes(32);
    const commitment = await vns.connect(user2).createCommitment("dhruv", salt);

    await vns.connect(user2).commit(commitment);

    await increaseTimeInSeconds(100, true);

    await vns.connect(user2).register("dhruv", salt, { value: ethers.utils.parseEther("5") });

    await expect(vns.connect(user2).withdraw("dhruv")).to.be.revertedWith("Cannot withdraw");
  });

  it("Should renew name before expiry", async function () {
    const salt = crypto.randomBytes(32);
    const commitment = await vns.connect(user1).createCommitment("dhruv", salt);

    await vns.connect(user1).commit(commitment);

    await increaseTimeInSeconds(100, true);

    await vns.connect(user1).register("dhruv", salt, { value: ethers.utils.parseEther("5") });

    let hashedName = await ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("dhruv")
    );
    let previousEndDate = await vns.nameLock(hashedName);

    await expect(vns.connect(user1).renewName("dhruv"))
      .to.emit(vns, "Renewed")
      .withArgs(
        "dhruv",
        previousEndDate.endDate.add(ethers.BigNumber.from(30 * 24 * 60 * 60))
      );
  });

  it("Shouldn't renew name after expiry", async function () {
    const salt = crypto.randomBytes(32);
    const commitment = await vns.connect(user1).createCommitment("dhruv", salt);

    await vns.connect(user1).commit(commitment);

    await increaseTimeInSeconds(100, true);

    await vns
    .connect(user1)
    .register("dhruv", salt, { value: ethers.utils.parseEther("5") });

    await increaseTimeInSeconds(30 * 24 * 60 * 60, true);

    await expect(vns.connect(user1).renewName("dhruv"))
      .to.be.revertedWith("Name is expired");
  });

  it("Should throw exception if name is not available", async function () {
    const salt1 = crypto.randomBytes(32);
    const commitment1 = await vns
      .connect(user2)
      .createCommitment("dhruv", salt1);

    await vns.connect(user2).commit(commitment1);

    await increaseTimeInSeconds(100, true);

    await vns
      .connect(user2)
      .register("dhruv", salt1, { value: ethers.utils.parseEther("5") });

    const salt2 = crypto.randomBytes(32);
    const commitment2 = await vns
      .connect(user3)
      .createCommitment("dhruv", salt2);

    await vns.connect(user3).commit(commitment2);

    await increaseTimeInSeconds(100, true);

    await expect(
      vns
        .connect(user3)
        .register("dhruv", salt2, { value: ethers.utils.parseEther("5") })
    ).to.be.revertedWith("This name is not available");
  });

  it("Should register name for user2 after it is expired for user1", async function () {
    const salt1 = crypto.randomBytes(32);
    const commitment1 = await vns
      .connect(user4)
      .createCommitment("dhruv", salt1);

    await vns.connect(user4).commit(commitment1);

    await increaseTimeInSeconds(100, true);

    await vns.connect(user4).register("dhruv", salt1, { value: ethers.utils.parseEther("5") });

    const user4InitialBalance = await ethers.provider.getBalance(user4.address);

    await increaseTimeInSeconds(30 * 24 * 60 * 60, true);

    const salt2 = crypto.randomBytes(32);
    const commitment2 = await vns
      .connect(user5)
      .createCommitment("dhruv", salt2);

    await vns.connect(user5).commit(commitment2);

    await increaseTimeInSeconds(100, true);

    await expect(
      vns
        .connect(user5)
        .register("dhruv", salt2, { value: ethers.utils.parseEther("5") })
    ).to.be.emit(vns, "Registered").withArgs("dhruv", ethers.utils.parseEther("5"), user5.address);

    const user4FinalBalance = await ethers.provider.getBalance(user4.address);
    expect(user4InitialBalance.add(ethers.utils.parseEther("5"))).to.equal(user4FinalBalance);
  })
});
