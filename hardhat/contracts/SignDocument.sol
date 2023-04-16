// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SignDocument {
    using SafeMath for uint256;

    struct Document {
        string hash;
        address[] signers;
        mapping(address => bool) hasSigned;
        uint256 timestamp;
    }

    mapping(uint256 => Document) private documents;
    uint256 private documentCounter;

    function signDocument(uint256 _documentId) external {
        Document storage doc = documents[_documentId];
        require(doc.signers.length > 0, "Document does not exist");
        require(!doc.hasSigned[msg.sender], "You have already signed this document");

        doc.hasSigned[msg.sender] = true;

        uint256 numSignatures = 0;
        for (uint i = 0; i < doc.signers.length; i++) {
            if (doc.hasSigned[doc.signers[i]]) {
                numSignatures++;
            }
        }

        if (numSignatures == doc.signers.length) {
            // Document is fully signed
            doc.timestamp = block.timestamp;
        }
    }

    function addDocument(string calldata _documentHash, address[] memory _signers) external returns (uint256 documentId) {
        documentCounter++;
        require(documents[documentCounter].signers.length == 0, "Document already exists");
        require(_signers.length > 0, "Document must have at least one signer");

        documents[documentCounter].hash = _documentHash;
        documents[documentCounter].signers = _signers;

        return documentCounter;
    }

    function verifyDocument(uint256 _documentId) external view returns (bool) {
        Document storage doc = documents[_documentId];
        require(doc.signers.length > 0, "Document does not exist");

        uint256 numSignatures = 0;
        for (uint i = 0; i < doc.signers.length; i++) {
            if (doc.hasSigned[doc.signers[i]]) {
                numSignatures++;
                if (numSignatures == doc.signers.length) {
                    return true;
                }
            }
        }
        return false;
    }
}
