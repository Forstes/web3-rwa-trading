// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RWACollection is ERC721 {
    using Strings for uint256;

    struct RwaTokenMetadata {
        string name;
        string description;
        string documentUri;
        string imageUri;
    }

    RwaTokenMetadata[] private rwaTokens;
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function mintRwaToken(
        address _to,
        string memory _name,
        string memory _description,
        string memory _documentUri,
        string memory _imageUri
    ) external returns (uint256) {
        RwaTokenMetadata memory metadata = RwaTokenMetadata({
            name: _name,
            description: _description,
            documentUri: _documentUri,
            imageUri: _imageUri
        });

        uint256 tokenId = rwaTokens.length;
        rwaTokens.push(metadata);


        _mint(_to, tokenId);

        return tokenId;
    }

    function getRwaTokenMetadata(uint256 _tokenId)
        external
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        require(_tokenId < rwaTokens.length, "RWA token does not exist");

        RwaTokenMetadata memory metadata = rwaTokens[_tokenId];
        return (metadata.name, metadata.description, metadata.documentUri, metadata.imageUri);
    }
}
