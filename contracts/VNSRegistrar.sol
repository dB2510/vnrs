//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./IVNSRegistrar.sol";

/// @title Contract for Vanity Name Registration Service
/// @author Dhruv Bodani
contract VNSRegistrar is IVNSRegistrar {
    uint64 constant public NAME_LOCKING_DURATION = 30 days;
    uint64 constant public MIN_COMMITMENT_AGE = 1 minutes;
    uint64 constant public MAX_COMMITMENT_AGE = 24 hours;
    uint constant public NAME_LOCKING_BASE_AMOUNT = 1 ether;

    struct NameLock {
        bool registered;
        address owner;
        uint64 endDate;
        uint cost;
    }

    mapping (bytes32 => uint) public commitments;

    mapping(bytes32 => NameLock) public nameLock;

    event Registered(string name, uint cost, address owner);
    event Renewed(string name, uint endDate);

    /// @notice Checks if the given name is available or not
    /// @dev A given name is available if either name is NOT already registered OR the name is registered but has expired
    /// @param nameId The keccak256 hash of the given name
    /// @return true if name is available, else false
    function isNameAvailable(bytes32 nameId) public override view returns (bool) {
        return !nameLock[nameId].registered ? true : block.timestamp > nameLock[nameId].endDate;
    }

    /// @notice Verifies and assigns the given commitment. Deletes the commitment if it has expired
    /// @param commitment Commitment hash
    function checkForCommitment(bytes32 commitment) internal {
        require(commitments[commitment] + MIN_COMMITMENT_AGE <= block.timestamp);
        require(commitments[commitment] + MAX_COMMITMENT_AGE > block.timestamp);
        delete(commitments[commitment]);
    }

    /// @notice Return locked funds to previous owner if name has expired
    /// @param nameId The keccak256 hash of the given name
    function returnFundsToPreviousOwner(bytes32 nameId) internal {
        // Name is available since it expired but owner is not zero address
        if (nameLock[nameId].owner != address(0)) {
            // start deregistration process
            address previousOwner = nameLock[nameId].owner;
            nameLock[nameId].owner = address(0);
            nameLock[nameId].registered = false;
            (bool success, ) = payable(previousOwner).call{value: nameLock[nameId].cost}("");
            require(success, "Transfer failed");
        }
    }

    /// @dev register is to be called after the commit is made
    /// @param name name that user wants to register
    /// @param secret secret string that user used to commit
    function register(string calldata name, bytes32 secret) external override payable {
        // check if the given name is available
        bytes32 nameId = keccak256(bytes(name));
        require(isNameAvailable(nameId), "This name is not available");

        // return funds to previous owner since the name has been expired
        returnFundsToPreviousOwner(nameId);

        // Now check if the given commitment is valid
        bytes32 commitment = createCommitment(name, secret);
        checkForCommitment(commitment);

        uint cost = calculateNamePriceFactor(name) * NAME_LOCKING_BASE_AMOUNT;
        require(msg.value >= cost, "Insufficient funds");
        
        nameLock[nameId].registered = true;
        nameLock[nameId].owner = msg.sender;
        nameLock[nameId].endDate = uint64(block.timestamp) + NAME_LOCKING_DURATION;
        nameLock[nameId].cost = cost;
        emit Registered(name, cost, msg.sender);

        if (msg.value > cost) {
            // refund extra amount
            (bool success, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }

    /// @notice calculates the price factor of the given name
    /// @param name Name
    /// @return price factor of the given name
    function calculateNamePriceFactor(string calldata name) public override pure returns (uint64) {
        return uint64(bytes(name).length);
    }

    /// @notice Renew existing name
    /// @param name The name that needs to be renewed
    function renewName(string calldata name) public override {
        bytes32 nameId = keccak256(bytes(name));
        require(nameLock[nameId].owner == msg.sender, "Only owner can renew");
        nameLock[nameId].endDate += NAME_LOCKING_DURATION;
        emit Renewed(name, nameLock[nameId].endDate);
    }

    /// @notice Withdraw locked funds after the expiry of name
    /// @param name The name that is expired
    function withdraw(string calldata name) external override {
        bytes32 nameId = keccak256(bytes(name));
        require(nameLock[nameId].owner == msg.sender, "Only owner can withdraw funds");
        require(isNameAvailable(nameId), "Cannot withdraw");
        nameLock[nameId].registered = false;
        nameLock[nameId].owner = address(0);
        (bool success, ) = payable(nameLock[nameId].owner).call{value: nameLock[nameId].cost}("");
        require(success, "Transfer failed");
    }

    /// @notice Create initial commitment for a vanity name
    /// @param name Committed name
    /// @param secret Committed secret
    function createCommitment(string memory name, bytes32 secret) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(keccak256(bytes(name)), msg.sender, secret));
    }

    /// @notice Save the current timestamp of the commitment
    /// @param commitment Given commitment
    function commit(bytes32 commitment) public {
        require(commitments[commitment] + MAX_COMMITMENT_AGE < block.timestamp, "commitment already exists");
        commitments[commitment] = block.timestamp;
    }
}