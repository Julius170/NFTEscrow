from brownie import *
from brownie import ManagerVrf, MyNFT, EscrowNFT
from scripts.help_scripts import get_account
from sys import exit


def checkBalanceAndFaucet(account, secAcc):
    fakeToken = Contract.from_explorer(
        config["networks"][network.show_active()]["faketoken"]
    )
    balance = account.balance()
    if balance < web3.toWei("2", "ether"):
        print("prepare at least 2 rinkebyETH to run this project")
        exit()
    else:
        account.transfer(secAcc, web3.toWei("1", "ether"))
        fakeToken.faucet(secAcc, {"from": account})


def deployManagerVRF(owner):
    link = Contract.from_explorer(config["networks"][network.show_active()]["link"])
    coordinator = config["networks"][network.show_active()]["coordinator"]
    linkAmount = web3.toWei("3", "ether")

    print("Deploy Manager VRF")
    contract = ManagerVrf.deploy(
        coordinator, link.address, {"from": owner}, publish_source=True
    )
    contract.tx.wait(5)
    link.approve(contract.address, linkAmount, {"from": owner})
    deposit_tx = contract.topUpLink(linkAmount, {"from": owner})
    deposit_tx.wait(5)

    topup_sub_tx = contract.topUpSubscription(linkAmount, {"from": owner})
    topup_sub_tx.wait(5)


def deployEscrow(owner):
    manager = ManagerVrf[-1]
    coordinator = config["networks"][network.show_active()]["coordinator"]
    weth = config["networks"][network.show_active()]["weth"]
    keyhash = config["networks"][network.show_active()]["keyhash"]
    subscriptionId = manager.getSubscriptionId({"from": owner})

    print("Deploy Escrow NFT Contract")
    contract = EscrowNFT.deploy(
        coordinator,
        weth,
        20,
        subscriptionId,
        100000,
        2,
        3,
        keyhash,
        {"from": owner},
        publish_source=True,
    )
    contract.tx.wait(5)

    tx_add_consumer = manager.addConsumer(contract.address, {"from": owner})
    tx_add_consumer.wait(5)

    tx_request_number = contract.requestRandomWords({"from": owner})
    tx_request_number.wait(5)


def deployNFT(owner):
    nftPrice = web3.toWei("0.001", "ether")
    print("Deploy MyNFT Contract")
    contract = MyNFT.deploy(
        "NFT Testnet",
        "NT",
        "",
        nftPrice,
        web3.toWei("1000", "ether"),
        config["networks"][network.show_active()]["weth"],
        {"from": owner},
        publish_source=True,
    )
    contract.tx.wait(5)


def main():
    owner = get_account()[0]
    secAcc = get_account()[1]
    checkBalanceAndFaucet(owner, secAcc)
    deployManagerVRF(owner)
    deployEscrow(owner)
    deployNFT(owner)
    print("Address List")
    print("Manager : {}".format(ManagerVrf[-1]))
    print("Escrow : {}".format(EscrowNFT[-1]))
    print("NFT : {}".format(MyNFT[-1]))
