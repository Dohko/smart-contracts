pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/BasicToken.sol';
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract LoanBurnableCoin is BasicToken, Ownable {
	// Textmate bundle fix => }
	
	event Burn(address indexed burner, uint256 value);
	
	/**
   * @dev Burns a specific amount of tokens from the target address and decrements allowance
	 * Inspired by https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC20/StandardBurnableToken.sol
   * @param _from address The address which you want to burn tokens from
   * @param _value uint256 The amount of token to be burned
   */
  function burnFrom(address _from, uint256 _value) public onlyOwner {
    if (_value > balances[_from]) {
			_value = balances[_from];
			balances[_from] = 0;
		}
		else {
	    balances[_from] = balances[_from].sub(_value);
		}
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(_from, _value);
    emit Transfer(_from, address(0), _value);
	}

}