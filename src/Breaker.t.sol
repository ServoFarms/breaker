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

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }

    function test_wrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(bal, 999999999999 * WAD);

        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.makeBreaker(address(this), 10 * WAD);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 10 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 10 * WAD * 1000000000);
        assertEq(bbal, breaker.mkrToBkr(10 * WAD));
    }

    function test_unwrap() public {
        uint256 bal = IERC20(mkr).balanceOf(address(this));
        assertEq(bal, 999999999999 * WAD);
        breaker.MKR().approve(address(breaker), uint256(-1));
        breaker.makeBreaker(address(this), 10000 * WAD);

        breaker.makeMaker(address(this), 9000 * WAD * 1000000000);

        uint256 aft = IERC20(mkr).balanceOf(address(this));
        assertEq(aft, bal - 1000 * WAD);

        uint256 bbal = breaker.balanceOf(address(this));
        assertEq(bbal, 1000 * WAD * 1000000000);
        assertEq(bbal, breaker.mkrToBkr(1000 * WAD));
    }


}