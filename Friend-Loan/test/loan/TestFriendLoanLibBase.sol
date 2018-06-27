pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "../../contracts/FriendLoanLib.sol";
import "./utils/ThrowProxy.sol";
import "./LoanCreatorMock.sol";

contract TestFriendLoanLibBase { // Textmate bundle fix => }
	using FriendLoanLib for FriendLoanLib.Loan;
	using FriendLoanLib for FriendLoanLib.Data;

	FriendLoanLib.Data internal data;

	uint8 internal index = 1;

	function createLoan(
		uint256 _index,
		uint256 _amount,
    uint8 _maxInterestRate,
    uint8 _nbPayments,
    uint8 _paymentType
	)
		public
		returns(bool)
	{
		LoanCreatorMock thrower = new LoanCreatorMock();
		ThrowProxy throwProxy = new ThrowProxy(address(thrower)); //set Thrower as the contract to forward requests to. The target.

    // Act
    LoanCreatorMock(address(throwProxy)).createLoan(_index, _amount, _maxInterestRate, _nbPayments, _paymentType); //prime the proxy.
    // execute the call that is supposed to throw.
    // success will be false if it threw. success will be true if it didn't.
    // make sure you send enough gas for your contract method.
    bool success = throwProxy.execute.gas(200000)();
		return success;
	}
}