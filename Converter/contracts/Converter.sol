pragma solidity ^0.4.24;

import "./Ownable.sol";


/**
 * @title Converter ETH / US DOLLAR
*/
contract Converter is Ownable {

  uint256 constant FD = 10 ** 4; // Four decimals
  uint256 constant ETHER = 10 ** 18;
	
	uint256 public sellRate; // sell eth for US dollar
	uint256 public buyRate; // buy US dollar for eth
	
	/**
   * @dev Function to compute ETH for US Dollar
   * @param _dollar The amount of US dollar (in WEI) to change.
   * @return The amount of ETH to receive
   */
	function buy(
		uint256 _dollar
	)
	 external
	 view
	 returns (uint256)
	{
		return ((_dollar * FD) * buyRate) / FD;
	}

	/**
   * @dev Function to compute US Dollar for ETH 
   * @param _eth The amount of ETH (in WEI) to change.
   * @return The amount of US dollar to receive
   */
	function sell(
		uint256 _eth
	)
	 external
	 view
	 returns (uint256)
	{
		return (((_eth * ETHER) * sellRate) / ETHER) / ETHER;
	}
	
	/**
   * @dev Function to update the sell and buy rate value
   * @param _newSellRate The new sell rate in US dollar (WEI formatted).
   * @param _newBuyRate The new buy rate in ETH (WEI formatted).
   */
	function changeRates(
		uint256 _newSellRate,
		uint256 _newBuyRate
	)
		external
		onlyOwner
	{
		require(_newSellRate > 0);
		require(_newBuyRate > 0);
		
		sellRate = _newSellRate;
		buyRate = _newBuyRate;
	}
	
}
