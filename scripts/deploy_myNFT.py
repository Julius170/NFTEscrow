from brownie import *
from brownie import MyNFT
from scripts.help_scripts import get_account


def main():
    account = get_account()
    contract = MyNFT.deploy(
        "My NFT",
        "MYNFT",
        "",
        web3.toWei("0.5", "ether"),
        10000,
        {"from": account[0]}
    )