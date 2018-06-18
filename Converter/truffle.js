var HDWalletProvider = require("truffle-hdwallet-provider");
var infura_apikey = "POn1GNcTEiSwT4PqPPcM";
var mnemonic = "voiture adverbe ventouse licorne bafouer bilingue replier abreuver camarade contact spécial usuel spacieux grogner romance";
// Address 0xFE21dfC55928Aa64dCd4547bB8D3FA676006E9B9

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 7545,
						gas: 325185,
            network_id: "*" // Match any network id
        },
		    ropsten:  {
		      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/" + infura_apikey),
		      network_id: 3,
		      gas: 325185
		    }
    },
		solc: {
	    	optimizer: {
		      enabled: true,
					runs: 200
	     }
	  }
};