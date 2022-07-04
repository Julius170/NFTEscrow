from brownie import *
from brownie import EscrowNFT, ManagerVrf
from scripts.help_scripts import get_account


def main():
    account = get_account()
    managerContract = ManagerVrf[-1]
    coordinator = config["networks"][network.show_active()]["coordinator"]
    weth = config["networks"][network.show_active()]["weth"]
    keyhash = config["networks"][network.show_active()]["keyhash"]

    # Get Subscription ID from ManagerVRF Contract
    subId = managerContract.getSubscriptionId({"from": account[0]})

    # Deploy Escrow NFT Contract
    print("Deploy Escrow NFT Contract")
    contract = EscrowNFT.deploy(
        coordinator,
        weth,
        20,
        subId,
        100000,
        2,
        3,
        keyhash,
        {"from": account[0]},
        publish_source=True,
    )
    contract.tx.wait(5)

    # Register Escrow NFT Contract to ManagerVRF Consumer
    print("Register Escrow NFT Contract to ManagerVRF Consumer")
    addConsumer = managerContract.addConsumer(contract.address, {"from": account[0]})
    addConsumer.wait(5)

    # Request random words from ManagerVRF
    print("Request random words from ManagerVRF")
    requestRandom = contract.requestRandomWords({"from": account[0]})
    requestRandom.wait(5)
