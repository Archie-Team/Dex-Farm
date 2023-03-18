//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Factory {
    address public feeTo;
    address public feeToSetter;
    address public BULC = 0x1603035964573375E9546fA2cDbed9Ad435865df;
    address public BUSD = 0x3afC77D320CB164134FC5afD73B8dB453813094a;
    mapping(address => mapping(address => address)) public getPair;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair
    );

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function createPair() external returns (address pair) {
        (address token0, address token1) = BULC < BUSD
            ? (BULC, BUSD)
            : (BUSD, BULC);
        require(token0 != address(0), "ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PAIR EXISTS"); // single check is sufficient
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        emit PairCreated(token0, token1, pair);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function ShowPair() external view returns (address) {
        return getPair[BULC][BUSD];
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
