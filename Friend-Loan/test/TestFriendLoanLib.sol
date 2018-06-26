pragma solidity ^0.4.24;

import "truffle/Assert.sol";  
import "../contracts/FriendLoanLib.sol";
import "./utils/ThrowProxy.sol";
import "./mocks/LoanCreatorMock.sol";

contract TestFriendLoanLib { // Textmate bundle fix => }
	using FriendLoanLib for FriendLoanLib.Loan;
	using FriendLoanLib for FriendLoanLib.Data;

	FriendLoanLib.Data private data;

	uint8 private index = 1;
	
	function createLoan(
		uint256 _index,
		uint256 _amount,
    uint8 _maxInterestRate,
    uint8 _nbPayments,
    uint8 _paymentType
	)
		private
		returns(bool)
	{
		LoanCreatorMock thrower = new LoanCreatorMock();
		ThrowProxy throwProxy = new ThrowProxy(address(thrower)); //set Thrower as the contract to forward requests to. The target.

    // Act
    LoanCreatorMock(address(throwProxy)).createLoan(_index, _amount, _maxInterestRate, _nbPayments, _paymentType); //prime the proxy.
    // execute the call that is supposed to throw.
    // success will be false if it threw. success will be true if it didn't.
    // make sure you send enough gas for your contract method.
    bool success = throwProxy.execute.gas(200000)();
		return success;
	}
	
  function testCouldNotCreateLoanWhenZeroMaxNbPayments() public {
    // Arrange
    uint256 _amount = 10;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 2;
    uint8 _paymentType = 2;

    // Act
    bool success = createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);

    // Assert
    Assert.equal(uint(data.maxNbPayments), 0, "The max number of payments is zero");
    Assert.isFalse(success, "the loan cannot be created when the nbPayments is bigger of maxNbPayments");
  }

  function testShouldUpdateMaxNbPayments() public {
    // Arrange
    uint8 _maxNbPayments = 36;

    // Act
		data.setMaxNbPayments(_maxNbPayments);

    // Assert
    Assert.equal(uint(data.maxNbPayments), _maxNbPayments, "The max number of payments has been updated");
  }

  function testCouldNotCreateLoanWhenZeroAmount() public {
    // Arrange
    uint256 _amount = 0;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 2;
    uint8 _paymentType = 2;

    // Act
    bool success = createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);

    // Assert
    Assert.isFalse(success, "the loan cannot be created when the amount is zero");
  }

  function testCouldNotCreateLoanWhenZeroNbPayment() public {
    // Arrange
    uint256 _amount = 10;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 0;
    uint8 _paymentType = 2;

    // Act
    bool success = createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);

    // Assert
    Assert.isFalse(success, "the loan cannot be created when the number of payment is zero");
  }
	
  function testCouldNotCreateLoanWhenPaymentTypeIsInvalid() public {
    // Arrange
    uint256 _amount = 10;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 2;
    uint8 _paymentType = 3;

    // Act
    bool success = createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);

    // Assert
    Assert.isFalse(success, "the loan cannot be created when the payment type is invalid");
  }

  function testCreateLoan() public {
    // Arrange
    uint256 _amount = 10;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 2;
    uint8 _paymentType = 2;

    // Act
		FriendLoanLib.Loan memory loan = data.createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);
		index++;

    // Assert
    Assert.equal(loan.borrower, msg.sender, "The loan and its borrower should be created");
  }

  function testCountOfLoans() public {
    // Arrange
    uint256 _amount = 10;
    uint8 _maxInterestRate = 10;
    uint8 _nbPayments = 2;
    uint8 _paymentType = 2;

    // Act
		data.createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);
		index++;
		data.createLoan(index, _amount, _maxInterestRate, _nbPayments, _paymentType);
		index++;

    // Assert
    Assert.equal(data.loans.length, index - 1, "The loans should be append to data");
  }

}