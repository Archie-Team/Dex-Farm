pragma solidity ^0.8.0;

// SPDX-License-Identifier:MIT
interface ICountDown {
    function timestamp() external view returns (uint256);

    function lockTime(address sender, uint128 position)
        external
        view
        returns (uint128);
}

contract CountDown {
    enum staking {
        None,
        for1month,
        for3month,
        for6month,
        for12month
    }
    staking choice;
    mapping(address => mapping(uint128 => uint128)) public lockTime;
    mapping(address => uint64) public positions;

    modifier isExist(uint128 position) {
        require(
            lockTime[msg.sender][position] != 0 &&
                position <= positions[msg.sender],
            "this position dose not exist!"
        );
        _;
    }
    modifier isDone(uint128 position) {
        require(
            lockTime[msg.sender][position] < block.timestamp,
            "this stake position time dose not end yet!!!"
        );
        _;
    }
    modifier checkChoice(uint128 _choice) {
        require(_choice > 0 && _choice <= 5, "wrong Choise!!!");
        _;
    }

    function stakeFor(uint8 _choice, address sender)
        internal
        checkChoice(_choice)
        returns (uint256)
    {
        choice = staking(_choice);
        uint128 position = positions[sender];
        uint128 stakeEndTime;
        if (choice == staking(1)) {
            stakeEndTime = lockTime[sender][position] = uint128(
                block.timestamp + 30 days
            );
        } else if (choice == staking(2)) {
            stakeEndTime = lockTime[sender][position] = uint128(
                block.timestamp + 90 days
            );
        } else if (choice == staking(3)) {
            stakeEndTime = lockTime[sender][position] = uint128(
                block.timestamp + 182 days + 12 hours
            );
        } else if (choice == staking(4)) {
            stakeEndTime = lockTime[sender][position] = uint128(
                block.timestamp + 365 days
            );
        }
        positions[sender]++;
        return stakeEndTime;
    }

    function timestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function updatePositions(uint128 position_, address sender) internal {
        for (uint128 i = position_; i < positions[sender]; i++) {
            lockTime[msg.sender][i] = lockTime[msg.sender][i + 1];
        }
        positions[sender] -= 1;
    }
}
