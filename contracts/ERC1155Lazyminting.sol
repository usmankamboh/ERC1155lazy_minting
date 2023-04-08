// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
contract ERC1155Lazyminting is ERC1155URIStorage, AccessControl,EIP712, Ownable  {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_DOMAIN = "NFTVoucher";
    string private constant SIGNATURE_VERSION = "1.0";
    uint256 public tokenIds;
    uint256 public serviceFee;
    address public marketplace;
    // Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        // The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
        uint256 mintPrice;
        // The metadata URI to associate with this token.
        string uri;
        // amount
        uint256 amount;
        // The royalty fee
        uint256 royalty;
        // Timestamp to increase safety
        uint256 timestamp;
        bytes signature;
    }
    mapping(address => uint256) pendingWithdrawals;
    // tokenId to Creator address
    mapping(uint256 => address) creator;
    // tokenId to royalty Fee
    mapping(uint256 => uint256) royaltyFee;
    event MintNFT(address owner, uint256 tokenID, address nftContract);
    constructor(address _marketplace,string memory _uri) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) ERC1155(_uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        serviceFee = 2.5e18;
        marketplace = _marketplace;
    }
    // Redeems an NFTVoucher for an actual NFT, creating it in the process.
    // _redeemer The address of the account which will receive the NFT upon success.
    // _voucher An NFTVoucher that describes the NFT to be redeemed.
    // _signer An EIP712 signature of the voucher, produced by the NFT creator.
    function redeem(
        address payable _signer,
        address _redeemer,
        NFTVoucher calldata _voucher
    ) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signerVerified = _verify(_voucher, _voucher.signature);
        // make sure that the signer is authorized to mint NFTs
        require(_signer == signerVerified, "Signature Invalid");
        // make sure that the signer is authorized to mint NFTs
        require(
            hasRole(MINTER_ROLE, _signer),
            "Signature invalid or unauthorized"
        );
        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= _voucher.mintPrice, "Insufficient funds to redeem");
        tokenIds++;
        creator[tokenIds] = _signer;
        royaltyFee[tokenIds] = _voucher.royalty;
        // first assign the token to the _signer, to establish provenance on-chain
        _mint(_signer, tokenIds,_voucher.amount,"");
        _setURI(tokenIds, _voucher.uri);
        setApprovalForAll(marketplace, true);
        // transfer the token to the redeemer
        _safeTransferFrom(_signer, _redeemer, tokenIds,_voucher.amount,"");
        // cut service fee
        uint256 fee = (_voucher.mintPrice * serviceFee) / 100e18;
        uint256 remainingPrice = _voucher.mintPrice - fee;
        // transfer price to owner
        _signer.transfer(remainingPrice);
        // record payment to signer's withdrawal balance
        // pendingWithdrawals[signer] += msg.value;
        emit MintNFT(msg.sender, tokenIds, address(this));
        return tokenIds;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    // Verifies the signature for a given NFTVoucher, returning the address of the signer.
    // Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    // voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher, bytes calldata signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, signature);
    }
    // Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    // voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 mintPrice,string uri,uint256 amount,uint256 royalty,uint256 timestamp)"
                        ),
                        voucher.mintPrice,
                        keccak256(bytes(voucher.uri)),
                        voucher.amount,
                        voucher.royalty,
                        voucher.timestamp
                    )
                )
            );
    }

    // _tokenUri The token URI passed
    // _royalty The royalty fee
    // TotalCount
    function multiMint(string memory _tokenUri,uint256 amount, uint256 _royalty)
        external
        returns (uint256)
    {
        tokenIds++;
        creator[tokenIds] = msg.sender;
        royaltyFee[tokenIds] = _royalty;
        _mint(msg.sender, tokenIds,amount,"");
        _setURI(tokenIds, _tokenUri);
        setApprovalForAll(marketplace, true);
        emit MintNFT(msg.sender, tokenIds, address(this));
        return tokenIds;
    }

    function setApproval(address _marketplace) public onlyOwner {
        setApprovalForAll(_marketplace, true);
    }

    function getCreator(uint256 _tokenId) public view returns (address) {
        return creator[_tokenId];
    }

    function getFee(uint256 _tokenId) public view returns (uint256) {
        return royaltyFee[_tokenId];
    }
}