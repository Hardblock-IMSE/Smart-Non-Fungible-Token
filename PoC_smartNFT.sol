///SPDX-License-Identifier: IMSE

pragma solidity ^0.8.0;

import "./smartNFT_Interface.sol";
import "./ERC721_Interface.sol";

contract PoC_smartNFT is ERC721,smartNFT{
    
    enum States { waitingForOwner, engagedWithOwner, waitingForUser, engagedWithUser }
    
    address manufacturer;                                   //Address of manufacturer and owner of Smart Contract
    uint256 tokenCounter;                                   //To give and genuine tokenID based on the number of tokens created.
    mapping(uint256 => address) ownerOfSD;                  //To khow who is the owner of an specific owner.
    mapping(address => uint256) tokenIDOfBCA;               //To khow which is the tokenID associated to a Secure Device.
    mapping(address => uint256) ownerBalance;               //To know how many tokens an owner has.
    mapping(address => uint256) userBalance;                //To know how many tokens a user can use.
    
    struct Token_Struct{
        address approved;                                   //Indicate who can transfer this token, 0 if no one.
        address SD;                                         //Indicate the BCA of the Secure device associated to this token.
        address user;                                       //Indicate who can use this secure device.
        States state;                                         //If blocked (false) then token should be verified by new user or new owner.
    }
    
    Token_Struct[] Secure_Token;
    
    constructor() {
        manufacturer = msg.sender;
        tokenCounter = 1;
        //this token is created to avoid the tokenId 0 in the first create token. 
        Secure_Token.push(Token_Struct(address(0), address(0), address(0), States.waitingForOwner));
    }
    
    function createToken(address _addressSD, address _addressOwner) public virtual override returns (uint256){
        //Check if the sender of message is from the manufacturer.
        require(manufacturer == msg.sender);
        //Check is Blockchain Account of Smart Device in the SmartContract
        if(tokenFromBCA(_addressSD)==0){
            //create a new token
            Secure_Token.push(Token_Struct(address(0), _addressSD, address(0), States.waitingForOwner));
            //Assigning a new tokenId
            uint256 _tokenId = tokenCounter ++;
            tokenIDOfBCA[_addressSD] = _tokenId;
            //Assigning the owner
            ownerOfSD[_tokenId] = _addressOwner;
            ownerBalance[_addressOwner]++;
            //return tokenId obtained
            return(_tokenId);
        }else{
            //If the BCA already exists then return the _tokenId
            return(tokenFromBCA(_addressSD));
        }
    }

    function setUser(uint256 _tokenId, address _addressUser) public virtual override{
        //Check if sender is the owner of token and the token state.
        require((ownerOfSD[_tokenId] == msg.sender) && (Secure_Token[_tokenId].state >= States.engagedWithOwner));
        //Only for ensure avoid overflow, for example in address 0.
        if(userBalance[Secure_Token[_tokenId].user]>0){
            //update the balance of token assigned to the old user
            userBalance[Secure_Token[_tokenId].user]--;
        }
        ////update the balance of token assigned to the new user
        userBalance[_addressUser]++;
        //Assign the new user to the token
        Secure_Token[_tokenId].user = _addressUser;
        //update the state of the token
        Secure_Token[_tokenId].state = States.waitingForUser;
        emit UserAssigned(_tokenId,_addressUser);
    }
    
    function userEngage(uint256 _tokenId) public virtual override{
        //Check if sender is the User of token and the State of token
        require(Secure_Token[_tokenId].user == msg.sender);
        require (Secure_Token[_tokenId].state == States.waitingForUser);
        //update the state of token
        Secure_Token[_tokenId].state = States.engagedWithUser;
        //Send a notification to User and Device
        emit UserEngaged(_tokenId);
    }
    
    function ownerEngage(uint256 _tokenId) public virtual override{
        //Check if sender is the owner of token and the State of token
        require(ownerOfSD[_tokenId] == msg.sender);
        require (Secure_Token[_tokenId].state == States.waitingForOwner);
        //update the state of token
        Secure_Token[_tokenId].state = States.engagedWithOwner;
        //Send a notification to Owner and Device
        emit OwnerEngaged(_tokenId);
    }
    
    function tokenFromBCA(address _addressSD) public virtual view override returns (uint256){
        return(tokenIDOfBCA[_addressSD]);
    }
    
    function ownerOfFromBCA(address _addressSD) public virtual view override returns (address){
        return(ownerOfSD[tokenIDOfBCA[_addressSD]]);
    }
    
    function userOf(uint256 _tokenId) public virtual view override returns (address){
         return(Secure_Token[_tokenId].user);
    }
    
    function userOfFromBCA(address _addressSD) public virtual override view returns (address){
        return(Secure_Token[tokenIDOfBCA[_addressSD]].user);
    }
    
    function userBalanceOf(address _addressUser) public virtual override view returns (uint256){
        return(userBalance[_addressUser]);
    }
    
    function userBalanceOfAnOwner(address _addressUser, address _addressOwner) public virtual override view returns (uint256){
        //TODO
    }
    
        function getInfoToken(uint256 _tokenId) public view returns ( address _BCA_OWNER,
                                                                    address _BCA_USER,
                                                                    address _BCA_SD,
                                                                    uint8   _state){
        _BCA_OWNER = ownerOfSD[_tokenId];
        _BCA_USER = Secure_Token[_tokenId].user;
        _BCA_SD = Secure_Token[_tokenId].SD;
        if(Secure_Token[_tokenId].state == States.waitingForOwner){
            _state = 0;
        }else if(Secure_Token[_tokenId].state == States.engagedWithOwner){
            _state = 1;
        }else if(Secure_Token[_tokenId].state == States.waitingForUser){
            _state = 2;
        }else {
            _state = 3;
        }
    }
    
    function getInfoTokenFromBCA(address _addressSD) public view returns ( address _BCA_OWNER,
                                                                    address _BCA_USER,
                                                                    uint256 _tokenId,
                                                                    uint8   _state){
        _tokenId = tokenIDOfBCA[_addressSD];
        _BCA_OWNER = ownerOfSD[_tokenId];
        _BCA_USER = Secure_Token[_tokenId].user;
        if(Secure_Token[_tokenId].state == States.waitingForOwner){
            _state = 0;
        }else if(Secure_Token[_tokenId].state == States.engagedWithOwner){
            _state = 1;
        }else if(Secure_Token[_tokenId].state == States.waitingForUser){
            _state = 2;
        }else {
            _state = 3;
        }
    }
    
    function balanceOf(address _owner) public virtual override view returns (uint256){
        return(ownerBalance[_owner]);
    }
    
    function ownerOf(uint256 _tokenId) public virtual override view returns (address){
        return(ownerOfSD[_tokenId]);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public virtual override payable{
        //out of scope
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public virtual override payable{
        //out of scope
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public virtual override payable{
        require(ownerOfSD[_tokenId] == msg.sender||Secure_Token[_tokenId].approved == msg.sender);
        require(ownerOfSD[_tokenId] == _from);
        ownerOfSD[_tokenId] = _to;
        ownerBalance[_from]--;
        ownerBalance[_to]++;
        Secure_Token[_tokenId].approved = address(0);
        Secure_Token[_tokenId].user = address(0);
        Secure_Token[_tokenId].state = States.waitingForOwner;
        emit Transfer(_from,_to,_tokenId);
    }

    function approve(address _approved, uint256 _tokenId) public virtual override payable{
        //out of scope
    }

    function setApprovalForAll(address _operator, bool _approved) public virtual override{
        //out of scope
    }

    function getApproved(uint256 _tokenId) public virtual override view returns (address){
        //out of scope
    }

    function isApprovedForAll(address _owner, address _operator) public virtual override view returns (bool){
        //out of scope
    }
}
