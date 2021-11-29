# VNRS

VNRS stands for `Vanity Name Registration System`. It is a front-running resistant smart contract application to register vanity names on Ethereum.

## How?

1. The user creates a commitment corresponding to the name he wants to register with a secret. It is a hash of user's address, name and secret.
2. The user commits the commitment obtained in #1.
3. The user calls `register` function after `MIN_COMMITMENT_AGE` but before `MAX_COMMITMENT_AGE` with the amount to be locked for `NAME_LOCKING_DURATION`(30 days). `Registered` event is emitted which denotes that the name is registered.

## Steps to run
```bash
npm install
npx hardhat compile
npx hardhat test
```

## FAQ
1. How do you prevent front-running attacks?
    * By using commit & reveal mechanism
2. Why is a minimum delay period of 1min required?
    * So that the reveal transaction is included in a different block than the commit transaction
3. How happens when user renews his registration?
    * He doesn't have to pay the fees again and his initial amount are locked for another 30 days.
4. How does the commit & reveal mechanism prevent front-running attacks?
    * `The best remediation is to remove the benefit of front-running in your application, mainly by removing the importance of transaction ordering or time.` - Consensys Smart Contract Best practices guide.
    * The commit transaction commits to the hash of the `vanity name`, `user address` and a `secret` string. 
    * After the above transaction is included in the blockchain, the reveal transaction checks if the commitment is valid. If it's valid, the logic for name registration is carried out.