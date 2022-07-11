from brownie import *
from brownie import MyNFT, EscrowNFT
from scripts.help_scripts import get_account


def buyNFT(buyer, nftContract, nftAmount):
    print("Buy NFT From MyNFT Contract")
    paymentAmount = nftAmount * web3.toWei("0.5", "ether")
    tx_buyNft = nftContract.buyMyNFT(nftAmount, {"from": buyer, "value": paymentAmount})
    tx_buyNft.wait(5)


def createEscrow(
    seller,
    buyer,
    tokenId,
    paymentAmount,
    paymentAddress,
    paymentMethod,
    escrowContract,
    nftContract,
):
    # Approve NFT to Escrow Contract
    nftContract.approve(escrowContract.address, tokenId, {"from": seller})

    tx_create = escrowContract.createEscrow(
        tokenId,
        paymentAmount,
        nftContract.address,
        paymentAddress,
        buyer.address,
        paymentMethod,
        {"from": seller},
    )
    tx_create.wait(5)
    escrowId = tx_create.events["NewEscrow"]["_escrowId"]
    print("Escrow ID : {}".format(escrowId))
    return escrowId


def payEscrow(
    buyer, escrowId, paymentAmount, paymentMethod, escrowContract, tokenContract
):
    if paymentMethod == 0:
        tx_pay_ether = escrowContract.payWithEther(
            escrowId, {"from": buyer, "value": paymentAmount}
        )
        tx_pay_ether.wait(5)
    else:
        tokenContract.approve(escrowContract.address, paymentAmount, {"from": buyer})

        tx_pay_token = escrowContract.payWithToken(
            escrowId, paymentAmount, {"from": buyer}
        )
        tx_pay_token.wait(5)


def claimPayment(seller, escrowId, escrowContract):
    tx_claim = escrowContract.claimPayment(escrowId, {"from": seller})
    tx_claim.wait(5)


def ownerClaimFeeEscrow(owner, paymentAddress, escrowContract):
    tx_wd_fee = escrowContract.withdrawFee(paymentAddress, {"from": owner})
    tx_wd_fee.wait(5)


def ownerClaimPaymentNFT(owner, nftContract):
    tx_claimPayment = nftContract.claimPayment({"from": owner})
    tx_claimPayment.wait(5)


def main():
    account1 = get_account()[0]
    account2 = get_account()[1]
    nft = MyNFT[-1]
    escrow = EscrowNFT[-1]
    fakeToken = Contract.from_explorer(
        config["networks"][network.show_active()]["faketoken"]
    )
    wethAddress = config["networks"][network.show_active()]["weth"]
    paymentAmount = web3.toWei("1", "ether")
    buyNFT(account1, nft, 2)
    escrowIdEther = createEscrow(account1, account2, 1, paymentAmount, wethAddress, 0, escrow, nft)
    escrowIdToken = createEscrow(account1, account2, 2, paymentAmount, fakeToken.address, 1, escrow, nft)
    payEscrow(account2, escrowIdEther, paymentAmount, 0, escrow, wethAddress)
    payEscrow(account2, escrowIdToken, paymentAmount, 1, escrow, fakeToken)
    claimPayment(account1, escrowIdEther, escrow)
    claimPayment(account1, escrowIdToken, escrow)
    ownerClaimFeeEscrow(account1, wethAddress, escrow)
    ownerClaimFeeEscrow(account1, fakeToken.address, escrow)
    ownerClaimPaymentNFT(account1, nft)
