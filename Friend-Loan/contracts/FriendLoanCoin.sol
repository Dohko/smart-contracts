pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import './LoanBurnableToken.sol';

contract FriendLoanCoin is MintableToken, LoanBurnableCoin {	// Textmate bundle fix => }

  string public name = "Friend Loan Coin";
  string public symbol = "FLC";
  uint8 public decimals = 2;
	
}