// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico
// Copyright (C) 2021 Dai Foundation
// Copyright (C) 2021 Servo Farms, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.12;

interface MKRToken {
  function totalSupply() external view returns (uint supply);
  function balanceOf( address who ) external view returns (uint value);
  function allowance( address owner, address spender ) external view returns (uint _allowance);

  function transfer( address to, uint value) external returns (bool ok);
  function transferFrom( address from, address to, uint value) external returns (bool ok);
  function approve( address spender, uint value ) external returns (bool ok);
}

contract Breaker {

  // --- Auth ---
  mapping (address => uint256) public wards;
  function rely(address usr) external auth {
    wards[usr] = 1;
    emit Rely(usr);
  }
  function deny(address usr) external auth {
    wards[usr] = 0;
    emit Deny(usr);
  }
  modifier auth {
    require(wards[msg.sender] == 1, "Breaker/not-authorized");
    _;
  }

  // --- ERC20 Data ---
  string   public constant name     = "Breaker Token";
  string   public constant symbol   = "BKR";
  string   public constant version  = "1";
  uint8    public constant decimals = 18;
  MKRToken public constant MKR      = MKRToken(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
  uint256  public totalSupply;

  mapping (address => uint256)                      public balanceOf;
  mapping (address => mapping (address => uint256)) public allowance;
  mapping (address => uint256)                      public nonces;

  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Rely(address indexed usr);
  event Deny(address indexed usr);

  // --- Math ---
  function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x);
  }
  function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x);
  }
  function mul(uint x, uint y) internal pure returns (uint z) {
    require(y == 0 || (z = x * y) / y == x);
  }
  function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = add(x, sub(y, 1)) / y;
  }

  // --- EIP712 niceties ---
  uint256 public  immutable deploymentChainId;
  bytes32 private immutable _DOMAIN_SEPARATOR;
  bytes32 public  constant  PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  constructor() public {
    wards[msg.sender] = 1;
    emit Rely(msg.sender);

    uint256 chainId;
    assembly {chainId := chainid()}
    deploymentChainId = chainId;
    _DOMAIN_SEPARATOR = _calculateDomainSeparator(chainId);
  }

  function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes(version)),
        chainId,
        address(this)
      )
    );
  }
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    uint256 chainId;
    assembly {chainId := chainid()}
    return chainId == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId);
  }

  // --- ERC20 Mutations ---
  function transfer(address to, uint256 value) external returns (bool) {
    require(to != address(0) && to != address(this), "Breaker/invalid-address");
    uint256 balance = balanceOf[msg.sender];
    require(balance >= value, "Breaker/insufficient-balance");

    balanceOf[msg.sender] = balance - value;
    balanceOf[to] += value;

    emit Transfer(msg.sender, to, value);

    return true;
  }
  function transferFrom(address from, address to, uint256 value) external returns (bool) {
    require(to != address(0) && to != address(this), "Breaker/invalid-address");
    uint256 balance = balanceOf[from];
    require(balance >= value, "Breaker/insufficient-balance");

    if (from != msg.sender) {
      uint256 allowed = allowance[from][msg.sender];
      if (allowed != type(uint256).max) {
        require(allowed >= value, "Breaker/insufficient-allowance");

        allowance[from][msg.sender] = allowed - value;
      }
    }

    balanceOf[from] = balance - value;
    balanceOf[to] += value;

    emit Transfer(from, to, value);

    return true;
  }
  function approve(address spender, uint256 value) external returns (bool) {
    allowance[msg.sender][spender] = value;

    emit Approval(msg.sender, spender, value);

    return true;
  }
  function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
    uint256 newValue = add(allowance[msg.sender][spender], addedValue);
    allowance[msg.sender][spender] = newValue;

    emit Approval(msg.sender, spender, newValue);

    return true;
  }
  function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
    uint256 allowed = allowance[msg.sender][spender];
    require(allowed >= subtractedValue, "Breaker/insufficient-allowance");
    allowed = allowed - subtractedValue;
    allowance[msg.sender][spender] = allowed;

    emit Approval(msg.sender, spender, allowed);

    return true;
  }

  // --- Mint/Burn ---
  function _mint(address to, uint256 value) internal {
    require(to != address(0) && to != address(this), "Breaker/invalid-address");
    balanceOf[to] = add(balanceOf[to], value);
    totalSupply   = add(totalSupply, value);

    emit Transfer(address(0), to, value);
  }
  function _burn(address from, uint256 value) internal {
    uint256 balance = balanceOf[from];
    require(balance >= value, "Breaker/insufficient-balance");

    if (from != msg.sender) {
      uint256 allowed = allowance[from][msg.sender];
      if (allowed != type(uint256).max) {
        require(allowed >= value, "Breaker/insufficient-allowance");

        allowance[from][msg.sender] = allowed - value;
      }
    }

    balanceOf[from] = balance - value;
    totalSupply     = sub(totalSupply, value);

    emit Transfer(from, address(0), value);
  }

  // --- Approve by signature ---
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(block.timestamp <= deadline, "Breaker/permit-expired");

    uint256 chainId;
    assembly {chainId := chainid()}

    bytes32 digest =
      keccak256(abi.encodePacked(
          "\x19\x01",
          chainId == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId),
          keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonces[owner]++,
            deadline
          ))
      ));

    require(owner != address(0) && owner == ecrecover(digest, v, r, s), "Breaker/invalid-permit");

    allowance[owner][spender] = value;
    emit Approval(owner, spender, value);
  }

  function mkrToBkr(uint256 mkr) public pure returns (uint256 bkr) {
    return mul(mkr, 1000000000);
  }

  function bkrToMkr(uint256 bkr) public pure returns (uint256 mkr) {
    return divup(bkr, 1000000000);
  }

  /**
  * @dev break Maker and make Breaker
  * @param to   address to send Breaker tokens
  * @param mkr  amount of MKR tokens to be wrapped
  */
  function makeBreaker(address to, uint256 mkr) public returns (uint256 bkr) {
    MKR.transferFrom(
        msg.sender,
        address(this),
        mkr
    );
    bkr = mkrToBkr(mkr);
    _mint(to, bkr);
  }

  /**
  * @dev break Breaker and make Maker
  * @param to   address to send Maker tokens
  * @param bkr  amount of tokens to be unwrapped
  */
  function makeMaker(address to, uint256 bkr) public returns (uint256 mkr) {
    mkr = bkrToMkr(bkr);
    bkr = mkrToBkr(mkr);

    if (msg.sender != to) {
        allowance[msg.sender][to] = sub(allowance[to][msg.sender], bkr);
        emit Approval(msg.sender, to, bkr);
    }

    _burn(to, bkr);

    MKR.transferFrom(
        address(this),
        to,
        mkr
    );
  }
}