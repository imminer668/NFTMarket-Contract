// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract NFTMarket is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    // NFT Contract address -> NFT TokenID -> Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // seller address -> amount earned
    mapping(address => uint256) private s_proceeds;

    address private owner;
    IERC721 nft;
    uint256 s_listingId;
    uint256 public NFTMarketFee;

    struct Listing {
        uint256 listingId; // *** I want that every Listing has a uinque Lising Number, just like in the real world :)
        uint256 price;
        address seller;
        address desiredNftAddress; // Desired NFTs for swap !!!W find a way to have multiple desiredNftAddresses ( and / or ) - maybe by using an array here(?)
        uint256 desiredTokenId; // Desired token IDs for swap !!!W find a way to have multiple desiredNftAddresses ( and / or ) - maybe by using an array here(?)
        uint8 category; //
    } // *** also find a way to have the seller list their nft for swap WITH additional ETH. so that they can say i want my 1ETH worth NFT to be swapped against this specific NFT AND 0.3 ETH.

    event ItemListed(
        uint256 indexed listingId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        bool isListed,
        uint256 price,
        address seller,
        address desiredNftAddress,
        uint256 desiredTokenId,
        uint8 category
    );
    // *** should i add the seller to this event? Yes, did it.
    event ItemBought(
        uint256 indexed listingId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        bool isListed,
        uint256 price,
        address seller,
        address buyer,
        address desiredNftAddress,
        uint256 desiredTokenId,
        uint8 category
    );

    event ItemCanceled(
        uint256 indexed listingId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        bool isListed,
        uint256 price,
        address seller,
        address desiredNftAddress,
        uint256 desiredTokenId,
        uint8 category
    );

    event ItemUpdated(
        uint256 indexed listingId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        bool isListed,
        uint256 price,
        address seller,
        address desiredNftAddress,
        uint256 desiredTokenId,
        uint8 category
    );
    error NFTMarket__NotApprovedForMarketplace();
    error NFTMarket__NotOwner(
        uint256 tokenId,
        address nftAddress,
        address nftOwner
    );
    error NFTMarket__PriceNotMet(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    );
    error NFTMarket__NoProceeds();
    error NFTMarket__TransferFailed();

    /////////////////
    // Constructor //
    /////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        uint256 fee,
        uint256 lastListingId
    ) public initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        NFTMarketFee = fee; // 1000 is 1%
        s_listingId = lastListingId;
    }

    ///////////////
    // Modifiers //
    ///////////////

    // nonReentrant Modifier is inherited

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller is not a admin"
        );
        _;
    }

    modifier notListed(address nftAddress, uint256 tokenId) {
        require(
            s_listings[nftAddress][tokenId].seller == address(0),
            "NFTMarket__AlreadyListed"
        );
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        require(
            s_listings[nftAddress][tokenId].seller != address(0),
            "NFTMarket__NotListed"
        );
        _;
    }

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        nft = IERC721(nftAddress);
        if (msg.sender != nft.ownerOf(tokenId)) {
            revert NFTMarket__NotOwner(
                tokenId,
                nftAddress,
                nft.ownerOf(tokenId)
            );
        }
        _;
    }

    ////////////////////
    // Main Functions //
    ////////////////////

    /*
     * @notice Method for listing your NFT on the marketplace
     * @param nftAddress: Address of the NFT to be listed
     * @param tokenId: TokenId of that NFT
     * @param price: The price the owner wants the NFT to sell for
     * @dev: Using approve() the user keeps on owning the NFT while it is listed
     */

    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address desiredNftAddress,
        uint256 desiredTokenId,
        uint8 category
    )
        external
        // Challenge: Have this contract accept payment in a subset of tokens as well
        // Hint: Use Chainlink Price Feeds to convert the price of the tokens between each other
        notListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        // require(
        //     price > 0 || desiredNftAddress != address(0),
        //     "NFTMarket__PriceMustBeAboveZeroOrNoDesiredNftGiven"
        // );

        require(
            !(nftAddress == desiredNftAddress && tokenId == desiredTokenId),
            "NFTMarket__NoSwapForSameNft"
        );

        // info: approve the NFT Marketplace to transfer the NFT (that way the Owner is keeping the NFT in their wallet until someone bougt it from the marketplace)
        checkApproval(nftAddress, tokenId);
        s_listingId++;
        s_listings[nftAddress][tokenId] = Listing(
            s_listingId,
            price,
            msg.sender,
            desiredNftAddress,
            desiredTokenId,
            category
        );
        emit ItemListed(
            s_listingId,
            nftAddress,
            tokenId,
            true,
            price,
            msg.sender,
            desiredNftAddress,
            desiredTokenId,
            category
        );
    }

    function checkApproval(address nftAddress, uint tokenId) internal {
        nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NFTMarket__NotApprovedForMarketplace();
        }
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        // checkApproval(nftAddress, tokenId);
        Listing memory listedItem = s_listings[nftAddress][tokenId];

        if (msg.value < listedItem.price) {
            revert NFTMarket__PriceNotMet(
                nftAddress,
                tokenId,
                listedItem.price
            );
        } else {
            uint256 fee = ((listedItem.price * NFTMarketFee) / 100000);
            uint256 newProceeds = listedItem.price - fee;
            s_proceeds[listedItem.seller] += newProceeds;
            s_proceeds[owner] += fee;
            if (listedItem.desiredNftAddress != address(0)) {
                require(
                    IERC721(listedItem.desiredNftAddress).ownerOf(
                        listedItem.desiredTokenId
                    ) == msg.sender,
                    "You don't own the desired NFT for swap"
                );
                checkApproval(
                    listedItem.desiredNftAddress,
                    listedItem.desiredTokenId
                );

                // Swap the NFTs
                IERC721(listedItem.desiredNftAddress).safeTransferFrom(
                    msg.sender,
                    listedItem.seller,
                    listedItem.desiredTokenId
                );
            }
            // maybe its safer to not use else but start a new if with `if (!listedItem.isForSwap) {`

            delete (s_listings[nftAddress][tokenId]); // W!!! cGPT said bv of reentrancy attacks i need to move this here instead of after the nft transfer. check if it still works. check if i should also consider that before transfering the swap NFT. // !!!W Ask cGPT again what else i need to do to be fully reentrancy attack proof

            IERC721(nftAddress).safeTransferFrom(
                listedItem.seller,
                msg.sender,
                tokenId
            );

            emit ItemBought(
                listedItem.listingId,
                nftAddress,
                tokenId,
                false,
                listedItem.price,
                listedItem.seller,
                msg.sender,
                listedItem.desiredNftAddress,
                listedItem.desiredTokenId,
                listedItem.category
            );
        }
    }

    function cancelListing(
        address nftAddress,
        uint256 tokenId
    )
        external
        isListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId]; // what happens to this memory variable after the struct in the mapping has been deleted and after the function has been executed? does it get deleted automatically?
        delete (s_listings[nftAddress][tokenId]);

        emit ItemCanceled(
            listedItem.listingId,
            nftAddress,
            tokenId,
            false,
            listedItem.price,
            msg.sender,
            listedItem.desiredNftAddress,
            listedItem.desiredTokenId,
            listedItem.category
        );
        // nft = IERC721(nftAddress); nft.approve(address(0), tokenId);
    }

    function updateListing(
        // take notice: when the listing gets updated the ListingId also gets updated!
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice,
        address newDesiredNftAddress,
        uint256 newdesiredTokenId
    )
        external
        isListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        // *** patrick didnt make sure that the updated price would be above 0 in his contract
        // require(
        //     newPrice > 0 || newDesiredNftAddress != address(0),
        //     "NFTMarket__PriceMustBeAboveZeroOrNoDesiredNftGiven"
        // );

        require(
            !(nftAddress == newDesiredNftAddress &&
                tokenId == newdesiredTokenId),
            "NFTMarket__NoSwapForSameNft"
        );

        checkApproval(nftAddress, tokenId); // *** patrick didnt check if the approval is still given in his contract
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        listedItem.price = newPrice;
        listedItem.desiredNftAddress = newDesiredNftAddress;
        listedItem.desiredTokenId = newdesiredTokenId;
        s_listings[nftAddress][tokenId] = listedItem;
        emit ItemUpdated(
            listedItem.listingId,
            nftAddress,
            tokenId,
            true,
            listedItem.price,
            msg.sender,
            listedItem.desiredNftAddress,
            listedItem.desiredTokenId,
            listedItem.category
        );
    }

    // to try out the ReentrancyAttack.sol,  comment out the `nonReentrant` , move the `s_proceeds[msg.sender] = 0;` to after the ETH transfer and change the `payable(msg.sender).transfer(proceeds);` to `(bool success, ) = payable(msg.sender).call{value: proceeds, gas: 30000000}("");` because Hardhat has an issue estimating the gas for the receive fallback function... The Original should work on the testnet, tho! !!!W Try on the testnet if reentrancy attack is possible
    function withdrawProceeds() external payable nonReentrant {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NFTMarket__NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        payable(msg.sender).transfer(proceeds); // *** I'm using this instead of Patricks (bool success, ) = payable(msg.sender).call{value: proceeds}(""); require(success, "NFTMarket__TransferFailed");`bc mine reverts on its own when it doesnt succeed, and therby I consider it better!
        // should this function also emit an event? just for being able to track when somebody withdrew?
    }

    function setFee(uint256 fee) external onlyAdmin {
        NFTMarketFee = fee;
    }

    //////////////////////
    // getter Functions //
    //////////////////////

    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }

    function getNextListingId() external view returns (uint256) {
        return s_listingId; // *** With this function people can find out what the next Listing Id would be
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
