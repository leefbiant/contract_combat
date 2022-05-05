// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint _nftId
    ) external;
}

contract DutchAuction {
    uint private constant DURATION = 1 days;

    IERC721 public immutable nft;
    uint public immutable nftId;

    address payable public immutable seller; // 卖出者
    uint public immutable startingPrice; // 起拍价
    uint public immutable startAt; // 起拍时间
    uint public immutable expiresAt;
    uint public immutable discountRate; // 折扣率

    constructor(
        uint _startingPrice,
        uint _discountRate,
        address _nft,
        uint _nftId
    ) {
       startingPrice = _startingPrice;
       discountRate  = _discountRate;
       startAt = block.timestamp;
       expiresAt = startAt + DURATION;
       seller = payable(msg.sender);

       require(_startingPrice >= _discountRate * DURATION, "starting price < min");

       nft = IERC721(_nft);
       nftId = _nftId; 
    }

    function getPrice() public view returns (uint) {
        uint costTime = block.timestamp - startAt;
        uint discount = costTime * discountRate;
        return startingPrice - discount; 
    }

    function buy() external payable {
        require(block.timestamp < expiresAt, "auction expired");
        uint price = getPrice();
        require(msg.value >= price, "ETH < price");
        nft.transferFrom(seller, msg.sender, nftId);
        uint refund = msg.value - price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
        seller.transfer(price);
    }
} 