// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

contract MyWalletTest { 
    string public name;
    mapping (address => bool) private approved;
    address public owner;

    modifier auth {
        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    } 

    function transferOwnership(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require(_owner != _addr, "New owner is the same as the old owner");
        assembly {
            sstore(owner.slot, _addr)
        }
    }
}