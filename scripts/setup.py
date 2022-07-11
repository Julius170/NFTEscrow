from brownie import *
from brownie import ManagerVrf, MyNFT, EscrowNFT
from scripts.help_scripts import get_account


def deployManagerVRF(owner):
    link = Contract.from_explorer(config["networks"][network.show_active()]["link"])
    coordinator = config["networks"][network.show_active()]["coordinator"]
    linkAmount = web3.toWei("3", "ether")

    print("Deploy Manager VRF")
    contract = ManagerVrf.deploy(
        coordinator, link.address, {"from": owner}, publish_source=True
    )
    contract.tx.wait(5)
    link.approve(contract.address, linkAmount, {"from": owner}, publish_source=True)
    deposit_tx = contract.topUpLink(linkAmount, {"from": owner}, publish_source=True)
    deposit_tx.wait(5)

    topup_sub_tx = contract.topUpSubscription(
        linkAmount, {"from": owner}, publish_source=True
    )
    topup_sub_tx.wait(5)


def deployEscrow(owner):
    manager = ManagerVrf[-1]
    coordinator = config["networks"][network.show_active()]["coordinator"]
    weth = config["networks"][network.show_active()]["weth"]
    keyhash = config["networks"][network.show_active()]["keyhash"]
    subscriptionId = manager.getSubscriptionId({"from": owner}, publish_source=True)

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

    tx_add_consumer = manager.addConsumer(
        contract.address, {"from": owner}, publish_source=True
    )
    tx_add_consumer.wait(5)

    tx_request_number = contract.requestRandomWords(
        {"from": owner}, publish_source=True
    )
    tx_request_number.wait(5)


def deployNFT(owner):
    nftPrice = web3.toWei("0.5", "ether")
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
    deployManagerVRF(owner)
    deployEscrow(owner)
    deployNFT(owner)
    print("Address List")
    print("Manager : {}".format(ManagerVrf[-1]))
    print("Escrow : {}".format(EscrowNFT[-1]))
    print("NFT : {}".format(MyNFT[-1]))
