// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

contract Base  {
    uint x ;
    uint256 balance;
    address owner;
    event Create(uint);
    constructor(uint _x) {
        owner = msg.sender;
        x = _x;
        emit Create(0);
    }
    receive() external payable {}

    fallback() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function deposit(uint256 val) public payable {
        balance = val;
    }

    function SetVal(uint val) public {
        x = val;
    }

    function GetVal() public view returns(uint) {
        return x;
    }

    function GetAddr() public view returns(address) {
        return address(this);
    }

    function destroy() public {
        payable(msg.sender).transfer(balance); 
        balance = 0;
    } 
}

interface cinterface {
  function SetVal(uint val)  external;
  function deposit(uint256)  external;
  function destroy()  external;
  function GetVal() external view  returns(uint);
}

contract Test {
    uint256 tx_gas = 21000000000000;
    struct Obj {
        address c1;
        bool enable;
    }
    mapping(address => Obj) c1_map;

    function CreateC1() public {
        require(c1_map[msg.sender].enable == false, "exist");
        Base b = new Base(uint(0));
        c1_map[msg.sender].enable = true;
        c1_map[msg.sender].c1 = b.GetAddr();
     }

    function SetVal(uint val) public {
        require(c1_map[msg.sender].enable == true, "exist");
        cinterface(c1_map[msg.sender].c1).SetVal(val);
     }

    function GetVal() public view returns(uint){
        require(c1_map[msg.sender].enable == true, "exist");
        uint v = cinterface(c1_map[msg.sender].c1).GetVal();
        return v;
     }

    function deposit() public payable {
        require(msg.value > tx_gas, "exist");
        require(c1_map[msg.sender].enable == true, "exist");
        uint256 real_balance = msg.value - tx_gas;
        bool sent = payable(c1_map[msg.sender].c1).send(msg.value);
        require(sent, "Failed to send Ether");
        cinterface(c1_map[msg.sender].c1).deposit(real_balance);
        
    }
     function destroy() public  {
         require(c1_map[msg.sender].enable == true, "exist");
         cinterface(c1_map[msg.sender].c1).destroy();
         c1_map[msg.sender].enable = false;
     }

     function GetBalance() public view returns(uint256) {
        return address(this).balance;
     }
}