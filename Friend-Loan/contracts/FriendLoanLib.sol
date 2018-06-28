pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

library FriendLoanLib {	
	
	using SafeMath for uint; // Textmate bundle fix => }
	
	struct Lender {
    bool created;
		address lender;
    uint256 amount;
    uint8 interestRate;
	}

	struct Guarantor {
    bool engaged;
		address guarantor;
    uint256 amount;
	}
	
	enum PaymentType {
		Day,
		Week,
		Month
	}
	
	struct Data {
		mapping (uint256 => Loan) loans;
		uint256 loansCount;
		uint8 maxNbPayments;
	}
	
	struct Loan {
		uint index;
		bool loanStarted;
		bool created;
	
		address borrower;
		uint256 totalAmount;
		uint8 maxInterestRate;
		uint8 nbPayments;
	
		PaymentType paymentType; 
	
		uint256 guaranteeAmount;
		mapping (address => Guarantor) guarantors;
		uint256 guarantorsCount;

		uint256 lendAmount;
		mapping (address => Lender) proposedLenders;
		mapping (address => Lender) acceptedLenders;
		uint256 lendersCount;
	}
	
	event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint8 maxInterestRate, uint8 nbPayments, uint8 paymentType);
	event GuarantorAdded(uint256 indexed loanKey, address indexed guarantor, uint256 guarantee);
	event GuarantorRemoved(uint256 indexed loanKey, address indexed guarantor);
	event GuarantorReplaced(uint256 indexed loanKey, address indexed oldGuarantor, address indexed newGuarantor);
	event LoanStarted(uint256 indexed loanKey);
	event LenderAdded(uint256 indexed loanKey, address indexed guarantor, uint256 lend, uint8 interestRate);
	
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
			created: true,
			loanStarted: false,
			index: _key,
			borrower: msg.sender,
			totalAmount: _amount,
			maxInterestRate: _maxInterestRate,
			nbPayments: _nbPayments,
			paymentType: FriendLoanLib.PaymentType(_paymentType),
			guaranteeAmount: 0,
			guarantorsCount: 0,
			lendersCount: 0,
			lendAmount: 0
		});
		self.loans[_key] = loan;
		self.loansCount++;
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
    require(self.loans[_loanKey].created == true);
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
    require(self.loans[_loanKey].created == true);
    require(self.loans[_loanKey].loanStarted == false);
		require(self.loans[_loanKey].totalAmount > 0 && self.loans[_loanKey].guaranteeAmount > 0 && self.loans[_loanKey].lendAmount > 0);
    require(self.loans[_loanKey].totalAmount == self.loans[_loanKey].guaranteeAmount);
		require(self.loans[_loanKey].totalAmount == self.loans[_loanKey].lendAmount);
		require(self.loans[_loanKey].guarantorsCount > 0 && self.loans[_loanKey].lendersCount > 0);
		require(self.loans[_loanKey].borrower == msg.sender);
		
		self.loans[_loanKey].loanStarted = true;
		emit LoanStarted(_loanKey);
		
		return true;
	}
	
	/**
	 * @dev adds a guarantor for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _amount The guarantee's amount
	 * @return true if the guarantor has been added
	 */
	function appendGuarantor(
		Data storage self,
		uint256 _loanKey,
		uint256 _amount
	)
		internal
		returns (uint256)
	{
    require(self.loans[_loanKey].created == true);
    require(self.loans[_loanKey].loanStarted == false);
    require(self.loans[_loanKey].borrower != msg.sender);
		require(_amount > 0);

		uint256 _totalAmount = self.loans[_loanKey].totalAmount;
		uint256 _guaranteeAmount = self.loans[_loanKey].guaranteeAmount;

		if(_guaranteeAmount.add(_amount) > _totalAmount) {
			_amount = _totalAmount.sub(_guaranteeAmount);
		}
		_guaranteeAmount += _amount;

		if(self.loans[_loanKey].guarantors[msg.sender].engaged == true) {
			uint256 _guarantorAmount = self.loans[_loanKey].guarantors[msg.sender].amount;
			_guarantorAmount = _guarantorAmount.add(_amount);
			self.loans[_loanKey].guarantors[msg.sender].amount = _guarantorAmount;
		}
		else {
			self.loans[_loanKey].guarantors[msg.sender] = Guarantor({guarantor: msg.sender, amount: _amount, engaged: true});
		}

		self.loans[_loanKey].guaranteeAmount = _guaranteeAmount;
		self.loans[_loanKey].guarantorsCount++;

		assert(self.loans[_loanKey].totalAmount >= self.loans[_loanKey].guaranteeAmount);
		emit GuarantorAdded(_loanKey, msg.sender, _amount);
		
		return _amount;
	}
	
	/**
	 * @dev removes a guarantor for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _guarantor The guarantor to remove
	 * @return true if the guarantor has been removed
	 */
	function removeGuarantor(
		Data storage self,
		uint256 _loanKey,
		address _guarantor
	)
		internal
		returns (bool)
	{
    require(self.loans[_loanKey].created == true);
    require(self.loans[_loanKey].loanStarted == false);
		require(self.loans[_loanKey].guarantors[_guarantor].engaged == true);
		
		uint256 _guaranteeAmount = self.loans[_loanKey].guaranteeAmount;
		uint256 _guarantorAmount = self.loans[_loanKey].guarantors[_guarantor].amount;
		
		_guaranteeAmount = _guaranteeAmount.sub(_guarantorAmount);
		self.loans[_loanKey].guaranteeAmount = _guaranteeAmount;
		self.loans[_loanKey].guarantors[_guarantor].engaged = false;
		self.loans[_loanKey].guarantors[_guarantor].amount = 0;
		self.loans[_loanKey].guarantorsCount--;
		
		assert(self.loans[_loanKey].guaranteeAmount >= 0);
		emit GuarantorRemoved(_loanKey, _guarantor);
		
		return true;
	}
	
	/**
	 * @dev replaces a loan's guarantor
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _oldGuarantor The guarantor to replace by
   * @param _newGuarantor The new guarantor to replace by
	 * @return true if the guarantor has been replaced
	 */
	function replaceGuarantor(
		Data storage self,
		uint256 _loanKey,
		address _oldGuarantor,
		address _newGuarantor
	)
		internal
		returns (bool)
	{
    require(self.loans[_loanKey].created == true);
		require(self.loans[_loanKey].guarantors[_oldGuarantor].engaged == true);
		
		uint256 _oldGuarantorAmount = self.loans[_loanKey].guarantors[_oldGuarantor].amount;
		uint256 _newGuarantorAmount = self.loans[_loanKey].guarantors[_newGuarantor].amount;
		_newGuarantorAmount = _newGuarantorAmount.add(_oldGuarantorAmount);
		
		self.loans[_loanKey].guarantors[_oldGuarantor].engaged = false;
		self.loans[_loanKey].guarantors[_oldGuarantor].amount = 0;

		self.loans[_loanKey].guarantors[_newGuarantor] = Guarantor({guarantor: _newGuarantor, amount: _newGuarantorAmount, engaged: true});

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
    require(self.loans[_loanKey].created == true);
		return self.loans[_loanKey].guarantors[_guarantor].engaged == true;
	}
	
	/**
	 * @dev adds a lender for a loan
   * @param self The storage data.
   * @param _loanKey The loan's key.
   * @param _amount The lend's amount
   * @param _interestRate The interest's rate
	 * @return true if the lender has been added
	 */
	function appendLender(
		Data storage self,
		uint256 _loanKey,
		uint256 _amount,
		uint8 _interestRate
	)
		public
		returns (bool)
	{
    require(self.loans[_loanKey].created == true);
    require(self.loans[_loanKey].loanStarted == false);
    require(self.loans[_loanKey].borrower != msg.sender);
    require(self.loans[_loanKey].maxInterestRate >= _interestRate);
		require(_amount > 0);
		
		uint256 _totalAmount = self.loans[_loanKey].totalAmount;
		uint256 _lendAmount = self.loans[_loanKey].lendAmount;

		if(_lendAmount.add(_amount) > _totalAmount) {
			_amount = _totalAmount.sub(_lendAmount);
		}
		_lendAmount += _amount;
		
		if(self.loans[_loanKey].proposedLenders[msg.sender].created == true) {
			uint256 _lenderAmount = self.loans[_loanKey].proposedLenders[msg.sender].amount;
			_lenderAmount = _lenderAmount.add(_amount);
			self.loans[_loanKey].proposedLenders[msg.sender].amount = _lenderAmount;
		}
		else {
			self.loans[_loanKey].proposedLenders[msg.sender] = Lender({lender: msg.sender, amount: _amount, interestRate: _interestRate, created: true});
		}
		
		self.loans[_loanKey].lendAmount = _lendAmount;
		self.loans[_loanKey].lendersCount++;

		assert(self.loans[_loanKey].totalAmount >= self.loans[_loanKey].guaranteeAmount);
		emit LenderAdded(_loanKey, msg.sender, _amount, _interestRate);
		
		return true;
	}

}