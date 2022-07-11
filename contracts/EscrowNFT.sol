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
    uint256 private escrowModulus = 10**escrowDigit;
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
    mapping(uint256 => mapping(address => uint256)) public userBalance;
    mapping(address => uint256) private contractBalance;

    event AdminClaimBalance(
        address _adminAddress,
        address _tokenAddress,
        uint256 _tokenAmount
    );
    event NewEscrow(
        uint256 _escrowId,
        uint256 _tokenId,
        address _nftAddress,
        address _sellerAddress,
        address _buyerAddress
    );
    event NewPayment(
        uint256 _escrowId,
        address _buyerAddress,
        address _sellerAddress,
        uint256 _paymentAmount
    );
    event NewRejectPayment(
        address _buyerAddress,
        address _sellerAddress,
        uint256 _tokenId
    );
    event NewCancleEscrow(
        uint256 _escrowId,
        address _sellerAddress,
        address _nftAddress,
        uint256 _tokenId
    );
    event ClaimPayment(
        address _sellerAddress,
        address _paymentAddress,
        uint256 _balanceAmount
    );

    modifier onlySeller(uint256 _escrowId) {
        require(sellerToBuyer[_escrowId].sellerAddress == msg.sender);
        _;
    }

    modifier onlyBuyer(uint256 _escrowId) {
        require(sellerToBuyer[_escrowId].buyerAddress == msg.sender);
        _;
    }

    modifier checkAmount(uint256 _escrowId, uint256 _paymentAmount) {
        require(sellerToBuyer[_escrowId].paymentAmount == _paymentAmount);
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

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
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

    function updateFee(uint256 _fee) external onlyOwner {
        require(_fee > 0);
        fee = _fee;
    }

    function withdrawFee(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0));
        require(contractBalance[_tokenAddress] > 0);
        uint256 tokenAmount = contractBalance[_tokenAddress];
        contractBalance[_tokenAddress] = 0;
        if (_tokenAddress == WETH) {
            IWETH(_tokenAddress).withdraw(tokenAmount);
            (bool status, ) = msg.sender.call{value: tokenAmount}("");
            require(status);
        } else {
            IERC20(_tokenAddress).transfer(msg.sender, tokenAmount);
        }
        emit AdminClaimBalance(msg.sender, _tokenAddress, tokenAmount);
    }

    function createEscrow(
        uint256 _tokenId,
        uint256 _paymentAmount,
        address _nftAddress,
        address _paymentAddress,
        address _buyerAddress,
        Payment _payment
    ) external {
        require(_paymentAmount > 0);
        require(_nftAddress != address(0));
        require(_paymentAddress != address(0));
        require(_buyerAddress != address(0));
        require(_buyerAddress != msg.sender);
        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _tokenId);
        rekberData.tokenId = _tokenId;
        rekberData.paymentAmount = _paymentAmount;
        rekberData.nftAddress = _nftAddress;
        rekberData.paymentAddress = _paymentAddress;
        rekberData.sellerAddress = msg.sender;
        rekberData.buyerAddress = _buyerAddress;
        rekberData.status = Status.Pending;
        rekberData.payment = _payment;
        uint256 escrowId = _generateEscrowId(_tokenId, _buyerAddress);
        sellerToBuyer[escrowId] = rekberData;
        emit NewEscrow(
            escrowId,
            _tokenId,
            _nftAddress,
            msg.sender,
            _buyerAddress
        );
    }

    function payWithEther(uint256 _escrowId)
        external
        payable
        onlyBuyer(_escrowId)
        checkAmount(_escrowId, msg.value)
    {
        require(sellerToBuyer[_escrowId].status == Status.Pending);
        (uint256 platformFee, uint256 userReceive) = _calculateFee(msg.value);
        sellerToBuyer[_escrowId].status = Status.Accept;
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(address(this), msg.value));
        userBalance[_escrowId][WETH] = userBalance[_escrowId][WETH].add(
            userReceive
        );
        contractBalance[WETH] = contractBalance[WETH].add(platformFee);
        IERC721(sellerToBuyer[_escrowId].nftAddress).transferFrom(
            address(this),
            msg.sender,
            sellerToBuyer[_escrowId].tokenId
        );
        emit NewPayment(
            _escrowId,
            msg.sender,
            sellerToBuyer[_escrowId].sellerAddress,
            msg.value
        );
    }

    function payWithToken(uint256 _escrowId, uint256 _tokenAmount)
        external
        onlyBuyer(_escrowId)
        checkAmount(_escrowId, _tokenAmount)
    {
        require(sellerToBuyer[_escrowId].status == Status.Pending);
        sellerToBuyer[_escrowId].status = Status.Accept;
        (uint256 platformFee, uint256 userReceive) = _calculateFee(
            _tokenAmount
        );
        IERC20(sellerToBuyer[_escrowId].paymentAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        userBalance[_escrowId][
            sellerToBuyer[_escrowId].paymentAddress
        ] = userBalance[_escrowId][sellerToBuyer[_escrowId].paymentAddress].add(
            userReceive
        );
        contractBalance[
            sellerToBuyer[_escrowId].paymentAddress
        ] = contractBalance[sellerToBuyer[_escrowId].paymentAddress].add(
            platformFee
        );
        IERC721(sellerToBuyer[_escrowId].nftAddress).transferFrom(
            address(this),
            msg.sender,
            sellerToBuyer[_escrowId].tokenId
        );
        emit NewPayment(
            _escrowId,
            sellerToBuyer[_escrowId].buyerAddress,
            msg.sender,
            _tokenAmount
        );
    }

    function rejectPayment(uint256 _escrowId) external onlyBuyer(_escrowId) {
        require(sellerToBuyer[_escrowId].status == Status.Pending);
        sellerToBuyer[_escrowId].status = Status.Reject;
        IERC721(sellerToBuyer[_escrowId].nftAddress).safeTransferFrom(
            address(this),
            sellerToBuyer[_escrowId].sellerAddress,
            sellerToBuyer[_escrowId].tokenId
        );
        emit NewRejectPayment(
            msg.sender,
            sellerToBuyer[_escrowId].sellerAddress,
            sellerToBuyer[_escrowId].tokenId
        );
    }

    function cancleEscrow(uint256 _escrowId) external onlySeller(_escrowId) {
        require(sellerToBuyer[_escrowId].status == Status.Pending);
        sellerToBuyer[_escrowId].status = Status.Canceled;
        IERC721(sellerToBuyer[_escrowId].nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            sellerToBuyer[_escrowId].tokenId
        );
        emit NewCancleEscrow(
            _escrowId,
            msg.sender,
            sellerToBuyer[_escrowId].nftAddress,
            sellerToBuyer[_escrowId].tokenId
        );
    }

    function claimPayment(uint256 _escrowId) external onlySeller(_escrowId) {
        require(sellerToBuyer[_escrowId].status == Status.Accept);
        address paymentAddress = sellerToBuyer[_escrowId].paymentAddress;
        uint256 balanceAmount = userBalance[_escrowId][paymentAddress];
        userBalance[_escrowId][paymentAddress] = 0;
        if (paymentAddress == WETH) {
            IWETH(paymentAddress).withdraw(balanceAmount);
            (bool status, ) = msg.sender.call{value: balanceAmount}("");
            require(status);
        } else {
            IERC20(paymentAddress).transfer(msg.sender, balanceAmount);
        }
        emit ClaimPayment(msg.sender, paymentAddress, balanceAmount);
    }

    function _calculateFee(uint256 _paymentAmount)
        private
        view
        returns (uint256 platformFee, uint256 userReceive)
    {
        platformFee = _paymentAmount.div(100).mul(fee);
        userReceive = _paymentAmount.sub(platformFee);
    }

    function _generateEscrowId(uint256 _nftId, address _buyerAddress)
        private
        view
        returns (uint256 escrowId)
    {
        uint256 id = (randomWords[0] % block.timestamp) + 1;
        escrowId =
            uint256(
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
            ) %
            escrowModulus;
    }
}
