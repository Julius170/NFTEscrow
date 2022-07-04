from brownie import *
from brownie import ManagerVrf
from scripts.help_scripts import get_account


def main():
    account = get_account()
    depositAmount = web3.toWei("2", "ether")
    coordinator = config["networks"][network.show_active()]["coordinator"]
    linkAddress = config["networks"][network.show_active()]["link"]
    linkToken = Contract.from_explorer(linkAddress)

    # Deploy ManagerVRF Contract
    print("Deploy ManagerVRF Contract")
    contract = ManagerVrf.deploy(
        coordinator, linkAddress, {"from": account[0]}, publish_source=True
    )
    contract.tx.wait(5)

    # Deposit Link Token to ManagerVRF
    print("Deposit Link Token to ManagerVRF")
    linkToken.approve(contract.address, depositAmount, {"from": account[0]})
    deposit = contract.topUpLink(depositAmount, {"from": account[0]})
    deposit.wait(5)

    # Deposit Link Token to ManagerVRF Subscription
    print("Deposit Link Token to ManagerVRF Subscription")
    depositSub = contract.topUpSubscription(depositAmount, {"from": account[0]})
    depositSub.wait(5)
