// SPDX-License-Identifier: MIT   
pragma solidity ^0.8.0;

contract Base {
    function  f1() public view returns(uint, uint) {
        return (1, block.timestamp);
    }
    function  f2() public view returns(uint, uint) {
        return (1, block.timestamp);
    }

    function getF1CallName() external pure returns(bytes memory) {
        return abi.encodeWithSelector(this.f1.selector);
    }

    function getF2CallName() external pure returns(bytes memory) {
        return abi.encodeWithSelector(this.f2.selector);
    }
}

contract Multicall {
    function mcall(address[] calldata _targets, bytes[] calldata _data) public view returns(bytes[] memory) {
        require(_targets.length == _data.length, "require same param");

        bytes[] memory results =  new bytes[](_data.length);

        for (uint i; i < _targets.length; i++) {
            (bool sucess, bytes memory result) = _targets[i].staticcall(_data[i]);
            require(sucess, "call fail");
            results[i] = result;
        }
        return results;
    }
}