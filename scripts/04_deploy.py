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
    print("NFT Address : {}".format(contract.address))

def escrowNFT(user1, user2):
    tokenId = 2
    paymentAmount = web3.toWei("1", "ether")
    token1Address = config['networks'][network.show_active()]['weth']
    nftContract = MyNFT[-1]
    escrow = EscrowNFT[-1]

    # approve nft token
    nftContract.approve(escrow.address, tokenId, {"from": user1})

    # create escrow
    tx_create = escrow.createEscrow(
        tokenId,
        paymentAmount,
        nftContract.address,
        token1Address,
        user2.address,
        0,
        {"from": user1}
    )
    tx_create.wait(5)
    escrowId = tx_create.events['NewEscrow']['_escrowId']
    tx_cancle = escrow.cancleEscrow(escrowId, {"from": user1})
    tx_cancle.wait(5)
    print(escrowId)
    print("NFT Escrow Address : {}".format(escrow.address))

def main():
    user1 = get_account()[0]
    user2 = get_account()[1]
    # buyNft(user1)
    escrowNFT(user1, user2)