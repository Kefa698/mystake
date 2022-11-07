// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is ReentrancyGuard {
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    // This is the reward token per second
    // Which will be multiplied by the tokens the user staked divided by the total
    // This ensures a steady reward rate of the platform
    // So the more users stake, the less for everyone who is staking.

    uint256 public constant REWARD_RATE = 100;
    uint256 public s_lastUpdateTime;
    uint256 public s_rewardPerTokenStored;

    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    uint256 private s_totalSupply;
    mapping(address => uint256) public s_balances;

    event Staked(address indexed user, uint256 indexed amount);
    event WithdrewStake(address indexed user, uint256 indexed amount);
    event ClaimedReward(address indexed user, uint256 indexed amount);

    constructor(address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    /**
     * @notice How much reward a token gets based on how long its been in and during which snapshots
     */
    function rewardPerToken() public view returns (uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        return
            s_rewardPerTokenStored +
            (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
    }

    /**
     * @notice how much a user has earned
     */

    function earned(address account) public view returns (uint256) {
        return
            ((s_balances[account] * (rewardPerToken() - s_userRewardPerTokenPaid[account])) /
                1e18) + s_rewards[account];
    }

    /**
     * @notice stake |deposit token into the contract
     * @param amount |amount to stake
     */
    function stake(uint256 amount)
        external
        updateReward(msg.sender)
        nonReentrant
        moreThanZero(amount)
    {
        s_totalSupply += amount;
        s_balances[msg.sender] += amount;
        emit Staked(msg.sender, amount);
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "tranfer failed");
    }

    /**
     * @notice withdraw |withdraw ton from the contract
     * @param amount ||amount to withdraw
     */
    function withdraw(uint256 amount)
        external
        updateReward(msg.sender)
        nonReentrant
        moreThanZero(amount)
    {
        s_totalSupply -= amount;
        s_balances[msg.sender] -= amount;
        emit WithdrewStake(msg.sender, amount);
        bool succuss = s_stakingToken.transfer(msg.sender, amount);
        require(succuss, "transfer failed");
    }

    function claimReward() external updateReward(msg.sender) nonReentrant {
        uint256 reward = s_rewards[msg.sender];
        s_rewards[msg.sender] = 0;
        emit ClaimedReward(msg.sender, reward);
    }

    //////////modifiers////////

    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp;
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "amount should be more than zero");
        _;
    }

    ////getter function/////////
    function getStaked(address account) public view returns (uint256) {
        return s_balances[account];
    }
}
