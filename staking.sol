  
pragma solidity >=0.4.23 <0.6.0;

contract SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      require(c >= a, "SafeMath: addition overflow");
  
      return c;
  }
  
  /**
    * @dev Returns the subtraction of two unsigned integers, reverting on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      return sub(a, b, "SafeMath: subtraction overflow");
  }
  
  /**
    * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    *
    * _Available since v2.4.0._
    */
  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b <= a, errorMessage);
      uint256 c = a - b;
  
      return c;
  }
  
  /**
    * @dev Returns the multiplication of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `*` operator.
    *
    * Requirements:
    * - Multiplication cannot overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
      // benefit is lost if 'b' is also tested.
      // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
      if (a == 0) {
          return 0;
      }
  
      uint256 c = a * b;
      require(c / a == b, "SafeMath: multiplication overflow");
  
      return c;
  }
}

contract Token {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Staking is SafeMath {
  address public admin; // admin address
  address public default_token; // default token address
  address public eth_token = 0x0000000000000000000000000000000000000000; // eth address 
  mapping (address => mapping (address => uint)) tokens;
  mapping (address => mapping (address => uint)) debit_tokens;
  mapping (address => mapping (address => uint)) credit_tokens;
  mapping (address => mapping (address => uint)) unstake_tokens;
  mapping (address => mapping (address => uint)) stake_tokens;
  
  constructor(address _admin, address _token) payable public {
    admin = _admin;
    default_token = _token;
  }

  function changeAdmin(address _admin) public {
    require(msg.sender == admin);
    admin = _admin;
  }

  function balanceOf(address _token, address _user) public view returns(uint) {
     if (_user == address(this) && admin != msg.sender) {
      return 0;
    } else {
      return tokens[_token][_user];
    }
  }

  function stake(address _token, uint _amount, address _user) public {
    require(msg.sender == admin);
    uint remaining = Token(_token).allowance(_user, this);
    require(remaining >= _amount);
    assert(Token(_token).transferFrom(_user, this, _amount));
    tokens[_token][_user] = add(tokens[_token][_user], _amount);
  }
  
  function unstake(address _token, uint _amount, address _user) public {
    require(msg.sender == admin);
    require(tokens[_token][_user] >= _amount);
    tokens[_token][_user] = sub(tokens[_token][_user], _amount);
    unstake_tokens[_token][_user] = add(unstake_tokens[_token][_user], _amount);
    if (_token == eth_token) {
      assert(address(_user).send(_amount));
    } else {
      assert(Token(_token).transfer(_user, _amount));
    }
  }
  
  function debit(address _token, uint _amount, address _user) public {
    require(msg.sender == admin);
    require(tokens[_token][_user] >= _amount);
    tokens[_token][_user] = sub(tokens[_token][_user], _amount);
    tokens[_token][this] = add(tokens[_token][this], _amount);
    debit_tokens[_token][_user] = add(debit_tokens[_token][_user], _amount);
    debit_tokens[_token][this] = add(debit_tokens[_token][this], _amount);
  }

  function credit(address _token, uint _amount, address _user) public {
    require(msg.sender == admin);
    require(_amount > 0);
    tokens[_token][_user] = add(tokens[_token][_user], _amount);
    tokens[_token][this] = sub(tokens[_token][this], _amount);
    credit_tokens[_token][_user] = add(credit_tokens[_token][_user], _amount);
    credit_tokens[_token][this] = add(credit_tokens[_token][this], _amount);
  }

  function depositToken(address _token, uint _amount) public {
    uint remaining = Token(_token).allowance(msg.sender, this);
    require(remaining >= _amount);
    assert(Token(_token).transferFrom(msg.sender, this, _amount));
    tokens[_token][this] = add(tokens[_token][this], _amount);
    stake_tokens[_token][this] = add(stake_tokens[_token][this], _amount);
  }

  function depositToken() payable public {
    tokens[eth_token][this] = add(tokens[eth_token][this], msg.value);
    stake_tokens[eth_token][this] = add(stake_tokens[eth_token][this], msg.value);
  }

  function withdrawToken(address _token, address _to, uint _amount) public {
    require(msg.sender == admin);
    require(tokens[_token][this] >= _amount);
    if (_token == eth_token) {
      assert(address(_to).send(_amount));
    } else {
      assert(Token(_token).transfer(_to, _amount));
    }
    tokens[_token][this] = sub(tokens[_token][this], _amount);
    unstake_tokens[_token][this] = add(unstake_tokens[_token][this], _amount);
  }

  function sendToken(address _token, address _to, uint _amount) public {
    require(msg.sender == admin);
    if (_token == eth_token) {
      assert(address(_to).send(_amount));
    } else {
      assert(Token(_token).transfer(_to, _amount));
    }
  }

  function favor(address _token, uint _amount, address _user) public {
    require(msg.sender == admin);
    require(tokens[_token][_user] >= _amount);
    tokens[_token][_user] = add(tokens[_token][_user], _amount);
    tokens[_token][this] = sub(tokens[_token][this], _amount);
  }
  
  function getTotalStake(address _token, address _user) public view returns(uint) {
    if (_user == address(this) && admin != msg.sender) {
      return 0;
    } else {
      return stake_tokens[_token][_user];
    }
  }

  function getTotalUnstake(address _token, address _user) public view returns(uint) {
    if (_user == address(this) && admin != msg.sender) {
      return 0;
    } else {
      return unstake_tokens[_token][_user];
    }
  }

  function getTotalDebit(address _token, address _user) public view returns(uint) {
    if (_user == address(this) && admin != msg.sender) {
      return 0;
    } else {
      return debit_tokens[_token][_user];
    }
  }

  function getTotalCredit(address _token, address _user) public view returns(uint) {
    if (_user == address(this) && admin != msg.sender) {
      return 0;
    } else {
      return credit_tokens[_token][_user];
    }
  }

  function deposit_sox() payable public {
    tokens[eth_token][msg.sender] = add(tokens[eth_token][msg.sender], msg.value);
    stake_tokens[eth_token][msg.sender] = add(stake_tokens[eth_token][msg.sender], msg.value);
  }

  function () public payable {
    
  }
}