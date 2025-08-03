// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract PlatformToken is
    ERC20,
    ERC20Permit,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 10亿代币

    event ToknesMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256);

    constructor(
        address initialOwner
    )
        ERC20("OnlineTicket Token", "OTT")
        ERC20Permit("OnlineTicket Token")
        Ownable(initialOwner)
    {
        uint256 initialSupply = MAX_SUPPLY / 10;
        _mint(initialOwner, initialSupply);
        emit ToknesMinted(initialOwner, initialSupply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "PlatformToken: mint to zero address");
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "PlatformToken: exceeds max supply"
        );
        _mint(to, amount);
        emit ToknesMinted(to, amount);
    }

    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(
            recipients.length == amounts.length,
            "PlatformToken: array length mismatch"
        );
        require(recipients.length <= 200, "PlatformToken: too many recipients");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(
            totalSupply() + totalAmount <= MAX_SUPPLY,
            "PlatformToken: exceeds max supply"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                recipients[i] != address(0),
                "PlatformToken: mint to zero address"
            );
            _mint(recipients[i], amounts[i]);
            emit ToknesMinted(recipients[i], amounts[i]);
        }
    }

    function burn(uint256 amount) external {
        require(amount > 0, "PlatformToken: burn amount must be positive");
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        require(amount > 0, "PlatformToken: burn amount must be positive");
        require(from != address(0), "PlatformToken: burn from zero address");

        _spendAllowance(from, msg.sender, amount);

        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        super._update(from, to, value);
    }

    function remainMintableSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(this), "PlatformToken: cannot withdraw self");
        require(to != address(0), "PlatformToken: withdraw to zero address");
        require(token != address(0), "PlatformToken: invalid token address");

        // 新增：防止将代币发送回代币合约自己
        require(token != to, "PlatformToken: cannot send token to itself");
        // 检查合约是否有足够余额
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "PlatformToken: insufficient balance");

        // 使用 safeTransfer 更安全
        bool success = IERC20(token).transfer(to, amount);
        require(success, "PlatformToken: transfer failed");

        // 添加事件记录
        emit EmergencyWithdraw(token, to, amount);
    }
}
