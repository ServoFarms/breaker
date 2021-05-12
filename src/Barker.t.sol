// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import "ds-test/test.sol";

import "./Barker.sol";

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

contract BarkerTest is DSTest {
    Barker barker;

    Hevm hevm;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    address mkr;
    address bkr;

    uint256 constant WAD = 10 ** 18;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        barker = new Barker();
        bkr = address(barker);
        mkr = address(barker.MKR());

        hevm.store(
            address(barker.MKR()),
            keccak256(abi.encode(address(this), uint256(1))),
            bytes32(uint256(999999999999 ether))
        );
    }

    function test_wrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(bal, 999999999999 * WAD);
        assertEq(barker.balanceOf(address(this)), 0);

        barker.MKR().approve(address(barker), uint256(-1));
        barker.barker(address(this), 10 * WAD);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 10 * WAD);

        uint256 bbal = barker.balanceOf(address(this));
        assertEq(bbal, 10 * WAD * 1000000000);
        assertEq(bbal, barker.mkrToBkr(10 * WAD));
    }

    function test_wrap_one_conti() public {
        barker.MKR().approve(address(barker), uint256(-1));
        barker.barker(address(this), 1);

        uint256 bbal = barker.balanceOf(address(this));
        assertEq(bbal, 10 ** 9);
    }

    function test_wrap_one_mkr() public {
        barker.MKR().approve(address(barker), uint256(-1));
        barker.barker(address(this), 1 * WAD);

        uint256 bbal = barker.balanceOf(address(this));
        assertEq(bbal, 1 * WAD * 10 ** 9);
    }

    function test_unwrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(barker.balanceOf(address(this)), 0);
        assertEq(bal, 999999999999 * WAD);
        barker.MKR().approve(address(barker), uint256(-1));
        barker.barker(address(this), 10000 * WAD);

        barker.maker(address(this), 9000 * WAD * 1000000000);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 1000 * WAD);

        uint256 bbal = barker.balanceOf(address(this));
        assertEq(bbal, 1000 * WAD * 1000000000);
        assertEq(bbal, barker.mkrToBkr(1000 * WAD));
    }

    function test_unwrap_small() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(barker.balanceOf(address(this)), 0);
        assertEq(bal, 999999999999 * WAD);
        barker.MKR().approve(address(barker), uint256(-1));
        barker.barker(address(this), 10000 * WAD);

        barker.maker(address(this), 1337); // smol amt

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 10000 * WAD);

        uint256 bbal = barker.balanceOf(address(this));
        assertEq(bbal, 10000 * WAD * 1000000000);
        assertEq(bbal, barker.mkrToBkr(10000 * WAD));
    }
}
