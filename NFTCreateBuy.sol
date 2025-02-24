// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract CollectionFactory is Ownable {
    using Strings for uint256;
    address public mainContract;

    constructor (address initialOwner) Ownable (initialOwner) {}

    error incorrectSymbolLength();
    error incorrectURI();
    error incorrectPrice();
    error onlyMainContract();
    error collectionNotFound();
    error incorrectIndex();
    error incorrectCollectionAddress();
    error incorrectNameLength();

    struct CollectionInfo {
        string name;
        string symbol;
        address collectionOwner;
        string collectionURI;
        uint price;
        uint quantityInStock;
        address collectionAddress;
        uint id;
    }  

    mapping(uint => CollectionInfo) public collections;
    uint public idCounter = 1;

    function setMainContractAddress(address _mainContractAddress) external payable onlyOwner{
        mainContract = _mainContractAddress;
    }

    modifier _onlyMainContract() {
        require(msg.sender == mainContract, onlyMainContract());
        _;
    }

    function createCollection(string calldata _name, string calldata _symbol, string calldata _collectionURI, uint _price, uint _quantityInStock) external payable {
        require(bytes(_name).length > 0 && bytes(_name).length < 64, incorrectNameLength());
        require(bytes(_symbol).length > 0 && bytes(_symbol).length < 8 , incorrectSymbolLength());
        require(bytes(_collectionURI).length > 0, incorrectURI());
        require(_price > 0, incorrectPrice());

        ERC721NewCollection collection = new ERC721NewCollection(_name, _symbol, _collectionURI, msg.sender, owner(), mainContract);
        address collectionAddress = address(collection);


        CollectionInfo memory newCollection = CollectionInfo({
            name: _name,
            symbol: _symbol,
            collectionOwner: msg.sender,
            collectionURI: _collectionURI,
            price: _price,
            quantityInStock: _quantityInStock,
            collectionAddress: collectionAddress,
            id: idCounter
        });
        collections[idCounter] = newCollection;
        idCounter++;
    }

    function getAddressById(uint _id) external  view returns(address) {
        require(collections[_id].id != 0, collectionNotFound());
        return(collections[_id].collectionAddress);
    }

    function getPrice (uint _id) external view returns (uint) {
        require(collections[_id].id != 0, collectionNotFound());
        return(collections[_id].price);
    }

    function getQuantity (uint _id) external view returns (uint) {
        require(collections[_id].id != 0, collectionNotFound());
        return(collections[_id].quantityInStock);
    }

    function updatePrice(uint256 _id, uint256 _newPrice) external _onlyMainContract {
        require(collections[_id].id != 0, collectionNotFound());
        collections[_id].price =  _newPrice;
    }

    function updateQuantity(uint _id, uint _newQuantity) external _onlyMainContract {
        require(collections[_id].id != 0, collectionNotFound());
        collections[_id].quantityInStock = _newQuantity;
    }
}   

//    ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/
contract ERC721NewCollection is ERC721 {
        using Strings for uint256;

        address private creator;
        string private baseURI;
        uint256 private tokenCounter;
        address private mPcreator;
        address public mainContract;
        
        constructor(
            string memory _name,
            string memory _symbol,
            string memory _collectionURI,
            address _creator,
            address _mPcreator,
            address _mainContract
        ) ERC721(_name, _symbol) {
            creator = _creator;
            mPcreator = _mPcreator;
            baseURI = _collectionURI;
            tokenCounter = 1;
            mainContract = _mainContract;
    }


    modifier onlyCreator() {
        require(msg.sender == mPcreator || msg.sender == creator,"Only creator can call this function");
        _;
    }

    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Only mainContract can call this function");
        _;
    }

    //ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/
    function mint(address _to) external onlyMainContract {
        uint256 newTokenId = tokenCounter;
        _safeMint(_to, newTokenId);
        tokenCounter++;
    }

    function setApprovalForAll(address operator, bool approved) public override onlyCreator{
        super.setApprovalForAll(operator, approved);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }
}

contract MainContract is CollectionFactory {

    CollectionFactory internal collectionFactory;
    // mapping (address => mapping(bytes8 => uint256)) private promo;

    mapping (address => uint) private amountOfCodes;

    mapping (address => bytes8[]) private uniqPromoForUser;

    /// @notice promoUseAlredy[promo] = bool true/false
    mapping (address => mapping(bytes8 => bool)) private promoUseAlredy;

    mapping(address => uint) private userNFT;

    event productPurchased(
        address indexed buyer,
        address indexed collectionAddress,
        uint256 price,
        uint cQuantity
    );

    event promoCodeSuccessfullyUsed(
        address indexed user,
        address indexed collectionAddress
    );

    // bytes10 public promik; // пока что для сохранения промокода используем переменную для просмотра реализации (ИЗМЕНИТЬ)
 
     constructor(address initialOwner, address _collectionFactoryAddress) CollectionFactory(initialOwner) {collectionFactory = CollectionFactory(_collectionFactoryAddress);}

    error NotEnoughFunds(uint price, uint getPrice);
    error PromoUsedAlredy(bool used);
    error InvalidPromo();
    error ZeroCollectionAddress();
    error TokenNotExsist();
    error notEnoughProductsInStock();
    error invalidPromoCode();
    error notEnoughFunds();

    // Функция для генерации промокода
    function generatePromoCode(address _user, uint256 _index) internal view returns (bytes8) {
      bytes8 random = bytes8(keccak256(abi.encode(block.timestamp, _user, _index)));
      return bytes8(random);
    }

    /**
    * @dev в этой функции человек совершает покупку товара
    * @param _id NFT collection
    * @param _quantity NFTS
    * @notice суть в том, что человек покупает, но еще не получает товар, по приезду товара к нему
    * @notice придет (или как то иначе) код, и только после его активации пользовотель сминтит NFT
    */

    function buy (uint _id, uint256 _quantity) external payable {
        address _collectionAddress = collectionFactory.getAddressById(_id);
        require(_collectionAddress != address(0), ZeroCollectionAddress());

        uint price = collectionFactory.getPrice(_id);
        uint256 totalPrice = price * _quantity;
        require(msg.value >= totalPrice, notEnoughFunds());

        for(uint i = 0; i < _quantity; i++) {
            bytes8 promoCode = generatePromoCode(msg.sender, amountOfCodes[msg.sender] + i);
            uniqPromoForUser[msg.sender][amountOfCodes[msg.sender] +i] = promoCode;
        }

        amountOfCodes[msg.sender] += _quantity;

        emit productPurchased(
            msg.sender,
            _collectionAddress,
            price,
            _quantity
        );
            
        uint cQuantity = collectionFactory.getQuantity(_id);
        collectionFactory.updateQuantity(_id, cQuantity - _quantity);

        if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function getPromo (uint _indexOfPromo) public view returns(bytes8) {
        require(uniqPromoForUser[msg.sender][_indexOfPromo] != bytes8(0), incorrectIndex());
        return (uniqPromoForUser[msg.sender][_indexOfPromo]);
    }

    function isPromoValid (bytes8 _promoCode) internal view returns (bool) {
        for (uint i = 0; i < uniqPromoForUser[msg.sender].length; i++) {
            if (uniqPromoForUser[msg.sender][i] == _promoCode) {
                return true;
            }
        }
        return false;
    }

    function reedemCode (address _collectionAddress, bytes8 _promoCode) public {
        ERC721NewCollection collection = ERC721NewCollection(_collectionAddress);
        require(_collectionAddress == collection.mainContract(), incorrectCollectionAddress());
        require(isPromoValid(_promoCode) == true, invalidPromoCode());
        require(promoUseAlredy[msg.sender][_promoCode] == false, PromoUsedAlredy(true));
        
        collection.mint(msg.sender);

        promoUseAlredy[msg.sender][_promoCode] = true;

        emit promoCodeSuccessfullyUsed(
            msg.sender,
            _collectionAddress
        );
    }
}
