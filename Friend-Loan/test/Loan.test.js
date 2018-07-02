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

	describe('loan', async function () {
	  before(async function() {
			await this.token.setMaxNbPayments(36);
			
			this.loanTotalAmount = 100;
			this.loanMaxInterestRate = 10;
			this.loanNbPayments = 6;
			this.loanPaymentType = 2;

			this.borrower = accounts[2];
			this.otherBorrower = accounts[3];
			this.guarantor = accounts[4];
			this.otherGuarantor = accounts[5];
			this.lenderOne = accounts[6];
			this.lenderTwo = accounts[7];
	  });
		
		describe('behaviours', async function () {
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
		});

		describe('creation', async function () {
			before(async function(){
				await this.token.addAddressToWhitelist(this.borrower, {from: this.owner});
			});

		  beforeEach(async function() {
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

			it('should not create a loan when max number of payments is zero', async function() {
				await this.token.setMaxNbPayments(0);
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when amount is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, 0, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when number of payments is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, 0, this.loanPaymentType, this.borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when payment type is invalid', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, 10, this.borrower)
				assert.isFalse(hasIncreased);
			});

			it('should create a loan', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(this.token, this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, this.borrower)
				assert.isTrue(hasIncreased);
			});

			it('should verify that the borrower is the one who passed', async function () {
				const receipt = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
				// See https://ethereum.stackexchange.com/questions/33192/how-do-i-know-which-transaction-generated-a-contract-in-factory-pattern?rq=1
				const logLoanCreated = receipt.logs[0];
				const borrower = logLoanCreated.args.borrower;
				borrower.should.equal(this.borrower);
			});
		});
		
		describe('start', async function () {
			before(async function(){
				await this.token.setMaxNbPayments(36);
				await this.token.addAddressToWhitelist(this.borrower, {from: this.owner});
				await this.token.addAddressToWhitelist(this.guarantor, {from: this.owner});
				await this.token.addAddressToWhitelist(this.lenderOne, {from: this.owner});
				await this.token.addAddressToWhitelist(this.lenderTwo, {from: this.owner});
			});
			
			beforeEach(async function() {
				const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
				this.loanId = parseInt(logs[0].args.id);
			});
			
			async function startLoan(token, key, from) {
				var isLoanStarted = false;
				try {
					await token.startLoan(key, { from });
					isLoanStarted = await token.isStarted(key);
				} catch (error) { isLoanStarted = false; }
				finally {
					return isLoanStarted;
				}
			}
			
			it('should start the loan', async function () {
				await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				const isLoanStarted = await startLoan(this.token, this.loanId, this.borrower);
				assert.isTrue(isLoanStarted);
			});
			
			it('should not start a nonexistent loan', async function() {
				const isLoanStarted = await startLoan(this.token, this.loanId, this.borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not restart an already started loan', async function() {
				await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				const isLoanStarted = await startLoan(this.token, this.loanId, this.borrower);
				assert.isTrue(isLoanStarted);
				var gotAnError = false;
				try {
					await this.token.startLoan(this.loanId, { from: this.borrower });
				}
				catch (error) {
					gotAnError = true;
				}
				finally {
					assert.isTrue(gotAnError);
				}
			});

			it('should not start a loan with a lend amount equal to zero', async function() {
				await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
				const isLoanStarted = await startLoan(this.token, this.loanId, this.borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not start a loan without the complete lend amount', async function() {
				await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
				await this.token.appendLender(this.loanId, this.loanTotalAmount - 10, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				const isLoanStarted = await startLoan(this.token, this.loanId, this.borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not start a loan when the sender is not the borrower', async function() {
				await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				var isLoanStarted = await startLoan(this.token, this.loanId, this.lenderOne);
				assert.isFalse(isLoanStarted);
				isLoanStarted = await startLoan(this.token, this.loanId, this.guarantor);
				assert.isFalse(isLoanStarted);
			});
			
		});
		
	});
});