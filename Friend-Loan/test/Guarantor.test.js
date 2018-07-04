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
	
  before(async function() {
		token = await Efher.deployed();
		await token.setMaxNbPayments(36);
  });

		
	describe('guarantors', async function () {
		before(async function() {
			await token.addAddressToWhitelist(borrower, {from: owner});
			await token.addAddressToWhitelist(guarantor, {from: owner});
			await token.addAddressToWhitelist(otherBorrower, {from: owner});
			await token.addAddressToWhitelist(lenderOne, {from: owner});

			const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
			loanId = parseInt(logs[0].args.id);
		});

		describe('append', async function () {

			async function hasGuarantorsCountBeenIncreased(token, loanKey, guarantorAmount, guarantor) {
				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await token.guarantorsCount(loanKey); } catch (error) { guarantorsCount = 0; }
				try {
					await token.appendGuarantor(loanKey, guarantorAmount, {from: guarantor})
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await token.guarantorsCount(loanKey); } catch (error) { currentGuarantorsCount = 0; }
					return parseInt(currentGuarantorsCount) > parseInt(guarantorsCount);
				}
			}

			it('should append a guarantor', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(token, loanId, 10000, guarantor);
				assert.isTrue(increased);
			});

			it('should not append a guarantor when the loan wasn\'t created', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(token, 99, 10000, guarantor);
				assert.isFalse(increased);
			});

			it('should not append a guarantor when the loan has started', async function() {
				const currentMaxNbPayments = await token.maxNbPayments();
				const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: otherBorrower});
				const newLoanId = parseInt(logs[0].args.id);
				var increased = await hasGuarantorsCountBeenIncreased(token, newLoanId, 10000, guarantor);
				assert.isTrue(increased);
				await token.appendLender(newLoanId, 10000, loanMaxInterestRate, {from: lenderOne})
				await token.approveLender(newLoanId, lenderOne, {from: otherBorrower});
				await token.startLoan(newLoanId, {from: otherBorrower});
				increased = await hasGuarantorsCountBeenIncreased(token, newLoanId, 10000, otherGuarantor);
				assert.isFalse(increased);
			});

			it('should not append a guarantor is the borrower too', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(token, loanId, 10000, borrower);
				assert.isFalse(increased);
			});

			it('should not append a guarantor if the guarantee is 0', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(token, loanId, 0, guarantor);
				assert.isFalse(increased);
			});
		});

		describe('remove', async function () {
			before(async function() {
				await token.appendGuarantor(loanId, 5000, {from: guarantor})
			});

			async function hasGuarantorsCountBeenDecreased(token, loanKey, guarantor) {
				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await token.guarantorsCount(loanKey); } catch (error) { guarantorsCount = 0; }
				try {
					await token.removeGuarantor(loanKey, {from: guarantor})
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await token.guarantorsCount(loanKey); } catch (error) { currentGuarantorsCount = 0; }
					return parseInt(currentGuarantorsCount) < parseInt(guarantorsCount);
				}
			}

			it('should remove a guarantor', async function() {
				const decreased = await hasGuarantorsCountBeenDecreased(token, loanId, guarantor);
				assert.isTrue(decreased);
			});

			it('should not remove a guarantor when the loan wasn\'t created', async function() {
				const decreased = await hasGuarantorsCountBeenDecreased(token, 99, guarantor);
				assert.isFalse(decreased);
			});

			it('should not remove a guarantor when the loan has started', async function() {
				const currentMaxNbPayments = await token.maxNbPayments();
				const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await token.appendGuarantor(newLoanId, 10000, {from: guarantor})
				await token.appendLender(newLoanId, 10000, loanMaxInterestRate, {from: lenderOne})
				await token.approveLender(newLoanId, lenderOne, {from: borrower})
				await token.startLoan(newLoanId, {from: borrower});
				const decreased = await hasGuarantorsCountBeenDecreased(token, newLoanId, guarantor);
				assert.isFalse(decreased);
			});

			it('should not remove a guarantor if not engaged on the loan', async function() {
				const decreased = await hasGuarantorsCountBeenDecreased(token, 99, otherGuarantor);
				assert.isFalse(decreased);
			});

			it('should prevent a non-owner to remove a guarantor', async function() {
				const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await token.appendGuarantor(newLoanId, 5000, {from: guarantor})

				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await token.guarantorsCount(newLoanId); } catch (error) { guarantorsCount = 0; }
				try {
					await token.forceRemoveGuarantor(newLoanId, guarantor, {from: guarantor});
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await token.guarantorsCount(newLoanId); } catch (error) { currentGuarantorsCount = 0; }
					assert.equal(parseInt(currentGuarantorsCount), parseInt(guarantorsCount));
				}
			});

			it('should force the owner to remove a guarantor ', async function() {
				const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await token.appendGuarantor(newLoanId, 5000, {from: guarantor});

				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await token.guarantorsCount(newLoanId); } catch (error) { guarantorsCount = 0; }
				try {
					await token.forceRemoveGuarantor(newLoanId, guarantor, {from: owner});
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await token.guarantorsCount(newLoanId); } catch (error) { currentGuarantorsCount = 0; }
					assert.isTrue(parseInt(currentGuarantorsCount) < parseInt(guarantorsCount));
				}
			});
		});

		describe('check guarantor on loan', async function () {

			before(async function() {
				await token.appendGuarantor(loanId, 5000, {from: guarantor})
			});

			it('should validate that the guarantor is on the loan', async function() {
				const isGuarantorOnLoan = await token.isGuarantorEngaged(loanId, guarantor);
				assert.isTrue(isGuarantorOnLoan);
			});

			it('should not validate that the guarantor is on the loan', async function() {
				const isGuarantorOnLoan = await token.isGuarantorEngaged(loanId, otherGuarantor);
				assert.isFalse(isGuarantorOnLoan);
			});

		});


		describe('replace', async function () {

			before(async function() {
				await token.addAddressToWhitelist(otherGuarantor, {from: owner});
				await token.appendGuarantor(loanId, 5000, {from: guarantor})
			});

			it('should replace a guarantor ', async function() {
				var isGuarantorOnLoan = await token.isGuarantorEngaged(loanId, guarantor);
				assert.isTrue(isGuarantorOnLoan);
				await token.replaceGuarantor(loanId, guarantor, {from: otherGuarantor});
				isGuarantorOnLoan = await token.isGuarantorEngaged(loanId, guarantor);
				assert.isFalse(isGuarantorOnLoan);
				isGuarantorOnLoan = await token.isGuarantorEngaged(loanId, otherGuarantor);
				assert.isTrue(isGuarantorOnLoan);
			});

		});

	});

});