# Contractful protocol

The core element of the protocol is the 'Manager' smart-contract. This contract stores all the hiring agreements created. It is in charge of tracking its states and of escrowing the funds for each Agreements' work sprint.
For a full explanation of all the parameters and functions go to contractful.vercel.app/documentation

## Flow 🌊

1. The contractee creates an agreement calling "createAgreement"
2. The contractor activates the agreement calling "activateAgreement"
3. The sprint period(paymentCycleDuration) is over.
4. Options:
   1. No action
      1. Chainlink automation calls the performUpkeep function that will release the funds as needed(migrateFunds) and pull new ones from the contractee(depositFundsForNextCycle).
      2. Repeat cycle
   2. The contractee calls 'challengeAgreement'
      1. The authorized user (governance - currently a founder's wallet address, soon a multi-sig and in the future a DAO) reviews the hiring agreement with both parties.
      2. The authorized user splits the escrowed funds in the most fair way(splitFunds).
      3. The agreement is closed

#### Notes 📒

- Is good to point out that each Chainlink automation doesn't release and pull funds individually per agreement. It does it on batches.
- The smart-contract does not stores the agreement description but only CID.
- In case the contractee is satisfied with his contractor's work but still wants to cancel the agreement for whatever might be the reason he can call "cancelAgreement". This action won't wait for the authorized user to split the funds and close the agreement. It will give all the funds for each worked day to the contractor and only the rest, minus a penalization fee will be given back to the contractee.
- If an agreement was never activated by the contractor, the contractee can call "cancelAgreement" and this function will return him the escrowed funds without penalization.

![CleanShot 2022-11-17 at 20 10 34](https://user-images.githubusercontent.com/54403738/202585056-5f68dd5e-a81e-41cc-ba18-ef192c9be30b.png)

## To-do 💼

- It isn't nice for the contractee's funds to be stuck on the smart-contract. We will add interaction with different low-risk web3 yield providers.
- Deploy a custom backend and move some parameters away from the smart-contract to save on gas costs.
- Use ZK to keep important details from a hiring agreement private.
- Pull tax information of the concerned parties into the smart-contract and automate tax payments.

## Local setup 🏗️

1. git clone this repository
2. `npm i`

For local deployment you are done
You can deploy locally: `npx hardhat`<br/>
You can also run tests: `npx hardhat test`

### Deploy to a test or live network

1. rename .env.example to .env
2. complete the network specific node URI or set a generic one
3. setup a network specific mnemonic or a generic one
4. run `npx hardhat deploy --network <network name>`

### Verify smart-contracts

1. rename .env.example to .env
2. complete your block explorer api key
3. run `npx hardhat --network <network name> etherscan-verify`
