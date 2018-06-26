const friendLoanLib = artifacts.require("FriendLoanLib");
const loanCoin = artifacts.require("FriendLoanCoin");

module.exports = function(deployer) {
  deployer.deploy(friendLoanLib);
	deployer.link(friendLoanLib, loanCoin);
  deployer.deploy(loanCoin);
};

