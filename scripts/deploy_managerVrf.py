from brownie import *
from brownie import ManagerVrf
from scripts.help_scripts import get_account

def main():
    coor = config['networks'][network.show_active()]['coordinator']
    link = config['networks'][network.show_active()]['link']
    account = get_account()
    token = Contract.from_explorer(link)
    deposit_amount = web3.toWei("2", "ether")
    manager = ManagerVrf.deploy(
        coor,
        link,
        {"from": account[0]}
    )
    # Approve Link for deposit to manager address
    token.approve(manager.address, deposit_amount, {"from": account[0]})

    # Topup Link to manager contract
    tx_topup = manager.topUpLink(deposit_amount, {"from": account[0]})
    tx_topup.wait(5)

    # Topup for subscription VRF
    tx_subscription = manager.topUpSubscription(deposit_amount, {"from": account[0]})
    tx_subscription.wait(5)
