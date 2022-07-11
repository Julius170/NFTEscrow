from brownie import Contract, accounts, config, network, web3


def get_account():
    if network.show_active() == "mainnet-fork":
        return accounts
    else:
        account = accounts.from_mnemonic(
            mnemonic=config["wallets"]["from_mnemonic"], count=5
        )
        return account


def transferEther():
    transferAmount = web3.toWei("1.2", "ether")
    main = get_account()[0]
    second = get_account()[1]
    main.transfer(second, transferAmount)
