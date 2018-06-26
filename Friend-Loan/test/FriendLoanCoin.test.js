const FriendLoanCoin = artifacts.require("FriendLoanCoin");

require('chai')
  .use(require('chai-as-promised'))
	.should();
	
contract('FriendLoanCoin', function(accounts) {
  before(async function() {
		this.token = await FriendLoanCoin.deployed();
		this.owner = accounts[0];
		this.otherAccount = accounts[1];
  });

	describe('token behaviour', async function () {
		it('should deploy the contract and store the address', async function(){
			let coinName = await this.token.name();
			let coinSymbol = await this.token.symbol();
			let coinDecimals = await this.token.decimals();
			coinName.should.equal("Friend Loan Coin");
			coinSymbol.should.equal("FLC");
			assert.equal(coinDecimals, 2);
		});

		it('sender (first account) should be token owner', async function () {
			let tokenOwner = await this.token.owner();
			tokenOwner.should.equal(this.owner);
		});
	
		it('mints the request amount from owner to another account', async function () {
			const amount = 100;
			const oldBalance = await this.token.balanceOf(this.otherAccount);
			await this.token.mint(this.otherAccount, amount, { from: this.owner });
			const balance = await this.token.balanceOf(this.otherAccount);
			assert.equal(oldBalance, 0);
			assert.equal(balance, amount);
		});
	
		it('burns the requested amount', async function () {
			const amount = 100;
			const oldBalance = await this.token.balanceOf(this.otherAccount);
			await this.token.burnFrom(this.otherAccount, amount, { from: this.owner });
	    const balance = await this.token.balanceOf(this.otherAccount);
		
			assert.equal(oldBalance, amount);
			assert.equal(balance, 0);
	  });

		it('prevents mints from non-owner', async function () {
			const amount = 5000;
			try {
				await this.token.mint(this.otherAccount, amount, { from: this.otherAccount });
			}
			catch (error) {}
			finally {
				const balance = await this.token.balanceOf(this.otherAccount);
				assert.notEqual(balance, amount);
			}
		});

		it('prevents burns from non-owner', async function () {
			const amount = 100;
			await this.token.mint(this.otherAccount, amount, { from: this.owner });
			try {
				await this.token.burnFrom(this.otherAccount, amount, { from: this.otherAccount });
			}
			catch (error) {}
			finally {
				const balance = await this.token.balanceOf(this.otherAccount);
				assert.equal(balance, amount);
			}
		});
	});
	
	describe('loan behaviour', async function () {
	  before(async function() {
			this.token = await FriendLoanCoin.deployed();
			this.owner = accounts[0];
			this.otherAccount = accounts[1];
			
			this.loanTotalAmount = 100;
			this.loanMaxInterestRate = 10;
			this.loanNbPayments = 6;
			this.loanPaymentType = 2;

			this.borrower = accounts[0];
			this.guarantor = accounts[1];
			this.lenderOne = accounts[2];
			this.lenderTwo = accounts[3];
	  });
		
		it('should prevent non-owner to update the max number of payments', async function () {
			const newMaxNbPayments = 48;
			try {
				await this.token.setMaxNbPayments(newMaxNbPayments, { from: this.otherAccount });
			}
			catch (error) {}
			finally {
				const currentMaxNbPayments = await this.token.maxNbPayments();
				assert.notEqual(currentMaxNbPayments, newMaxNbPayments);
			}
		});
		
		it('should update the max number of payments', async function () {
			const newMaxNbPayments = 48;
			await this.token.setMaxNbPayments(newMaxNbPayments, { from: this.owner });
			const currentMaxNbPayments = await this.token.maxNbPayments();
			assert.equal(currentMaxNbPayments, newMaxNbPayments);
		});
		
		
		it('should create a loan', async function () {
			const receipt = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			// See https://ethereum.stackexchange.com/questions/33192/how-do-i-know-which-transaction-generated-a-contract-in-factory-pattern?rq=1
			const logLoanCreated = receipt.logs[0];
			const borrower = logLoanCreated.args.borrower;
			borrower.should.equal(this.borrower);
		});
		
		it('should increment counter', async function () {
			const oldLoansCount = await this.token.loansCount()
			await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			const loansCount = await this.token.loansCount()
			assert.equal(loansCount, Number(oldLoansCount) + 2);
		});
	});
	
	
});