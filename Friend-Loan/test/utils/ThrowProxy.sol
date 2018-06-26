pragma solidity ^0.4.24;

// see https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests

// Proxy contract for testing throws
contract ThrowProxy { // Textmate bundle fix => }
  address public target;
  bytes data;

  constructor(address _target) public {
    target = _target;
  }

  //prime the data using the fallback function.
  function() public {
    data = msg.data;
  }

  function execute() public returns (bool) {
    return target.call(data);
  }
}
