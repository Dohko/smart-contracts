pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

library FriendLoanLib {	
	
	using SafeMath for uint; // Textmate bundle fix => }
	
	struct Lender {
		address lender;
    uint256 totalLoanAmount;
    uint8 interestRate;
	}
	
	struct Guarantor {
		address guarantor;
    uint256 amount;
	}
	
	enum PaymentType {
		Day,
		Week,
		Month
	}
	
	struct Data {
	    Loan[] loans;
			uint8 maxNbPayments;
	}
	
	struct Loan {
		uint index;
		bool loanStarted;
	
		address borrower;
		uint256 totalAmount;
		uint8 maxInterestRate;
		uint8 nbPayments;
	
		PaymentType paymentType; 
	
		uint256 guaranteeAmount;
		mapping (address => Guarantor) guarantors;
		mapping (address => Lender) lenders;
	}
	
	event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint8 maxInterestRate, uint8 nbPayments, uint8 paymentType);
	
	/**
	 * @dev The Loan creator
   * @param self The storage data.
   * @param _key primary key - loan index.
   * @param _amount The amount to lend in ETH.
   * @param _maxInterestRate The maximum interest charged by the borrower.
   * @param _nbPayments The number of loan payments.
   * @param _paymentType Type of payment (daily, weekly, monthly).
	 * @return true if the loan was added to the storage loans list, false if the loan wasn't added
	 */
	function createLoan(
		Data storage self,
		uint256 _key,
		uint256 _amount,
		uint8 _maxInterestRate,
		uint8 _nbPayments,
		uint8 _paymentType
	)
		internal
		returns(Loan)
	{
		// 1. Conditions
		require(_amount > 0);
		require(_nbPayments > 0);
		require(self.maxNbPayments > _nbPayments);
		require(uint(PaymentType.Month) >= _paymentType);

		// 2. Effects
		Loan memory loan = Loan({
			loanStarted: false,
			index: _key,
			borrower: msg.sender,
			totalAmount: _amount,
			maxInterestRate: _maxInterestRate,
			nbPayments: _nbPayments,
			paymentType: FriendLoanLib.PaymentType(_paymentType),
			guaranteeAmount: 0
		});
		self.loans.push(loan);
		emit LoanCreated(loan.index, loan.borrower, loan.totalAmount, loan.maxInterestRate, loan.nbPayments, uint8(loan.paymentType));

		// 3. Interaction
		return loan;
	}
	
	/**
	 * @dev updates the max number of payments
   * @param self The storage data.
   * @param _maxNbPayments The new max number of loan payments.
	 * @return true if the max number of payment has been updated
	 */
	function setMaxNbPayments (
		Data storage self,
		uint8 _maxNbPayments
	)
		public
		returns (bool)
	{
		self.maxNbPayments = _maxNbPayments;
		return true;
	}
	
	
}