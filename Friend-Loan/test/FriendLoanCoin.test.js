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
			await this.token.setMaxNbPayments(36);
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
		
		it('should prevent user not on whitelist to create a loan', async function () {
			try {
				await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			}
			catch (error) {}
			finally {
				const loansCount = await this.token.loansCount()
				assert.equal(loansCount, 0);
			}
		});
		
		it('adds a user to whitelist', async function () {
			await this.token.addAddressToWhitelist(this.borrower, {from: this.owner});
			const isBorrowerOnWhitelist = await this.token.whitelist(this.borrower);
			assert.isTrue(isBorrowerOnWhitelist);
		});
		
		it('should update the max number of payments', async function() {
			await this.token.setMaxNbPayments(2);
			var maxNbPayments = await this.token.maxNbPayments();
			assert.equal(maxNbPayments, 2);

			await this.token.setMaxNbPayments(55);
			maxNbPayments = await this.token.maxNbPayments();
			assert.equal(maxNbPayments, 55);
		});
		
		describe('should not create a loan when', async function () {
		  after(async function() {
				await this.token.setMaxNbPayments(36);
			});
			
			async function hasLoansCountBeenIncreased(token, totalAmount, maxInterestRate, nbPayments, paymentType, from) {
				const loansCount = await token.loansCount();
				try {
					await token.createLoan(totalAmount, maxInterestRate, nbPayments, paymentType, { from });
				}
				catch (error) {}
				finally {
					const currentLoansCount = await token.loansCount()
					return parseInt(currentLoansCount) > parseInt(loansCount);
				}
			}
			
			it('max number of payments is zero', async function() {
				await this.token.setMaxNbPayments(0);
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});
		
			it('amount is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, 0, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});
			
			it('number of payments is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, 0, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});
			
			it('payment type is invalid', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, 10, this.borrower)
				assert.isFalse(hasIncreased);
			});
		});
		
		
	});
});