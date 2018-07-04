const Efher = artifacts.require("Efher");

require('chai')
  .use(require('chai-as-promised'))
	.should();
	
contract('Efher', function(accounts) {
	let token;
	let loanId;
	const owner = accounts[0];
	const otherAccount = accounts[1];
	const loanTotalAmount = 100;
	const loanMaxInterestRate = 10;
	const loanNbPayments = 6;
	const loanPaymentType = 2;

	const borrower = accounts[2];
	const otherBorrower = accounts[3];
	const guarantor = accounts[4];
	const otherGuarantor = accounts[5];
	const lenderOne = accounts[6];
	const lenderTwo = accounts[7];
	
  before(async function() {
		token = await Efher.deployed();
  });

	describe('loan', async function () {
	  before(async function() {
			await token.setMaxNbPayments(36);
	  });
		
		describe('behaviours', async function () {
			it('should prevent non-owner to update the max number of payments', async function () {
				const newMaxNbPayments = 48;
				try {
					await token.setMaxNbPayments(newMaxNbPayments, { from: otherAccount });
				}
				catch (error) {}
				finally {
					const currentMaxNbPayments = await token.maxNbPayments();
					assert.notEqual(currentMaxNbPayments, newMaxNbPayments);
				}
			});

			it('should update the max number of payments', async function () {
				const newMaxNbPayments = 48;
				await token.setMaxNbPayments(newMaxNbPayments, { from: owner });
				const currentMaxNbPayments = await token.maxNbPayments();
				assert.equal(currentMaxNbPayments, newMaxNbPayments);
			});

			it('should prevent user not on whitelist to create a loan', async function () {
				try {
					await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				}
				catch (error) {}
				finally {
					const loansCount = await token.loansCount()
					assert.equal(loansCount, 0);
				}
			});

			it('adds a user to whitelist', async function () {
				await token.addAddressToWhitelist(borrower, {from: owner});
				const isBorrowerOnWhitelist = await token.whitelist(borrower);
				assert.isTrue(isBorrowerOnWhitelist);
			});

			it('should update the max number of payments', async function() {
				await token.setMaxNbPayments(2);
				var maxNbPayments = await token.maxNbPayments();
				assert.equal(maxNbPayments, 2);

				await token.setMaxNbPayments(55);
				maxNbPayments = await token.maxNbPayments();
				assert.equal(maxNbPayments, 55);
			});
		});

		describe('creation', async function () {
			before(async function(){
				await token.addAddressToWhitelist(borrower, {from: owner});
			});

		  beforeEach(async function() {
				await token.setMaxNbPayments(36);
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
				await token.setMaxNbPayments(0);
				const hasIncreased = await hasLoansCountBeenIncreased(token, loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when amount is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(token, 0, loanMaxInterestRate, loanNbPayments, loanPaymentType, borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when number of payments is zero', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(token, loanTotalAmount, loanMaxInterestRate, 0, loanPaymentType, borrower)
				assert.isFalse(hasIncreased);
			});

			it('should not create a loan when payment type is invalid', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(token, loanTotalAmount, loanMaxInterestRate, loanNbPayments, 10, borrower)
				assert.isFalse(hasIncreased);
			});

			it('should create a loan', async function() {
				const hasIncreased = await hasLoansCountBeenIncreased(token, loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, borrower)
				assert.isTrue(hasIncreased);
			});

			it('should verify that the borrower is the one who passed', async function () {
				const receipt = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				// See https://ethereum.stackexchange.com/questions/33192/how-do-i-know-which-transaction-generated-a-contract-in-factory-pattern?rq=1
				const logLoanCreated = receipt.logs[0];
				const logBorrower = logLoanCreated.args.borrower;
				borrower.should.equal(logBorrower);
			});
		});
		
		describe('start', async function () {
			before(async function(){
				await token.setMaxNbPayments(36);
				await token.addAddressToWhitelist(borrower, {from: owner});
				await token.addAddressToWhitelist(guarantor, {from: owner});
				await token.addAddressToWhitelist(lenderOne, {from: owner});
				await token.addAddressToWhitelist(lenderTwo, {from: owner});
			});
			
			beforeEach(async function() {
				const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				loanId = parseInt(logs[0].args.id);
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
				await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor});
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne});
				await token.approveLender(loanId, lenderOne, {from: borrower});
				const isLoanStarted = await startLoan(token, loanId, borrower);
				assert.isTrue(isLoanStarted);
			});
			
			it('should not start a nonexistent loan', async function() {
				const isLoanStarted = await startLoan(token, loanId, borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not restart an already started loan', async function() {
				await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor});
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne});
				await token.approveLender(loanId, lenderOne, {from: borrower});
				const isLoanStarted = await startLoan(token, loanId, borrower);
				assert.isTrue(isLoanStarted);
				var gotAnError = false;
				try {
					await token.startLoan(loanId, { from: borrower });
				}
				catch (error) {
					gotAnError = true;
				}
				finally {
					assert.isTrue(gotAnError);
				}
			});

			it('should not start a loan with a lend amount equal to zero', async function() {
				await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor});
				const isLoanStarted = await startLoan(token, loanId, borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not start a loan without the complete lend amount', async function() {
				await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor});
				await token.appendLender(loanId, loanTotalAmount - 10, loanMaxInterestRate, {from: lenderOne});
				await token.approveLender(loanId, lenderOne, {from: borrower});
				const isLoanStarted = await startLoan(token, loanId, borrower);
				assert.isFalse(isLoanStarted);
			});

			it('should not start a loan when the sender is not the borrower', async function() {
				await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor});
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne});
				await token.approveLender(loanId, lenderOne, {from: borrower});
				var isLoanStarted = await startLoan(token, loanId, lenderOne);
				assert.isFalse(isLoanStarted);
				isLoanStarted = await startLoan(token, loanId, guarantor);
				assert.isFalse(isLoanStarted);
			});
			
		});
		
	});
});