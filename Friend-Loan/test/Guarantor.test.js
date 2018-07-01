const FriendLoanCoin = artifacts.require("FriendLoanCoin");

require('chai')
  .use(require('chai-as-promised'))
	.should();
	
contract('FriendLoanCoin', function(accounts) {
  before(async function() {
		this.token = await FriendLoanCoin.deployed();
		this.owner = accounts[0];
		this.otherAccount = accounts[1];
		
		await this.token.setMaxNbPayments(36);
		
		this.loanTotalAmount = 100;
		this.loanMaxInterestRate = 10;
		this.loanNbPayments = 6;
		this.loanPaymentType = 2;

		this.borrower = accounts[0];
		this.otherBorrower = accounts[4];
		this.guarantor = accounts[1];
		this.otherGuarantor = accounts[5];
		this.lenderOne = accounts[2];
		this.lenderTwo = accounts[3];
  });

		
	describe('guarantors', async function () {
		before(async function() {
			await this.token.addAddressToWhitelist(this.borrower, {from: this.owner});
			await this.token.addAddressToWhitelist(this.guarantor, {from: this.owner});
			await this.token.addAddressToWhitelist(this.otherBorrower, {from: this.owner});
			await this.token.addAddressToWhitelist(this.lenderOne, {from: this.owner});

			const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			this.loanId = parseInt(logs[0].args.id);
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
				const increased = await hasGuarantorsCountBeenIncreased(this.token, this.loanId, 10000, this.guarantor);
				assert.isTrue(increased);
			});

			it('should not append a guarantor when the loan wasn\'t created', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(this.token, 99, 10000, this.guarantor);
				assert.isFalse(increased);
			});

			it('should not append a guarantor when the loan has started', async function() {
				const currentMaxNbPayments = await this.token.maxNbPayments();
				const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.otherBorrower});
				const newLoanId = parseInt(logs[0].args.id);
				var increased = await hasGuarantorsCountBeenIncreased(this.token, newLoanId, 10000, this.guarantor);
				assert.isTrue(increased);
				await this.token.appendLender(newLoanId, 10000, this.loanMaxInterestRate, {from: this.lenderOne})
				await this.token.approveLender(newLoanId, this.lenderOne, {from: this.otherBorrower});
				await this.token.startLoan(newLoanId, {from: this.otherBorrower});
				increased = await hasGuarantorsCountBeenIncreased(this.token, newLoanId, 10000, this.otherGuarantor);
				assert.isFalse(increased);
			});

			it('should not append a guarantor is the borrower too', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(this.token, this.loanId, 10000, this.borrower);
				assert.isFalse(increased);
			});

			it('should not append a guarantor if the guarantee is 0', async function() {
				const increased = await hasGuarantorsCountBeenIncreased(this.token, this.loanId, 0, this.guarantor);
				assert.isFalse(increased);
			});
		});

		describe('remove', async function () {
			before(async function() {
				await this.token.appendGuarantor(this.loanId, 5000, {from: this.guarantor})
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
				const decreased = await hasGuarantorsCountBeenDecreased(this.token, this.loanId, this.guarantor);
				assert.isTrue(decreased);
			});

			it('should not remove a guarantor when the loan wasn\'t created', async function() {
				const decreased = await hasGuarantorsCountBeenDecreased(this.token, 99, this.guarantor);
				assert.isFalse(decreased);
			});

			it('should not remove a guarantor when the loan has started', async function() {
				const currentMaxNbPayments = await this.token.maxNbPayments();
				const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await this.token.appendGuarantor(newLoanId, 10000, {from: this.guarantor})
				await this.token.appendLender(newLoanId, 10000, this.loanMaxInterestRate, {from: this.lenderOne})
				await this.token.approveLender(newLoanId, this.lenderOne, {from: this.borrower})
				await this.token.startLoan(newLoanId, {from: this.borrower});
				const decreased = await hasGuarantorsCountBeenDecreased(this.token, newLoanId, this.guarantor);
				assert.isFalse(decreased);
			});

			it('should not remove a guarantor if not engaged on the loan', async function() {
				const decreased = await hasGuarantorsCountBeenDecreased(this.token, 99, this.otherGuarantor);
				assert.isFalse(decreased);
			});

			it('should prevent a non-owner to remove a guarantor', async function() {
				const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await this.token.appendGuarantor(newLoanId, 5000, {from: this.guarantor})

				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await this.token.guarantorsCount(newLoanId); } catch (error) { guarantorsCount = 0; }
				try {
					await this.token.forceRemoveGuarantor(newLoanId, this.guarantor, {from: this.guarantor});
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await this.token.guarantorsCount(newLoanId); } catch (error) { currentGuarantorsCount = 0; }
					assert.equal(parseInt(currentGuarantorsCount), parseInt(guarantorsCount));
				}
			});

			it('should force the owner to remove a guarantor ', async function() {
				const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
				const newLoanId = parseInt(logs[0].args.id);
				await this.token.appendGuarantor(newLoanId, 5000, {from: this.guarantor});

				var guarantorsCount = 0;
				var currentGuarantorsCount = 0;
				try { guarantorsCount = await this.token.guarantorsCount(newLoanId); } catch (error) { guarantorsCount = 0; }
				try {
					await this.token.forceRemoveGuarantor(newLoanId, this.guarantor, {from: this.owner});
				}
				catch (error) {}
				finally {
					try { currentGuarantorsCount = await this.token.guarantorsCount(newLoanId); } catch (error) { currentGuarantorsCount = 0; }
					assert.isTrue(parseInt(currentGuarantorsCount) < parseInt(guarantorsCount));
				}
			});
		});

		describe('check guarantor on loan', async function () {

			before(async function() {
				await this.token.appendGuarantor(this.loanId, 5000, {from: this.guarantor})
			});

			it('should validate that the guarantor is on the loan', async function() {
				const isGuarantorOnLoan = await this.token.isGuarantorEngaged(this.loanId, this.guarantor);
				assert.isTrue(isGuarantorOnLoan);
			});

			it('should not validate that the guarantor is on the loan', async function() {
				const isGuarantorOnLoan = await this.token.isGuarantorEngaged(this.loanId, this.otherGuarantor);
				assert.isFalse(isGuarantorOnLoan);
			});

		});


		describe('replace', async function () {

			before(async function() {
				await this.token.addAddressToWhitelist(this.otherGuarantor, {from: this.owner});
				await this.token.appendGuarantor(this.loanId, 5000, {from: this.guarantor})
			});

			it('should replace a guarantor ', async function() {
				var isGuarantorOnLoan = await this.token.isGuarantorEngaged(this.loanId, this.guarantor);
				assert.isTrue(isGuarantorOnLoan);
				await this.token.replaceGuarantor(this.loanId, this.guarantor, {from: this.otherGuarantor});
				isGuarantorOnLoan = await this.token.isGuarantorEngaged(this.loanId, this.guarantor);
				assert.isFalse(isGuarantorOnLoan);
				isGuarantorOnLoan = await this.token.isGuarantorEngaged(this.loanId, this.otherGuarantor);
				assert.isTrue(isGuarantorOnLoan);
			});

		});

	});

});