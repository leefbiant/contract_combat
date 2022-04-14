
// SPDX-License-Identifier: MIT   
pragma solidity ^0.8.0;
// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
//
// ----------------------------------------------------------------------------
interface ERC20Interface {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external pure returns (uint8);
  function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);
  function approveOrigin(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);
  function PERMIT_TYPEHASH() external pure returns (bytes32);
  function nonces(address owner) external view returns (uint);

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

}

// ----------------------------------------------------------------------------
// Safe Math Library
// ----------------------------------------------------------------------------

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


contract BaseCoin is ERC20Interface {
    ///////////////////////

    using SafeMath for uint;

    string public name ;
    string public symbol ;
    uint8 public constant decimals = 18;
    uint public constant max_uint = 2**256 - 1;
    uint  public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    event ApprovalBase(address indexed owner, address indexed spender, uint value);
    event TransferBase(address indexed from, address indexed to, uint value);
    event Permit(address indexed from, address indexed to, uint value);

    constructor()  {
        name = "BaseCoin token";
        symbol = "BaseCoin";
        uint _totalSupply = 100000000 * 10**19;


        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
        _mint(msg.sender, _totalSupply);
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) internal virtual {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) internal virtual {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function approveOrigin(address spender, uint value) external virtual returns (bool) {
         _approve(tx.origin, spender, value);
        return true;
    }

    function transfer(address to, uint value) external virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external virtual returns (bool) {
        if (allowance[from][msg.sender] != max_uint) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNATURE');
        emit Permit(owner, spender, value);
        _approve(owner, spender, value);
    } 
}


contract Coin is  BaseCoin {
    uint8 public burn_rate; // 燃烧率
    uint8 public trade_rate; // 交易费率

    address owner;
    using SafeMath for uint;

    uint constant unit = 10**19; 
    constructor(string memory _name, string memory _symbol, uint _supply, uint8 _burn_rate, uint8 _trade_rate) {
        require(_supply > 0, "err supply");
        require(_burn_rate < 30, "err _burn_rate");
        require(_trade_rate < 30, "err _trade_rate");
        name = _name;
        symbol = _symbol;
        totalSupply = _supply * unit;
        burn_rate = _burn_rate;
        trade_rate = _trade_rate;

        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
        balanceOf[tx.origin] = totalSupply;
        owner = tx.origin;
        emit Transfer(address(0), tx.origin, totalSupply);
    }

   function approveOrigin(address spender, uint tokens) external override returns (bool) {
        uint burn_token = burnToken(tokens); 
        uint fee_token = FeeToken(tokens);  
        uint real_token = tokens.add(burn_token.add(fee_token));
        _approve(tx.origin, spender, real_token);
        return true;
   }
   function transferFrom(address from, address to, uint tokens) external override returns (bool) {
        uint burn_token = burnToken(tokens); 
        uint fee_token = FeeToken(tokens);  
        uint real_token = tokens.add(burn_token.add(fee_token));

        if (allowance[from][msg.sender] != max_uint) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(real_token);
        }
        require(balanceOf[from] >= real_token, "not enough");

        _transfer(from, to, tokens);
        if (burn_token > 0) _transfer(from, address(0), burn_token);
        if (fee_token > 0) _transfer(from, owner, fee_token);

        return true;
    }

    function transfer(address to, uint tokens) public override returns (bool success) {

        if (to == owner) {
            _transfer(msg.sender, to, tokens);
            return true; 
        }

        uint burn_token = burnToken(tokens); 
        uint fee_token = FeeToken(tokens); 
        uint real_token = tokens.add(burn_token.add(fee_token));
        require(balanceOf[msg.sender] >= real_token, "not enough");

        _transfer(msg.sender, to, tokens);
        if (burn_token > 0) _transfer(msg.sender, address(0), burn_token);
        if (fee_token > 0) _transfer(msg.sender, owner, fee_token);
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