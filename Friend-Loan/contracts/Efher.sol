pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/ownership/Whitelist.sol';
import "./EfherLib.sol";

contract Efher is Whitelist {	// Textmate bundle fix => }

	// The emergency mode
	bool emergency;
	
	using SafeMath for uint;
	using EfherLib for EfherLib.Data;
	// our storage data
	EfherLib.Data private data;
	
	mapping(address => uint) refunds;
	
  uint256 private counter = 0;

	// It contains users performing an action (withdrawal, add a guarantee..).
	// The user is blocked the time of the action then unlock at the end.
	mapping (address => bool) locked;
	
	event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint256 maxInterestRate, uint8 nbPayments, uint8 paymentType);
	event GuarantorAdded(uint256 indexed loanKey, address indexed guarantor, uint256 guarantee);
	event GuarantorRemoved(uint256 indexed loanKey, address indexed guarantor);
	event GuarantorReplaced(uint256 indexed loanKey, address indexed oldGuarantor, address indexed newGuarantor);
	event LoanStarted(uint256 indexed loanKey);
	event LenderAdded(uint256 indexed loanKey, address indexed lender, uint256 lend, uint256 interestRate);
	event LenderRemoved(uint256 indexed loanKey, address indexed lender);
	event LenderApproved(uint256 indexed loanKey, address indexed lender, uint256 lend, uint256 interestRate);
	event LenderDisapproved(uint256 indexed loanKey, address indexed lender, uint256 totalLendAmount, uint256 lendAmount);
	
  /**
   * @dev Throws if we are in the emergency mode.
   */
  modifier notOnEmergencyMode() {
    require(emergency == false);
    _;
  }
	
  /**
   * @dev Throws if called by an locker account.
   */
  modifier exceptLocked() {
    require(locked[msg.sender] == false);
    _;
  }
	
	/**
	 * @dev Returns the contract balance
	 * @return the contract balance
	 */
  function getBalance() public view returns (uint256) {
      return address(this).balance;
  }
	
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
		uint256 _maxInterestRate,
		uint8 _nbPayments,
		uint8 _paymentType
	)
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		public
		returns (bool)
	{
		locked[msg.sender] = true;
		counter = counter.add(1);
		data.createLoan(counter, _amount, _maxInterestRate, _nbPayments, _paymentType);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev withdraw a sender address
	 * @return true if the sender has been refunded
	 */
	function withdrawBalance() notOnEmergencyMode exceptLocked public returns (bool) {
		require(refunds[msg.sender] > 0);
		locked[msg.sender] = true;
    uint amountToWithdraw = refunds[msg.sender];
    refunds[msg.sender] = 0;
		msg.sender.transfer(amountToWithdraw);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev Custody of borrower money on deposit
   * @param _loanKey The loan's key.
   * @param _amount The deposit amount.
	 * @return true if the money was deposited
	 */
	function depositFromBorrower(
		uint256 _loanKey,
		uint256 _amount
	)
		notOnEmergencyMode
		exceptLocked
		payable
		public
		returns (bool) {
		require(msg.value == _amount);
		locked[msg.sender] = true;
		data.depositFromBorrower(_loanKey, _amount);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev Returns the current borrower deposit and loan underfund 
   * @param _loanKey The loan's key.
	 * @return current borrower deposit and loan underfund
	 */
	function borrowerDepositAndUnderfund(uint256 _loanKey) public view returns (uint256, uint256) {
		return data.borrowerDepositAndUnderfund(_loanKey);
	}
	
	/**
	 * @dev update the max number of payments
   * @param _maxNbPayments The new max number of loan payments.
	 * @return true if the max number of payment has been updated
	 */
	function setMaxNbPayments(uint8 _maxNbPayments) notOnEmergencyMode onlyOwner public returns (bool) {
		data.setMaxNbPayments(_maxNbPayments);
		return true;
	}
	
	/**
	 * @dev Activates the emergency mode
	 * @return true if the emergency mode has been activated
	 */
	function redButton() onlyOwner public returns (bool) {
		emergency = true;
		return true;
	}

	/**
	 * @dev Turns off the emergency mode
	 * @return true if the emergency mode has been disabled
	 */
	function greenButton() onlyOwner public returns (bool) {
		emergency = false;
		return true;
	}
	

	/**
	 * @dev Unlock an address
	 * @return true if the address has been unlocked
	 */
	function unlockAddress(address _address) onlyOwner public returns (bool) {
		locked[_address] = false;
		return true;
	}

	/**
	 * @dev Lock an address
	 * @return true if the address has been locked
	 */
	function lockAddress(address _address) onlyOwner public returns (bool) {
		locked[_address] = true;
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
		return counter;
	}
	

	/**
	 * @dev starts the loan
   * @param _loanKey The loan's key.
	 * @return true if the loan has started
	 */
	function startLoan(uint256 _loanKey) notOnEmergencyMode onlyWhitelisted exceptLocked public returns(bool) {
		locked[msg.sender] = true;
		data.startLoan(_loanKey);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev Generates all loan repayments for the current period
   * @param _loanKey The loan's key.
	 * @return true if all the current loan repayments was generated.
	 */
	function generateLoanRepayments(uint256 _loanKey) notOnEmergencyMode exceptLocked public returns (bool) {
		locked[msg.sender] = true;
		(EfherLib.PaymentGenerator memory _generator) = data.generateLoanRepayments(_loanKey);
		for(uint8 i = 0; i < _generator.lastUngeneratedPayments.length; i++) {
			data.loans[_loanKey].settlements[i].generated = true;
		}
		for(uint8 j = 0; j < _generator.lenders.length; j++) {
			refunds[_generator.lenders[j]] = refunds[_generator.lenders[j]].add(_generator.amounts[j]);
		}
		data.stopProcessing(_loanKey);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev gives the loan status
   * @param _loanKey The loan's key.
	 * @return the loan status: 0 = nil, 1 = pending, 2 = started, 3 = paused, 4 = closed
	 */
	function loanStatus(uint256 _loanKey) public view returns(uint) {
		return data.loanStatus(_loanKey);
	}
	
	/**
	 * @dev give the settlements planning for a loan
   * @param _loanKey The loan's key.
	 * @return an array of timestamps and an array of bool with settlement status
	 */
	function settlements(uint256 _loanKey) public view returns(uint256[], bool[]) {
		return data.settlements(_loanKey);
	}
	
	/**
	 * @dev Returns the loans, amounts lent and its interest rates for a lender
   * @param _lender the lender.
	 * @return an array containing the loan indexes, an array containing the amounts lent and an array containing the interest rates
	 */
	function loansForLender(address _lender) public view returns(uint256[], uint256[], uint256[]) {
		return data.loansForLender(_lender);
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
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		payable
		public
		returns (bool)
	{
		require(msg.value == _amount);
		locked[msg.sender] = true;
		uint256 _refundAmount = data.appendGuarantor(_loanKey, _amount);
		refunds[msg.sender] = refunds[msg.sender].add(_refundAmount);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev removes a guarantor for a loan
   * @param _loanKey The loan's key.
	 * @return true if the guarantor has been removed
	 */
	function removeGuarantor(uint256 _loanKey) notOnEmergencyMode onlyWhitelisted exceptLocked public returns (bool) {
		locked[msg.sender] = true;
		uint256 _refundAmount = data.removeGuarantor(_loanKey, msg.sender);
		refunds[msg.sender] = refunds[msg.sender].add(_refundAmount);
		locked[msg.sender] = false;
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
		uint256 _refundAmount = data.removeGuarantor(_loanKey, _guarantor);
		refunds[_guarantor] = refunds[_guarantor].add(_refundAmount);
		return true;
	}
	
	/**
	 * @dev replaces a loan's guarantor
   * @param _loanKey The loan's key.
   * @param _oldGuarantor The guarantor to replace by
   * @param _amount The new guarantee amount. Mush be the same amount as the previous one
	 * @return true if the guarantor has been replaced
	 */
	function replaceGuarantor(
		uint256 _loanKey,
		address _oldGuarantor,
		uint256 _amount
	)
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		payable
		public
		returns (bool)
	{
		require(msg.value == _amount);
		locked[msg.sender] = true;
		data.replaceGuarantor(_loanKey, _oldGuarantor, msg.sender, _amount);
		refunds[_oldGuarantor] = refunds[_oldGuarantor].add(_amount);
		locked[msg.sender] = false;
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
		uint256 _interestRate
	)
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		payable
		public
		returns (bool)
	{
		require(msg.value == _amount);
		locked[msg.sender] = true;
		uint256 _refundAmount = data.appendLender(_loanKey, _amount, _interestRate);
		refunds[msg.sender] = refunds[msg.sender].add(_refundAmount);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev removes a lender for the pending lenders list
   * @param _loanKey The loan's key.
	 * @return true if the lender has been removed
	 */
	function removeLender(uint256 _loanKey) notOnEmergencyMode onlyWhitelisted exceptLocked public returns (bool) {
		locked[msg.sender] = true;
		uint256 _amount = data.removeLender(_loanKey);
		refunds[msg.sender] = refunds[msg.sender].add(_amount);
		locked[msg.sender] = false;
		return true;
	}
	
	/**
	 * @dev gives the list of pending lenders for a loan
   * @param _loanKey The loan's key.
	 * @return the lenders addresses, amounts and interest rates
	 */
	function pendingLendersList(uint256 _loanKey) public view returns (address[], uint256[], uint256[]) {
		return formattedLendersList(data.pendingLendersList(_loanKey));
	}
	
	/**
	 * @dev format a lenders list
   * @param _lenders lenders list.
	 * @return the lenders addresses, amounts and interest rates
	 */
	function formattedLendersList(EfherLib.Lender[] _lenders) private pure returns (address[], uint256[], uint256[]) {
		address[] memory _addresses = new address[](_lenders.length);
		uint256[] memory _amounts = new uint256[](_lenders.length);
		uint256[] memory _interestRates = new uint256[](_lenders.length);
		
		for(uint256 i = 0; i < _lenders.length; i++) {
			EfherLib.Lender memory _lender = _lenders[i];
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
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		public
		returns (bool, uint256)
	{
		locked[msg.sender] = true;
		(bool _success, uint256 _lendAmount) = data.approveLender(_loanKey, _lenderAddress);
		locked[msg.sender] = false;
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
		notOnEmergencyMode
		onlyWhitelisted
		exceptLocked
		public
		returns (bool, uint256)
	{
		locked[msg.sender] = true;
		(bool _success, uint256 _lendAmount) = data.removeApprovedLender(_loanKey, _lenderAddress);
		locked[msg.sender] = false;
		return (_success, _lendAmount);
 	}
	
	/**
	 * @dev gives the list of approved lenders for a loan
   * @param _loanKey The loan's key.
	 * @return the list of approved lenders
	 */
	function approvedLendersList(uint256 _loanKey) public view returns (address[], uint256[], uint256[]) {
		return formattedLendersList(data.approvedLendersList(_loanKey));
	}
	
}