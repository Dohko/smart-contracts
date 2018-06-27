pragma solidity ^0.4.24;

import "../../contracts/FriendLoanLib.sol";

contract LoanCreatorMock { // Textmate bundle fix => }
	using FriendLoanLib for FriendLoanLib.Loan;
	using FriendLoanLib for FriendLoanLib.Data;

	FriendLoanLib.Data private data;

  function createLoan(
		uint256 _index,
		uint256 _amount,
    uint8 _maxInterestRate,
    uint8 _nbPayments,
    uint8 _paymentType
	)
		public
	{
		data.createLoan(_index, _amount, _maxInterestRate, _nbPayments, _paymentType);
  }

}
