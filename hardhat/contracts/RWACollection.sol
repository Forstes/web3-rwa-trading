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

    function mint(
        string calldata _name,
        string calldata _description,
        string calldata _documentUri,
        string calldata _imageUri
    ) external returns (uint256) {
        RwaTokenMetadata memory metadata = RwaTokenMetadata({
            name: _name,
            description: _description,
            documentUri: _documentUri,
            imageUri: _imageUri
        });

        uint256 tokenId = rwaTokens.length;
        rwaTokens.push(metadata);
        _mint(msg.sender, tokenId);

        return tokenId;
    }

    function getRwaTokenMetadata(uint256 _tokenId) external view returns (RwaTokenMetadata memory) {
        require(_tokenId < rwaTokens.length, "RWA token does not exist");

        RwaTokenMetadata memory metadata = rwaTokens[_tokenId];
        return metadata;
    }

    function getCollectionLength() external view returns (uint256) {
        return rwaTokens.length;
    }

    function getRwaTokensMetadata(uint256 _start, uint256 _limit) external view returns (RwaTokenMetadata[] memory) {
        require(_limit <= 250, "limit must not exceed 250 items");

        uint256 end = _start + _limit;
        if (end > rwaTokens.length) {
            end = rwaTokens.length;
        }

        RwaTokenMetadata[] memory result = new RwaTokenMetadata[](end - _start);

        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = rwaTokens[i];
        }
        return result;
    }
}
