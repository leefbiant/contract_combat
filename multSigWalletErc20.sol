// SPDX-License-Identifier: MIT   
// 支持ERC20的多签钱包

pragma solidity ^0.8.0;


interface IERC20 {

  function balanceOf(address owner) external view returns (uint);
  function transfer(address to, uint value) external returns (bool);
}

contract multSigWalletErc20 {

    event Deposit(address indexed owner, uint indexed value, uint total_value);
    event SubTransaction(address indexed owner, address indexed to, uint value, uint id);
    event ConfirmTransaction(address indexed owner, uint indexed to);
    event ExecuteTransaction(address indexed owner, uint indexed id);
    event UnconfirmTransaction(address indexed owner, uint indexed id);

    // 多签用户
    address[] public owners;
    // 多钱用户map
    mapping(address => bool) isOwner;
    // 最小批准数
    uint public required;

    struct Transaction {
        address to; // 接收方用户/合约
        address erc_addr; // erc20合约地址
        uint value;
        bool executed;
        uint numConfirmations;
        bytes data;
    }

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    modifier onlyOwens() {
        // 消息发送者是否 多钱人
        require(isOwner[msg.sender], "not owner");
        _;
    }
    // 交易ID存在
    modifier existTransId(uint _id) {
        require(_id < transactions.length, "not exist");
        _;
    }

    // 交易未执行
    modifier notExecuted(uint _id) {
        require(!transactions[_id].executed, "tx already executed");
        _;
    }

    // 交易未确认
    modifier notConfirm(uint _id) {
        require(!isConfirmed[_id][msg.sender], "has confirm");
        _;
    }

    constructor(address[] memory _owner, uint _required) {
        require(_required > 0, "must > 0");
        // 最小批准数是否 小于等于 用户数
        require(_owner.length >= _required, "owner must >= required");

        for (uint i; i < _owner.length; i++) {
            address owner = _owner[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "exist owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required; 
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // 提交一个转账申请
    function subTransaction(address _to, uint _value, bytes memory _data) external onlyOwens {
        require(balanceOf() >= _value, "not enough");
        uint transid = transactions.length;
        transactions.push(Transaction({
            to: _to,
            erc_addr : address(0),
            value : _value,
            executed : false,
            numConfirmations : 0,
            data : _data 
        })
        );
        emit SubTransaction(msg.sender, _to, _value, transid);
    }

    function subERC20Transaction(address _to, address _erc_addr, uint _value, bytes memory _data) external onlyOwens {
        require(IERC20(_erc_addr).balanceOf(address(this)) >= _value, "not enough");
        uint transid = transactions.length;
        transactions.push(Transaction({
            to: _to,
            erc_addr : _erc_addr,
            value : _value,
            executed : false,
            numConfirmations : 0,
            data : _data 
        })
        );
        emit SubTransaction(msg.sender, _to, _value, transid);
    }

    // 签名确认该笔交易
    function confirmTransaction(uint _id) external onlyOwens existTransId(_id) notExecuted(_id) notConfirm(_id) {
       Transaction storage transaction = transactions[_id];
       transaction.numConfirmations += 1;
       isConfirmed[_id][msg.sender] = true;
       emit ConfirmTransaction(msg.sender, _id);
    }

    // 执行一笔交易
    function executeTransaction(uint _id) external onlyOwens existTransId(_id) notExecuted(_id) {
        Transaction storage transaction = transactions[_id];
        require(transaction.numConfirmations >= required, "< required");
        transaction.executed = true;
        if (address(transaction.erc_addr) == address(0)) {
            require(balanceOf() >= transaction.value, "not enough value");
            (bool sucess,) = transaction.to.call{value : transaction.value}(transaction.data);
            require(sucess, "tx fail"); 
        } else {
            require(IERC20(transaction.erc_addr).balanceOf(address(this)) >= transaction.value, "not enough erc token");
            bool sucess = IERC20(transaction.erc_addr).transfer(transaction.to, transaction.value); 
            require(sucess, "tx fail"); 
        }

        emit ExecuteTransaction(msg.sender, _id);
    } 

    // 取消授权

    function unconfirmTransaction(uint _id) external onlyOwens existTransId(_id) notExecuted(_id) {
        require(isConfirmed[_id][msg.sender], "not confirm");
        Transaction storage transaction = transactions[_id];
        transaction.numConfirmations -= 1;
        isConfirmed[_id][msg.sender] = false;

        emit UnconfirmTransaction(msg.sender, _id);
    }

    function balanceOf() public view returns(uint) {
        return address(this).balance;
    }

    function balanceOfERC20(address _erc20_addr) public view returns(uint) {
        return IERC20(_erc20_addr).balanceOf(address(this));
    }

    function deposit() public payable {
        return;
    }
}