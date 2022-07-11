// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/IWETH.sol";

/**
 * @title MyNFT (Non-Fungible Token)
 *  @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, Enumerable extension
 */
contract MyNFT is Context, ERC165, IERC721, IERC721Metadata, Ownable {
    using Address for address;
    using Strings for uint256;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Token metadata
    string private _name;
    string private _symbol;
    string private baseURI;
    uint256 private _maxSupply;
    uint256 private _mintingPrice;
    uint256 private balance;
    address private WETH;
    Counters.Counter private _totalSupply;

    // Mapping from token id to token owners
    mapping(uint256 => address) private _owners;

    // Mapping from owners address to token id
    mapping(address => uint256) private _balances;

    // Mapping from token id to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owners address to operator address
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting the name, symbol,max supply and base URI
     * @param name_ string: Name of the token
     * @param symbol_ string: Symbol of the token
     * @param baseURI_ string: Base URI of the token
     * @param maxSupply_ uint256: Max supply of the token
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 mintingPrice,
        uint256 maxSupply_,
        address _weth
    ) {
        _name = name_;
        _symbol = symbol_;
        _maxSupply = maxSupply_;
        baseURI = baseURI_;
        _mintingPrice = mintingPrice;
        WETH = _weth;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     * @return _name string: Token name
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     * @return _symbol string: Token symbol
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Return Max Supply
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Return Total Supply
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply.current();
    }

    /**
     * @dev See {IERC721-balanceOf}.
     * @param owner_ address: owners of the token
     */
    function balanceOf(address owner_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            owner_ != address(0),
            "ERC721: balance query for the zero address"
        );
        return _balances[owner_];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     * @param tokenId_ uint256: Token ID
     */
    function ownerOf(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (address)
    {
        address owners = _owners[tokenId_];
        require(
            owners != address(0),
            "ERC721: owners query for nonexistent token"
        );
        return owners;
    }

    /**
     * @dev See {IERC721-tokenURI}.
     * @param tokenId_ uint256: Token ID
     */
    function tokenURI(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId_),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory uri = _baseURI();
        return
            bytes(uri).length > 0
                ? string(abi.encodePacked(uri, tokenId_.toString(), ".json"))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return baseURI;
    }

    /**
     * @dev See {IERC721-approve}.
     * @param to_ address: Address to approve
     * @param tokenId_ uint256: Token ID
     */
    function approve(address to_, uint256 tokenId_) public virtual override {
        address owners = MyNFT.ownerOf(tokenId_);
        require(to_ != owners, "ERC721: approval to current owners");
        require(
            _msgSender() == owners || isApprovedForAll(owners, _msgSender()),
            "ERC721: approve caller is not owners nor approved for all"
        );
        _approve(to_, tokenId_);
    }

    /**
     * @dev See {IERC721-getApproved}.
     * @param tokenId_ uint256: Token ID
     */
    function getApproved(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (address)
    {
        require(
            _exists(tokenId_),
            "ERC721: approved query for nonexistent token"
        );
        return _tokenApprovals[tokenId_];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     * @param operator_ address: Operator address
     * @param approved_ bool: Approval status
     */
    function setApprovalForAll(address operator_, bool approved_)
        public
        virtual
        override
    {
        _setApprovalForAll(_msgSender(), operator_, approved_);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     * @param owner_ address: owners address
     * @param operator_ address: Operator address
     */
    function isApprovedForAll(address owner_, address operator_)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner_][operator_];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     * @param from_ address: Address to transfer from
     * @param to_ address: Address to transfer to
     * @param tokenId_ uint256: Token ID
     */
    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId_),
            "ERC721: transfer caller is not owners nor approved"
        );

        _transfer(from_, to_, tokenId_);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owners nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owners or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        address owners = MyNFT.ownerOf(tokenId);
        return (spender == owners ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owners, spender));
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            MyNFT.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owners"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owners
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(MyNFT.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owners` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owners,
        address operator,
        bool approved
    ) internal virtual {
        require(owners != operator, "ERC721: approve to caller");
        _operatorApprovals[owners][operator] = approved;
        emit ApprovalForAll(owners, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owners of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function _calculatePayment(uint256 _tokenMount)
        internal
        view
        returns (uint256)
    {
        require(_tokenMount > 0);
        return _tokenMount.mul(_mintingPrice);
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function buyMyNFT(uint256 amount_) external payable {
        require(amount_ > 0, "ERC721: mint amount must be positive");
        require(_calculatePayment(amount_) == msg.value);
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(address(this), msg.value));
        balance = balance.add(msg.value);
        for (uint256 i = 1; i <= amount_; i++) {
            _totalSupply.increment();
            _safeMint(msg.sender, _totalSupply.current(), "");
        }
    }

    function claimPayment() external onlyOwner {
        uint256 amount = balance;
        balance = 0;
        IWETH(WETH).withdraw(amount);
        (bool status, ) = msg.sender.call{value: amount}("");
        require(status);
    }
}
