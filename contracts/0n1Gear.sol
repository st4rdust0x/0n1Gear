pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";
import "./mocks/OniMock.sol";
import "hardhat/console.sol";

contract OniGear is ERC721URIStorage, ReentrancyGuard, Ownable {
    // @dev - copied from ON1 contract as poss variables
    uint256 public constant ONI_GIFT = 300;
    uint256 public constant ONI_PUBLIC = 7_700;
    uint256 public constant ONI_MAX = ONI_GIFT + ONI_PUBLIC;
    uint256 public constant PURCHASE_LIMIT = 7;
    bool public activated;
    bool public isAllowListActive;
    uint256 public constant PRICE_ONI = 0.01 ether;
    uint256 public constant PRICE_PUBLIC = 0.05 ether;

    uint256 private _tokenCount;
    address private _oniAddress;
    IERC721Enumerable private _oniContract;
    mapping(uint256 => bool) private _claimedList;
    mapping(bytes32 => bytes32[]) private lookups;

    // Optimise all variables using bytes32 instead of strings. Can't seem to initialise an array of bytes32 so have to create them individually
    // and add to mapping at construction. Seems most gas efficient as contract gas heavy due to everything on chain
    bytes32 private constant weaponCategory1 = "PRIMARY WEAPON";
    bytes32 private constant weaponCategory2 = "SECONDARY WEAPON";
    bytes32 private constant weaponsBytes1 = "Katana";
    bytes32 private constant weaponsBytes2 = "Handgun";
    bytes32 private constant weaponsBytes3 = "Poision Darts";

    //Temporary array of categories until populate with real values.
    bytes32[] private categories = [
        weaponCategory1,
        weaponCategory2,
        weaponCategory1,
        weaponCategory2,
        weaponCategory1,
        weaponCategory2,
        weaponCategory1,
        weaponCategory2
    ];

    string[] private suffixes = ["of Power", "of Giants", "of the Twins"];

    string[] private namePrefixes = [
        "Agony",
        "Apocalypse",
        "Armageddon",
        "Beast",
        "Behemoth",
        "Blight"
    ];

    string[] private nameSuffixes = ["Bane", "Root", "Moon"];

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function pluck(uint256 tokenId, bytes32 keyPrefix)
        internal
        view
        returns (string memory)
    {
        bytes32[] memory sourceArray = lookups[keyPrefix];
        uint256 rand = random(string(abi.encodePacked(keyPrefix, tokenId)));
        string memory output = string(
            abi.encodePacked(sourceArray[rand % sourceArray.length])
        );
        uint256 greatness = rand % 21;
        if (greatness > 14) {
            output = string(
                abi.encodePacked(output, " ", suffixes[rand % suffixes.length])
            );
        }
        if (greatness >= 19) {
            string[2] memory name;
            name[0] = namePrefixes[rand % namePrefixes.length];
            name[1] = nameSuffixes[rand % nameSuffixes.length];
            if (greatness == 19) {
                output = string(
                    abi.encodePacked('"', name[0], " ", name[1], '" ', output)
                );
            } else {
                output = string(
                    abi.encodePacked(
                        '"',
                        name[0],
                        " ",
                        name[1],
                        '" ',
                        output,
                        " +1"
                    )
                );
            }
        }
        return output;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        //Optimise the tokenURI process by making a loop and using variables stored in mapping
        string[17] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';
        for (uint256 i = 0; i < 8; i++) {
            uint256 position = i * 2 + 1;
            parts[position] = pluck(tokenId, categories[i]);
            parts[position + 1] = string(
                abi.encodePacked(
                    '</text><text x="10" y="',
                    toString((position + 2) * 20),
                    '" class="base">'
                )
            );
        }

        parts[16] = "</text></svg>";

        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6],
                parts[7],
                parts[8]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                parts[9],
                parts[10],
                parts[11],
                parts[12],
                parts[13],
                parts[14],
                parts[15],
                parts[16]
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Gear #',
                        tokenId,
                        '", "description": "0N1 Gear is a derivative of Loot for 0N1 Force with randomized adventurer gear generated and stored on chain.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function totalSupply() public view returns (uint256 supply) {
        return _tokenCount;
    }

    function setIsActive(bool _isActive) external onlyOwner {
        activated = _isActive;
    }

    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    //TODO - add owner purchase function

    function purchase(uint256 numberOfTokens) external payable nonReentrant {
        require(activated, "Contract inactive");
        require(!isAllowListActive, "Only from Allow List");
        require(_tokenCount < ONI_PUBLIC, "All tokens minted");
        require(
            _tokenCount + numberOfTokens <= ONI_PUBLIC,
            "Purchase > ONI_PUBLIC"
        );
        require(PRICE_ONI * numberOfTokens <= msg.value, "ETH insufficient");
        require(numberOfTokens <= PURCHASE_LIMIT, "Too much On1Gear");
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 idToMint;
            //Want to start any token IDs at 1, not 0
            for (uint256 j = 1; j < ONI_PUBLIC + 1; j++) {
                if (!_claimedList[j]) {
                    idToMint = j;
                    //Add this here to ensure don't return the same value each time
                    _claimedList[j] = true;
                    break;
                }
            }
            _tokenCount++;
            _safeMint(msg.sender, idToMint);
        }
    }

    function setOniContractAddress(address oniAddress) external {
        _oniAddress = oniAddress;
        _oniContract = IERC721Enumerable(_oniAddress);
    }

    function getTokenIdsForOni(address owner)
        internal
        view
        returns (uint256[] memory tokenIds)
    {
        uint256 numberOfOnis = _oniContract.balanceOf(owner);
        require(numberOfOnis > 0, "No Tokens to mint");
        uint256[] memory tokenIdsToReturn = new uint256[](numberOfOnis);
        for (uint256 i = 0; i < numberOfOnis; i++) {
            tokenIdsToReturn[i] = _oniContract.tokenOfOwnerByIndex(owner, i);
        }
        return tokenIdsToReturn;
    }

    function claimAllTokens() external payable {
        require(activated, "Contract inactive");
        require(isAllowListActive, "Allow List inactive");
        require(_tokenCount < ONI_PUBLIC, "All tokens minted");
        uint256[] memory tokensOwnedByAddress = getTokenIdsForOni(msg.sender);

        // Loop through all tokens available to this address and calculate how many are unclaimed.
        // Removing items fom arrays in solidity isn't easy, hence not just mutating original array and removing taken elements.
        // Also can't create a dynamic new array so in order to validate costs etc need to run the loop twice. :facepalm.

        uint256 unclaimedOnis;
        for (uint256 j = 0; j < tokensOwnedByAddress.length; j++) {
            bool alreadyClaimed = _claimedList[tokensOwnedByAddress[j]];
            if (!alreadyClaimed) {
                unclaimedOnis++;
            }
        }
        require(unclaimedOnis > 0, "No Tokens left to mint");
        require(PRICE_ONI * unclaimedOnis <= msg.value, "ETH insufficient");

        for (uint256 j = 0; j < tokensOwnedByAddress.length; j++) {
            uint256 tokenId = tokensOwnedByAddress[j];
            bool alreadyClaimed = _claimedList[tokenId];
            if (!alreadyClaimed) {
                _tokenCount++;
                _claimedList[tokenId] = true;
                _safeMint(msg.sender, tokenId);
            }
        }
    }

    function claimToken(uint256 oniId) external payable {
        require(activated, "Contract inactive");
        require(isAllowListActive, "Allow List inactive");
        require(_tokenCount < ONI_PUBLIC, "All tokens minted");
        require(PRICE_ONI <= msg.value, "ETH insufficient");
        bool alreadyClaimed = _claimedList[oniId];
        require(!alreadyClaimed, "Already minted");
        uint256[] memory tokensOwnedByAddress = getTokenIdsForOni(msg.sender);
        bool isOwned = false;
        for (uint256 j = 0; j < tokensOwnedByAddress.length; j++) {
            uint256 oniToMatch = tokensOwnedByAddress[j];
            if (oniToMatch == oniId) {
                isOwned = true;
                break;
            }
        }
        require(isOwned, "Not authorised");
        _tokenCount++;
        _claimedList[oniId] = true;
        _safeMint(msg.sender, oniId);
    }

    function ownerClaim(uint256[] calldata oniIds) external onlyOwner {
        require(activated, "Contract inactive");
        // Loop twice to validate entire transaction OK
        for (uint256 i = 0; i < oniIds.length; i++) {
            uint256 oniId = oniIds[i];
            require(oniId > ONI_PUBLIC && oniId <= ONI_MAX, "Token ID invalid");
            bool alreadyClaimed = _claimedList[oniId];
            require(!alreadyClaimed, "Already minted");
        }
        for (uint256 i = 0; i < oniIds.length; i++) {
            uint256 oniId = oniIds[i];
            _tokenCount++;
            _claimedList[oniId] = true;
            _safeMint(owner(), oniId);
        }
    }

    constructor() ERC721("0N1 Gear", "0N1GEAR") Ownable() {
        lookups[categories[0]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        //TODO create static data as bytes as more space efficient?
        lookups[categories[1]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[2]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[3]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[4]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[5]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[6]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
        lookups[categories[7]] = [weaponsBytes1, weaponsBytes2, weaponsBytes3];
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
