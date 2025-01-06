// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    uint256 constant SEND_VALUE = 0.1 ether; // 100000000000000000
    uint256 constant STARTING_BALANCE = 10 ether; // 100000000000000000
    uint256 constant GAS_PRICE = 1;
    address USER = makeAddr("user");

    // This is run before any other function in the contract.
    // setUp is called everytime before any other function
    // say you want to run testMinDollarIsFive and testOwnerIsMsgSender, setUp runs once before testMinDollar, and once before testOwner.
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinDollarIsFive() public view {
        console.log(fundMe.MINIMUM_USD());
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        console.log(fundMe.getOwnerAddress()); // This is the address of the contract deployer for FundMe i.e FundMeTest()
        console.log(msg.sender); // This is our address
        console.log(address(this)); // This is the address of this contract.
        assertEq(fundMe.getOwnerAddress(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        console.log(version);
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // Next line should revert only if it fails.
        fundMe.fund(); // Send 0 Eth (OFC this would fail because its not up to $5)
    }

    function testFundUpdatesFUndedDataStructure() public {
        vm.prank(USER); // The next tx will be sent by this address
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFUnded = fundMe.getaddressToAmountFunded(USER);
        assertEq(amountFUnded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunders(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // USER is not the owner
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawFromSingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Action
        uint256 gasStart = gasleft(); // 1000

        vm.txGasPrice(GAS_PRICE); // Sets a gas price for subsequent tx in this function.
        vm.prank(fundMe.getOwnerAddress()); // 200
        fundMe.withdraw();

        uint256 gasEnd = gasleft(); // 800
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // Equivalent to uint256 gasUsed = (gasStart - gasEnd) * GAS_PRICE;
        console.log(gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }

    function testWithDrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), STARTING_BALANCE); // Hoaxing does both prank and deal - Sending the next tx from this address and giving it a starting balance.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Action
        vm.startPrank(fundMe.getOwnerAddress());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }

    function testWithDrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), STARTING_BALANCE); // Hoaxing does both prank and deal - Sending the next tx from this address and giving it a starting balance.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Action
        vm.startPrank(fundMe.getOwnerAddress());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }
}
