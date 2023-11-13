// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract nft is ERC721, Ownable,ERC2981 {
    uint256 private _nextTokenId;

    string public uriPrefix = "";
    string public uriSuffix = ".json";

    address private _royaltiesReceiver;
    // Percentage of each sale to pay as royalties
    uint256 public constant royaltiesPercentage = 5;
    // EIP-712 domain separator
    bytes32 private DOMAIN_SEPARATOR;
    
    constructor(address initialOwner,string memory name, string memory symbol,address initialRoyaltiesReceiver, string memory _uri)
        ERC721(name, symbol)
    {
            DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("EventTicket")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
        _royaltiesReceiver = initialRoyaltiesReceiver;
        uriPrefix = _uri;
    }

    function safeMint(address to) public onlyOwner {
       uint256 tokenId = _nextTokenId++;
       _safeMint(to, tokenId);
    }

     function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
   
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tostring(uint256(_tokenId)), uriSuffix))
        : "";
    }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }

  function tostring(uint256 _value)public pure returns(string memory){
   return Strings.toString(_value);
  }

  
    // Function to transfer a ticket using an EIP-712 signature
    function transferWithSignature(address from, address to, uint256 tokenId, bytes memory signature) external {
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                keccak256("TransferWithSignature(address from,address to,uint256 tokenId)"),
                from,
                to,
                tokenId
            ))
        ));
        address signer = ECDSA.recover(hash, signature);
        require(signer == from, "EventTicket: invalid signature");
        _transfer(from, to, tokenId);
    }

       function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function royaltiesReceiver() external view returns(address) {
        return _royaltiesReceiver;
    }


    function setRoyaltiesReceiver(address newRoyaltiesReceiver)
    external onlyOwner {
        require(newRoyaltiesReceiver != _royaltiesReceiver); // dev: Same address
        _royaltiesReceiver = newRoyaltiesReceiver;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view override returns
  (address receiver, uint256 royaltyAmount) {
        uint256 _royalties = (_salePrice * royaltiesPercentage) / 100;
        return (_royaltiesReceiver, _royalties);
    }
}