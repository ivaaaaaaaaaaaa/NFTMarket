// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CollectionFactory is Ownable {
    using Strings for uint256;
    constructor (address initialOwner) Ownable(initialOwner) {}

    error incorrectSymbolLength();
    error incorrectURI();
    error incorrectPrice();
    error incorrectIndex();
    error incorrectNameLength();


    struct CollectionInfo {
        string name;
        string symbol;
        address collectionOwner;
        string collectionURI;
        uint price;
        address collectionAddress; 
    }  

    /**
     * @notice addressCollectionById[address ownerCollection][uint256 collectionIndex] = addressCollection
     * @notice addressCounter[address ownerCollection] = uint256 counterCollection
     * @notice collectionsByCreator[address ownerCollection](0) = collectionInfo
     */
    mapping (address => mapping(uint => address)) public addressCollectionById;
    mapping(address => uint) public addressCounter;
    mapping(address => CollectionInfo[]) public collectionsByCreator;


    event CreateNewCollection(
        string name,
        string symbol,
        address indexed collectionOwner,
        string indexed collectionURI,
        uint price,
        address indexed collectionAddress
    );


    /**
     * @dev this is function create a new collection NFT
     * @param _name NFT name
     * @param _symbol NFT symbol
     * @param _collectionURI URI collection
     * @param _price NFT price
     */
    function createCollection(string calldata _name, string calldata _symbol, string calldata _collectionURI, uint _price) external payable {
        require(bytes(_name).length > 0 && bytes(_name).length < 64, incorrectNameLength());
        require(bytes(_symbol).length > 0 && bytes(_symbol).length < 8 , incorrectSymbolLength());
        require(bytes(_collectionURI).length > 0, incorrectURI());
        require(_price > 0, incorrectPrice());

        ERC721NewCollection collection = new ERC721NewCollection(_name, _symbol, _collectionURI, msg.sender, owner(), _price);
        address collectionAddress = address(collection);


        CollectionInfo memory newCollection = CollectionInfo({
            name: _name,
            symbol: _symbol,
            collectionOwner: msg.sender,
            collectionURI: _collectionURI,
            price: _price,
            collectionAddress: collectionAddress 
        });

        collectionsByCreator[msg.sender].push(newCollection);
        uint currentCounter = addressCounter[msg.sender];
        addressCollectionById[msg.sender][currentCounter] = collectionAddress;
        addressCounter[msg.sender]++;

        emit CreateNewCollection(
          _name,
          _symbol,
          msg.sender,
          _collectionURI,
          _price,
          collectionAddress 
        );
    }

    /**
     * @dev get collection address by index
     * @param _index collection index
     * @notice if new collection create, index++
     */
    function getAddressByIndex(uint _index) public view returns(address) {
        //require(addressCounter[msg.sender] < _index, incorrectIndex());
        return(addressCollectionById[msg.sender][_index]);
    }
}
//    ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/
contract ERC721NewCollection is ERC721 {
    using Strings for uint256;

    address private creator;
    string private collectionURI;
    uint256 private tokenCounter;
    uint256 private price;
    address private mPcreator;
    
    /**
     * @param _name NFT name
     * @param _symbol NFT symbol
     * @param _collectionURI  URI collection
     * @param _creator creator collection (msg.sender)
     * @param _mPcreator marketplace creator
     * @param _price NFT price
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _collectionURI,
        address _creator,
        address _mPcreator,
        uint256 _price
    ) ERC721(_name, _symbol) {
        creator = _creator;
        mPcreator = _mPcreator;
        collectionURI = _collectionURI;
        price = _price;
        tokenCounter = 1;
    }

    /**
     * @dev this is modifier maybe active later
     */
    modifier onlyCreator() {
        // require(msg.sender == mPcreator,"Only creator can call this function wfwefwefwe"); // функцию должен вызвать и владелец маркетплецса и создатель коллекции, что не корректно
        // require(msg.sender == creator,"Only creator can call this function");
        // require(msg.sender == );
        _;
    }

    /**
     * @dev mint new NFT
     * @param _to address where mint new NFT
     */
    function mint(address _to) external onlyCreator {
        uint256 newTokenId = tokenCounter;
        _mint(_to, newTokenId);
        tokenCounter++;
    }


    /**
     * @dev get to manage all NFT to operator 
     * @param operator the address that gets the ability to manage all the owner's NFTs
     * @param approved permission/prohibition
     */
    function setApprovalForAll(address operator, bool approved) public virtual override onlyCreator{
        super.setApprovalForAll(operator, approved);
    }

   
    /** 
     * @dev get price NFT collection
     * @notice this is function we need only require in contract - Buy, function - buyNFT
     */  
    function getPrice() public view returns (uint) {
        return price;
    }

    function getTokenCounter() public view returns(uint256){
        return tokenCounter;
    }
}


contract Buy is CollectionFactory {

 /**
  * @notice promo[address User][bytes10 promoCode] = uint256 NFTid
  * @notice promoUseAlredy[promo] = bool true/false
  */
 mapping (address user => mapping( bytes10 promo => uint256 tokenId )) public promo;
 mapping (bytes10 promo => bool use) public promoUseAlredy;

 event NFTPurchased(
    uint indexed tokenId,
    address indexed buyer,
    address indexed collectionAddress,
    uint256 price,
    bytes10 promo
 );

 event reedemPromoCode(
    address indexed user,
    address indexed collectionAddress,
    bytes10 promoCode,
    uint256 tokenId
 );

 bytes10 public promik; // пока что для сохранения промокода используем переменную для просмотра реализации (ИЗМЕНИТЬ)
 
 constructor(address initialOwner) CollectionFactory(initialOwner){}

 error EnoughFuns(uint price, uint getPrice);
 error PromoUsedAlredy(bool used);
 error InvalidPromo();
 error ZeroCollectionAddress();
 error TokenNotExsist();
 
 /**
  * @dev в этой функции человек совершает покупку товара
  * @param collectionAddress address NFT collection
  * @param tokenId NFT
  * @notice суть в том, что человек покупает, но еще не получает товар, по приезду товара к нему
  * @notice придет (или как то иначе) код, и только после его активации пользовотель сминтит NFT
  */
 function buyNFT( address collectionAddress, uint256 tokenId ) public payable {
    require(collectionAddress != address(0), ZeroCollectionAddress());
    ERC721NewCollection collection = ERC721NewCollection(collectionAddress);
    
    uint256 tokenCounter = collection.getTokenCounter();
    require(tokenCounter<= tokenId, TokenNotExsist());
    
    uint256 price = collection.getPrice();
    require(msg.value >= price , EnoughFuns(price, msg.value));
    
    bytes10 promoCode = bytes10(keccak256(abi.encode(block.timestamp))); // для получения промокода хэшируем время транзакции, что бы его было почти невозможно получить
    promik = promoCode;
    promo[msg.sender][promoCode] = tokenId;
    emit NFTPurchased(
        tokenId,
        msg.sender,
        collectionAddress,
        price,
        promoCode
    );
 }
 
 /**
  * @dev reddem promo cod and mint NFT
  * @param collectionAddress address NFT collection
  * @param promoCode promo code
  */
 function reedemCode( address collectionAddress, bytes10 promoCode ) public payable {
 ERC721NewCollection collection = ERC721NewCollection(collectionAddress);
 require(!promoUseAlredy[promoCode], PromoUsedAlredy(true));
 require(promo[msg.sender][promoCode] > 0, InvalidPromo());
 promoUseAlredy[promoCode] = true;
 collection.mint(msg.sender);
 emit reedemPromoCode(
    msg.sender,
    collectionAddress,
    promoCode,
    promo[msg.sender][promoCode]
 );

 }
}
