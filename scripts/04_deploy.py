from brownie import *
from brownie import MyNFT, EscrowNFT
from scripts.help_scripts import get_account


"""
In this file, we will run a simulation 
of buying NFT directly from the MyNFT smart-contract 
and reselling it using the EscrowNFT smart-contract.
====================================================
"""

def buyNft(user1):
    """
    In this simulation, user1 will be considered as a buyer
    """
    contract = MyNFT[-1]
    nftAmount = 2
    etherValue = nftAmount * web3.toWei("0.5", "ether")
    tx = contract.buyMyNFT(nftAmount, {"from": user1, "value": etherValue})
    tx.wait(5)
    print("user1 has {} MyNFT".format(contract.balanceOf(user1.address, {"from": user1})))

def main():
    user1 = get_account()[0]
    user2 = get_account()[1]
    buyNft(user1)