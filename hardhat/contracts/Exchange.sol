// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./NFTCollection.sol";
import "./SignDocument.sol";

contract RWAExchange is Ownable {
    using SafeMath for uint256;

    struct Offer {
        address owner;
        ERC20 tokenOfPayment;
        uint256 price;
        uint256 rwaTokenId;
        mapping(address => uint256) bids;
        address[] bidAddresses;
        address acceptedBuyer;
        uint256[] offerDocumentsIds;
        bool completed;
        bool paymentClaimed;
        bool rwaClaimed;
    }

    struct Bid {
        address buyerAddress;
        uint256 value;
    }

    mapping(uint256 => Offer) offers;
    uint256 private offerCounter;
    RWACollection rwa;
    SignDocument documents;

    constructor(address _tokenCollectionAddress, address _documentSignAddress) {
        rwa = RWACollection(_tokenCollectionAddress);
        documents = SignDocument(_documentSignAddress);
    }

    modifier offerExists(uint256 offerId) {
        require(address(offers[offerId].tokenOfPayment) != address(0), "Offer does not exist");
        _;
    }

    modifier offerNotCompleted(uint256 offerId) {
        require(!offers[offerId].completed, "This offer was completed");
        _;
    }

    modifier onlyBuyer(uint256 offerId) {
        require(offers[offerId].bids[msg.sender] > 0, "Sender is not a buyer");
        _;
    }

    modifier onlySeller(uint256 offerId) {
        require(offers[offerId].owner == msg.sender, "Sender is not a seller");
        _;
    }

    function createOffer(address _tokenOfPayment, uint256 _price, uint256 _rwaTokenId) external {
        // Transfer the token from the owner to contract
        rwa.safeTransferFrom(msg.sender, address(this), _rwaTokenId);
        offerCounter++;
        Offer storage newOffer = offers[offerCounter];
        newOffer.tokenOfPayment = ERC20(_tokenOfPayment);
        newOffer.price = _price;
        newOffer.rwaTokenId = _rwaTokenId;
    }

    function placeBid(uint256 _offerId, uint256 _value) external offerExists(_offerId) {
        require(offers[_offerId].bids[msg.sender] == 0, "Sender is already has a bid for this offer");
        offers[_offerId].tokenOfPayment.transferFrom(msg.sender, address(this), _value);
        offers[_offerId].bids[msg.sender] = _value;
    }

    function cancelBid(uint256 _offerId) external offerNotCompleted(_offerId) {
        offers[_offerId].tokenOfPayment.transfer(msg.sender, offers[_offerId].bids[msg.sender]);
        offers[_offerId].bids[msg.sender] = 0;
    }

    function acceptBid(uint256 _offerId, address _buyer) external onlySeller(_offerId) {
        require(offers[_offerId].acceptedBuyer == address(0), "Bid for this offer is already accepted");
        require(offers[_offerId].bids[msg.sender] > 0, "This bid was cancelled");
        offers[_offerId].acceptedBuyer = _buyer;
    }

    function cancelAcceptedBid(uint256 _offerId) external onlySeller(_offerId) offerNotCompleted(_offerId) {
        offers[_offerId].acceptedBuyer = address(0);
    }

    function putDocumentsToSign(
        uint256 _offerId,
        bytes32[] calldata _docHashes
    ) external onlyBuyer(_offerId) offerNotCompleted(_offerId) {
        Offer storage offer = offers[_offerId];
        address[] memory signers = new address[](2);
        signers[0] = msg.sender;
        signers[1] = offer.owner;

        for (uint256 i = 0; i < _docHashes.length; i++) {
            offer.offerDocumentsIds.push(documents.addDocument(_docHashes[i], signers));
        }
    }

    function areDocumentsSigned(uint256 _offerId) public view returns (bool) {
        uint256[] storage docIds = offers[_offerId].offerDocumentsIds;

        for (uint256 i = 0; i < docIds.length; i++) {
            if (!documents.verifyDocument(docIds[i])) return false;
        }
        return true;
    }

    function claimPayment(uint256 _offerId) external onlySeller(_offerId) {
        require(!offers[_offerId].paymentClaimed, "Payment was already claimed");
        require(areDocumentsSigned(_offerId), "Documents are not signed");

        Offer storage offer = offers[_offerId];
        offer.tokenOfPayment.transfer(offer.owner, offer.bids[offer.acceptedBuyer]);
        offer.paymentClaimed = true;
        offer.completed = true;
    }

    function claimRWA(uint256 _offerId) external onlyBuyer(_offerId) {
        require(!offers[_offerId].rwaClaimed, "RWA was already claimed");
        require(areDocumentsSigned(_offerId), "Documents are not signed");

        Offer storage offer = offers[_offerId];
        rwa.safeTransferFrom(address(this), msg.sender, offer.rwaTokenId);
        offer.rwaClaimed = true;
        offer.completed = true;
    }


    function getAllBids(uint256 _offerId) external view onlySeller(_offerId) returns (Bid[] memory) {
        Offer storage offer = offers[_offerId];
        Bid[] memory bids = new Bid[](offer.bidAddresses.length);

        for (uint256 i = 0; i < offer.bidAddresses.length; i++) {
            address buyer = offer.bidAddresses[i];
            uint256 value = offer.bids[buyer];
            bids[i] = Bid(buyer, value);
        }
        return bids;
    }
}
