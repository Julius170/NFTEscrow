from brownie import *
from brownie import MyNFT
from scripts.help_scripts import get_account


def main():
    account = get_account()
    nftPrice = web3.toWei("0.5", "ether")
    print("Deploy MyNFT Contract")
    contract = MyNFT.deploy(
        "My NFT",
        "MYNFT",
        "",
        nftPrice,
        10000,
        {"from": account[0]},
        publish_source=True,
    )
    contract.tx.wait(5)
