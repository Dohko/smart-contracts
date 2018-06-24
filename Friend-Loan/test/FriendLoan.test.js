
require('chai')
  .use(require('chai-as-promised'))
	.should();
	
	
contract('FriendLoan', function(accounts) {
	const FriendLoan = artifacts.require("FriendLoan");
	const _loanAmount = 100;
	const _maxInterestRate = 10;
	const _nbPayments = 6;
	const _paymentType = 2; // YEAR

	const _borrower = accounts[0];
	const _lender = accounts[1];
	
  before(async function() {
		this.loan = await FriendLoan.new(_loanAmount, _maxInterestRate, _nbPayments, _paymentType, {from: _borrower});
  });

	beforeEach(async function () {
	});
	
	it('should deploy the contract and store the address', async function(){
		let borrower = await this.loan.borrower();
		let loanAmount = await this.loan.amount();
		let maxInterestRate = await this.loan.maxInterestRate();
		let nbPayments = await this.loan.nbPayments();
		let paymentType = await this.loan.paymentType();
		
		borrower.should.equal(_borrower);
		assert.equal(loanAmount, _loanAmount);
		assert.equal(maxInterestRate, _maxInterestRate);
		assert.equal(nbPayments, _nbPayments);
		assert.equal(paymentType, _paymentType);
	});

	
});