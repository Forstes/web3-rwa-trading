// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./RWACollection.sol";
import "./SignDocument.sol";

contract RWAExchange is Ownable, ERC721Holder {
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
        bool canceled;
        bool paymentClaimed;
        bool rwaClaimed;
    }

    struct OfferView {
        address owner;
        ERC20 tokenOfPayment;
        uint256 price;
        uint256 rwaTokenId;
        address acceptedBuyer;
        bool completed;
        bool canceled;
        RWACollection.RwaTokenMetadata metadata;
    }

    struct Bid {
        address buyerAddress;
        uint256 value;
    }

    mapping(uint256 => Offer) public offers;
    uint256 private offerCounter;
    mapping(address => uint256[]) public joinedOffers;

    RWACollection rwa;
    SignDocument documents;

    constructor(address _tokenCollectionAddress, address _documentSignAddress) {
        rwa = RWACollection(_tokenCollectionAddress);
        documents = SignDocument(_documentSignAddress);
    }

    modifier offerExists(uint256 offerId) {
        require(
            address(offers[offerId].tokenOfPayment) != address(0) && !offers[offerId].canceled,
            "Offer does not exist or was cancelled"
        );
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

    function createOffer(address _tokenOfPayment, uint256 _price, uint256 _rwaTokenId) external returns (uint256 offerId) {
        require(_tokenOfPayment != address(0), "Invalid token of payment");
        require(_price > 0, "Invalid price");

        rwa.safeTransferFrom(msg.sender, address(this), _rwaTokenId);
        Offer storage newOffer = offers[offerCounter];
        offerCounter++;
        newOffer.owner = msg.sender;
        newOffer.tokenOfPayment = ERC20(_tokenOfPayment);
        newOffer.price = _price;
        newOffer.rwaTokenId = _rwaTokenId;
        return offerCounter - 1;
    }

    function cancelOffer(uint256 _offerId) external onlySeller(_offerId) {
        require(!offers[_offerId].canceled, "Offer was already canceled");
        require(!anyDocumentsSigned(_offerId), "Can not cancel an offer when documents are signed");

        offers[_offerId].canceled = true;
        rwa.safeTransferFrom(address(this), msg.sender, offers[_offerId].rwaTokenId);
    }

    function placeBid(uint256 _offerId, uint256 _value) external offerExists(_offerId) {
        require(offers[_offerId].bids[msg.sender] == 0, "Sender is already has a bid for this offer");
        offers[_offerId].tokenOfPayment.transferFrom(msg.sender, address(this), _value);
        offers[_offerId].bids[msg.sender] = _value;
        offers[_offerId].bidAddresses.push(msg.sender);
        joinedOffers[msg.sender].push(_offerId);
    }

    function cancelBid(uint256 _offerId) external {
        require(offers[_offerId].bids[msg.sender] != 0, "Sender didn't placed bid for this offer");

        if (offers[_offerId].acceptedBuyer == msg.sender) {
            require(!anyDocumentsSigned(_offerId), "Bid cannot be canceled after any of documents has been signed");
        }

        offers[_offerId].tokenOfPayment.transfer(msg.sender, offers[_offerId].bids[msg.sender]);
        offers[_offerId].bids[msg.sender] = 0;
    }

    function acceptBid(uint256 _offerId, address _buyer) external offerExists(_offerId) onlySeller(_offerId) {
        require(offers[_offerId].acceptedBuyer == address(0), "Bid for this offer is already accepted");
        require(offers[_offerId].bids[_buyer] > 0, "This bid was cancelled");
        offers[_offerId].acceptedBuyer = _buyer;
    }

    function cancelAcceptedBid(uint256 _offerId) external onlySeller(_offerId) offerNotCompleted(_offerId) {
        if (offers[_offerId].offerDocumentsIds.length > 0)
            require(!anyDocumentsSigned(_offerId), "Can not cancel accepted bid when any of documents was signed");

        offers[_offerId].acceptedBuyer = address(0);
    }

    function putDocumentsToSign(
        uint256 _offerId,
        string[] calldata _docHashes
    ) external onlyBuyer(_offerId) offerNotCompleted(_offerId) returns (uint256[] memory) {
        require(offers[_offerId].acceptedBuyer == msg.sender, "Sender is not allowed to put documents");
        require(offers[_offerId].offerDocumentsIds.length == 0, "Documents was already uploaded");

        Offer storage offer = offers[_offerId];
        address[] memory signers = new address[](2);
        signers[0] = msg.sender;
        signers[1] = offer.owner;

        for (uint256 i = 0; i < _docHashes.length; i++) {
            offer.offerDocumentsIds.push(documents.addDocument(_docHashes[i], signers));
        }
        return offer.offerDocumentsIds;
    }

    function anyDocumentsSigned(uint256 _offerId) public view returns (bool) {
        uint256[] storage docIds = offers[_offerId].offerDocumentsIds;

        for (uint256 i = 0; i < docIds.length; i++) {
            if (documents.verifyDocument(docIds[i])) return true;
        }
        return false;
    }

    function allDocumentsSigned(uint256 _offerId) public view returns (bool) {
        uint256[] storage docIds = offers[_offerId].offerDocumentsIds;

        if (docIds.length == 0) return false;

        for (uint256 i = 0; i < docIds.length; i++) {
            if (!documents.verifyDocument(docIds[i])) return false;
        }
        return true;
    }

    function claimPayment(uint256 _offerId) external onlySeller(_offerId) {
        require(!offers[_offerId].paymentClaimed, "Payment was already claimed");
        require(allDocumentsSigned(_offerId), "Documents are not signed");

        Offer storage offer = offers[_offerId];
        offer.tokenOfPayment.transfer(offer.owner, offer.bids[offer.acceptedBuyer]);
        offer.paymentClaimed = true;
        offer.completed = true;
    }

    function claimRWA(uint256 _offerId) external onlyBuyer(_offerId) {
        require(offers[_offerId].acceptedBuyer == msg.sender, "Sender is not allowed to claim");
        require(!offers[_offerId].rwaClaimed, "RWA was already claimed");
        require(allDocumentsSigned(_offerId), "Documents are not signed");

        Offer storage offer = offers[_offerId];
        rwa.safeTransferFrom(address(this), msg.sender, offer.rwaTokenId);
        offer.rwaClaimed = true;
        offer.completed = true;
    }

    function getOffers(uint256 _start, uint256 _limit) external view returns (OfferView[] memory) {
        require(_limit <= 250, "limit must not exceed 250 items");

        uint256 end = _start + _limit;
        if (end > offerCounter) {
            end = offerCounter;
        }

        OfferView[] memory result = new OfferView[](end - _start);

        for (uint256 i = _start; i < end; i++) {
            OfferView memory offerData = OfferView({
                owner: offers[i].owner,
                tokenOfPayment: offers[i].tokenOfPayment,
                price: offers[i].price,
                rwaTokenId: offers[i].rwaTokenId,
                acceptedBuyer: offers[i].acceptedBuyer,
                completed: offers[i].completed,
                canceled: offers[i].canceled,
                metadata: rwa.getRwaTokenMetadata(offers[i].rwaTokenId)
            });
            result[i - _start] = offerData;
        }
        return result;
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

    function getSenderPlacedBids(uint256 _pointer, uint256 _limit) external view returns (OfferView[] memory, uint256[] memory) {
        require(_limit <= 25, "limit must not exceed 25 items");

        uint256[] memory joinedOffer = joinedOffers[msg.sender];

        if (_pointer >= joinedOffer.length) {
            _pointer = joinedOffer.length - 1;
        }

        uint256 end = _pointer - _limit;
        if (end < 0) {
            end = 0;
        }

        OfferView[] memory result = new OfferView[](_pointer - end);
        uint256[] memory bidValues = new uint256[](_pointer - end);

        for (uint256 i = _pointer; i >= end; i--) {
            OfferView memory offerData = OfferView({
                owner: offers[joinedOffer[i]].owner,
                tokenOfPayment: offers[joinedOffer[i]].tokenOfPayment,
                price: offers[joinedOffer[i]].price,
                rwaTokenId: offers[joinedOffer[i]].rwaTokenId,
                acceptedBuyer: offers[joinedOffer[i]].acceptedBuyer,
                completed: offers[joinedOffer[i]].completed,
                canceled: offers[joinedOffer[i]].canceled,
                metadata: rwa.getRwaTokenMetadata(offers[joinedOffer[i]].rwaTokenId)
            });
            result[_pointer - end] = offerData;
            bidValues[_pointer - end] = offers[joinedOffer[i]].bids[msg.sender];
        }
        return (result, bidValues);
    }
}
