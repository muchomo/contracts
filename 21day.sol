// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract StakingContract {
    uint256 constant public REWARD_LOCK_DURATION = 21 days;
    uint256 constant public TAX_PERCENTAGE = 3;
    
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    
    struct PoolInfo {
        IERC20 token;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }
    
    IERC20 public rewardsToken;
    uint256 public startTime;
    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => PoolInfo) public poolInfo;
    uint256 public totalAllocPoint;
    uint256 public accRewardPerShare;
    
    constructor(IERC20 _rewardsToken, uint256 _startTime) {
        rewardsToken = _rewardsToken;
        startTime = _startTime;
    }
    
    function stake(uint256 _poolId, uint256 _amount) external {
        require(block.timestamp >= startTime, "Staking not yet started");
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[msg.sender];
        updatePool(_poolId);
        
        if (user.amount > 0) {
            uint256 pendingRewards = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
            if (pendingRewards > 0) {
                rewardsToken.transfer(msg.sender, pendingRewards);
            }
        }
        
        if (_amount > 0) {
            pool.token.transferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
        }
        
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
    }
    
    function unstake(uint256 _poolId, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient staked amount");
        updatePool(_poolId);
        
        uint256 pendingRewards = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pendingRewards > 0) {
            rewardsToken.transfer(msg.sender, pendingRewards);
        }
        
        if (_amount > 0) {
            user.amount -= _amount;
            pool.token.transfer(msg.sender, _amount);
        }
        
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
    }
    
    function claim(uint256 _poolId) external {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[msg.sender];
        updatePool(_poolId);
        
        uint256 pendingRewards = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pendingRewards > 0) {
            uint256 taxAmount = (pendingRewards * TAX_PERCENTAGE) / 100;
            rewardsToken.transfer(msg.sender, pendingRewards - taxAmount);
            rewardsToken.transfer(address(this), taxAmount);
        }
        
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
    }
    
    function updatePool(uint256 _poolId) internal {
        PoolInfo storage pool = poolInfo[_poolId];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocksSinceLastUpdate = block.number - pool.lastRewardBlock;
        uint256 rewardPerBlock = rewardsToken.balanceOf(address(this)) / blocksSinceLastUpdate;
        pool.accRewardPerShare += (rewardPerBlock * pool.allocPoint * 1e18) / totalAllocPoint / tokenSupply;
        pool.lastRewardBlock = block.number;
    }
}
