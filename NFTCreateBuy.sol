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
        address collectionAddress; // удалить
    }  
    mapping (address => mapping(uint => address)) public addressCollectionById;
    mapping(address => uint) public addressCounter;
    mapping(address => CollectionInfo[]) public collectionsByCreator;

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
            collectionAddress: collectionAddress // удалить 
        });

        collectionsByCreator[msg.sender].push(newCollection);
        uint currentCounter = addressCounter[msg.sender];
        addressCollectionById[msg.sender][currentCounter] = collectionAddress;
        addressCounter[msg.sender]++;
    }
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


    modifier onlyCreator() {
        // require(msg.sender == mPcreator,"Only creator can call this function wfwefwefwe"); функцию должен вызвать и владелец маркетплецса и создатель коллекции, что не корректно
        // require(msg.sender == creator,"Only creator can call this function");
        // require(msg.sender == );
        _;
    }


    function getBalance(address collectionAddress, address _owner) public  returns (uint256) { // функция для проверки того что все сработало валидно
        return balanceOf(_owner);
    }

    
    function mint(address _to) external onlyCreator {
        uint256 newTokenId = tokenCounter;
        _mint(_to, newTokenId);
        tokenCounter++;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override onlyCreator{
        super.setApprovalForAll(operator, approved);
    }


    function getPrice() public returns (uint) {
        return price;
    }

}


contract Buy is CollectionFactory {

 mapping (address user => mapping( bytes10 promo => uint256 tokenId )) public promo;
 mapping (bytes10 promo => bool use) public promoUseAlredy;

 bytes10 public promik;
 
 
 constructor(address initialOwner) CollectionFactory(initialOwner){

 }

 error EnoughFuns(uint price, uint getPrice);
 error PromoUsedAlredy(bool used);
 error InvalidPromo();

 function buyNFT( address collectionAddress, uint256 tokenId ) public payable  {
    ERC721NewCollection collection = ERC721NewCollection(collectionAddress);
    uint256 price = collection.getPrice();
    require(msg.value >= price , EnoughFuns(price, msg.value));
    bytes10 promoCode = bytes10(keccak256(abi.encode(block.timestamp))); // для получения промокода хэшируем время транзакции, что бы его было почти невозможно получить
    promik = promoCode;
    promo[msg.sender][promoCode] = tokenId;
 }

 function reedemCode( address collectionAddress, bytes10 promoCode ) public payable {
 ERC721NewCollection collection = ERC721NewCollection(collectionAddress);
 require(!promoUseAlredy[promoCode], PromoUsedAlredy(true));
 require(promo[msg.sender][promoCode] > 0, InvalidPromo());
 promoUseAlredy[promoCode] = true;
 collection.mint(msg.sender);
 }

 function getBalanceOwner(address callectionAddress) public returns (uint256){
    ERC721NewCollection collection = ERC721NewCollection(callectionAddress);
    return collection.getBalance(callectionAddress, msg.sender);
 }
}
