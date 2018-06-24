const loanCoin = artifacts.require("FriendLoanCoin");

module.exports = function(deployer) {
  deployer.deploy(loanCoin);
};

