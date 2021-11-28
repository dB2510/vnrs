//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./IVNSRegistrar.sol";

contract VNSRegistrar is IVNSRegistrar {
    uint constant public NAME_LOCKING_DURATION = 30 days;
    uint constant public NAME_LOCKING_BASE_AMOUNT = 1 ether;
    uint constant public MIN_COMMITMENT_AGE = 1 minutes;
    uint constant public MAX_COMMITMENT_AGE = 24 hours;

    struct NameLock {
        bool registered;
        address owner;
        uint endDate;
        uint cost;
    }

    mapping (bytes32 => uint) public commitments;

    mapping(bytes32 => NameLock) nameLock;

    event Registered(string name, uint cost, address owner);

    /// A given name is available if either name is NOT already registered OR the name is registered but has expired
    function isNameAvailable(bytes32 nameId) public override view returns (bool) {
        return !nameLock[nameId].registered ? true : block.timestamp > nameLock[nameId].endDate;
    }

    function checkForCommitment(bytes32 commitment) internal {
        require(commitments[commitment] + MIN_COMMITMENT_AGE <= block.timestamp);
        require(commitments[commitment] + MAX_COMMITMENT_AGE > block.timestamp);
        delete(commitments[commitment]);
    }

    function checkForAvailability(bytes32 nameId) internal {
        require(isNameAvailable(nameId), "This name is not available");

        // Name is available since it expired but owner is not zero address
        if (nameLock[nameId].owner != address(0)) {
            // start deregistration process
            deregister(nameId);
        }
    }

    function register(string calldata name, bytes32 secret) external override payable {
        bytes32 commitment = createCommitment(name, secret);
        // require a valid commitment
        checkForCommitment(commitment);

        // if name is available
        bytes32 nameId = keccak256(bytes(name));
        checkForAvailability(nameId);

        uint cost = calculateNamePriceFactor(name) * NAME_LOCKING_BASE_AMOUNT;
        require(msg.value >= cost, "Insufficient funds");
        nameLock[nameId].registered = true;
        nameLock[nameId].owner = msg.sender;
        nameLock[nameId].endDate = block.timestamp + NAME_LOCKING_DURATION;
        nameLock[nameId].cost = cost;
        emit Registered(name, cost, msg.sender);

        if (msg.value > cost) {
            (bool success, ) = payable(msg.sender).call{value: cost}("");
            require(success, "Refund failed");
        }
    }

    function calculateNamePriceFactor(string calldata name) public override pure returns (uint8) {
        return uint8(bytes(name).length);
    }

    function renewName(string calldata name) public override {
        bytes32 nameId = keccak256(abi.encode(name));
        require(nameLock[nameId].owner == msg.sender, "Only owner can renew");
        nameLock[nameId].endDate += NAME_LOCKING_DURATION;
    }

    function deregister(bytes32 nameId) internal {
        (bool success, ) = payable(nameLock[nameId].owner).call{value: nameLock[nameId].cost}("");
        require(success, "Transfer failed");
    }

    function withdraw(string calldata name) public override {
        bytes32 nameId = keccak256(bytes(name));
        require(nameLock[nameId].owner == msg.sender, "Only owner can withdraw funds");
        require(!isNameAvailable(nameId), "Cannot withdraw");
        nameLock[nameId].registered = false;
        nameLock[nameId].owner = address(0);
        (bool success, ) = payable(nameLock[nameId].owner).call{value: nameLock[nameId].cost}("");
        require(success, "Transfer failed");
    }

    function createCommitment(string memory name, bytes32 secret) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(keccak256(bytes(name)), msg.sender, secret));
    }

    function commit(bytes32 commitment) public {
        require(commitments[commitment] + MAX_COMMITMENT_AGE < block.timestamp, "commitment already exists");
        commitments[commitment] = block.timestamp;
    }
}