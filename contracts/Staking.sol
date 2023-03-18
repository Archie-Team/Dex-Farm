// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "./UniswapV2Library.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./CountDown.sol";

// import "./CountDown.sol";

contract Staking is Ownable, ReentrancyGuard, CountDown {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    address public pair; //PAIR ADDRESS
    IERC20 public rewardToken; //REWARD TOKEN ADDRESS
    IERC20 public stakingToken; //LP TOKEN ADDRESS

    uint256 public StakedRewardFreezed = 0; //FREEZED STAKE REWARD
    uint256 public StakedReward; //FREE STAKE REWAED
    uint256 public totalValueLockLPToken; // LP TOKEN LoCKED
    uint256 public totalValueLockBUSD; //LP TOKEN LoCKED PER BUSD
    mapping(address => uint256) public AllStakedBalance; // stake = {};
    mapping(address => mapping(uint32 => uint256)) public stakedBalance; // stake = {};
    mapping(address => mapping(uint32 => uint8)) public stakedChoise; // choise = {};

    event Stake(address indexed user, uint256 amount, uint256 endTime);
    event Unstake(address indexed user, uint256 amount, uint256 reward);
    event ClaimReward(address indexed user, uint256 reward);
    event Distribute(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken) {
        /* ======= PAIR AND LPTOKEN HAVE SAVE ADDRESSES ======= */
        pair = _stakingToken; //PAIR ADDRESS
        stakingToken = IERC20(_stakingToken); //LP TOKEN ADDRESS
        rewardToken = IERC20(_rewardToken); //REWARD ADDRESS
    }

    /* ========== FUNCTIONS ========== */

    function calculateAmountBulc(uint256 _amountBusd)
        public
        view
        returns (uint256)
    {
        bool trueToken = (IUniswapV2Pair(pair).token0() ==
            address(rewardToken)); //CHECK WHICH ADDRESS IS REWARD ADDRESS

        uint256 reserveBulc; //REWARD ADDRESS
        uint256 reserveBusd; //FEE TOKEN ADDRESS
        if (trueToken) {
            (reserveBulc, reserveBusd, ) = IUniswapV2Pair(pair).getReserves(); //GET RESERVES
        } else {
            (reserveBusd, reserveBulc, ) = IUniswapV2Pair(pair).getReserves(); //GET RESERVES
        }
        return UniswapV2Library.quote(_amountBusd, reserveBusd, reserveBulc);
    }

    function calculateAmountBusd(uint256 _BulcAmount)
        public
        view
        returns (uint256)
    {
        bool trueToken = (IUniswapV2Pair(pair).token0() !=
            address(rewardToken)); //CHECK WHICH ADDRESS IS NOT REWARD ADDRESS

        uint256 reserveBulc; //REWARD TOKEN ADDRESS
        uint256 reserveBusd; //FEE TOKEN ADDRESS
        if (!trueToken) {
            (reserveBulc, reserveBusd, ) = IUniswapV2Pair(pair).getReserves(); //GET RESERVES
        } else {
            (reserveBusd, reserveBulc, ) = IUniswapV2Pair(pair).getReserves(); //GET RESERVES
        }
        return UniswapV2Library.quote(_BulcAmount, reserveBulc, reserveBusd);
    }

    function calculateValue(uint256 _LpTokenAmount)
        public
        view
        returns (uint256 valueLpPerBusd)
    {
        uint256 LPBalancePair = IUniswapV2Pair(pair).totalSupply(); //
        bool trueToken = (IUniswapV2Pair(pair).token0() !=
            address(rewardToken));
        uint256 BusdAmount;

        if (trueToken) {
            (BusdAmount, , ) = IUniswapV2Pair(pair).getReserves();
        } else {
            (, BusdAmount, ) = IUniswapV2Pair(pair).getReserves();
        }
        uint256 BusdBalancePair = BusdAmount;

        uint256 pairValue = BusdBalancePair * 2;
        uint256 LpTokenPerBusdValue = Math.ceilDiv(pairValue, LPBalancePair);
        valueLpPerBusd = _LpTokenAmount * LpTokenPerBusdValue;
    }

    function calculatePermit(uint256 amount_, uint8 choice_)
        public
        pure
        returns (uint256 exactAmount)
    {
        uint256 amount = amount_; //GAS SAVING

        if (choice_ == 1) {
            exactAmount = Math.ceilDiv((amount * 60), (12 * 100)); //60APR
        }
        if (choice_ == 2) {
            exactAmount = Math.ceilDiv((amount * 120), (4 * 100)); //120APR
        }
        if (choice_ == 3) {
            exactAmount = Math.ceilDiv((amount * 160), (2 * 100)); //160APR
        }
        if (choice_ == 4) {
            exactAmount = Math.ceilDiv((amount * 300), 100); //300APR
        }
    }

    function calculate(uint256 _LPamount, uint8 choice)
        public
        view
        returns (uint256 permitPerBulc)
    {
        uint256 BusdAmount = calculateValue(_LPamount);
        uint256 permitPerBusd = calculatePermit(BusdAmount, choice);
        permitPerBulc = calculateAmountBulc(permitPerBusd);
    }

    function stake(uint256 _amount, uint8 _Choise)
        external
        checkChoice(_Choise)
        nonReentrant
    {
        require(_amount > 0, "Cannot stake 0");
        uint256 lock = calculate(_amount, _Choise);
        require(StakedReward > lock, "owner have not enough bulc to pay!");
        IERC20 Busd;
        bool trueToken = (IUniswapV2Pair(pair).token0() !=
            address(rewardToken));
        if (trueToken) {
            Busd = IERC20(IUniswapV2Pair(pair).token0());
        } else {
            Busd = IERC20(IUniswapV2Pair(pair).token1());
        }

        uint256 fee = calculateValue(_amount) / 100;
        Busd.transferFrom(msg.sender, owner(), fee);
        StakedReward -= lock;
        StakedRewardFreezed += lock;
        // address BulcPairBalance=IERC20(_pair.token1()); 9999996998999999000
        //        99999999999998889999004000000000000
        //                                         9999996999999999000
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        AllStakedBalance[msg.sender] += _amount; // stake[address] = amount;
        stakedBalance[msg.sender][uint32(positions[msg.sender])] = _amount; // stake[address] = amount;
        stakedChoise[msg.sender][uint32(positions[msg.sender])] = _Choise;
        totalValueLockLPToken += _amount; // T = T + amount;
        totalValueLockBUSD += calculateValue(_amount);
        uint256 endTime = stakeFor(_Choise, msg.sender);
        emit Stake(msg.sender, _amount, endTime);
    }

    function unstake(uint32 position)
        external
        isExist(position)
        isDone(position)
        nonReentrant
    {
        uint256 deposited = stakedBalance[msg.sender][position]; // deposited = stake[address];
        stakingToken.safeTransfer(msg.sender, deposited);
        uint8 choise = stakedChoise[msg.sender][position];
        uint256 reward = calculate(deposited, choise);

        if (reward > 0) {
            rewardToken.safeTransfer(msg.sender, reward);
        }
        StakedRewardFreezed -= reward;
        totalValueLockLPToken -= deposited; // T = T - deposited;
        totalValueLockBUSD -= calculateValue(deposited);

        stakedBalance[msg.sender][position] = 0; // stake[address] = 0;
        AllStakedBalance[msg.sender] -= deposited; // stake[address] = 0;
        updatePositions(position, msg.sender); //updatePositions

        emit Unstake(msg.sender, deposited, reward);
    }

    function distribute(uint256 _reward) external onlyOwner {
        require(_reward > 0, "Cannot distribute 0");

        rewardToken.safeTransferFrom(msg.sender, address(this), _reward);
        StakedReward += _reward;
        emit Distribute(msg.sender, _reward);
    }

    function witdraw(uint256 rewardTokenAmount) external onlyOwner {
        require(rewardTokenAmount == 0, "0 amount");
        require(
            rewardTokenAmount <= StakedReward,
            "you can witdraw rewardFreezd"
        );
        rewardToken.transfer(msg.sender, rewardTokenAmount);
        StakedReward -= rewardTokenAmount;
        emit Distribute(msg.sender, rewardTokenAmount);
    }

    function rewardOf(address _account, uint32 position)
        public
        view
        returns (uint256)
    {
        uint256 deposited = stakedBalance[_account][position];
        uint8 choice = stakedChoise[_account][position];
        return calculate(deposited, choice);
    }

    function getAll(address sender_, uint8 position)
        public
        view
        returns (
            uint256 deadLine,
            uint256 reward,
            uint256 choise,
            uint256 LPTokenBalnce
        )
    {
        deadLine = lockTime[sender_][position];
        reward = rewardOf(sender_, position);
        choise = stakedChoise[sender_][position];
        LPTokenBalnce = stakedBalance[sender_][position];
    }
}
