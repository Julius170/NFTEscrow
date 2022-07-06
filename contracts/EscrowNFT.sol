// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "../interfaces/IWETH.sol";

contract EscrowNFT is VRFConsumerBaseV2, Ownable {
    // State variables used for Chainlink VRF
    VRFCoordinatorV2Interface coordinatorVrf;
    using SafeMath for uint256;
    uint256[] private randomWords;
    uint256 private requestId;
    uint256 public fee;
    uint256 private escrowDigit = 16;
    uint256 private escrowModulus = 10 ** escrowDigit;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    uint32 numberWords;
    uint16 requestConfirmation;
    bytes32 keyHash;
    address WETH;

    enum Payment {
        Ether,
        Token
    }

    enum Status {
        Pending,
        Accept,
        Reject,
        Canceled
    }

    struct RekberData {
        uint256 tokenId;
        uint256 paymentAmount;
        address nftAddress;
        address paymentAddress;
        address sellerAddress;
        address buyerAddress;
        Status status;
        Payment payment;
    }
    RekberData rekberData;

    mapping(uint256 => RekberData) public sellerToBuyer;
    mapping(uint256 => mapping(address => uint256)) private userBalance;
    mapping(address => uint256) private contractBalance;

    event UpdateFee(address _sender, uint256 _amountFee);
    event NewEscrow(
        uint256 _tokenId,
        uint256 _escrowId,
        address _nftAddress,
        address _sellerAddress,
        address _buyerAddress
    );
    event NewCancle(address _seller, address _buyer, uint256 _tokenId);
    event NewPayment(address _buyer, uint256 _rekberId, uint256 paymentTotal);
    event NewReject(address _buyer, uint256 _rekberId, uint256 paymentTotal);
    event NewClaim(
        address _sellerAddress,
        address _assetAddress,
        uint256 _claimAmount
    );

    modifier onlySeller(uint256 _rekberId) {
        require(sellerToBuyer[_rekberId].sellerAddress == msg.sender);
        _;
    }

    modifier onlyBuyer(uint256 _rekberId) {
        require(sellerToBuyer[_rekberId].buyerAddress == msg.sender);
        _;
    }

    constructor(
        address _coordinatorVrf,
        address _weth,
        uint256 _fee,
        uint64 _subscriptionId,
        uint32 _callBackGasLimit,
        uint32 _numberWords,
        uint16 _requestConfirmation,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_coordinatorVrf) {
        coordinatorVrf = VRFCoordinatorV2Interface(_coordinatorVrf);
        fee = _fee;
        WETH = _weth;
        subscriptionId = _subscriptionId;
        callBackGasLimit = _callBackGasLimit;
        numberWords = _numberWords;
        requestConfirmation = _requestConfirmation;
        keyHash = _keyHash;
    }

    function requestRandomWords() external onlyOwner {
        requestId = coordinatorVrf.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmation,
            callBackGasLimit,
            numberWords
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory _randomWords)
        internal
        override
    {
        randomWords = _randomWords;
    }

    function updateFee(uint256 _amountFee) external onlyOwner {
        require(_amountFee > 0);
        fee = _amountFee;
        emit UpdateFee(msg.sender, _amountFee);
    }

    function adminClaimFee(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0));
        require(contractBalance[_feeAddress] > 0);
        uint256 amountBalance = contractBalance[_feeAddress];
        if (_feeAddress == WETH) {
            IWETH(WETH).withdraw(amountBalance);
            contractBalance[_feeAddress] = 0;
            (bool status, ) = msg.sender.call{value: amountBalance}("");
            require(status);
        } else {
            contractBalance[_feeAddress] = 0;
            IERC20(_feeAddress).transfer(msg.sender, amountBalance);
        }
    }

    function createEscrow(
        uint256 _tokenId,
        uint256 _paymentAmount,
        address _nftAddress,
        address _paymentAddress,
        address _buyerAddress,
        Payment _payment
    ) external returns (uint256 escrowId) {
        require(_paymentAmount > 0);
        require(_nftAddress != address(0));
        require(_paymentAddress != address(0));
        require(_buyerAddress != address(0));
        escrowId = _createEscrowId(_tokenId, _buyerAddress);
        IERC721 nft = IERC721(_nftAddress);
        nft.transferFrom(msg.sender, address(this), _tokenId);
        if (_payment == Payment.Ether) {
            rekberData.paymentAddress = WETH;
        } else {
            rekberData.paymentAddress = _paymentAddress;
        }
        rekberData.tokenId = _tokenId;
        rekberData.paymentAmount = _paymentAmount;
        rekberData.nftAddress = _nftAddress;
        rekberData.sellerAddress = msg.sender;
        rekberData.buyerAddress = _buyerAddress;
        rekberData.status = Status.Pending;
        rekberData.payment = _payment;
        sellerToBuyer[escrowId] = rekberData;
        emit NewEscrow(
            _tokenId,
            escrowId,
            _nftAddress,
            msg.sender,
            _buyerAddress
        );
    }

    function cancleEscrow(uint256 _escrowId) external onlySeller(_escrowId) {
        require(sellerToBuyer[_escrowId].status == Status.Pending);
        IERC721 nft = IERC721(sellerToBuyer[_escrowId].nftAddress);
        sellerToBuyer[_escrowId].status = Status.Canceled;
        nft.transferFrom(address(this), msg.sender, sellerToBuyer[_escrowId].tokenId);
        emit NewCancle(msg.sender, sellerToBuyer[_escrowId].buyerAddress, sellerToBuyer[_escrowId].tokenId);
    }

    function _calculateFee(uint256 _paymentAmount)
        private
        view
        returns (uint256 feePlatform, uint256 userReceive)
    {
        feePlatform = _paymentAmount.div(100).mul(fee);
        userReceive = _paymentAmount.sub(feePlatform);
    }

    function _createEscrowId(uint256 _nftId, address _buyerAddress) private view returns (uint256 escrowId) {
        uint256 id = (randomWords[0] % block.timestamp) + 1;
        escrowId = uint256(
            keccak256(
                abi.encode(
                    randomWords[1],
                    id,
                    block.timestamp,
                    msg.sender,
                    _nftId,
                    _buyerAddress
                )
            )
        ) % escrowModulus;
    }
}
