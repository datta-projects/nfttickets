// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ticketPool is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    address public nftContract;
    address public tokenContract;
    uint256 public baseTicketPrice;
    uint256 public maxTickets;
    uint256 public timeToEvent;
    uint256 public priceIncreaseRate;
    Counters.Counter private currentTicketIndex;
    Counters.Counter private totalTicketsSold;

    mapping(uint256 => address) public ticketOwners;
    mapping(address => uint256[]) public ownerTickets;

    event TicketAdded(uint256 indexed tokenId, address indexed owner);
    event TicketRemoved(uint256 indexed tokenId, address indexed owner);
    event TicketSold(uint256 indexed tokenId, address indexed buyer, uint256 newPrice);

    modifier eventNotStarted() {
        require(block.timestamp < timeToEvent, "Event has already started");
        _;
    }

    modifier notSoldOut() {
        require(totalTicketsSold.current() < maxTickets, "No more tickets available");
        _;
    }

    constructor(
        address _nftContract,
        address _tokenContract,
        uint256 _baseTicketPrice,
        uint256 _maxTickets,
        uint256 _timeToEvent,
        uint256 _priceIncreaseRate
    )  {
        nftContract = _nftContract;
        tokenContract = _tokenContract;
        baseTicketPrice = _baseTicketPrice;
        maxTickets = _maxTickets;
        timeToEvent = _timeToEvent;
        priceIncreaseRate = _priceIncreaseRate;
    }

    function addTickets(uint256[] calldata tokenIds) external onlyOwner {
        require(totalTicketsSold.current() + tokenIds.length <= maxTickets, "Exceeds maximum tickets");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(ERC721(nftContract).ownerOf(tokenId) == owner(), "Not the owner of the NFT");

            ticketOwners[tokenId] = owner();
            ownerTickets[owner()].push(tokenId);
            ERC721(nftContract).safeTransferFrom(msg.sender,address(this),tokenId);

            emit TicketAdded(tokenId, owner());
        }
    }

    function removeTickets(uint256[] calldata tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(ticketOwners[tokenId] == owner(), "Not the owner of the ticket");

            ticketOwners[tokenId] = address(0);
            ownerTickets[owner()] = _removeElement(ownerTickets[owner()], tokenId);
            ERC721(nftContract).safeTransferFrom(address(this),msg.sender,tokenId);

            emit TicketRemoved(tokenId, owner());
        }
    }

    function buyTicket() external notSoldOut eventNotStarted {
        require(ownerTickets[msg.sender].length > 0, "No tickets available for the buyer");

        uint256 tokenId = ownerTickets[msg.sender][0];
        address previousOwner = ticketOwners[tokenId];

        // Calculate the new ticket price based on time to the event
        uint256 newPrice = calculateTicketPrice();

        // Transfer funds from the buyer to the previous owner using safeTransferFrom
        IERC20(tokenContract).transferFrom(msg.sender, previousOwner, newPrice);

        // Transfer the NFT to the buyer using safeTransferFrom
        ERC721(nftContract).safeTransferFrom(previousOwner, msg.sender, tokenId);

        // Update ticket ownership and balance
        ticketOwners[tokenId] = msg.sender;
        ownerTickets[previousOwner] = _removeElement(ownerTickets[previousOwner], tokenId);
        ownerTickets[msg.sender].push(tokenId);

        // Increase the ticket index for the next buyer
        currentTicketIndex.increment();
        totalTicketsSold.increment();

        // Emit event for ticket sale
        emit TicketSold(tokenId, msg.sender, newPrice);
    }

    function calculateTicketPrice() internal view returns (uint256) {
        uint256 timeRemaining = timeToEvent > block.timestamp ? timeToEvent - block.timestamp : 0;
        uint256 timeMultiplier = priceIncreaseRate.mul(timeRemaining);
        return baseTicketPrice.add(timeMultiplier);
    }

    function _removeElement(uint256[] storage array, uint256 element) internal returns (uint256[] storage) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
        return array;
    }
}
