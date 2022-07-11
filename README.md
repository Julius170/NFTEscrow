# NFT Escrow

NFT Escrow is a smart-contract that can make it easier for users to buy or sell their NFTs to other specified users. NFT Escrow also supports payment of purchases using ETH or with ERC20 Tokens, according to the agreement between the seller and the buyer.

- [NFT Escrow](#chainlink-mix)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Testnet Development](#testnet-development)
  - [Running Scripts and Deployment](#running-scripts-and-deployment)
    - [Setup Contract](#setup-contract)
    - [Escrow Simulation](#escrow-simulation)
  - [Linting](#linting)
  - [License](#license)

## Prerequisites

Please install or have installed the following:

- [nodejs and npm](https://nodejs.org/en/download/)
- [python](https://www.python.org/downloads/)
## Installation

1. [Install Brownie](https://eth-brownie.readthedocs.io/en/stable/install.html), if you haven't already. Here is a simple way to install brownie.


```bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath
# restart your terminal
pipx install eth-brownie
```
Or, if that doesn't work, via pip
```bash
pip install eth-brownie
```

2. Download the project and install dependencies.

```bash
git clone https://github.com/PatrickAlphaC/chainlink-mix
cd chainlink-mix
pip install -r requirements.txt
```

## Testnet Development
Before we deploy to the Rinkeby network, do the following.

Set your `WEB3_INFURA_PROJECT_ID`, and `MNEMONIC` [environment variables](https://www.twilio.com/blog/2017/01/how-to-set-environment-variables.html).

You can get a `WEB3_INFURA_PROJECT_ID` by getting a free trial of [Infura](https://infura.io/). At the moment, it does need to be infura with brownie. If you get lost, you can [follow this guide](https://ethereumico.io/knowledge-base/infura-api-key-guide/) to getting a project key. You can find your `MNEMONIC` from your ethereum wallet like [metamask](https://metamask.io/) or you can create a temporary mnemonic to test this project [Bip39 Mnemonic Code](https://iancoleman.io/bip39/)

You'll also need testnet ETH and LINK. You can get LINK and ETH into your wallet by using the [faucets located here](https://docs.chain.link/docs/link-token-contracts). If you're new to this, [watch this video.](https://www.youtube.com/watch?v=P7FX_1PePX0). Look at the `rinkeby` sections for those specific testnet faucets. 

You can add your environment variables to a `.env` file. You can use the [.env.exmple](https://github.com/yafiabiyyu/NFTEscrow/blob/main/.env.example) as a template, just fill in the values and rename it to '.env'.

Here is what your `.env` should look like:
```
WEB3_INFURA_PROJECT_ID=<PROJECT_ID>
PRIVATE_KEY=<PRIVATE_KEY>
```


![WARNING](https://via.placeholder.com/15/f03c15/000000?text=+) **WARNING** ![WARNING](https://via.placeholder.com/15/f03c15/000000?text=+)

DO NOT SEND YOUR PRIVATE KEY WITH FUNDS IN IT ONTO GITHUB

## Running Scripts and Deployment

### Setup Contract

This will deploy the smart contract to rinkeby and make faucet requests to the FakeToken faucet I have created.
```bash
brownie run scripts/setup.py --network rinkeby
```
### Escrow Simulation

This will run a simulation of the entire function of the NFT Escrow.

```bash
brownie run scripts/simulation.py --network rinkeby
```

## Linting

If you're using [vscode](https://code.visualstudio.com/) and the [solidity extension](https://github.com/juanfranblanco/vscode-solidity), you can create a folder called `.vscode` at the root folder of this project, and create a file called `settings.json`, and add the following content:

```json
{
  "solidity.remappings": [
    "@chainlink/=[YOUR_HOME_DIR]/.brownie/packages/smartcontractkit/chainlink-brownie-contracts@0.2.2",
    "@openzeppelin/=[YOUR_HOME_DIR]/.brownie/packages/OpenZeppelin/openzeppelin-contracts@4.3.2"
  ]
}
```
This will quiet the linting errors it gives you. 

## License

This project is licensed under the [MIT license](LICENSE).