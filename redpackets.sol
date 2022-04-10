// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

contract redpacket {

    // 红包总金额
    // 创建红包的人
    address owner;
    uint256 total_tax;

    struct receiveObj {
        address user;
        uint256 recv_balance;
    }

    struct userPacketObj {
        bool m_enable;  // 是够有效
        uint256 m_balance; // 红包总余额
        uint256 m_claim_balance; // 已经领取金额
        uint8 m_num; // 红包总数
        uint8 m_claim_num; // 已经领取数量
        uint256 m_expired_time; // 过期时间
        mapping(address => receiveObj) m_recv_map;
    }
   
   //mapping(address => receiveObj) recv_mgr; 
   mapping(uint256 => userPacketObj) packet_mgr; 

   event Debug(uint);


    constructor () {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

   function createPacket(uint8 num, uint256 _expiretime) public payable {

       // 输入金额 输入数量大于0
       require(msg.value > 0 && num > 0, "require > 0");
       uint256 id = getPacketId(msg.sender);
       // 当前地址的红包已经被领取完了
       require(packet_mgr[id].m_enable == false, "require enable");
       // 超时时间默认24小时
       uint256 expiretime = 86400;
       if (_expiretime > 0) expiretime = _expiretime;

       packet_mgr[id].m_enable = true;
       packet_mgr[id].m_num = num;
       packet_mgr[id].m_balance = msg.value;
       packet_mgr[id].m_expired_time = block.timestamp + expiretime;
       emit Debug(packet_mgr[id].m_expired_time);
       emit Debug(packet_mgr[id].m_balance);
   }

   function destroyPacket() public payable {
       uint256 id = getPacketId(msg.sender);
       require(packet_mgr[id].m_enable == true, "not exist");
       if (packet_mgr[id].m_balance > 0) {
           payable(msg.sender).transfer(packet_mgr[id].m_balance);
       }
       /*
       packet_mgr[id].m_balance = 0;
       packet_mgr[id].m_enable = false;
       */
       delete packet_mgr[id];
       emit Debug(0);
   }
   
    function claim(uint256 id) public  {
        // 红包不存在
        require(packet_mgr[id].m_enable == true, "not exist");

        // 已经领取完毕
        require(packet_mgr[id].m_claim_num < packet_mgr[id].m_num, "no redpacket"); 

        // 红包已经过期
        require(packet_mgr[id].m_expired_time > block.timestamp, "packet expired"); 

        // 已经领取过了
        require(packet_mgr[id].m_recv_map[msg.sender].recv_balance == 0, "has claim"); 

        uint8 leftover = packet_mgr[id].m_num - packet_mgr[id].m_claim_num;
        uint256 recv_balance  = packet_mgr[id].m_balance;
        uint256 key = random();
        if ((leftover >> 1) > 1) {
           recv_balance = key % (packet_mgr[id].m_balance / 2);
        } else if (leftover > 1 ) {
            recv_balance = key % packet_mgr[id].m_balance;
        }
        // 千三税收
        uint256 tax = recv_balance * 3 / 100;
        emit Debug(tax);
        recv_balance -= tax;
        packet_mgr[id].m_balance -= recv_balance + tax;
        emit Debug(packet_mgr[id].m_balance);

        // 添加列表
        packet_mgr[id].m_claim_num += 1; 
        packet_mgr[id].m_claim_balance += recv_balance + tax; 
        packet_mgr[id].m_recv_map[msg.sender].user = msg.sender; 
        packet_mgr[id].m_recv_map[msg.sender].recv_balance = recv_balance; 

        // 发送红包 
        payable(msg.sender).transfer(recv_balance); 
        emit Debug(recv_balance);
        // 获取税收
        payable(owner).transfer(tax); 
        total_tax += tax;
        emit Debug(tax);
    }

    // 检查当前发送红包领取情况
    function ckeckMyPacket() public view returns (uint256, uint256, uint256, uint8, uint8) {
        uint256 id = getPacketId(msg.sender);
        require(packet_mgr[id].m_enable == true, "not exist");
        return (id, packet_mgr[id].m_balance, packet_mgr[id].m_claim_balance, packet_mgr[id].m_num, packet_mgr[id].m_claim_num);
    }

    // 检查红包领取情况
    function checkClaimPacket(uint256 id) public view returns(uint256) {
       require(packet_mgr[id].m_enable == true, "not exist");
       return packet_mgr[id].m_recv_map[msg.sender].recv_balance;
    }

    function random() private view returns (uint256) {
       return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    }

    function getPacketId(address a) private pure returns (uint256) {
       return uint256(uint256(keccak256(abi.encodePacked(a))) % 1000000);
    }

    function getTotalTax() public view isOwner returns(uint256) {
        return total_tax;
    }
} 