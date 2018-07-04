const Efher = artifacts.require("Efher");

require('chai')
  .use(require('chai-as-promised'))
	.should();
	
contract('Efher', function(accounts) {
	let token;
	let owner = accounts[0];

  before(async function() {
		token = await Efher.deployed();
  });

	describe('behaviour', async function () {
		it('should deploy the contract and store the address', async function(){
			assert(token.address);
		});
		
		it('should be the first account that\'s the owner', async function () {
			let tokenOwner = await token.owner();
			tokenOwner.should.equal(owner);
		});
	});
	
});