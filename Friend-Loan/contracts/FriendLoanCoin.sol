pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'openzeppelin-solidity/contracts/ownership/Whitelist.sol';
import './LoanBurnableToken.sol';
import "./FriendLoanLib.sol";

contract FriendLoanCoin is MintableToken, LoanBurnableCoin, Whitelist {	// Textmate bundle fix => }

  string public name = "Friend Loan Coin";
  string public symbol = "FLC";
  uint8 public decimals = 2;
	
	using FriendLoanLib for FriendLoanLib.Data;
	// our storage data
	FriendLoanLib.Data data;
	
  uint256 public counter = 0;
	
	event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint8 maxInterestRate, uint8 nbPayments, uint8 paymentType);
	event GuarantorAdded(uint256 indexed loanKey, address indexed guarantor, uint256 guarantee);
	event GuarantorRemoved(uint256 indexed loanKey, address indexed guarantor);
	event GuarantorReplaced(uint256 indexed loanKey, address indexed oldGuarantor, address indexed newGuarantor);
	event LoanStarted(uint256 indexed loanKey);
	event LenderAdded(uint256 indexed loanKey, address indexed lender, uint256 lend, uint8 interestRate);
	event LenderRemoved(uint256 indexed loanKey, address indexed lender);
	event LenderApproved(uint256 indexed loanKey, address indexed lender, uint256 lend, uint8 interestRate);
	event LenderDisapproved(uint256 indexed loanKey, address indexed lender, uint256 totalLendAmount, uint256 lendAmount);
	
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
	 * @dev gives the number of loans in contract
	 * @return the number of loans
	 */
	function loansCount() public view returns(uint256) {
		return data.loansCount;
	}
	

	/**
	 * @dev starts the loan
   * @param _loanKey The loan's key.
	 * @return true if the loan has started
	 */
	function startLoan(uint256 _loanKey) onlyWhitelisted public returns(bool) {
		data.startLoan(_loanKey);
		return true;
	}
	
	/**
	 * @dev checks if a specified guarantor is engaged by the loan
   * @param _loanKey The loan's key.
   * @param _guarantor The guarantor to check
	 * @return true if the guarantor is engaged
	 */
	function isGuarantorEngaged(
		uint256 _loanKey,
		address _guarantor
	)
		public
		view
		returns (bool)
	{
		return data.isGuarantorEngaged(_loanKey, _guarantor);
	}

	/**
	 * @dev gives the number of guarantors for a loan
   * @param _loanKey The loan's key.
	 * @return the number of guarantors
	 */
	function guarantorsCount(uint256 _loanKey) public view returns(uint256) {
		return data.guarantorsCount(_loanKey);
	}
	
	/**
	 * @dev adds a guarantor for a loan
   * @param _loanKey The loan's key.
   * @param _amount The guarantee's amount
	 * @return true if the guarantor has been added
	 */
	function appendGuarantor(
		uint256 _loanKey,
		uint256 _amount
	)
		onlyWhitelisted
		public
		returns (bool)
	{
		data.appendGuarantor(_loanKey, _amount);
		return true;
	}
	
	/**
	 * @dev removes a guarantor for a loan
   * @param _loanKey The loan's key.
	 * @return true if the guarantor has been removed
	 */
	function removeGuarantor(uint256 _loanKey) onlyWhitelisted public returns (bool) {
		data.removeGuarantor(_loanKey, msg.sender);
		return true;
	}
	
	/**
	 * @dev only owner - forces remove a guarantor for a loan
   * @param _loanKey The loan's key.
	 * @param _guarantor the guarantor to remove
	 * @return true if the guarantor has been removed
	 */
	function forceRemoveGuarantor(
		uint256 _loanKey,
		address _guarantor
	)
		onlyOwner
		public
		returns (bool)
	{
		data.removeGuarantor(_loanKey, _guarantor);
		return true;
	}
	
	/**
	 * @dev replaces a loan's guarantor
   * @param _loanKey The loan's key.
   * @param _oldGuarantor The guarantor to replace by
	 * @return true if the guarantor has been replaced
	 */
	function replaceGuarantor(
		uint256 _loanKey,
		address _oldGuarantor
	)
		onlyWhitelisted
		public
		returns (bool)
	{
		data.replaceGuarantor(_loanKey, _oldGuarantor, msg.sender);
		return true;
	}
	
	/**
	 * @dev adds a lender for a loan
   * @param _loanKey The loan's key.
   * @param _amount The lend's amount
   * @param _interestRate The interest's rate
	 * @return true if the lender has been added
	 */
	function appendLender(
		uint256 _loanKey,
		uint256 _amount,
		uint8 _interestRate
	)
		onlyWhitelisted
		public
		returns (bool)
	{
		data.appendLender(_loanKey, _amount, _interestRate);
		return true;
	}
	
	/**
	 * @dev removes a lender for the pending lenders list
   * @param _loanKey The loan's key.
	 * @return true if the lender has been removed
	 */
	function removeLender(uint256 _loanKey) public returns (bool) {
		data.removeLender(_loanKey);
		return true;
	}
	
	/**
	 * @dev gives the list of pending lenders for a loan
   * @param _loanKey The loan's key.
	 * @return the lenders addresses, amounts and interest rates
	 */
	function pendingLendersList(uint256 _loanKey) public view returns (address[], uint256[], uint8[]) {
		return formattedLendersList(data.pendingLendersList(_loanKey));
	}
	
	/**
	 * @dev format a lenders list
   * @param _lenders lenders list.
	 * @return the lenders addresses, amounts and interest rates
	 */
	function formattedLendersList(FriendLoanLib.Lender[] _lenders) private pure returns (address[], uint256[], uint8[]) {
		address[] memory _addresses = new address[](_lenders.length);
		uint256[] memory _amounts = new uint256[](_lenders.length);
		uint8[] memory _interestRates = new uint8[](_lenders.length);
		
		for(uint256 i = 0; i < _lenders.length; i++) {
			FriendLoanLib.Lender memory _lender = _lenders[i];
			_addresses[i] = _lender.lender;
			_amounts[i] = _lender.amount;
			_interestRates[i] = _lender.interestRate;
		}
		return (_addresses, _amounts, _interestRates);
	}
	
	
	/**
	 * @dev approves a lender from the pending lender list
   * @param _loanKey The loan's key.
   * @param _lenderAddress The lender's address.
	 * @return true if the lender has been approved and the lend's amount
	 */
	function approveLender(
		uint256 _loanKey,
		address _lenderAddress
	)
		onlyWhitelisted
		public
		returns (bool, uint256)
	{
		(bool _success, uint256 _lendAmount) = data.approveLender(_loanKey, _lenderAddress);
		return (_success, _lendAmount);
	}
	
	/**
	 * @dev removes an approved lender from the approved lender list
   * @param _loanKey The loan's key.
   * @param _lenderAddress The lender's address.
	 * @return true if the lender has been removed from the approved lender list and the lend's amount
	 */
	function removeApprovedLender(
		uint256 _loanKey,
		address _lenderAddress
	)
		onlyWhitelisted
		public
		returns (bool, uint256)
	{
		(bool _success, uint256 _lendAmount) = data.removeApprovedLender(_loanKey, _lenderAddress);
		return (_success, _lendAmount);
 	}
	
	/**
	 * @dev gives the list of approved lenders for a loan
   * @param _loanKey The loan's key.
	 * @return the list of approved lenders
	 */
	function approvedLendersList(uint256 _loanKey) public view returns (address[], uint256[], uint8[]) {
		return formattedLendersList(data.approvedLendersList(_loanKey));
	}
	
}