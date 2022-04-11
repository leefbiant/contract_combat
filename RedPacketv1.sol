// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

contract RedPacket {
  // 接收者信息
  struct receiveObj {
    address user;
    uint256 claim_balance;
  }

  // 红包信息
  struct userPacketObj {
    uint256 m_claim_balance; // 已经领取金额
    uint8 m_num; // 红包总数
    uint8 m_claim_num; // 已经领取数量
    uint256 m_expired_time; // 过期时间
    mapping(address => receiveObj) m_recv_map;
  }

  // 红包管理信息
  userPacketObj red_packet;  

  // 红包创建者
  address owner;

  // 主合约，用于收税
  address main_contract;

  event RedPacketDebug(uint);

  constructor (address _main_contract) {
    // 创者是合约
    owner = tx.origin;

    // 收税钱包
    main_contract = _main_contract;
  }

  modifier isOwner() {
    require(tx.origin == owner, "Caller is not owner");
    _;
  }

  receive() external payable {}

  fallback() external payable {}

  // 获取红包余额
  function GetBalance() public view returns (uint) {
    return address(this).balance;
  }


  function random() private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
  }

  function QueryPacket() public view returns (uint256, uint256, uint8, uint8) {
    return (address(this).balance, red_packet.m_claim_balance, red_packet.m_num, red_packet.m_claim_num);
  }

    function GetAddr() public view returns(address) {
        return address(this);
    }
  // 创建红包
  function CreateRedPacket(uint8 num, uint256 _expiretime) public payable returns(bool) {
    // 输入金额 输入数量大于0
    require(address(this).balance > 0 && num > 0, "require > 0");
    // 超时时间默认24小时
    uint256 expiretime = 3600;
    if (_expiretime > 0) expiretime = _expiretime;

    red_packet.m_num = num;
    red_packet.m_expired_time = block.timestamp + expiretime;
    emit RedPacketDebug(red_packet.m_expired_time);
    return true;
  }

  // 习销毁红包
  function Destroy() public payable isOwner {
    if (GetBalance() > 0) {
      payable(owner).transfer(GetBalance());
    }
    emit RedPacketDebug(100);
    selfdestruct(payable(owner)); 
  }


  // 领取红包
  function Claim(address user) public payable returns (bool) {
    // 当前合约中已经不存余额
    require(address(this).balance > 0, "no redpacket");

    // 已经过期
    require(red_packet.m_expired_time > block.timestamp, "packet expired"); 

    // 已经领取过了
    require(red_packet.m_recv_map[user].claim_balance == 0, "has claim"); 

    uint8 leftover = red_packet.m_num - red_packet.m_claim_num;
    uint256 overage_balance = address(this).balance; 
    uint256 claim_balance  = address(this).balance;
    uint256 key = random();
    if ((leftover >> 2) > 1) {
      claim_balance = key % (address(this).balance / 4);
    } else if ((leftover >> 1) > 1) {
      claim_balance = key % (overage_balance / 2);
    } else if (leftover > 1 ) {
      claim_balance = key % overage_balance;
    }

    // 千三税收
    uint256 tax = claim_balance * 3 / 100;
    emit RedPacketDebug(tax);
    claim_balance -= tax;

    // 添加列表
    red_packet.m_claim_num += 1; 
    red_packet.m_claim_balance += claim_balance + tax; 
    red_packet.m_recv_map[user].user = user; 
    red_packet.m_recv_map[user].claim_balance = claim_balance; 

    // 发送红包 
    payable(user).transfer(claim_balance); 
    emit RedPacketDebug(claim_balance);
    // 获取税收
    payable(main_contract).transfer(tax); 
    emit RedPacketDebug(tax);
    // 余额
    emit RedPacketDebug(address(this).balance); 
    return true;
  } 

  function QueryRedPacket() public view returns (uint256, uint256, uint8, uint8)  {
      return (address(this).balance, red_packet.m_claim_balance, red_packet.m_num,  red_packet.m_claim_num);
  }
}


interface RpInterface {
  function CreateRedPacket(uint8 num, uint256 _expiretime) external returns(bool) ;
  function Claim(address user) external payable returns (bool);
  function Destroy() external payable;
  function QueryRedPacket() external view returns (uint256, uint256, uint8, uint8);
}


// 红包管理合约
contract RedPacketMgr {
  address owner;

  // 红包结构
  struct RedPacketObj {
    bool m_enable;
    address contract_addr;
  } 

  // 
  mapping(uint256 => RedPacketObj) red_packet_map;
  modifier isOwner() {
    require(msg.sender == owner, "Caller is not owner");
    _;
  } 
  constructor () {
    owner = msg.sender;
  }

  function getPacketId(address a) private pure returns (uint256) {
     return uint256(uint256(keccak256(abi.encodePacked(a))) % 100000000);
  }

  function CreateRedPacket(uint8 num, uint256 _expiretime) public payable returns(uint256) {
    require(tx.origin == msg.sender && msg.value > 0 , "balance > 0");

    uint256 id = getPacketId(msg.sender);
    require(red_packet_map[id].m_enable == false, "exist");

    // 创建红包
    RedPacket c = new RedPacket(owner);   
    address contract_addr = c.GetAddr();
    red_packet_map[id].contract_addr = contract_addr;
    bool ret = payable(red_packet_map[id].contract_addr).send(msg.value); 
    require(ret == true, "send fai");

    ret = RpInterface(contract_addr).CreateRedPacket(num, _expiretime); 
    require(ret == true, "CreateRedPacket fai");
    
    red_packet_map[id].m_enable = true;
    return id; 
  }


  // 销毁红包
  function Destroy() public {
    uint256 id = getPacketId(msg.sender);
    require(tx.origin == msg.sender && red_packet_map[id].m_enable == true, "");
    
    RpInterface(red_packet_map[id].contract_addr).Destroy(); 
    red_packet_map[id].m_enable = false; 
  }

  // 领取红包
  function ClaimRedPacket(uint256 id) public {
     require(tx.origin == msg.sender, "fail");
     require(red_packet_map[id].m_enable == true, "not exist");
     bool ret = RpInterface(red_packet_map[id].contract_addr).Claim(msg.sender);
     require(ret == true, "fail");
  }

  // 查询红包
  function QueryRedPacket() public view  returns (uint256, uint256, uint256, uint8, uint8) {
     uint256 id = getPacketId(msg.sender);
     require(red_packet_map[id].m_enable == true, "not exist");
     (uint256 a, uint256 b, uint8 c, uint8 d) = RpInterface(red_packet_map[id].contract_addr).QueryRedPacket();
     return (id, a, b, c, d); 
  }
}
