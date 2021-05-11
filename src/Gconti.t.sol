pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Gconti.sol";

contract GcontiTest is DSTest {
    Gconti gconti;

    function setUp() public {
        gconti = new Gconti();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
