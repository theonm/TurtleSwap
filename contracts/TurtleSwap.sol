// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TurtleSwap is ReentrancyGuard {
    IERC20 public transactionToken;
    IERC20 public quoteToken;
    uint256 public transactionAmount;
    AggregatorV3Interface public priceFeed;

    address public makerAddress;

    event Made(address indexed maker, uint256 amount);
    event Taken(address indexed maker, address indexed taker, uint256 transactionAmount, uint256 quoteAmount);

    constructor(
        address _transactionToken,
        address _quoteToken,
        uint256 _transactionAmount,
        address _priceFeed
    )
    {
        require(_transactionToken != address(0) && _quoteToken != address(0) && _priceFeed != address(0), "Address cannot be zero");
        transactionToken = IERC20(_transactionToken);
        quoteToken = IERC20(_quoteToken);
        transactionAmount = _transactionAmount;
        priceFeed = AggregatorV3Interface(_priceFeed);
        makerAddress = address(0);
    }

    function make() external nonReentrant {
        require(makerAddress == address(0), "Maker address must be empty");
        require(transactionToken.balanceOf(msg.sender) >= transactionAmount, "Insufficient transaction token amount");
        require(transactionToken.allowance(msg.sender, address(this)) >= transactionAmount, "Contract has insufficient transfer permission for the transaction token");
        makerAddress = msg.sender;
        transactionToken.transferFrom(msg.sender, address(this), transactionAmount);
        emit Made(msg.sender, transactionAmount);
    }

    function take() external nonReentrant {
        require(makerAddress != address(0), "Maker address must not be empty");
        require(makerAddress != msg.sender, "Maker and taker addresses must not be the same");

        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");

        uint256 priceDecimals = priceFeed.decimals();
        uint256 quoteAmount = transactionAmount * uint256(price) / (10 ** priceDecimals);

        require(quoteToken.balanceOf(msg.sender) >= quoteAmount, "Insufficient quote token amount");
        require(quoteToken.allowance(msg.sender, address(this)) >= quoteAmount, "Contract has insufficient transfer permission for the quote token");

        transactionToken.transfer(msg.sender, transactionAmount);
        quoteToken.transferFrom(msg.sender, makerAddress, quoteAmount);
        emit Taken(makerAddress, msg.sender, transactionAmount, quoteAmount);
        makerAddress = address(0);
    }
}