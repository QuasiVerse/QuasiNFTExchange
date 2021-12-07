pragma solidity ^0.4.21;


library SafeMath {
    function safeMul(uint a, uint b) internal pure returns (uint) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal pure returns (uint) {
        uint256 c = a / b;
        return c;
    }

    function safeSub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }
    function safeAdd(uint a, uint b) internal pure returns (uint) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Ownable {

    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}

interface  NFT {

    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    
}

interface ERC20 {
    function transfer(address _to, uint _value) returns (bool);
    function transferFrom(address _from, address _to, uint _value) returns (bool);
    function balanceOf(address _owner) constant returns (uint balance);
    function allowance(address _owner, address _spender) constant returns (uint remaining);
}

contract Exchange is Ownable {

    struct UserData {
        mapping(address => NFTSpace) NFT;
        mapping(address => uint) ERC20
    }
    
    struct NFTSpace {
        mapping(uint8 => Space) space;
    }
    
    struct Space {
        uint tokenId;
        uint rate;
        bool available;
        address secondaryTokenAddress;

    }
  
    using SafeMath for uint;
    
    bool public initialized = false;

    mapping(address => UserData) internal userData;
    
    event SellOwnerRights(address indexed receiverAddress, address indexed primaryTokenAddress, address indexed  secondaryTokenAddress, uint slot, uint tokenId, uint sellRate, bool available);
    event SellOwnerRightsFulfillment(address indexed senderAddress, address indexed primaryTokenAddress, address indexed secondaryTokenAddress, uint sellRate);
   
    event ERC20Deposit(address indexed senderAddress, address indexed secondaryTokenAddress, uint depositAmount);
    event ERC20Withdraw(address indexed senderAddress, address indexed secondaryTokenAddress, uint withdrawAmount);
    event NFTDeposit(address indexed senderAddress, address indexed primaryTokenAddress, uint tokenId);
    event NFTWithdraw(address indexed senderAddressr, address indexed primaryTokenAddress, uint tokenId);    
        
    modifier whenSaleIsActive() {
        // Check if sale is active
        assert(isActive());

        _;
    }

    function initialize() public onlyOwner {
        require(initialized == false);
        initialized = true;
    }
    
    function terminate() public onlyOwner {
        require(initialized == true);
        initialized = false;
    }

    function isActive() public constant returns (bool) {
        return (initialized);
    }
    
    function depositNft(address _primaryTokenAddress, uint8 _space, uint _tokenId) public whenSaleIsActive {
        require(userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId == 0);
        address approved = NFT(_primaryTokenAddress).getApproved(_tokenId);
        require (msg.sender == approved);
        NFT(_primaryTokenAddress).transferFrom(msg.sender, this, _tokenId);
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId = _tokenId;
        emit NFTDeposit(msg.sender, _primaryTokenAddress, _tokenId);
    }
    
    function withdrawNft(address _primaryTokenAddress, uint8 _space, uint _tokenId) public whenSaleIsActive {
        require (userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId == _tokenId);
        NFT(_primaryTokenAddress).transferFrom(this, msg.sender, _tokenId);
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId = 0;
        emit NFTWithdraw(msg.sender, _primaryTokenAddress, _tokenId);
    }
    
    function depositErc20(address _secondaryTokenAddress) public whenSaleIsActive {
        uint weiAmount = ERC20(_secondaryTokenAddress).allowance(msg.sender, this);
        require (weiAmount > 0);
        require (ERC20(_secondaryTokenAddress).balanceOf(msg.sender) >= weiAmount);
        require (ERC20(_secondaryTokenAddress).transferFrom(msg.sender, this, weiAmount));
        userData[msg.sender].ERC20[_secondaryTokenAddress] = userData[msg.sender].ERC20[_secondaryTokenAddress].safeAdd(weiAmount);
        emit ERC20Deposit(msg.sender, _secondaryTokenAddress, weiAmount);
    }  
    
    function withdrawErc20(address _secondaryTokenAddress, uint withdrawAmount) public whenSaleIsActive {
        uint weiAmount = userData[msg.sender].ERC20[_secondaryTokenAddress];
        require (weiAmount > 0);
        require (weiAmount >= withdrawAmount);
        require (ERC20(_secondaryTokenAddress).transferFrom(this, msg.sender, withdrawAmount));
        userData[msg.sender].ERC20[_secondaryTokenAddress] = userData[msg.sender].ERC20[_secondaryTokenAddress].safeSub(withdrawAmount);
        emit ERC20Withdraw(msg.sender, _secondaryTokenAddress, withdrawAmount);
    } 
    
    function getBalanceNft(address userAddress, address _primaryTokenAddress, uint8 _space) public constant returns (uint balance){
        return userData[userAddress].NFT[_primaryTokenAddress].space[_space].tokenId;
    }
    
    function getBalanceErc20(address userAddress, address _secondaryTokenAddress) public constant returns (uint balance){
        return userData[userAddress].ERC20[_secondaryTokenAddress];
    }
    
    function sellOwnerRights(address _primaryTokenAddress, address _secondaryTokenAddress, uint8 _space, uint _tokenId, uint _sellRate) public whenSaleIsActive {
        require (userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId == _tokenId);
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].rate = _sellRate;
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].available = true;
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].secondaryTokenAddress = _secondaryTokenAddress;
        emit SellOwnerRights(msg.sender, _primaryTokenAddress, _secondaryTokenAddress, _space, _tokenId, _sellRate, true);
    }  
        
    function cancelSellOwnerRights(address _primaryTokenAddress, address _secondaryTokenAddress, uint8 _space, uint _tokenId) public whenSaleIsActive {
        require(userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId == _tokenId);
        require(userData[msg.sender].NFT[_primaryTokenAddress].space[_space].available == true);
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].available = false;
        emit SellOwnerRights(msg.sender, _primaryTokenAddress, _secondaryTokenAddress, _space, _tokenId, 0, false);
    }
    
    function buyOwnerRights(address _primaryTokenAddress, address _secondaryTokenAddress, uint8 _space, uint _tokenId, address receiverAddress, uint _sellRate) public whenSaleIsActive {
        require(msg.sender != receiverAddress);
        require(userData[msg.sender].ERC20[_secondaryTokenAddress] >= _sellRate);
        require(userData[receiverAddress].NFT[_primaryTokenAddress].space[_space].rate == _sellRate);
        require(userData[receiverAddress].NFT[_primaryTokenAddress].space[_space].tokenId == _tokenId);
        require(userData[receiverAddress].NFT[_primaryTokenAddress].space[_space].available == true);
        require(userData[receiverAddress].NFT[_primaryTokenAddress].space[_space].secondaryTokenAddress == _secondaryTokenAddress);
        uint utilityRate = _sellRate/20;
        uint postUtilityRate = _sellRate.safeSub(utilityRate);
        userData[msg.sender].ERC20[_secondaryTokenAddress] = userData[msg.sender].ERC20[_secondaryTokenAddress].safeSub(_sellRate);
        userData[receiverAddress].ERC20[_secondaryTokenAddress] = userData[msg.sender].ERC20[_secondaryTokenAddress].safeAdd(postUtilityRate);
        userData[owner].ERC20[_secondaryTokenAddress] = userData[owner].ERC20[_secondaryTokenAddress].safeAdd(utilityRate);
        userData[receiverAddress].NFT[_primaryTokenAddress].space[_space].tokenId == 0;
        userData[msg.sender].NFT[_primaryTokenAddress].space[_space].tokenId == _tokenId;
        emit SellOwnerRights(receiverAddress, _primaryTokenAddress, _secondaryTokenAddress, _space, _tokenId, 0, false);
        emit SellOwnerRightsFulfillment(msg.sender, _primaryTokenAddress, _secondaryTokenAddress, _sellRate);
    }
}