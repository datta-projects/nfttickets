// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract marketplace is Ownable {

 uint256 public orderCount;
 bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

 struct Order {
  address tokenaddress;
  uint256 tokenid;
  address seller;
  bool issold;
  uint256 priceinwei;
 }

 struct offers{
  uint256 offerid;
  uint256 offerprice;
  address offermadeby;
  bool offervalid;
 }

 mapping(uint256 => Order)orders;
 mapping(address =>mapping(uint256 => offers[]))publicoffers;

 event listedforsale(address tokenaddress,uint256 tokenid,uint256 priceinwei,address seller);
 event listingsold(address seller,address buyer,address tokenaddress,uint256 tokenid,uint256 price);
 event offermade(address offermadeby, address tokenaddress, uint256 tokenid, uint256 offerpriceinwei);
 event publicofferaccepted(address offerer, address tokenaddress, uint256 tokenid, uint256 priceaccepted);
 event publicofferwithdrawn(address offerer, address tokenaddress, uint256 tokenid, uint256 pricewithdrawn);
 event RoyaltiesPaid(uint256 tokenId, uint value);


 function listforsale(address _tokenaddress, uint256 _tokenid,uint256 _priceinwei)public payable returns(bool){
  orders[orderCount] = Order(
    _tokenaddress,
    _tokenid,
    msg.sender,
    false,
    _priceinwei
  );
  ERC721(_tokenaddress).safeTransferFrom(msg.sender,address(this),_tokenid);
  emit listedforsale(_tokenaddress, _tokenid, _priceinwei, msg.sender);
  return true;
 }

 function buyfromlisting(uint256 _listingid)public payable {
  Order storage order = orders[_listingid];
  require(msg.value >= order.priceinwei,"value sent should be more than or Equal to listing price");
  order.issold = true;

  uint256 salevalue = msg.value;
  if(_checkRoyalties(order.tokenaddress)){
    salevalue = _deduceRoyalties(order.tokenid,order.priceinwei,order.tokenaddress);
  }
  order.seller.call{value: salevalue}('');

  ERC721(order.tokenaddress).safeTransferFrom(address(this),msg.sender, order.tokenid);
  emit listingsold(order.seller, msg.sender, order.tokenaddress, order.tokenid, msg.value);
 }

 function makeoffer(address tokenaddress, uint256 tokenid, uint256 offerpriceinwei)public payable {
  require(msg.value >= offerpriceinwei,"amount not right");
  publicoffers[tokenaddress][tokenid].push(offers(
   publicoffers[tokenaddress][tokenid].length,
   msg.value,
   msg.sender,
   true
  )
  );
  emit offermade(msg.sender, tokenaddress, tokenid, msg.value);
 }

 function acceptpublicoffer(uint256 offerid,address tokenaddress,uint256 tokenid)public payable{
  require(ERC721(tokenaddress).ownerOf(tokenid) == msg.sender,"be the owner of nft to accept offers");
  offers storage offer = publicoffers[tokenaddress][tokenid][offerid];
  require(!offer.offervalid,"cant accept aaccepted offer");
  uint256 salevalue = offer.offerprice;
  offer.offervalid = false;
  if(_checkRoyalties(tokenaddress)){
    salevalue = _deduceRoyalties(tokenid,offer.offerprice,tokenaddress);
  }
  msg.sender.call{value: salevalue}('');
  ERC721(tokenaddress).safeTransferFrom(msg.sender, offer.offermadeby, tokenid);
  emit publicofferaccepted(offer.offermadeby, tokenaddress, tokenid, offer.offerprice);
 }

 function withdrawoffer(uint256 offerid,address tokenaddress, uint256 tokenid)public{
  offers storage offer = publicoffers[tokenaddress][tokenid][offerid];
  require(offer.offermadeby == msg.sender,"not the guy who made the offer :(");
  offer.offervalid = false;
  offer.offermadeby.call{value: offer.offerprice}('');
  emit publicofferwithdrawn(msg.sender, tokenaddress, tokenid, offer.offerprice);
 }

 function _checkRoyalties(address _contract) internal returns (bool) {
  (bool success) = IERC2981(_contract).
  supportsInterface(_INTERFACE_ID_ERC2981);
  return success;
 }

 function _deduceRoyalties(uint256 tokenId, uint256 grossSaleValue,address _tokenaddres)
 internal returns (uint256 netSaleAmount) {
     // Get amount of royalties to pays and recipient
     (address royaltiesReceiver, uint256 royaltiesAmount) = ERC2981(_tokenaddres)
     .royaltyInfo(tokenId, grossSaleValue);
     // Deduce royalties from sale value
     uint256 netSaleValue = grossSaleValue - royaltiesAmount;
     // Transfer royalties to rightholder if not zero
     if (royaltiesAmount > 0) {
         royaltiesReceiver.call{value: royaltiesAmount}('');
     }
     // Broadcast royalties payment
     emit RoyaltiesPaid(tokenId, royaltiesAmount);
     return netSaleValue;
 }

// Add this function to your existing Marketplace contract
function getPublicOffersByAddress(address offerer) external view returns (offers[] memory) {
  uint256 numOrders = orderCount;
  uint256 totalUserOffers = 0;
  // Count the total number of offers made by the address
  for (uint256 i = 0; i < numOrders; i++) {
      totalUserOffers += publicoffers[orders[i].tokenaddress][orders[i].tokenid].length;
  }
 // Create a fixed-size array to store the user's offers
  offers[] memory userOffers = new offers[](totalUserOffers);
  uint256 currentIndex = 0;
  // Populate the array with the user's offers
  for (uint256 i = 0; i < numOrders; i++) {
      offers[] storage offersArray = publicoffers[orders[i].tokenaddress][orders[i].tokenid];

      for (uint256 j = 0; j < offersArray.length; j++) {
          if (offersArray[j].offermadeby == offerer) {
              userOffers[currentIndex] = offersArray[j];
              currentIndex++;
          }
      }
  }

  return userOffers;
}




}
