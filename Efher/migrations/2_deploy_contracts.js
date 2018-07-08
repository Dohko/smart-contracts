const EfherLib = artifacts.require("EfherLib");
const Efher = artifacts.require("Efher");

module.exports = function(deployer) {
  deployer.deploy(EfherLib);
	deployer.link(EfherLib, Efher);
  deployer.deploy(Efher);
};

