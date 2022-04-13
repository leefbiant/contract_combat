
// SPDX-License-Identifier: MIT   
pragma solidity >=0.4.22 <0.9.0;
// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
//
// ----------------------------------------------------------------------------
interface ERC20Interface {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// Safe Math Library
// ----------------------------------------------------------------------------
contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a); 
        c = a - b; 
    } 
    function safeMul(uint a, uint b) public pure returns (uint c) { 
        c = a * b; 
        require(a == 0 || c / a == b);
    } 
    
    function safeDiv(uint a, uint b) public pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


contract BaseCoin is ERC20Interface, SafeMath {
    string public name;
    string public symbol;
    uint8 public decimals; // 18 decimals is the strongly suggested default, avoid changing it

    uint256 public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor()  {
        name = "BaseCoin token";
        symbol = "BaseCoin";
        decimals = 18;
        _totalSupply = 100000000 * 10**19;

        balances[tx.origin] = _totalSupply;
        emit Transfer(address(0), tx.origin, _totalSupply);
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[tx.origin][spender] = tokens;
        emit Approval(tx.origin, spender, tokens);
        return true;
    }

    function transfer(address to, uint tokens) public virtual returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public virtual returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][to] = safeSub(allowed[from][to], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function addr() public view  returns (address){
        return address(this);
    }
}


contract Coin is  BaseCoin {
    uint8 public burn_rate; // 燃烧率
    uint8 public trade_rate; // 交易费率

    address owner;

    uint constant unit = 10**19; 
    constructor(string memory _name, string memory _symbol, uint _supply, uint8 _burn_rate, uint8 _trade_rate) {
        require(_supply > 0, "err supply");
        require(_burn_rate < 30, "err _burn_rate");
        require(_trade_rate < 30, "err _trade_rate");
        name = _name;
        symbol = _symbol;
        decimals = 18;
        _totalSupply = _supply * unit;
        burn_rate = _burn_rate;
        trade_rate = _trade_rate;

        balances[tx.origin] = _totalSupply;
        owner = tx.origin;
        emit Transfer(address(0), tx.origin, _totalSupply);
    }

    function transfer(address to, uint tokens) public override returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);

        uint burn_token = burnToken(tokens); 
        uint fee_token = FeeToken(tokens); 
        uint real_token = safeSub(tokens, safeAdd(burn_token, fee_token));

        balances[to] = safeAdd(balances[to], real_token);
        emit Transfer(msg.sender, to, real_token);

        balances[owner] = safeAdd(balances[owner], fee_token);
        emit Transfer(msg.sender, owner, fee_token);
        
        emit Transfer(address(0), address(0), burn_token);

        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][to] = safeSub(allowed[from][to], tokens);

        uint burn_token = burnToken(tokens); 
        uint fee_token = FeeToken(tokens); 
        uint real_token = safeSub(tokens, safeAdd(burn_token, fee_token));

        balances[to] = safeAdd(balances[to], real_token);
        emit Transfer(from, to, tokens);

        balances[owner] = safeAdd(balances[owner], fee_token);
        emit Transfer(msg.sender, owner, fee_token);
        
        emit Transfer(address(0), address(0), burn_token);

        return true;
    }

    function burnToken(uint tokens) private view returns(uint) {
        if (burn_rate > 0)  {
           return (tokens / 1000 * burn_rate);
        }
        return 0;
    }  

    function FeeToken(uint tokens) private view returns(uint) {
        if (trade_rate > 0)  {
           return (tokens / 1000 * trade_rate);
        }
        return 0;
    } 
}


contract CoinFactory {
    struct CoinInfo {
        string name;
        uint supply; 
        uint8 burn_rate; 
        uint8 trade_rate; 
        address c;
        bool enable;
    }
    mapping (address => mapping(string => CoinInfo)) coin_map;

    function createCoin(string memory _name, string memory _symbol, uint _supply, uint8 _burn_rate, uint8 _trade_rate) public returns (bool) {
        Coin c = new Coin(_name, _symbol, _supply, _burn_rate, _trade_rate);  
        CoinInfo memory coin = CoinInfo(_name, _supply, _burn_rate, _trade_rate, address(c), true);
        coin_map[tx.origin][_symbol] = coin;
        return true;
    }

    function getCoin(string memory symbol) public view returns (string memory, uint, uint8, uint8, address) {
        require(coin_map[msg.sender][symbol].enable == true, "not exist");
        return (coin_map[msg.sender][symbol].name, coin_map[msg.sender][symbol].supply, coin_map[msg.sender][symbol].burn_rate, coin_map[msg.sender][symbol].trade_rate, coin_map[msg.sender][symbol].c);
    }

    function getCoinByaddr(address user, string memory symbol) public view returns (string memory, uint, uint8, uint8, address) {
        require(coin_map[msg.sender][symbol].enable == true, "not exist");
        return (coin_map[user][symbol].name, coin_map[msg.sender][symbol].supply, coin_map[msg.sender][symbol].burn_rate, coin_map[msg.sender][symbol].trade_rate, coin_map[msg.sender][symbol].c);
    }
}