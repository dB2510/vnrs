//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IVNSRegistrar {
    // called by user with the specified name to register
    function register(string calldata name, bytes32 secret) external payable;

    // to check the availablility of the name with given id
    function isNameAvailable(bytes32 id) external view returns (bool);

    // to calculate the price of a given name
    function calculateNamePriceFactor(string calldata name) external returns (uint64);

    // renew name
    function renewName(string calldata name) external;

    // withdraw locked amount
    function withdraw(string calldata name) external;

    // create commitment
    function createCommitment(string memory name, bytes32 secret) external returns (bytes32);
}