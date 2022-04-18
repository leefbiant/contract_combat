// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

interface IERC20 {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);
  function approveOrigin(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IVERIFY {
  function verify(address user) external returns(bool);
}

library TransferHelper {
    event TransferHelperDebug(address, address, address, uint);
    function approveOrigin(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20(token).approveOrigin.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
        emit TransferHelperDebug(token, msg.sender, to, value);
    }

    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20(token).approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
        emit TransferHelperDebug(token, msg.sender, to, value);
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20(token).transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
        emit TransferHelperDebug(token, msg.sender, to, value);
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20(token).transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
        emit TransferHelperDebug(token, msg.sender, to, value);
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

contract RedPacket {
   using SafeMath for uint;

  // 接收者信息
  struct receiveObj {
    address user;
    uint256 claim_balance;
  }

  // 红包信息
  struct userPacketObj {
    uint256 m_claim_balance; // 已经领取金额
    uint8 m_num; // 红包总数
    uint256 m_max_val; // 单个红包最大金额
    uint8 m_type; // 0 拼手气红包 1 等额红包
    uint8 m_claim_num; // 已经领取数量
    uint256 m_expired_time; // 过期时间
    mapping(address => receiveObj) m_recv_map;
  }

  // 红包管理信息
  userPacketObj red_packet;  

  // 红包创建者
  address owner;
  address token; // ERC20代币地址

  address verify_addr; // 验证地址

  // 主合约，用于收税
  address main_contract;

  event RedPacketDebug(uint);
  event VerifyEv(address, address);

  constructor (address _main_contract, address _token, uint256 _token_num) {
    // 创者是合约
    owner = tx.origin;
    require(_token_num > 0, "token_num > 0");
    // 收税钱包
    main_contract = _main_contract;

    // 红包token  
    token = _token;
    //uint256 token_num = _token_num * 1000000000000000000;
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
    return (IERC20(token).balanceOf(address(this)), red_packet.m_claim_balance, red_packet.m_num, red_packet.m_claim_num);
  }

  function GetAddr() public view returns(address) {
    return address(this);
  }
  // 创建红包
  function CreateRedPacket(uint8 num, uint256 max_val, uint8 _type, uint256 _expiretime) public payable returns(bool) {
    // 输入金额 输入数量大于0
    uint256 balance = IERC20(token).balanceOf(address(this));
    require(balance > 0 && num > 0, "require > 0");
    // 超时时间默认24小时
    uint256 expiretime = 3600;
    if (_expiretime > 0) expiretime = _expiretime;

    red_packet.m_num = num;
    red_packet.m_max_val = max_val * (10 ** IERC20(token).decimals());
    red_packet.m_type = _type; 
    red_packet.m_expired_time = block.timestamp + expiretime;
    emit RedPacketDebug(address(this).balance);
    emit RedPacketDebug(red_packet.m_max_val);
    return true;
  }

  // 销毁红包
  function Destroy() public payable isOwner {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
       TransferHelper.safeTransfer(token, owner, balance);
    }
    emit RedPacketDebug(100);
    selfdestruct(payable(owner)); 
  }

  function SetVerifyAddr(address _verify_addr) public isOwner {
    require(_verify_addr != address(0), "err verify_addr");
    verify_addr = _verify_addr;
  }

  function ThirdVerify(address user) private  {
    (bool success, bytes memory data) = verify_addr.call(abi.encodeWithSelector(IVERIFY(verify_addr).verify.selector, user));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    emit VerifyEv(verify_addr, user);
  }

  // 领取红包
  function Claim(address user) public payable returns (bool) {
    // 当前合约中已经不存余额
    uint256  balance = IERC20(token).balanceOf(address(this));
    require(balance > 0, "no redpacket");

    // 已经过期
    require(red_packet.m_expired_time > block.timestamp, "packet expired"); 

    // 已经领取过了
    require(red_packet.m_recv_map[user].claim_balance == 0, "has claim"); 

    if (verify_addr != address(0)) {
      ThirdVerify(msg.sender);
    }

    uint8 leftover = red_packet.m_num - red_packet.m_claim_num;
    uint256 claim_balance  = balance;
    if (red_packet.m_type == 0) {
      uint256 key = random();
      if ((leftover >> 2) > 1) {
        claim_balance = key % (balance.mul(4));
      } else if ((leftover >> 1) > 1) {
        claim_balance = key % (balance.mul(2));
      } else if (leftover > 1 ) {
        claim_balance = key % balance;
      }

      if (claim_balance > red_packet.m_max_val) claim_balance = red_packet.m_max_val; 
    } else {
      claim_balance = balance / leftover;
    }


    // 千三税收
    uint256 tax = claim_balance.mul(100) * 3;
    emit RedPacketDebug(tax);
    claim_balance -= tax;

    // 添加列表
    red_packet.m_claim_num += 1; 
    red_packet.m_claim_balance += claim_balance + tax; 
    red_packet.m_recv_map[user].user = user; 
    red_packet.m_recv_map[user].claim_balance = claim_balance; 

    // 发送红包 
    TransferHelper.safeTransfer(token, user, claim_balance);
    emit RedPacketDebug(claim_balance);

    // 获取税收
    TransferHelper.safeTransfer(token, main_contract, tax);

    // 余额
    emit RedPacketDebug(IERC20(token).balanceOf(address(this))); 
    return true;
  } 

  function QueryRedPacket() public view returns (uint256, uint256, uint8, uint8)  {
    return (IERC20(token).balanceOf(address(this)), red_packet.m_claim_balance, red_packet.m_num,  red_packet.m_claim_num);
  }

  function QueryClaim(address user) public view returns(uint256) {
    return red_packet.m_recv_map[user].claim_balance;
  }
}


interface RpInterface {
  function CreateRedPacket(uint8 num, uint256 m_max_val, uint256 _expiretime) external returns(bool) ;
  function Claim(address user) external payable returns (bool);
  function Destroy() external payable;
  function QueryRedPacket() external view returns (uint256, uint256, uint8, uint8);
  function QueryClaim(address user) external view returns(uint256);
}


// 红包管理合约
contract ERCRedPacketFactory {
  address owner;

  // 红包结构
  struct RedPacketObj {
    bool m_enable;
    address token;
    address contract_addr;
  } 

  event ERCRedPacket(uint);
  mapping(uint256 => RedPacketObj) red_packet_map;
  modifier isOwner() {
    require(msg.sender == owner, "Caller is not owner");
    _;
  } 
  constructor () {
    owner = msg.sender;
  }

  receive() external payable {}

  fallback() external payable {}

  function getBalance() private view isOwner returns (uint) {
    return address(this).balance;
  }

  // 获取token数量
  function getToken(address token) private view isOwner returns (uint) {
    return IERC20(token).balanceOf(address(this));
  }

  function getPacketId(address a) private pure returns (uint256) {
    return uint256(uint256(keccak256(abi.encodePacked(a))) % 100000000);
  }

  function CreateRedPacket(address _token, uint256 _token_num, uint8 num, uint256 max_val, uint256 _expiretime) public payable returns(uint256) {
    require(tx.origin == msg.sender, "must person");

    uint256 id = getPacketId(msg.sender);
    require(red_packet_map[id].m_enable == false, "exist");

    // 创建红包
    RedPacket c = new RedPacket(address(this), _token, _token_num);   
    address contract_addr = c.GetAddr();
    red_packet_map[id].contract_addr = contract_addr;
    red_packet_map[id].token = _token;

   
    uint256 token_num =  10 ** IERC20(_token).decimals() * _token_num;
    if (IERC20(_token).balanceOf(address(this)) < token_num) {
       // 如果未授权则授权
      TransferHelper.approveOrigin(_token, address(this), token_num); 
    }
   
    // 转币
    TransferHelper.safeTransferFrom(_token, msg.sender, contract_addr, token_num);

    bool ret = RpInterface(contract_addr).CreateRedPacket(num, max_val, _expiretime); 
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
  function QueryRedPacket() public view  returns (uint256, uint256, uint256, uint256, uint8, uint8) {
    uint256 id = getPacketId(msg.sender);
    require(red_packet_map[id].m_enable == true, "not exist");
    uint256 my_token = IERC20(red_packet_map[id].token).balanceOf(msg.sender);
    (uint256 a, uint256 b, uint8 c, uint8 d) = RpInterface(red_packet_map[id].contract_addr).QueryRedPacket();
    return (id, my_token, a, b, c, d); 
  }

  function BalanceOf(address token) public view  returns (uint256) {
    return IERC20(token).balanceOf(msg.sender);
  }

  function QueryClaim(uint256 id) public view returns(uint256) {
    require(red_packet_map[id].m_enable == true, "not exist");
    return RpInterface(red_packet_map[id].contract_addr).QueryClaim(msg.sender); 
  }

  // 查询收入
  function QueryIncome(address token) public view isOwner returns(uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  // 改变收税钱包
  function ChangeOWner() public payable isOwner  {
    owner = msg.sender;
  }

  // 收割手续费
  function Harvest(address token) public payable isOwner  {
    uint256 token_num = IERC20(token).balanceOf(address(this));
    // 转币
    TransferHelper.safeTransfer(token, owner, token_num);
  }
}