// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Nibbstack/nf-token.sol";
import "./Nibbstack/ownable.sol";
import "./OpenZeppelin/Strings.sol";

/**
 * @notice A non-fungible certificate that anybody can create by spending eth
 * 
 * Control of the NFT means control of the VM (ownerOf plays a huge role in this)
 * sync script would have to go through entire smart contract to change owner ship
 * -or- listen for transfer emits until certain block number
 * 
 * You can set price of VM based on class
 * Each class sells for a certain price and then you can do anything with it game wise
 * 
 * Smart contact tracks down expiration date of the VM
 * 
 * Smart contract allows setting time! They can pay more in advanced when first minting
 * Smart contract allows "topping off" to prevent pre-mature deletion (requires emit); renewals!
 * 
 */
abstract contract DeadmanSwitch is Ownable {
    address private _kin;
    uint256 private _timestamp;
    constructor() {
        _kin = msg.sender;
        _timestamp = block.timestamp;
    }
    // @notice Event for when deadman switch is set
    event SetDeadSwitch(address indexed kin_, uint256 indexed days_);
    /**
    * @notice to be used by contract owner to set a deadman switch in the event of worse case scenario
    * @param kin_ the address of the next owner of the smart contract if the owner dies
    * @param days_ number of days from current time that the owner has to check-in prior to, otherwise the kin can claim ownership
    */
    function setDeadmanSwitch(address kin_, uint256 days_) onlyOwner external returns (bool){
      require(days_ < 365, "9M-ERC721: Must check-in once a year");
      require(kin_ != address(0), CANNOT_TRANSFER_TO_ZERO_ADDRESS);
      _kin = kin_;
      _timestamp = block.timestamp + (days_ * 1 days);
      emit SetDeadSwitch(kin_, days_);
      return true;
    }
    /**
    * @notice to be used by the next of kin to claim ownership of the smart contract if the time has expired
    * @return true on successful owner transfer
    */
    function claimSwitch() external returns (bool){
      require(msg.sender == _kin, "9M-ERC721: Only next of kin can claim a deadman's switch");
      require(block.timestamp > _timestamp, "9M-ERC721: Deadman is alive");
      emit OwnershipTransferred(owner, _kin);
      owner = _kin;
      return true;
    }
    /**
    * @notice used to see who the next owner of the smart contract will be, if the switch expires
    * @return the address of the next of kin
    */
    function getKin() public view virtual returns (address) {
        return _kin;
    }
    /**
    * @notice used to get the date that the switch expires to allow for claiming it
    * @return the timestamp for which the switch expires
    */
    function getExpiry() public view virtual returns (uint256) {
        return _timestamp;
    }
}

contract GM_721 is NFToken, DeadmanSwitch
{
    // @notice Event for when NFT is minted
    event MintedNFT(address indexed minter, uint256 indexed tokenId, uint256 indexed days_);

    // @notice Event for when mint price changes
    event SetMintPrice(uint256 indexed vm_classifier, uint256 indexed price);

    // @notice Event for when mint price changes
    event RenewNFT(uint256 indexed tokenId, uint256 indexed days_);

    // @notice Event for when base URI is set
    event SetBaseURI(string indexed baseURI);

    /// @dev The serial number of the next certificate to create
    uint256 public nextCertificateId = 1;

    // Base URI
    string public _baseURIextended;

    mapping(uint256 => bytes32) certificateDataHashes;

    // ERC721 tokenURI standard
    mapping (uint256 => string) private _tokenURIs;

    // Mappings for VM prices, VM expiry, VM classifier
    mapping (uint256 => uint256) private _vm_types;
    mapping (uint256 => uint256) private _vm_expiry;
    mapping (uint256 => uint256) private _vm_classifier;

    // Mapping for total days rented on server or person
    mapping (address => uint256) public total_days_rented;
    mapping (uint256 => uint256) public server_days_rented;

    /**
     * @notice The price to create certificates influenced by token circulation and max supply
     * @return The price to create certificates
     */
    function mintingPrice(uint vm_classifier, uint256 days_) external view returns (uint256) {
        return days_ * _vm_types[vm_classifier];
    }

    /**
     * @return Expiration date of VM
     */
    function getExpiry(uint token_id) external view returns (uint256) {
        return _vm_expiry[token_id];
    }

    /**
     * @return Type of VM
     */
    function getVMType(uint token_id) external view returns (uint256) {
        return _vm_classifier[token_id];
    }

    /**
     * @notice Set new price to create certificates
     * @param vm_classifier The type of VM
     * @param vm_price The price of the VM in ETH
     */
    function setMintingPrice(uint vm_classifier, uint vm_price) onlyOwner external {
        _vm_types[vm_classifier] = vm_price;
        emit SetMintPrice(vm_classifier, vm_price);
    }

    /**
     * @notice used by the contract owner to set a prefix string at the beginning of all token resource locations.
     * @param baseURI_ the string that goes at the beginning of all token URI
     *
     */
    function setBaseURI(string calldata baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
        emit SetBaseURI(baseURI_);
    }

    /**
     * @notice Purpose is to set the remote location of the JSON artifact
     * @param tokenId the id of the certificate
     * @return The remote location of the JSON artifact
     *
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        require(bytes(Strings.toString(_vm_classifier[tokenId])).length > 0, "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = Strings.toString(_vm_classifier[tokenId]);
        string memory base = _baseURIextended;

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        return string(abi.encodePacked(base, _tokenURI));
    }

    /**
     * @notice Renew existing VM. anyone can renew anyone's VM for them
     * @param token_id The VM
     * @param days_ Number of days to add
     */
    function renewVM(uint256 token_id, uint256 days_) external payable {
        uint256 price = days_ * _vm_types[_vm_classifier[token_id]];
        require(price > 0, "9M-ERC721: VM can't be free");
        require(days_ < 365, "9M-ERC721: Can rent VM for a year max"); // ? owner should set max
        
        // Send ETH to owner of this contract
        require(msg.value == price, "9M-ERC721: Insufficient funds");
        payable(owner).transfer(msg.value);

        // if not expired add days to existing expiry, if expired add days from now on
        if(_vm_expiry[token_id] > block.timestamp){
            _vm_expiry[token_id] += (days_ * 1 days);
        }else{
            _vm_expiry[token_id] = block.timestamp + (days_ * 1 days);
        }

        // Add days to profile and server metadata
        server_days_rented[token_id] += days_;
        total_days_rented[msg.sender] += days_;

        emit RenewNFT(token_id, days_);
    }

    /**
     * @notice Allows anybody to mint new NFT that represents VM
     * @param vm_classifier The type of VM to get
     * @param days_ The number of days we rent this VM for
     *
     */
    function create(uint256 vm_classifier, uint256 days_) external payable returns (uint) {
        uint256 price = days_ * _vm_types[vm_classifier];
        require(price > 0, "9M-ERC721: VM can't be free");
        require(days_ < 365, "9M-ERC721: Can rent VM for a year max"); // ? owner should set max

        // Send ETH to owner of this contract
        require(msg.value == price, "9M-ERC721: Insufficient funds");
        payable(owner).transfer(msg.value);

        // Create the certificate
        uint256 newCertificateId = nextCertificateId;

        // Set expire date of NFT
        _vm_expiry[newCertificateId] = block.timestamp + (days_ * 1 days);

        // Set VM classifier to know which one to deploy
        _vm_classifier[newCertificateId] = vm_classifier;

        // Add days to profile and server metadata
        server_days_rented[newCertificateId] += days_;
        total_days_rented[msg.sender] += days_;

        _mint(msg.sender, newCertificateId);
        nextCertificateId = nextCertificateId + 1;
        // Emit that we minted an NFT
        emit MintedNFT(msg.sender, newCertificateId, days_);

        return newCertificateId;
    }
}
