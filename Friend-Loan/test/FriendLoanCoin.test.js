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
	
});