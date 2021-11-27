//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./IVNSRegistrar.sol";

contract VNSRegistrar is IVNSRegistrar {
    uint constant public NAME_LOCKING_DURATION = 30 days;
    uint constant public NAME_LOCKING_BASE_AMOUNT = 1 ether;

    struct NameLock {
        bool registered;
        address owner;
        uint endDate;
        uint8 priceFactor;
    }

    // keccak256("xyz.com") => DOESN'T YET EXIST
    // default NameLock {
    // registered = false
    // owner = 0x0
    // endDate = 0
    // }
    
    // available = !registered

    mapping(bytes32 => NameLock) nameLock;

    /// A given name is available if either name is NOT already registered OR the name is registered but has expired
    function isNameAvailable(bytes32 nameId) public override view returns (bool) {
        return !nameLock[nameId].registered ? true : block.timestamp > nameLock[nameId].endDate;
    }

    function register(string calldata name) external override payable {
        bytes32 nameId = keccak256(abi.encode(name));
        require(isNameAvailable(nameId), "This name is not available");
        /// Name is available since it expired but owner is not zero address
        if (nameLock[nameId].owner != address(0)) {
            // start deregistration process
            deregister(nameId);
        }
        uint8 namePriceFactor = calculateNamePriceFactor(name);
        require(msg.value == NAME_LOCKING_BASE_AMOUNT * namePriceFactor, "Insufficient funds");
        nameLock[nameId].registered = true;
        nameLock[nameId].owner = msg.sender;
        nameLock[nameId].endDate = block.timestamp + NAME_LOCKING_DURATION;
        nameLock[nameId].priceFactor = namePriceFactor;
    }

    function calculateNamePriceFactor(string calldata name) public override pure returns (uint8) {
        return uint8(bytes(name).length);
    }

    function renewName(string calldata name) public override {
        bytes32 nameId = keccak256(abi.encode(name));
        require(nameLock[nameId].owner == msg.sender, "Only owner can renew");
        nameLock[nameId].endDate += NAME_LOCKING_DURATION;
    }

    // reentrancy guard is needed here
    function deregister(bytes32 nameId) public override {
        (bool success, ) = payable(nameLock[nameId].owner).call{value: nameLock[nameId].priceFactor * NAME_LOCKING_BASE_AMOUNT}("");
        require(success, "Transfer failed");
    }
}