pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'openzeppelin-solidity/contracts/ownership/Whitelist.sol';
import './LoanBurnableToken.sol';
import "./FriendLoanLib.sol";

contract FriendLoanCoin is MintableToken, LoanBurnableCoin, Whitelist {	// Textmate bundle fix => }

  string public name = "Friend Loan Coin";
  string public symbol = "FLC";
  uint8 public decimals = 2;
	
	using FriendLoanLib for FriendLoanLib.Loan;
	using FriendLoanLib for FriendLoanLib.Data;
	// our storage data
	FriendLoanLib.Data data;
	
  uint256 public counter = 0;
	
	event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint8 maxInterestRate, uint8 nbPayments, uint8 paymentType);
	
	/**
	 * @dev The Loan creator
   * @param _amount The amount to lend in ETH.
   * @param _maxInterestRate The maximum interest charged by the borrower.
   * @param _nbPayments The number of loan payments.
   * @param _paymentType Type of payment (daily, weekly, monthly).
	 * @return true if the loan was added to the storage loans list, false if the loan wasn't added
	 */
	function createLoan (
		uint256 _amount,
		uint8 _maxInterestRate,
		uint8 _nbPayments,
		uint8 _paymentType
	)
		onlyWhitelisted
		public
		returns (bool)
	{		
		counter++;
		data.createLoan(counter, _amount, _maxInterestRate, _nbPayments, _paymentType);
		return true;
	}
	
	/**
	 * @dev update the max number of payments
   * @param _maxNbPayments The new max number of loan payments.
	 * @return true if the max number of payment has been updated
	 */
	function setMaxNbPayments(uint8 _maxNbPayments) onlyOwner public returns (bool) {
		data.setMaxNbPayments(_maxNbPayments);
		return true;
	}

	/**
	 * @dev get the max number of payments
	 * @return the max number of payments
	 */
	function maxNbPayments() public view returns (uint8) {
		return data.maxNbPayments;
	}
	
	/**
	 * @dev get the number of loans in contract
	 * @return the number of loans
	 */
	function loansCount() public view returns(uint256) {
		return data.loans.length;
	}
	
}