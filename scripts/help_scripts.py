from brownie import accounts, config, network


def get_account():
    if network.show_active() == "mainnet-fork":
        return accounts
    else:
        account = accounts.from_mnemonic(
            mnemonic=config['wallets']['from_mnemonic'],count=5
        )
        return account