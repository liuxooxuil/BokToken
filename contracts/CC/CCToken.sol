
// SPDX-License-Identifier: MIT
/**
            -- 整改策略 --
    1.合约mint时间时需要记录时间戳来进行换算 （代币发布后 记录当前时间戳 如果五年之后有人进行回购则调用回购方法 回购比例按1.05依次增加 将代币存储到address之中）
    2.转账后，contract里的token总量减少，用户余额（已解决）
    3.增加铸币的百分比 （定义铸币得分发节点使用百分比得方式 来进行代币得发布）(已解决)
    4.定义回购规则 和回购地址 （在定义之中先使用token记录法验证是否满足条件 如若不满足 则onwable 满足则trmsfor）
    5.定义10释放规程（倘若三年后释放存储） 先一同铸造 之后释放 百分比收购收回 从pool池中进行定义
    6.定义全部释放规则（重写）
    7.删除转账限制（重写）
    8.分流计算token数量进行分发 而不是一笔均衡分发（已解决）
   
   [
    ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", 800000000000000000000],
    ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", 200000000000000000000]
]
0xE592427A0AECE92DE3ED81235A9C5B9B2E8F7D2C


// constructor(address[] memory _teamAddresses, address _uniswapPool)
    //     ERC20("csyd", "CSYD")
    //     Ownable(msg.sender)
    // {
    //     require(_teamAddresses.length > 0, "At least one team address required");
    //     teamAddresses = _teamAddresses;
    //     uniswapPool = _uniswapPool;

    //     _mint(msg.sender, TOTAL_SUPPLY * 80 / 100); // 80%流通

    //     // 流通的百分之八十需要进行计算来运行 总投资商的_teamAddresses地址和投资数量 进行换算 将这百分之八十的数量进行百分百换算分发

    //     for (uint256 i = 0; i < teamAddresses.length; i++) {
    //         _mint(teamAddresses[i], TOTAL_SUPPLY * 10 / 100 / teamAddresses.length); // 10%团队
    //     }
    //     _mint(address(this), TOTAL_SUPPLY * 10 / 100); // 10%资金池

    //     teamLockedUntil = block.timestamp + TEAM_LOCK_PERIOD; // 锁仓设置
    // }

    187500 * 0.8 = 150000    

*/
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/INonfungiblePositionManager.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Pool.sol";

contract CSYDToken is ERC20, Ownable {


    uint256 public constant TOTAL_SUPPLY = 187_500_000 * 10**18; // 1.875亿枚
    uint256 public constant TEAM_LOCK_PERIOD = 3 * 365 days; // 团队锁仓3年


    struct TeamMember {
        address memberAddress;
        uint256 investmentAmount;
    }

    TeamMember[] private teamMembers;    
    // address[] private teamAddresses; // 投资者地址
    uint256 public teamLockedUntil;
    address public uniswapPool;


    constructor(TeamMember[] memory _teamMembers, address _uniswapPool) 
        ERC20("csyd", "CSYD")
        Ownable(msg.sender)
    {
        require(_teamMembers.length > 0, "At least one team member required");
        uniswapPool = _uniswapPool;

        uint256 totalInvestment = 0;  // 记录投资数量

        // 计算总投资
        for (uint256 i = 0; i < _teamMembers.length; i++) {
            totalInvestment += _teamMembers[i].investmentAmount;
            teamMembers.push(_teamMembers[i]); // 存储团队成员
        }

        uint256 market = TOTAL_SUPPLY * 80 / 100; // 市场流动性
        uint256 totalDistribution = 0;

        // 分发流通代币
        for (uint256 i = 0; i < teamMembers.length; i++) {
            uint256 share = (teamMembers[i].investmentAmount * market) / totalInvestment; // 计算每个成员的份额
            _mint(teamMembers[i].memberAddress, share);
            totalDistribution += share;
        }

        // 确保分发的总量不超过市场流动性
        require(totalDistribution <= market, "Total distribution exceeds market");

        _mint(msg.sender, market - totalDistribution); // 剩余流通代币分配给合约拥有者
        _mint(address(this), TOTAL_SUPPLY * 10 / 100); // 10%资金池

        teamLockedUntil = block.timestamp + TEAM_LOCK_PERIOD; // 锁仓设置

        // 发布的代币记录一下发币时间的 在五年之后 才可进行回购 代币价值1.05进行回购 第六年的可按1.06 以此内推 直至封顶的第十年的比例1.10 回购之后的代币归属 资金如何给执行回购操作人员

    }


    modifier teamLocked(uint256 amount) {
        require(block.timestamp >= teamLockedUntil || balanceOf(msg.sender) >= amount, "Team tokens are locked");
        _;
    }

    // 重写转账
    function transfer(address recipient, uint256 amount) public override teamLocked(amount) returns (bool) {
        return super.transfer(recipient, amount);
    }

    // 合约铸造者方法
    function transferFrom(address sender, address recipient, uint256 amount) public override teamLocked(amount) returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function getCurrentPrice() public view returns (uint256 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**192); // 计算价格
    }

    function getTeamMembers() public view returns (TeamMember[] memory) {
        return teamMembers; // 返回所有团队成员信息
    }

    function getTeamMember(uint256 index) public view returns (address, uint256) {
        require(index < teamMembers.length, "Index out of bounds"); // 检查索引范围
        TeamMember memory member = teamMembers[index];
        return (member.memberAddress, member.investmentAmount); // 返回地址和投资金额
    }

    function getTeamMemberCount() public view returns (uint256) {
        return teamMembers.length; // 返回团队成员的数量
    }
}