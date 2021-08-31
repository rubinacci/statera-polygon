// Statera v3 - Polygon Bridge compatible
// 30-08-2021

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity 0.8.0;

// File: contracts/common/AccessControlMixin.sol

contract AccessControlMixin is AccessControl {
    string private _revertMsg;
    function _setupContractId(string memory contractId) internal {
        _revertMsg = string(abi.encodePacked(contractId, ": INSUFFICIENT_PERMISSIONS"));
    }

    modifier only(bytes32 role) {
        require(
            hasRole(role, _msgSender()),
            _revertMsg
        );
        _;
    }
}

// File: contracts/child/ChildToken/IChildToken.sol

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}



contract Statera is
    ERC20,
    IChildToken,
    AccessControlMixin
{
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowed;

    //Construct token without minting. Set childChainManager proxy address to allow Polygon Bridge to mint tokens

    constructor(
        string memory name_,
        string memory symbol_,
        address childChainManager
    ) public ERC20(name_, symbol_) {
        _setupContractId("Statera");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */

    function deposit(address user, bytes calldata depositData)
        external
        override
        only(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function cut(uint256 value) public returns (uint256)  {
        uint256 cutValue = value.mul(100).div(10000);
        return cutValue;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);
        
        //Statera - Calculate 1% of transferred tokens to be burned and remainder
        uint256 tokensToBurn = cut(amount);
        uint256 tokensToTransfer = amount.sub(tokensToBurn);

        //Decrement sender balance
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        //Increment recipient balance
        _balances[recipient] = _balances[recipient].add(tokensToTransfer);
        
        //Transfer and burn
        emit Transfer(sender, recipient, tokensToTransfer);
        emit Transfer(sender, address(0), tokensToBurn);
    }
}



