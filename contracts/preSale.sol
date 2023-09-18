// SPDX-License-Identifier: MIT
//gautam
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    uint256 public rate; // Single uint value for rate
    address public saleToken;
    uint public saleTokenDec;
    uint256 public totalTokensforSale;
    uint256 public maxBuyLimit;
    uint256 public minBuyLimit;
    mapping(address => bool) public tokenWL;
    mapping(address => uint256) public tokenPrices; // Single uint value for token price

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

    uint256 public totalTokensSold;

    event TokenAdded(address token, uint256 price);
    event TokenUpdated(address token, uint256 price);
    event TokensBought(
        address indexed buyer,
        address indexed token,
        uint256 amount,
        uint256 tokensBought
    );
    event SaleTokenAdded(address token, uint256 amount);

    constructor() {}

    modifier isPresaleHasNotStarted() {
        require(
            presaleStartTime != 0,
            "Presale: Presale has not started yet"
        );
        _;
    }

    modifier isPresaleStarted() {
        require(
            block.timestamp >= presaleStartTime,
            "Presale: Presale has not started yet"
        );
        _;
    }

    modifier isPresaleNotEnded() {
        require(
            block.timestamp < presaleEndTime,
            "Presale: Presale has ended"
        );
        _;
    }

    modifier isPresaleEnded() {
        require(
            block.timestamp >= presaleEndTime,
            "Presale: Presale has not ended yet"
        );
        _;
    }

    function setSaleTokenParams(
        address _saleToken,
        uint256 _totalTokensforSale
    ) external onlyOwner {
        require(
            _saleToken != address(0),
            "Presale: Sale token cannot be zero address"
        );
        require(
            _totalTokensforSale > 0,
            "Presale: Total tokens for sale cannot be zero"
        );
        saleToken = _saleToken;
        saleTokenDec = IERC20Metadata(saleToken).decimals();

        IERC20(saleToken).safeTransferFrom(
            msg.sender,
            address(this),
            _totalTokensforSale
        );
        totalTokensforSale = IERC20(saleToken).balanceOf(address(this));
        emit SaleTokenAdded(_saleToken, _totalTokensforSale);
    }

    function startAndSetPresaleEndTime(
        uint256 _presaleEndTime
    ) external onlyOwner {
        presaleStartTime = block.timestamp;
        presaleEndTime = presaleStartTime + _presaleEndTime;
    }

    function upateTime(
        uint256 _presaleEndTime
    ) external onlyOwner {
        presaleEndTime = block.timestamp + _presaleEndTime;
    }

    function addWhiteListedToken(
        address _token,
        uint256 _price
    ) external onlyOwner {
        tokenWL[_token] = true;
        tokenPrices[_token] = _price;
        emit TokenAdded(_token, _price);
    }

    function updateEthRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    function updateTokenRate(
        address _token,
        uint256 _price
    ) external onlyOwner {
        require(tokenWL[_token], "Presale: Token not whitelisted");
        tokenPrices[_token] = _price;
        emit TokenUpdated(_token, _price);
    }



    function getTokenAmount(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        uint256 amtOut;
        if (token != address(0)) {
            require(tokenWL[token], "Presale: Token not whitelisted");

            amtOut = tokenPrices[token] != 0
                ? (amount * (10 ** saleTokenDec)) / (tokenPrices[token])
                : 0;
        } else {
            amtOut = rate != 0
                ? (amount * (10 ** saleTokenDec)) / (rate)
                : 0;
        }
        return amtOut;
    }

    function buyToken(
        address _token,
        uint256 _amount
    ) external payable isPresaleStarted isPresaleNotEnded {

        uint256 saleTokenAmt = _token != address(0)
            ? getTokenAmount(_token, _amount)
            : getTokenAmount(address(0), msg.value);

        require(
            (totalTokensSold + saleTokenAmt) <= totalTokensforSale,
            "Presale: Total Token Sale Reached!"
        );

        if (_token == address(0)) {
            require(saleTokenAmt >= minBuyLimit, "Presale: Token amount below min buy limit");
            IERC20(saleToken).safeTransfer(msg.sender, saleTokenAmt);
        } else {
            require(saleTokenAmt >= minBuyLimit, "Presale: Amount below min buy limit");
            require(tokenWL[_token], "Presale: Token not whitelisted");
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            IERC20(saleToken).safeTransfer(msg.sender, saleTokenAmt);
        }
        totalTokensSold += saleTokenAmt;
        emit TokensBought(msg.sender, _token, _amount, saleTokenAmt);
    }

    function setMinBuyLimit(uint256 _minBuyLimit) external onlyOwner {
        minBuyLimit = _minBuyLimit;
    }

    function setMaxBuyLimit(uint256 _maxBuyLimit) external onlyOwner {
        maxBuyLimit = _maxBuyLimit;
    }

    // Withdraw sale tokens to the owner's address
    function withdrawSaleToken(uint256 _amount) external onlyOwner isPresaleEnded {
        IERC20(saleToken).safeTransfer(msg.sender, _amount);
    }

    // Withdraw all available sale tokens to the owner's address
    function withdrawAllSaleToken() external onlyOwner isPresaleEnded {
        uint256 amt = IERC20(saleToken).balanceOf(address(this));
        IERC20(saleToken).safeTransfer(msg.sender, amt);
    }

    // Withdraw specific ERC20 tokens to the owner's address
    function withdraw(address token, uint256 amt) public   onlyOwner {
        require(token != saleToken, "Presale: Cannot withdraw sale token with this method, use withdrawSaleToken() instead");
        IERC20(token).safeTransfer(msg.sender, amt);
    }

     function withdrawAll(address token) external onlyOwner {
        require(token != saleToken, "Presale: Cannot withdraw sale token with this method, use withdrawAllSaleToken() instead");
        uint256 amt = IERC20(token).balanceOf(address(this));
        withdraw(token, amt);
    }

    // Withdraw ETH to the owner's address
    function withdrawCurrency(uint256 amt) external onlyOwner {
        payable(msg.sender).transfer(amt);
    }
}