# contractful protocol

\[[Polygon Mumbai testnet | ✅ Deployed](https://mumbai.polygonscan.com/address/0xE4930EDeAd758036Bd830983A26340ac7F366869)\]

🙌️  News: **[For early MVP access, click here to participate in our survey from Nov to Dec 2022](https://forms.gle/E3xPJwu6wBbnvB7t6)**.

The protocol that realizes peer-2-peer, safe and secure Hiring Agreements for everyone to use.

You will also find [more details on the devpost page on the contractful project](https://devpost.com/software/contractful-hiring-agreements).

## Quick start

If you want to go ahead and put up a Hiring Agreement, please find [the demo link and quick start instructions for users in the contractful frontend project](https://github.com/contractful/frontend-v1).

## Introduction

The contractful protocol lets everyone create peer-2-peer, safe and secure Hiring Agreements. Freelancers, service providers and also permanent employees can use contractful together with their clients or employers to manifest their collaboration terms on-chain.

The Agreement is build on top of an underlying agile collaboration process. It assumes contractor and contractee to exchange information on a regular basis ("Conversation over Documantation").

The core element of the protocol is the 'Manager' smart-contract. This contract stores all the hiring agreements created. It is in charge of tracking its states and of escrowing the funds for each Agreements' work sprint.

For a full explanation of all the parameters and functions go to contractful.vercel.app/documentation
You will also find [more details on the devpost page on the contractful project](https://devpost.com/software/contractful-hiring-agreements).

## Flow of the protocol 🌊

1. The contractee creates an agreement calling "createAgreement"
2. The contractor activates the agreement calling "activateAgreement"
3. The sprint period(paymentCycleDuration) is over.
4. Options:
   1. No action
      1. **Chainlink automation** calls the performUpkeep function that will release the funds as needed(migrateFunds) and pull new ones from the contractee(depositFundsForNextCycle).
      2. Repeat cycle
   2. The contractee calls 'challengeAgreement'
      1. The authorized user (governance - currently a founder's wallet address, soon a multi-sig and in the future a DAO) reviews the hiring agreement with both parties.
      2. The authorized user splits the escrowed funds in the most fair way(splitFunds).
      3. The agreement is closed

### Notes 📒

- Is good to point out that Chainlink automation doesn't release and pull funds individually per agreement. It does it on batches.
- The smart-contract does not stores the agreement's description since it can have an arbitrary size. **It only stores the CID.**
- In case the contractee is satisfied with his contractor's work but still wants to cancel the agreement for whatever might be the reason he can call "cancelAgreement". This action won't wait for the authorized user to split the funds and close the agreement. It will give all the funds for each worked day to the contractor and only the rest, minus a penalization fee will be given back to the contractee.
- If an agreement was never activated by the contractor, the contractee can call "cancelAgreement" and this function will return him the escrowed funds without penalization.

![contractful process, 2022-11-17 at 20 10 34](https://user-images.githubusercontent.com/54403738/202585056-5f68dd5e-a81e-41cc-ba18-ef192c9be30b.png)

## The protocol architecture

* The protocol is provided on the **Polygon blockchain** as a Smart Contract.
* Automated migration of funds is realized through **Chainlink Automation**.
* Contract details are **stored on IPFS** and linked to the protocol via their `cid`.
* The protocol is accessible for users through the [contractful frontend application](https://github.com/contractful/frontend-v1) (official demo: <https://contractful.vercel.app/>).

### Why Polygon?

The Polygon blockchain ecosystem is very developer friendly. The chain itself is fast, scalable, permissionless and EVM compatible. Its Mumbai testnet can be accessed easily and provides all the necessary tooling (e.g. Faucet, polygonscan).

### Why Chainlink Automation?

Once the budget for a payment period (e.g. a 2 weeks sprint) are delegated to the Hiring Agreement, and the freelancer or service prodiders starts working on the contract, it is critical to the solution that the payment is guaranteed to be released according to the pre-agreed terms. Chainlink Automation ensures that this will happen.

### Why IPFS?

contractful Hiring Agreements are decentralized in every aspect. But blockchains are not suitable to host big payloads of data (due to the high costs of blockspace). The detailed description of a Hiring Agreement can have an arbitrary size, and might also get comparably long. Therefore data of the description is stored on IPFS. To secure the description, it is encrypted using AES ([see the contractful frontend application](https://github.com/contractful/frontend-v1)).

### protocol API

For a documentation of the protocol API, (you can visit https://contactful.vercel.app/documentation)[https://contactful.vercel.app/documentation].

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
