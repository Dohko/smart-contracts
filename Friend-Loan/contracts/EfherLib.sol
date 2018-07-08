pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

library EfherLib {	
	
	using SafeMath for uint; // Textmate bundle fix => }
	
	uint256 constant interestMultiplier = 10 ** 5; // precision 5
	
	struct PaymentGenerator {
		Loan loan;
		bool isLastPayment;
		uint8[] lastUngeneratedPayments;
		Lender[] approvedLenders;
		address[] lenders;
		uint256[] amounts;
		uint256 guaranteeBalance;
	}
	
	struct Lender {
    bool created;
		uint256 index;
		address lender;
    uint256 amount;
    uint256 interestRate;
	}

	struct Guarantor {
    bool engaged;
		address guarantor;
    uint256 amount;
	}
	
	struct Settlement {
		uint256 timestamp;
		bool generated;
	}
	
	enum PaymentType {
		Day,
		Week,
		Month
	}

	enum LoanStatus {
		Nil,
		Pending,
		Started,
		Paused,
		Closed
	}
	
	struct Data {
		mapping (uint256 => Loan) loans;
		mapping (address => uint256[]) userLoans;
		uint8 maxNbPayments;
	}
	
	struct Loan {
		uint index;
		LoanStatus status;
		bool processing;
	
		address borrower;
		uint256 totalAmount;
		uint256 maxInterestRate;
		uint8 nbPayments;
	
		PaymentType paymentType; 
	
		uint256 guaranteeAmount;
		mapping (address => Guarantor) guarantors;
		uint256 guarantorsCount;

		uint256 lendAmount;
		
		mapping (address => Lender) pendingLenders;
		address[] pendingLendersKeys;
		uint256 pendingLendersSize;
		
		mapping (address => Lender) approvedLenders;
		address[] approvedLendersKeys;
		uint256 approvedLendersSize;
		
		mapping (uint8 => Settlement) settlements;
		uint256 settlementsSize;
		
		uint256 depositFund;
		uint256 underfund;
	}
	
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
		uint256 _maxInterestRate,
		uint8 _nbPayments,
		uint8 _paymentType
	)
		internal
		returns(Loan)
	{
		// 1. Conditions
    require(self.loans[_key].status == LoanStatus.Nil);
		require(_amount > 0);
		require(_nbPayments > 0);
		require(self.maxNbPayments > _nbPayments);
		require(uint(PaymentType.Month) >= _paymentType);

		// 2. Effects
		Loan memory loan = Loan({
			index: _key,
			status: LoanStatus.Pending,
			processing: false,
			borrower: msg.sender,
			totalAmount: _amount,
			maxInterestRate: _maxInterestRate,
			nbPayments: _nbPayments,
			paymentType: EfherLib.PaymentType(_paymentType),
			guaranteeAmount: 0,
			guarantorsCount: 0,
			approvedLendersSize: 0,
			approvedLendersKeys: new address[](0),
			lendAmount: 0,
			pendingLendersKeys: new address[](0),
			pendingLendersSize: 0,
			settlementsSize: 0,
			depositFund: 0,
			underfund: 0
			
		});
		self.loans[_key] = loan;
		emit LoanCreated(loan.index, loan.borrower, loan.totalAmount, loan.maxInterestRate, loan.nbPayments, uint8(loan.paymentType));

		// 3. Interaction
		return loan;
	}
	
	/**
	 * @dev Custody of borrower money on deposit
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _amount The deposit amount.
	 * @return true if the money was deposited
	 */
	function depositFromBorrower(
		Data storage self,
		uint256 _loanKey,
		uint256 _amount
	)
		internal
		returns (bool)
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
	  require(self.loans[_loanKey].borrower == msg.sender);
		
		if (self.loans[_loanKey].underfund > 0) {
			if (self.loans[_loanKey].underfund >= _amount) {
				_amount = 0;
				self.loans[_loanKey].underfund = self.loans[_loanKey].underfund.sub(_amount);
			}
			else {
				_amount = _amount.sub(self.loans[_loanKey].underfund);
				self.loans[_loanKey].underfund = 0;
			}
		}
		
		self.loans[_loanKey].depositFund = _amount;

		return true;
	}
	
	/**
	 * @dev Returns the current borrower deposit and loan underfund 
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return current borrower deposit and loan underfund
	 */
	function borrowerDepositAndUnderfund(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns (uint256, uint256)
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
		return (self.loans[_loanKey].depositFund, self.loans[_loanKey].underfund);
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
		internal
		returns (bool)
	{
		self.maxNbPayments = _maxNbPayments;
		return true;
	}
	
	/**
	 * @dev gives the number of guarantors for a loan
   * @param _loanKey The loan's key.
	 * @return the number of guarantors
	 */
	function guarantorsCount(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns(uint256)
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
		return self.loans[_loanKey].guarantorsCount;
	}
	
	/**
	 * @dev starts the loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return true if the loan has started
	 */
	function startLoan(
		Data storage self,
		uint256 _loanKey
	)
		internal
		returns(bool)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
		require(self.loans[_loanKey].totalAmount > 0 && self.loans[_loanKey].guaranteeAmount > 0 && self.loans[_loanKey].lendAmount > 0);
    require(self.loans[_loanKey].totalAmount == self.loans[_loanKey].guaranteeAmount);
		require(self.loans[_loanKey].totalAmount == self.loans[_loanKey].lendAmount);
		require(self.loans[_loanKey].guarantorsCount > 0 && self.loans[_loanKey].approvedLendersSize > 0);
		require(self.loans[_loanKey].borrower == msg.sender);
		require(self.loans[_loanKey].settlementsSize == 0);
		
		Settlement[] memory _settlements = getSettlements(self.loans[_loanKey].paymentType, self.loans[_loanKey].nbPayments);
		assert(_settlements.length > 0);
		
		for(uint8 i = 0; i < _settlements.length; i++) {
			self.loans[_loanKey].settlements[i] = _settlements[i];
		}
		self.loans[_loanKey].settlementsSize = i;
		
		bool append = appendLoanToUser(self, _loanKey);
		assert(append);
		
		self.loans[_loanKey].status = LoanStatus.Started;
		emit LoanStarted(_loanKey);
		
		return true;
	}
	
	/**
	 * @dev Generates all loan repayments for the current period
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return true if is the last payment, an array with the settlement indexed, an array with the address to refund, an array with the amounts to refund
	 */
	function generateLoanRepayments(
		Data storage self,
		uint256 _loanKey
	)
		internal
		returns (PaymentGenerator)
	{
    require(self.loans[_loanKey].status == LoanStatus.Started);
		require(self.loans[_loanKey].processing == false);
		self.loans[_loanKey].processing = true;
		
		PaymentGenerator memory _generator = PaymentGenerator({
			loan: self.loans[_loanKey],
			isLastPayment: false,
			lastUngeneratedPayments: getUngeratedPaymentIndexes(self, _loanKey),
			approvedLenders: approvedLendersList(self, _loanKey),
			lenders: new address[](self.loans[_loanKey].approvedLendersSize),
			amounts: new uint256[](self.loans[_loanKey].approvedLendersSize),
			guaranteeBalance: 0
		});
		
		_generator = processGenerator(_generator);

		self.loans[_loanKey].depositFund = _generator.loan.depositFund;
		self.loans[_loanKey].underfund = _generator.loan.underfund;

		return _generator;
	}
	
	function processGenerator(PaymentGenerator _generator) private pure returns (PaymentGenerator) {
		if (_generator.lastUngeneratedPayments.length > 0 && _generator.loan.settlementsSize > 0) {
			_generator.isLastPayment = (_generator.lastUngeneratedPayments[_generator.lastUngeneratedPayments.length - 1] == _generator.loan.settlementsSize - 1);
		}
		
		_generator.guaranteeBalance = _generator.loan.depositFund.add(_generator.loan.guaranteeAmount).sub(_generator.loan.underfund);
		uint256 _index = 0;
		for(uint8 i = 0; i < _generator.lastUngeneratedPayments.length; i++) {
			for(uint256 j = 0; j < _generator.approvedLenders.length; j++) {
				if (_generator.guaranteeBalance == 0) {
					_generator.isLastPayment = true;
					break;
				}
				uint256 _amount = percent(_generator.approvedLenders[j].amount, _generator.loan.totalAmount, 5);
				uint256 _interest = _amount.mul(interestMultiplier).mul(_generator.approvedLenders[j].interestRate).div(interestMultiplier.mul(100));
				_amount = _amount.add(_interest.div(interestMultiplier));
				
				if (_amount >= _generator.guaranteeBalance) {
					_amount = _generator.guaranteeBalance;
					_generator.guaranteeBalance = 0;
					_generator.lenders[_index] = _generator.approvedLenders[j].lender;
					_generator.amounts[_index] = _amount;
				}
				_generator.guaranteeBalance = _generator.guaranteeBalance.sub(_amount);
				if (_generator.loan.depositFund >= _amount) {
					_generator.loan.depositFund = _generator.loan.depositFund.sub(_amount);
				}
				else {
					_generator.loan.underfund = _generator.loan.underfund.add(_amount);
				}
				_index = _index.add(1);
			}
		}
		return _generator;
	}
	
	/**
	 * @dev Change the loan processing flag
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return true if the loan processing flag has changed
	 */
	function stopProcessing(
		Data storage self,
		uint256 _loanKey
	)
		internal
		returns (bool)
	{
    require(self.loans[_loanKey].status == LoanStatus.Started);
		require(self.loans[_loanKey].processing == true);
		self.loans[_loanKey].processing = false;
		return true;
	}
	
	/**
	 * @dev returns the ungenerated payments indexes
	 */
	function getUngeratedPaymentIndexes(Data storage self, uint256 _loanKey) private view returns (uint8[]) {
		(uint256[] memory _timestamps, bool[] memory _statuses) = settlements(self, _loanKey);
		//  it is not possible to resize memory arrays
		uint8[] memory _tmpUngeratedPayments = new uint8[](_timestamps.length);
		uint8 _size = 0;
		for(uint8 i = 0; i < _timestamps.length; i++) {
			if (now > _timestamps[i] && _statuses[i] == false) {
				_tmpUngeratedPayments[_size] = i;
				_size++;
			}
		}

		uint8[] memory _ungeratedPayments = new uint8[](_size);
		for(uint8 j = 0; j < _size; j++) {
			_ungeratedPayments[j] = _tmpUngeratedPayments[j];
		}
		return _ungeratedPayments;
	}
	
	/**
	 * @dev https://stackoverflow.com/questions/42738640/division-in-ethereum-solidity/42739843
	 */
	function percent(uint256 numerator, uint256 denominator, uint8 precision) private pure returns(uint quotient) {
		// caution, check safe-to-multiply here
		uint256 _numerator  = numerator.mul(10) ** (precision + 1);
		// with rounding of last digit
		uint256 _quotient =  _numerator.div(denominator).add(5).div(10);
		return ( _quotient);
	}
	
	/**
	 * @dev returns a settlements planning
   * @param _paymentType the payment type (day / week / month).
   * @param _nbPayments The number of payments.
	 * @return an array of timestamps
	 */
	function getSettlements(
		PaymentType _paymentType,
		uint8 _nbPayments
	)
		private
		constant
		returns(Settlement[])
	{
		Settlement[] memory _settlements = new Settlement[](_nbPayments);
		uint256 _multiplier;
		if(_paymentType == PaymentType.Day) {
			_multiplier = 1 days;
		}
		else if(_paymentType == PaymentType.Week) {
			_multiplier = 7 days;
		}
		else if(_paymentType == PaymentType.Month) {
			_multiplier = 31 days;
		}
		else {
			return new Settlement[](0);
		}
		for(uint8 i = 0; i < _nbPayments; i++) {
			uint256 _settleTime = now.mul(now).mul(_multiplier).mul(i + 1);
			_settlements[i] = Settlement({timestamp: _settleTime, generated: false});
		}
		return _settlements;
	}
	
	/**
	 * @dev appends the loan to the lenders
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return true if the loan has been added
	 */
	function appendLoanToUser(
		Data storage self,
		uint256 _loanKey
	)
		private
		returns(bool)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
		require(self.loans[_loanKey].settlementsSize > 0);
		
		for(uint256 i = 0; i < self.loans[_loanKey].approvedLendersKeys.length; i++) {
			address _lenderAddress = self.loans[_loanKey].approvedLendersKeys[i];
			if (_lenderAddress != address(0)) {
				self.userLoans[_lenderAddress].push(_loanKey);
			}
		}
		return true;
	}
	
	/**
	 * @dev Returns the loans, amounts lent and its interest rates for a lender
   * @param self The storage data.
   * @param _lender the lender.
	 * @return an array containing the loan indexes, an array containing the amounts lent and an array containing the interest rates
	 */
	function loansForLender(
		Data storage self,
		address _lender
	)
	internal
	view
	returns(uint256[], uint256[], uint256[])
	{
		uint256 _nbLoans = self.userLoans[_lender].length;
		uint256[] memory _loans = new uint256[](_nbLoans);
		uint256[] memory _amounts = new uint256[](_nbLoans);
		uint256[] memory _interestRates = new uint256[](_nbLoans);
		uint256 _index = 0;
		for(uint256 i = 0; i < _nbLoans; i++) {
			uint256 _loanId = self.userLoans[_lender][i];
			if (uint(self.loans[_loanId].status) >= uint(LoanStatus.Pending) && self.loans[_loanId].approvedLenders[_lender].created == true) {
				_loans[_index] = _loanId;
				_amounts[_index] = self.loans[_loanId].approvedLenders[_lender].amount;
				_interestRates[_index] = self.loans[_loanId].approvedLenders[_lender].interestRate;
				_index++;
			}
		}
		return (_loans, _amounts, _interestRates);
	}
	
	/**
	 * @dev give the settlements planning for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return an array of Settlements
	 */
	function settlements(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns(uint256[], bool[])
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Started));
		require(self.loans[_loanKey].settlementsSize == 0);
		
		uint256[] memory _timestamps = new uint256[](self.loans[_loanKey].settlementsSize);
		bool[] memory _statuses = new bool[](self.loans[_loanKey].settlementsSize);
		uint256 _index = 0;
		for(uint8 i = 0; i < self.loans[_loanKey].settlementsSize; i++) {
			Settlement memory _settlement = self.loans[_loanKey].settlements[i];
			if (_settlement.timestamp > 0) {
				_timestamps[_index] = _settlement.timestamp;
				_statuses[_index] = _settlement.generated;
				_index = _index.add(1);
			}
		}
		return (_timestamps, _statuses);
	}
	
	/**
	 * @dev gives the loan status
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return the loan status: 0 = nil, 1 = pending, 2 = started, 3 = paused, 4 = closed
	 */
	function loanStatus(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns(uint)
	{
		return uint(self.loans[_loanKey].status);
	}
	
	/**
	 * @dev adds a guarantor for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _amount The guarantee's amount
	 * @return the amount to refund
	 */
	function appendGuarantor(
		Data storage self,
		uint256 _loanKey,
		uint256 _amount
	)
		internal
		returns (uint256)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
    require(self.loans[_loanKey].borrower != msg.sender);
		require(self.loans[_loanKey].totalAmount > self.loans[_loanKey].guaranteeAmount);
		require(_amount > 0);

		uint256 _totalAmount = self.loans[_loanKey].totalAmount;
		uint256 _guaranteeAmount = self.loans[_loanKey].guaranteeAmount;

		uint256 _refundAmount = 0;
		if(_guaranteeAmount.add(_amount) > _totalAmount) {
			uint256 _diff = _totalAmount.sub(_guaranteeAmount);
			assert(_amount >= _diff);
			_refundAmount = _amount.sub(_diff);
			_amount = _diff;
		}
		_guaranteeAmount = _guaranteeAmount.add(_amount);

		if(self.loans[_loanKey].guarantors[msg.sender].engaged == true) {
			uint256 _guarantorAmount = self.loans[_loanKey].guarantors[msg.sender].amount;
			_guarantorAmount = _guarantorAmount.add(_amount);
			self.loans[_loanKey].guarantors[msg.sender].amount = _guarantorAmount;
		}
		else {
			self.loans[_loanKey].guarantors[msg.sender] = Guarantor({guarantor: msg.sender, amount: _amount, engaged: true});
		}

		self.loans[_loanKey].guaranteeAmount = _guaranteeAmount;
		self.loans[_loanKey].guarantorsCount = self.loans[_loanKey].guarantorsCount.add(1);

		assert(self.loans[_loanKey].totalAmount >= self.loans[_loanKey].guaranteeAmount);
		emit GuarantorAdded(_loanKey, msg.sender, _amount);
		
		return _refundAmount;
	}
	
	/**
	 * @dev removes a guarantor for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _guarantor The guarantor to remove
	 * @return the guarantee amount to refund to the former guarantor
	 */
	function removeGuarantor(
		Data storage self,
		uint256 _loanKey,
		address _guarantor
	)
		internal
		returns (uint256)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
		require(self.loans[_loanKey].guarantors[_guarantor].engaged == true);
		
		uint256 _guaranteeAmount = self.loans[_loanKey].guaranteeAmount;
		uint256 _guarantorAmount = self.loans[_loanKey].guarantors[_guarantor].amount;
		
		_guaranteeAmount = _guaranteeAmount.sub(_guarantorAmount);
		self.loans[_loanKey].guaranteeAmount = _guaranteeAmount;
		delete self.loans[_loanKey].guarantors[_guarantor];
		self.loans[_loanKey].guarantorsCount = self.loans[_loanKey].guarantorsCount.sub(1);
		
		assert(self.loans[_loanKey].guaranteeAmount >= 0);
		emit GuarantorRemoved(_loanKey, _guarantor);
		
		return _guarantorAmount;
	}
	
	/**
	 * @dev replaces a loan's guarantor
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _oldGuarantor The guarantor to replace by
   * @param _newGuarantor The new guarantor to replace by
   * @param _amount The new guarantee amount. Mush be the same amount as the previous one
	 * @return true if the guarantor has been replaced
	 */
	function replaceGuarantor(
		Data storage self,
		uint256 _loanKey,
		address _oldGuarantor,
		address _newGuarantor,
		uint256 _amount
	)
		internal
		returns (bool)
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
		require(_amount > 0);
		require(_oldGuarantor != _newGuarantor);
		require(self.loans[_loanKey].guarantors[_oldGuarantor].engaged == true);
		require(self.loans[_loanKey].guarantors[_newGuarantor].engaged == false);
		    require(_amount == self.loans[_loanKey].guarantors[_oldGuarantor].amount);

		delete self.loans[_loanKey].guarantors[_oldGuarantor];

		self.loans[_loanKey].guarantors[_newGuarantor] = Guarantor({guarantor: _newGuarantor, amount: _amount, engaged: true});

		assert(self.loans[_loanKey].guaranteeAmount >= 0);
		assert(self.loans[_loanKey].totalAmount >= self.loans[_loanKey].guaranteeAmount);
		emit GuarantorReplaced(_loanKey, _oldGuarantor, _newGuarantor);
		
		return true;
	}
	
	/**
	 * @dev checks if a specified guarantor is engaged by the loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _guarantor The guarantor to check
	 * @return true if the guarantor is engaged
	 */
	function isGuarantorEngaged(
		Data storage self,
		uint256 _loanKey,
		address _guarantor
	)
		internal
		view
		returns (bool)
	{
    if (self.loans[_loanKey].status == LoanStatus.Nil) {
			return false;
		}
		else {
			return self.loans[_loanKey].guarantors[_guarantor].engaged == true;
		}
	}
	
	/**
	 * @dev adds a lender to the pending list
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _amount The lend's amount
   * @param _interestRate The interest's rate
	 * @return the refund amount when amount is greater than the loan 
	 */
	function appendLender(
		Data storage self,
		uint256 _loanKey,
		uint256 _amount,
		uint256 _interestRate
	)
		public
		returns (uint256)
	{
		require(_amount > 0);
    require(self.loans[_loanKey].status == LoanStatus.Pending);
    require(self.loans[_loanKey].borrower != msg.sender);
    require(self.loans[_loanKey].maxInterestRate >= _interestRate);
		require(self.loans[_loanKey].pendingLenders[msg.sender].created == false);
		
		uint256 _refundAmount = 0;
		if(_amount > self.loans[_loanKey].totalAmount) {
			_refundAmount = _amount.sub(self.loans[_loanKey].totalAmount);
			_amount = self.loans[_loanKey].totalAmount;
		}
		
		self.loans[_loanKey].pendingLenders[msg.sender] = Lender({index: 0, lender: msg.sender, amount: _amount, interestRate: _interestRate, created: true});
		uint256 _newIndex = self.loans[_loanKey].pendingLendersKeys.push(msg.sender);
		self.loans[_loanKey].pendingLenders[msg.sender].index = _newIndex.sub(1);
		self.loans[_loanKey].pendingLendersSize = self.loans[_loanKey].pendingLendersSize.add(1);
		
		emit LenderAdded(_loanKey, msg.sender, _amount, _interestRate);
		
		return _refundAmount;
	}
	
	/**
	 * @dev removes a lender for the pending lenders list
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return the amount to refund to the lender
	 */
	function removeLender(
		Data storage self,
		uint256 _loanKey
	)
		internal
		returns (uint256)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
    require(self.loans[_loanKey].borrower != msg.sender);
    require(self.loans[_loanKey].pendingLenders[msg.sender].created == true);

		uint256 _lenderAmount = self.loans[_loanKey].pendingLenders[msg.sender].amount;
		if(self.loans[_loanKey].approvedLenders[msg.sender].created == true) {
			self.loans[_loanKey].lendAmount = self.loans[_loanKey].lendAmount.sub(_lenderAmount);
			uint256 _approvedLenderIndex = self.loans[_loanKey].approvedLenders[msg.sender].index;
			delete self.loans[_loanKey].approvedLendersKeys[_approvedLenderIndex];
			delete self.loans[_loanKey].approvedLenders[msg.sender];
			self.loans[_loanKey].approvedLendersSize = self.loans[_loanKey].approvedLendersSize.sub(1);
		}
		uint256 _pendingLenderIndex = self.loans[_loanKey].pendingLenders[msg.sender].index;
		delete self.loans[_loanKey].pendingLenders[msg.sender];
		delete self.loans[_loanKey].pendingLendersKeys[_pendingLenderIndex];
		self.loans[_loanKey].pendingLendersSize = self.loans[_loanKey].pendingLendersSize.sub(1);
		
		emit LenderRemoved(_loanKey, msg.sender);
		
		return _lenderAmount;
	}
	
	/**
	 * @dev gives the list of pending lenders for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return the list of pending lenders
	 */
	function pendingLendersList(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns (Lender[])
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
		Lender[] memory _lenders = new Lender[](self.loans[_loanKey].pendingLendersSize);
		
		uint256 _index = 0;
		for(uint256 i = 0; i < self.loans[_loanKey].pendingLendersKeys.length; i++) {
			address _lenderAddress = self.loans[_loanKey].pendingLendersKeys[i];
			if (_lenderAddress != address(0)) {
				Lender memory _lender = self.loans[_loanKey].pendingLenders[_lenderAddress];
				_lenders[_index] = _lender;
				_index = _index.add(1);
			}
		}
		return _lenders;
	}

	/**
	 * @dev approves a lender from the pending lender list
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _lenderAddress The lender's address.
	 * @return true if the lender has been approved and the lend's amount
	 */
	function approveLender(
		Data storage self,
		uint256 _loanKey,
		address _lenderAddress
	)
		internal
		returns (bool, uint256)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
    require(self.loans[_loanKey].borrower == msg.sender);
		require(self.loans[_loanKey].guaranteeAmount == self.loans[_loanKey].totalAmount);
		require(self.loans[_loanKey].lendAmount < self.loans[_loanKey].totalAmount);
    require(self.loans[_loanKey].pendingLenders[_lenderAddress].created == true);
    require(self.loans[_loanKey].pendingLenders[_lenderAddress].amount > 0);
    require(self.loans[_loanKey].approvedLenders[_lenderAddress].created == false);
		
		uint256 _amount = self.loans[_loanKey].pendingLenders[_lenderAddress].amount;
		uint256 _interestRate = self.loans[_loanKey].pendingLenders[_lenderAddress].interestRate;
		if(self.loans[_loanKey].lendAmount.add(_amount) > self.loans[_loanKey].totalAmount) {
			_amount = self.loans[_loanKey].totalAmount.sub(self.loans[_loanKey].lendAmount);
		}

		self.loans[_loanKey].approvedLenders[_lenderAddress] = Lender({index: 0, lender: _lenderAddress, amount: _amount, interestRate: _interestRate, created: true});
		uint256 newIndex = self.loans[_loanKey].approvedLendersKeys.push(_lenderAddress);
		self.loans[_loanKey].approvedLenders[_lenderAddress].index = newIndex.sub(1);
		self.loans[_loanKey].approvedLendersSize = self.loans[_loanKey].approvedLendersSize.add(1);
		self.loans[_loanKey].lendAmount = self.loans[_loanKey].lendAmount.add(_amount);
		
		emit LenderApproved(_loanKey, _lenderAddress, _amount, _interestRate);

		return (true, _amount);
	}

	/**
	 * @dev removes an approved lender from the approved lender list
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _lenderAddress The lender's address.
	 * @return true if the lender has been removed from the approved lender list and the lend's amount
	 */
	function removeApprovedLender(
		Data storage self,
		uint256 _loanKey,
		address _lenderAddress
	)
		internal
		returns (bool, uint256)
	{
    require(self.loans[_loanKey].status == LoanStatus.Pending);
    require(self.loans[_loanKey].borrower == msg.sender);
    require(self.loans[_loanKey].pendingLenders[_lenderAddress].created == true);
    require(self.loans[_loanKey].approvedLenders[_lenderAddress].created == true);
		require(self.loans[_loanKey].lendAmount > 0);
		require(self.loans[_loanKey].approvedLenders[_lenderAddress].amount > 0);
		require(self.loans[_loanKey].lendAmount >= self.loans[_loanKey].approvedLenders[_lenderAddress].amount);
		
		uint256 _amount = self.loans[_loanKey].approvedLenders[_lenderAddress].amount;
		uint256 _lenderIndex = self.loans[_loanKey].approvedLenders[_lenderAddress].index;

		delete self.loans[_loanKey].approvedLenders[_lenderAddress];
		delete self.loans[_loanKey].approvedLendersKeys[_lenderIndex];
		self.loans[_loanKey].approvedLendersSize = self.loans[_loanKey].approvedLendersSize.sub(1);
		self.loans[_loanKey].lendAmount = self.loans[_loanKey].lendAmount.sub(_amount);

		emit LenderDisapproved(_loanKey, _lenderAddress, self.loans[_loanKey].lendAmount, _amount);

		return (true, _amount);
	}
	
	/**
	 * @dev gives the list of approved lenders for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
	 * @return the list of approved lenders
	 */
	function approvedLendersList(
		Data storage self,
		uint256 _loanKey
	)
		internal
		view
		returns (Lender[])
	{
    require(uint(self.loans[_loanKey].status) >= uint(LoanStatus.Pending));
		Lender[] memory _lenders = new Lender[](self.loans[_loanKey].approvedLendersSize);
		
		uint256 _index = 0;
		for(uint256 i = 0; i < self.loans[_loanKey].approvedLendersKeys.length; i++) {
			address _lenderAddress = self.loans[_loanKey].approvedLendersKeys[i];
			if (_lenderAddress != address(0)) {
				Lender memory _lender = self.loans[_loanKey].approvedLenders[_lenderAddress];
				_lenders[_index] = _lender;
				_index = _index.add(1);
			}
		}
		return _lenders;
	}
	
	
}