pragma solidity ^0.4.24;

contract FriendLoan {	// Textmate bundle fix => }

	address public borrower;
	uint256 public amount;
	uint8 public maxInterestRate;
	uint8 public nbPayments;
	
	enum PaymentType {DAY, WEEK, MONTH}
	PaymentType public paymentType; 


	/**
	 * @dev The Loan constructor
   * @param _amount The amount to lend in ETH.
   * @param _maxInterestRate The maximum interest charged by the borrower.
   * @param _nbPayments The number of loan payments.
   * @param _paymentType Type of payment (daily, weekly, monthly).
	 */
	constructor(
		uint256 _amount,
		uint8 _maxInterestRate,
		uint8 _nbPayments,
		uint8 _paymentType
	)
		public
	{
		require(uint(PaymentType.MONTH) >= _paymentType);
		borrower = msg.sender;
		amount = _amount;
		maxInterestRate = _maxInterestRate;
		nbPayments = _nbPayments;
		paymentType = PaymentType(_paymentType);
	}

}