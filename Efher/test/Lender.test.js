const Efher = artifacts.require("Efher");

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
	const guarantor = accounts[3];
	const lenderOne = accounts[4];
	const lenderTwo = accounts[5];
	
  before(async function() {
		token = await Efher.deployed();
		await token.setMaxNbPayments(36);
		
		await token.addAddressToWhitelist(borrower, {from: owner});
		await token.addAddressToWhitelist(guarantor, {from: owner});
		await token.addAddressToWhitelist(lenderOne, {from: owner});
		await token.addAddressToWhitelist(lenderTwo, {from: owner});
  });

	describe('lenders', async function () {

		beforeEach(async function() {
			const { logs } = await token.createLoan(loanTotalAmount, loanMaxInterestRate, loanNbPayments, loanPaymentType, {from: borrower});
			loanId = parseInt(logs[0].args.id);
			await token.appendGuarantor(loanId, loanTotalAmount, {from: guarantor, value: loanTotalAmount});
		});

		describe('pending lender list', async function () {

			it('should include the new lender on the pending list', async function() {
				var [addresses, amounts, rates] = await token.pendingLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
				const amount = 50;
				await token.appendLender(loanId, amount, loanMaxInterestRate, {from: lenderOne, value: amount});
				[addresses, amounts, rates] = await token.pendingLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
			});

			it('should not include the new lender on the pending list', async function() {
				var [addresses, amounts, rates] = await token.pendingLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
				const amount = 50;
				await token.appendLender(loanId, amount, loanMaxInterestRate, {from: lenderOne, value: amount});
				await token.removeLender(loanId, {from: lenderOne});
				[addresses, amounts, rates] = await token.pendingLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
			});
		});

		describe('append lender on pending list', async function () {
			async function appendLender(token, key, lender, amount, interest) {
				var addresses = [], amounts = [], rates = [];
				try { await token.appendLender(key, amount, interest, {from: lender, value: amount}); }catch (error) {addresses = [], amounts = [], rates = [];}
				finally {
					try { [addresses, amounts, rates] = await token.pendingLendersList(key); } catch (error) { addresses, amounts, rates = [];}
					return addresses.includes(lender);
				}
			}

			it('should append a lender on pending list', async function() {
				const append = await appendLender(token, loanId, lenderOne, loanTotalAmount, loanMaxInterestRate);
				assert.isTrue(append);
			});

			it('should not append a lender when the loan is not created', async function() {
				const append = await appendLender(token, 100000, lenderOne, loanTotalAmount, loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when the loan has started', async function() {
				var append = await appendLender(token, loanId, lenderOne, loanTotalAmount, loanMaxInterestRate);
				assert.isTrue(append);
				await token.approveLender(loanId, lenderOne, {from: borrower});
				await token.startLoan(loanId, {from: borrower});
				append = await appendLender(token, loanId, lenderTwo, loanTotalAmount, loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when lender is the borrower', async function() {
				const append = await appendLender(token, loanId, borrower, loanTotalAmount, loanMaxInterestRate);
				assert.isFalse(append);
			});

			it('should not append a lender when the interest provided is bigger of the loan max interest rate', async function() {
				const append = await appendLender(token, loanId, lenderOne, loanTotalAmount, loanMaxInterestRate + 1);
				assert.isFalse(append);
			});

			it('should not append a lender when he is already on the pending list', async function() {
				var append = await appendLender(token, loanId, lenderOne, loanTotalAmount, loanMaxInterestRate);
				assert.isTrue(append);
				append = await appendLender(token, loanId, borrower, loanTotalAmount, loanMaxInterestRate);
				assert.isFalse(append);
			});
		});

		describe('remove lender on pending list', async function () {

			beforeEach(async function() {
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne, value: loanTotalAmount});
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
				const isAlreadyOnList = await removeLender(token, loanId, lenderOne);
				assert.isFalse(isAlreadyOnList);
			});

			it('should not remove a lender when the loan is not created', async function() {
				const isAlreadyOnList = await removeLender(token, 100000, lenderOne);
				assert.isFalse(isAlreadyOnList);
			});

			it('should not remove a lender when the loan has started', async function() {
				await token.approveLender(loanId, lenderOne, {from: borrower});
				await token.startLoan(loanId, {from: borrower});
				const isAlreadyOnList = await removeLender(token, loanId, lenderOne);
				assert.isTrue(isAlreadyOnList);
			});

			it('should not remove a lender when he is not on the pending list', async function() {
				const isAlreadyOnList = await removeLender(token, loanId, lenderTwo);
				assert.isFalse(isAlreadyOnList);
			});
		});

		describe('approved lender list', async function () {
			beforeEach(async function() {
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne, value: loanTotalAmount});
			});

			it('should include the lender on the approved list', async function() {
				var [addresses] = await token.approvedLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
				await token.approveLender(loanId, lenderOne, {from: borrower});
				[addresses] = await token.approvedLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
			});

			it('should not include the lender on the approved list', async function() {
				var [addresses] = await token.approvedLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
				await token.approveLender(loanId, lenderOne, {from: borrower});
				[addresses] = await token.approvedLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
				await token.removeApprovedLender(loanId, lenderOne, {from: borrower});
				[addresses] = await token.approvedLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
			});

			it('should not anymore include the lender on the approved list where he is removed himself', async function() {
				var [addresses] = await token.approvedLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
				await token.approveLender(loanId, lenderOne, {from: borrower});
				[addresses] = await token.approvedLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
				await token.removeLender(loanId, {from: lenderOne});
				[addresses] = await token.approvedLendersList(loanId);
				assert.isFalse(addresses.includes(lenderOne));
			});
		});

		describe('approve a lender', async function () {
			beforeEach(async function() {
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne, value: loanTotalAmount});
			});

			async function approveLender(token, key, lender, from) {
				var addresses = [];
				try { await token.approveLender(key, lender, { from }); } catch (error) {}
				try { [addresses] = await token.approvedLendersList(key); } catch (error) {}
				return addresses.includes(lender);
			}

			it('should approve a lender', async function() {
				const approved = await approveLender(token, loanId, lenderOne, borrower);
				assert.isTrue(approved);
			});

			it('should not approve a lender when the loan is not created', async function() {
				const approved = await approveLender(token, 10000, lenderOne, borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender when the loan has started', async function() {
				var approved = await approveLender(token, loanId, lenderOne, borrower);
				assert.isTrue(approved);
				await token.startLoan(loanId, {from: borrower});
				approved = await approveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender if the sender is not the borrower', async function() {
				var approved = await approveLender(token, loanId, lenderOne, lenderOne);
				assert.isFalse(approved);
			});

			it('should not approve a lender if a guarantee is not equal to the loan\' amount', async function() {
				await token.removeGuarantor(loanId, {from: guarantor});
				var approved = await approveLender(token, loanId, lenderOne, borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender if the lend amount has already been reached', async function() {
				await approveLender(token, loanId, lenderOne, borrower);
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderTwo, value: loanTotalAmount});
				var approved = await approveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(approved);
			});

			it('should not approve a lender who\'s not on the pending list', async function() {
				var approved = await approveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(approved);
			});

			it('should not approve an already approved lender', async function() {
				await approveLender(token, loanId, lenderOne, borrower);
				var [addresses] = await token.approvedLendersList(loanId);
				assert.isTrue(addresses.length == 1);
				try {
					await token.approveLender(loanId, lenderOne, { from: borrower });
				}
				catch (error) {}
				finally {
					[addresses] = await token.approvedLendersList(loanId);
					assert.isTrue(addresses.length == 1);
				}
			});
		});

		describe('remove an approved lender', async function () {
			beforeEach(async function() {
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderOne, value: loanTotalAmount});
				await token.approveLender(loanId, lenderOne, { from: borrower });
			});

			async function disapproveLender(token, key, lender, from) {
				var addresses = [];
				try { await token.removeApprovedLender(key, lender, { from }); } catch (error) {}
				try { [addresses] = await token.approvedLendersList(key); } catch (error) {}
				return addresses.includes(lender);
			}

			it('should remove an approved lender', async function() {
				const alreadyOnList = await disapproveLender(token, loanId, lenderOne, borrower);
				assert.isFalse(alreadyOnList);
			});

			it('should not remove an approved lender from a nonexistent loan', async function() {
				await disapproveLender(token, 10000, lenderOne, borrower);
				const [addresses] = await token.approvedLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
			});

			it('should not remove an approved lender from a started loan', async function() {
				await token.startLoan(loanId, {from: borrower});
				const alreadyOnList = await disapproveLender(token, loanId, lenderOne, borrower);
				assert.isTrue(alreadyOnList);
			});

			it('should not remove an approved lender when sender is not the borrower', async function() {
				const alreadyOnList = await disapproveLender(token, loanId, lenderOne, lenderOne);
				assert.isTrue(alreadyOnList);
			});

			it('should not remove an approved lender who\'s not on the pending list', async function() {
				const alreadyOnList = await disapproveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(alreadyOnList);
			});

			it('should not remove an approved lender who\'s not on the approved list', async function() {
				await token.appendLender(loanId, loanTotalAmount, loanMaxInterestRate, {from: lenderTwo, value: loanTotalAmount});
				const alreadyOnList = await disapproveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(alreadyOnList);
			});

			it('should remove an approved lender when its lend amount was greater at the beginning than the amount requested', async function() {
				await token.removeLender(loanId, {from: lenderOne});

				const amountLenderOne = loanTotalAmount - 40;
				const amountLenderTwo = loanTotalAmount;
				await token.appendLender(loanId, amountLenderOne, loanMaxInterestRate, {from: lenderOne, value: amountLenderOne});
				await token.approveLender(loanId, lenderOne, { from: borrower });

				await token.appendLender(loanId, amountLenderTwo, loanMaxInterestRate, {from: lenderTwo, value: amountLenderTwo});
				await token.approveLender(loanId, lenderTwo, { from: borrower });

				await token.removeApprovedLender(loanId, lenderOne, {from: borrower});
				await token.removeApprovedLender(loanId, lenderTwo, {from: borrower});

				var alreadyOnList = await disapproveLender(token, loanId, lenderOne, borrower);
				assert.isFalse(alreadyOnList);
				alreadyOnList = await disapproveLender(token, loanId, lenderTwo, borrower);
				assert.isFalse(alreadyOnList);

				var [addresses, amounts, rates] = await token.pendingLendersList(loanId);
				assert.isTrue(addresses.includes(lenderOne));
				assert.isTrue(addresses.includes(lenderTwo));
				assert.isTrue(amounts[0] == amountLenderOne);
				assert.isTrue(amounts[1] == amountLenderTwo); // the lenderTwo initial lend amount isn't updated anymore!
			});

		});
		
	});

});