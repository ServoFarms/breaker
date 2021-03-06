// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import "ds-test/test.sol";

import "./Breaker.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external view returns (bytes32);
}

interface IERC20 {
  function totalSupply() external view returns (uint supply);
  function balanceOf( address who ) external view returns (uint value);
  function allowance( address owner, address spender ) external view returns (uint _allowance);

  function transfer( address to, uint value) external returns (bool ok);
  function transferFrom( address from, address to, uint value) external returns (bool ok);
  function approve( address spender, uint value ) external returns (bool ok);
}

contract BreakerBreaker {

    Breaker bkr;

    constructor(address _breaker) public {
        bkr = Breaker(_breaker);
    }

    function approve(address _token) public {
        IERC20(_token).approve(address(bkr), uint256(-1));
    }

    function breaker(uint256 _mkr) public returns (uint256 _bkr) {
        _bkr = bkr.breaker(_mkr);
    }

    function maker(uint256 _bkr) public returns (uint256 _mkr) {
        _mkr = bkr.maker(_bkr);
    }
}

contract BreakerTest is DSTest {
    Breaker breaker;

    Hevm hevm;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    address mkr;
    address bkr;

    uint256 constant WAD = 10 ** 18;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        breaker = new Breaker();
        bkr = address(breaker);
        mkr = address(breaker.MKR());

        hevm.store(
            address(breaker.MKR()),
            keccak256(abi.encode(address(this), uint256(1))),
            bytes32(uint256(999999999999 ether))
        );
    }

    function test_wrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(bal, 999999999999 * WAD);
        assertEq(breaker.balanceOf(address(this)), 0);

        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.breaker(10 * WAD);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 10 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 10 * WAD * 1000000000);
        assertEq(bbal, breaker.mkrToBkr(10 * WAD));
    }

    function test_wrap_one_conti() public {
        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.breaker(1);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 10 ** 9);
    }

    function test_wrap_one_mkr() public {
        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.breaker(1 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 1 * WAD * 10 ** 9);
    }

    function test_unwrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(breaker.balanceOf(address(this)), 0);
        assertEq(bal, 999999999999 * WAD);
        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.breaker(10000 * WAD);

        breaker.maker(9000 * WAD * 1000000000);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 1000 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 1000 * WAD * 1000000000);
        assertEq(bbal, breaker.mkrToBkr(1000 * WAD));
    }

    function test_unwrap_small() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(breaker.balanceOf(address(this)), 0);
        assertEq(bal, 999999999999 * WAD);
        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.breaker(10000 * WAD);

        breaker.maker(1337); // smol amt

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 10000 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 10000 * WAD * 1000000000);
        assertEq(bbal, breaker.mkrToBkr(10000 * WAD));
    }

    function test_user_interaction() public {
        BreakerBreaker user = new BreakerBreaker(address(breaker));
        breaker.MKR().transferFrom(address(this), address(user), 100 * WAD);
        assertEq(breaker.MKR().balanceOf(address(user)), 100 * WAD);

        user.approve(mkr);

        user.breaker(50 * WAD);
        assertEq(breaker.MKR().balanceOf(address(user)), 50 * WAD);
        assertEq(breaker.balanceOf(address(user)), 50 * WAD * 10**9);

        user.maker(25 * WAD * 10**9 + 123456);
        assertEq(breaker.MKR().balanceOf(address(user)), 75 * WAD);
        assertEq(breaker.balanceOf(address(user)), 25 * WAD * 10**9);

        user.breaker(75 * WAD);
        assertEq(breaker.MKR().balanceOf(address(user)), 0);
        assertEq(breaker.balanceOf(address(user)), 100 * WAD * 10**9);

        user.maker(100 * WAD * 10**9);
        assertEq(breaker.MKR().balanceOf(address(user)), 100 * WAD);
        assertEq(breaker.balanceOf(address(user)), 0);
    }
}
