const FriendLoanCoin = artifacts.require("FriendLoanCoin");

require('chai')
  .use(require('chai-as-promised'))
	.should();
	

contract('FriendLoanCoin', function(accounts) {
  before(async function() {
		this.token = await FriendLoanCoin.deployed();
		await this.token.setMaxNbPayments(36);
		this.owner = accounts[0];
		this.otherAccount = accounts[1];
		
		
		this.loanTotalAmount = 100;
		this.loanMaxInterestRate = 10;
		this.loanNbPayments = 6;
		this.loanPaymentType = 2;

		this.borrower = accounts[2];
		this.guarantor = accounts[3];
		this.lenderOne = accounts[4];
		this.lenderTwo = accounts[5];
		
		await this.token.addAddressToWhitelist(this.borrower, {from: this.owner});
		await this.token.addAddressToWhitelist(this.guarantor, {from: this.owner});
		await this.token.addAddressToWhitelist(this.lenderOne, {from: this.owner});
		await this.token.addAddressToWhitelist(this.lenderTwo, {from: this.owner});
  });

	describe('lenders', async function () {

		beforeEach(async function() {
			const { logs } = await this.token.createLoan(this.loanTotalAmount, this.loanMaxInterestRate, this.loanNbPayments, this.loanPaymentType, {from: this.borrower});
			this.loanId = parseInt(logs[0].args.id);
			await this.token.appendGuarantor(this.loanId, this.loanTotalAmount, {from: this.guarantor});
		});

		describe('pending lender list', async function () {

			it('should include the new lender on the pending list', async function() {
				var [addresses, amounts, rates] = await this.token.pendingLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
				await this.token.appendLender(this.loanId, 10000, this.loanMaxInterestRate, {from: this.lenderOne});
				[addresses, amounts, rates] = await this.token.pendingLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
			});

			it('should not include the new lender on the pending list', async function() {
				var [addresses, amounts, rates] = await this.token.pendingLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
				await this.token.appendLender(this.loanId, 10000, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.removeLender(this.loanId, {from: this.lenderOne});
				[addresses, amounts, rates] = await this.token.pendingLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
			});
		});

		describe('append lender on pending list', async function () {
			async function appendLender(token, key, lender, amount, interest) {
				var addresses = [], amounts = [], rates = [];
				try { await token.appendLender(key, amount, interest, {from: lender}); }catch (error) {addresses = [], amounts = [], rates = [];}
				finally {
					try { [addresses, amounts, rates] = await token.pendingLendersList(key); } catch (error) { addresses, amounts, rates = [];}
					return addresses.includes(lender);
				}
			}

			it('should append a lender on pending list', async function() {
				const append = await appendLender(this.token, this.loanId, this.lenderOne, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isTrue(append);
			});

			it('should not append a lender when the loan is not created', async function() {
				const append = await appendLender(this.token, 100000, this.lenderOne, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when the loan has started', async function() {
				var append = await appendLender(this.token, this.loanId, this.lenderOne, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isTrue(append);
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				await this.token.startLoan(this.loanId, {from: this.borrower});
				append = await appendLender(this.token, this.loanId, this.lenderTwo, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when lender is the borrower', async function() {
				const append = await appendLender(this.token, this.loanId, this.borrower, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when the interest provided is bigger of the loan max interest rate', async function() {
				const append = await appendLender(this.token, this.loanId, this.lenderOne, this.loanTotalAmount, this.loanMaxInterestRate + 1);
				assert.isFalse(append);
			});

			it('should not append a lender when he is already on the pending list', async function() {
				var append = await appendLender(this.token, this.loanId, this.lenderOne, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isTrue(append);
				append = await appendLender(this.token, this.loanId, this.borrower, this.loanTotalAmount, this.loanMaxInterestRate);
				assert.isFalse(append);
			});
		});

		describe('remove lender on pending list', async function () {

			beforeEach(async function() {
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
			});

			async function removeLender(token, key, lender) {
				var addresses = [], amounts = [], rates = [];
				try { await token.removeLender(key, {from: lender}); } catch (error) {addresses = [], amounts = [], rates = [];}
				finally {
					try { [addresses, amounts, rates] = await token.pendingLendersList(key); } catch (error) { addresses, amounts, rates = [];}
					return addresses.includes(lender);
				}
			}

			it('should remove a lender on pending list', async function() {
				const isAlreadyOnList = await removeLender(this.token, this.loanId, this.lenderOne);
				assert.isFalse(isAlreadyOnList);
			});

			it('should not remove a lender when the loan is not created', async function() {
				const isAlreadyOnList = await removeLender(this.token, 100000, this.lenderOne);
				assert.isFalse(isAlreadyOnList);
			});

			it('should not remove a lender when the loan has started', async function() {
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				await this.token.startLoan(this.loanId, {from: this.borrower});
				const isAlreadyOnList = await removeLender(this.token, this.loanId, this.lenderOne);
				assert.isTrue(isAlreadyOnList);
			});

			it('should not remove a lender when he is not on the pending list', async function() {
				const isAlreadyOnList = await removeLender(this.token, this.loanId, this.lenderTwo);
				assert.isFalse(isAlreadyOnList);
			});
		});

		describe('approved lender list', async function () {
			beforeEach(async function() {
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
			});

			it('should include the lender on the approved list', async function() {
				var [addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				[addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
			});

			it('should not include the lender on the approved list', async function() {
				var [addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				[addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
				await this.token.removeApprovedLender(this.loanId, this.lenderOne, {from: this.borrower});
				[addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
			});

			it('should not anymore include the lender on the approved list where he is removed himself', async function() {
				var [addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
				await this.token.approveLender(this.loanId, this.lenderOne, {from: this.borrower});
				[addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
				await this.token.removeLender(this.loanId, {from: this.lenderOne});
				[addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isFalse(addresses.includes(this.lenderOne));
			});
		});

		describe('approve a lender', async function () {
			beforeEach(async function() {
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
			});

			async function approveLender(token, key, lender, from) {
				var addresses = [];
				try { await token.approveLender(key, lender, { from }); } catch (error) {}
				try { [addresses] = await token.approvedLendersList(key); } catch (error) {}
				return addresses.includes(lender);
			}

			it('should approve a lender', async function() {
				const approved = await approveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isTrue(approved);
			});

			it('should not approve a lender when the loan is not created', async function() {
				const approved = await approveLender(this.token, 10000, this.lenderOne, this.borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender when the loan has started', async function() {
				var approved = await approveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isTrue(approved);
				await this.token.startLoan(this.loanId, {from: this.borrower});
				approved = await approveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender if the sender is not the borrower', async function() {
				var approved = await approveLender(this.token, this.loanId, this.lenderOne, this.lenderOne);
				assert.isFalse(approved);
			});

			it('should not approve a lender if a guarantee is not equal to the loan\' amount', async function() {
				await this.token.removeGuarantor(this.loanId, {from: this.guarantor});
				var approved = await approveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender if the lend amount has already been reached', async function() {
				await approveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderTwo});
				var approved = await approveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender who\'s not on the pending list', async function() {
				var approved = await approveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(approved);
			});

			it('should not approve an already approved lender', async function() {
				await approveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				var [addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isTrue(addresses.length == 1);
				try {
					await this.token.approveLender(this.loanId, this.lenderOne, { from: this.borrower });
				}
				catch (error) {}
				finally {
					[addresses] = await this.token.approvedLendersList(this.loanId);
					assert.isTrue(addresses.length == 1);
				}
			});
		});
		
		describe('remove an approved lender', async function () {
			beforeEach(async function() {
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, { from: this.borrower });
			});
			
			async function disapproveLender(token, key, lender, from) {
				var addresses = [];
				try { await token.removeApprovedLender(key, lender, { from }); } catch (error) {}
				try { [addresses] = await token.approvedLendersList(key); } catch (error) {}
				return addresses.includes(lender);
			}
			
			it('should remove an approved lender', async function() {
				const alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isFalse(alreadyOnList);
			});

			it('should not remove an approved lender from a nonexistent loan', async function() {
				await disapproveLender(this.token, 10000, this.lenderOne, this.borrower);
				const [addresses] = await this.token.approvedLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
			});

			it('should not remove an approved lender from a started loan', async function() {
				await this.token.startLoan(this.loanId, {from: this.borrower});
				const alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isTrue(alreadyOnList);
			});

			it('should not remove an approved lender when sender is not the borrower', async function() {
				const alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderOne, this.lenderOne);
				assert.isTrue(alreadyOnList);
			});

			it('should not remove an approved lender who\'s not on the pending list', async function() {
				const alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(alreadyOnList);
			});

			it('should not remove an approved lender who\'s not on the approved list', async function() {
				await this.token.appendLender(this.loanId, this.loanTotalAmount, this.loanMaxInterestRate, {from: this.lenderTwo});
				const alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(alreadyOnList);
			});
			
			it('should remove an approved lender when its lend amount was greater at the beginning than the amount requested', async function() {
				await this.token.removeLender(this.loanId, {from: this.lenderOne});
				
				const amountLenderOne = this.loanTotalAmount - 40;
				const amountLenderTwo = this.loanTotalAmount;
				await this.token.appendLender(this.loanId, amountLenderOne, this.loanMaxInterestRate, {from: this.lenderOne});
				await this.token.approveLender(this.loanId, this.lenderOne, { from: this.borrower });
				
				await this.token.appendLender(this.loanId, amountLenderTwo, this.loanMaxInterestRate, {from: this.lenderTwo});
				await this.token.approveLender(this.loanId, this.lenderTwo, { from: this.borrower });
				
				await this.token.removeApprovedLender(this.loanId, this.lenderOne, {from: this.borrower});
				await this.token.removeApprovedLender(this.loanId, this.lenderTwo, {from: this.borrower});
				
				var alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderOne, this.borrower);
				assert.isFalse(alreadyOnList);
				alreadyOnList = await disapproveLender(this.token, this.loanId, this.lenderTwo, this.borrower);
				assert.isFalse(alreadyOnList);
				
				var [addresses, amounts, rates] = await this.token.pendingLendersList(this.loanId);
				assert.isTrue(addresses.includes(this.lenderOne));
				assert.isTrue(addresses.includes(this.lenderTwo));
				assert.isTrue(amounts[0] == this.loanTotalAmount - 40);
				assert.isTrue(amounts[1] == this.loanTotalAmount - amountLenderOne); // the lenderTwo lend amount was updated
			});
			
		});
		
	});

});