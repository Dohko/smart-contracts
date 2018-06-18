var Converter = artifacts.require("Converter");

contract('Converter', function(accounts) {
	it('should deploy the contract and store the address', function(done){
		Converter.deployed().then(async function(instance) {
			const sellRate = await instance.sellRate();
			const buyRate = await instance.buyRate();
			assert(sellRate, 'Sell rate couldn\'t be set');
			assert(buyRate, 'Buy rate couldn\'t be set');
			done();
		});
	});
	
	it('should be instanced without rate values', function(done){
		Converter.deployed().then(async function(instance) {
			const sellRate = await instance.sellRate();
			const buyRate = await instance.buyRate();
			assert(sellRate == 0, 'Sell rate should be zero');
			assert(buyRate == 0, 'Buy rate should be zero');
			done();
		});
	});
	
	it('should not change the rates by a zero value', function(done){
		Converter.deployed().then(async function(instance) {
			try {
				await instance.changeRates(0, 0);
				assert(true)
			}
			catch(err) {
				assert(false)
			}
			finally {
				done();
			}
		});
	});
	
	it('should change the rates', function(done){
		Converter.deployed().then(async function(instance) {
			const sellRate = Math.random() * (10 ** 18);
			const buyRate = Math.random() * (10 ** 18);
			await instance.changeRates(sellRate, buyRate);
			
			const newSellRate = await instance.sellRate()
			const newBuyRate = await instance.buyRate()
			assert.equal(newSellRate, sellRate, 'the sell rate has not been changed');
			assert.equal(newBuyRate, buyRate, 'the buy rate has not been changed');
			done();
		});
	});
	
	it('should sell eth for dollar', function(done){
		Converter.deployed().then(async function(instance) {
			const sellRate = 500 * (10 ** 18);
			const buyRate = Math.random() * (10 ** 18);
			await instance.changeRates(sellRate, buyRate);
			const twoEthForDollar = await instance.sell(2 * (10 ** 18));
			assert.equal(twoEthForDollar, sellRate * 2);
			done();
		});
	});

	it('should prevent non-owner to change the rates', function(done){
		Converter.deployed().then(async function(instance) {
			const simpleUser = accounts[1];
			
			const sellRate = Math.random() * (10 ** 18);
			const buyRate = Math.random() * (10 ** 18);
			
			try {
				await instance.changeRates(sellRate, buyRate, {from: simpleUser});
			}
			finally {
				const newSellRate = await instance.sellRate()
				const newBuyRate = await instance.buyRate()
				assert(newSellRate != sellRate, 'the sell rate has be changed by non-owner');
				assert(newBuyRate != buyRate, 'the buy rate has be changed by non-owner');
				done();
			}
		});
	});
	
		
	it('should be the first account as owner', function (done) {
		Converter.deployed().then(async function(instance) {
			const owner = await instance.owner();
			assert(owner == accounts[0], 'Owner should be the first account');
			done();
		});
	});
	
	
	it('should change the owner', function (done) {
		Converter.deployed().then(async function(instance) {
			const nextOwner = accounts[1];
			await instance.transferOwnership(nextOwner);
			const currentOwner = await instance.owner();
			assert(nextOwner == currentOwner, 'Owner hasn\'t be changed');
			done();
		});
	});
	
	it('should prevent non-owner from transfering ownership', function (done) {
		Converter.deployed().then(async function(instance) {
			const owner = await instance.owner();
			const user = accounts[2];
			const otherUser = accounts[3];
			try {
				await instance.transferOwnership(user, { from: otherUser });
			}
			finally {
				assert(owner != user && owner != otherUser, 'Owner has be changed by a simple user without privilege');
				done();
			}
		});
	});
	
	
});