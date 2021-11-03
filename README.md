# NFT Marketplace example with Next.js and Solidity

This project demonstrates a basic NFT marketplace.

## Technical Configuration

### Frontend

- Next.js
- Tailwind.css
- [Ethers.js](https://docs.ethers.io/v5/)
- [ipfs-http-client](https://www.npmjs.com/package/ipfs-http-client)
- [Web3Modal](https://www.npmjs.com/package/web3modal)

### SmartContracts

- Solidity
- [OpenZeppelin](https://openzeppelin.com/)
- [Hardhat](https://hardhat.org/)
- [ethereum-waffle](https://www.npmjs.com/package/ethereum-waffle)

## Setup locally

### Run local node

`npx hardhat node`

### Deploy the contracts to local network

Local
`npx hardhat run scripts/deploy.js --network localhost`

Rinkeby
`npx hardhat run scripts/deploy.js --network rinkeby`
### Start local server(frontend)

`npm run dev`
