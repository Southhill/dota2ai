# DOTA机器人脚本(Dota Bot Scripting)

> 来源：Valve Developer Community
> 原文：[Zh/Dota Bot Scripting](https://developer.valvesoftware.com/wiki/Zh/Dota_Bot_Scripting)

## 目录

- [1 概述](#概述)
  - [1.1 团队级别](#团队级别)
  - [1.2 模式级别](#模式级别)
  - [1.3 行为级别](#行为级别)
- [2 目录结构](#目录结构)
  - [2.1 完全接手](#完全接手)
  - [2.2 模式重写](#模式重写)
  - [2.3 技能和物品使用](#技能和物品使用)
  - [2.4 物品购买](#物品购买)
  - [2.5 团队级别需求](#团队级别需求)
  - [2.6 英雄选择](#英雄选择)
- [3 API参考](#api参考)
  - [3.1 全局](#全局)
  - [3.2 单位作用域](#单位作用域)
- [4 机器人难度](#机器人难度)
  - [4.1 消极(Passive)](#消极passive)
  - [4.2 简单(Easy)](#简单easy)
  - [4.3 中等(Medium)](#中等medium)
  - [4.4 困难(Hard)](#困难hard)
  - [4.5 疯狂(Unfair)](#疯狂unfair)
- [5 调试](#调试)
- [6 潜在位置](#潜在位置)
- [7 英雄战斗力](#英雄战斗力)
- [8 附录A - 链接到一个泛用的Lua脚本实现](#附录a---链接到一个泛用的lua脚本实现)
- [9 附录B - 可用常量列表](#附录b---可用常量列表)
  - [9.1 机器人模式](#机器人模式)
  - [9.2 行为需求值](#行为需求值)
  - [9.3 模式需求值](#模式需求值)
  - [9.4 伤害类型](#伤害类型)
  - [9.5 难度等级](#难度等级)
  - [9.6 物品购买结果](#物品购买结果)
  - [9.7 游戏模式](#游戏模式)
  - [9.8 队伍](#队伍)
  - [9.9 路](#路)
  - [9.10 游戏状态](#游戏状态)
  - [9.11 英雄选择状态](#英雄选择状态)
  - [9.12 神符](#神符)
  - [9.13 神符状态](#神符状态)

## 概述

Dota中的机器人脚本通过lua语言实现。该过程是服务器级别的，因此并不需要实现检查屏幕像素或是模拟鼠标点击这样的操作；脚本会检查游戏状态并直接发送指令到各部件。脚本可以完全访问所有的实体位置，冷却时间，法力值，等等队伍中的玩家所期望的内容。API所限制的操作脚本也不能执行——战争迷雾中的单位不能被查寻，对非脚本控制的对象不能下达指令，等等。

现在已经有了一个为机器人脚本开发开设的论坛：[dev subforum](http://dev.dota2.com/forumdisplay.php?f=497)

除了lua脚本之外，底层的C++机器人代码仍然存在，而且脚本能够决定对机器人的安排使用多少底层代码。

机器人被组织为三个评估和决策等级：

### 团队级别

这一级别代码决定全体团队成员去推线，防守，打钱发育，或是去打肉山。这些要求独立存在于任何机器人的状态之外。它们不是强制性的；事实上它们不会决定任何机器人的任何行为。这些要求仅仅为所有机器人提供可用的决策依据。

### 模式级别

模式是一种高级的要求，机器人会频繁地在模式间切换，选择最高分数的模式作为它们当前行为的模式。例如对线，尝试杀死某个单位，打钱，撤退和推塔等模式。

### 行为级别

行为是机器人可以基于即时去做的，单独的一件事。这些事粗略地说，是关于鼠标点击和按下按钮的行为——像是移动到某个位置，攻击某个目标，或是购买某样物品。

整体流程上大概是团队级别提供对全体队员当前战略的顶层指导。每个机器人会评估它们各个模式的需求分数，综合考虑团队级别的需求和机器人个体级别的需求。分数最高的模式将变为当前激活模式，该模式将负责控制机器人所表现出的行为。

## 目录结构

所有正在开发中的机器人脚本会放在DOTA2安装文件夹中game/dota/scripts/vscripts/bots目录下。当你上传你的脚本到工坊时，就会上传该目录下的内容。而下载的脚本则放在你Steam安装目录下自己的文件夹中。

机器人脚本被结构化为可以独立实现的多个元素。哪个逻辑被重写取决于你在你的文件中实现了哪个函数。

下面的每个脚本元素都有自己的脚本作用域：

### 完全接手

如果你想完全地接手控制英雄，你可以在文件名为`bot_generic.lua`的文件中实现`Think()`函数，该函数将代替标准机器人智能代码的每一帧。这将会完全地接手控制所有机器人——团队级别和模式级别的智能都不再起作用。你要负责对所有的机器人发出所有的行为指令。如果你仅仅打算控制某个特定的英雄，比如火女(Lina)，你可以在文件名为`bot_lina.lua`的文件中实现`Think()`函数。

被完全接手的英雄仍然会受到游戏难度的修正（参考附件B），并仍会计算它们的估计伤害值。

### 模式重写

如果你想在已有模式体系下修改某个模式逻辑的需求和行为，例如修改对线模式(laning mode)，你可以在文件名为`mode_laning_generic.lua`的文件中实现如下函数：

- `GetDesire()` - 每帧都被调用，需要返回一个0到1之间的浮点值，该值标志了该模式有多大可能成为当前激活模式
- `OnStart()` - 当该模式成为当前激活模式时调用
- `OnEnd()` - 当该模式让出控制权给其他被激活模式时调用
- `Think()` - 当该模式为当前激活模式时，每帧都被调用。负责发出机器人的行为指令。

你也可以仅重写某个特定英雄的模式逻辑，比如火女(Lina)，写在文件名为`mode_laning_lina.lua`的文件中。如果你想在特定英雄的模式重写时调用泛用的英雄模式代码，请参考附件A的实现细节。

可重写的机器人模式清单如下：

- laning
- attack
- roam
- retreat
- secret_shop
- side_shop
- rune
- push_tower_top
- push_tower_mid
- push_tower_bot
- defend_tower_top
- defend_tower_mid
- defend_tower_bottom
- assemble
- team_roam
- farm
- defend_ally
- evasive_maneuvers
- roshan
- item
- ward

### 技能和物品使用

如果你只想重写在技能和物品使用时的决策，你可以在文件名为`ability_item_usage_generic.lua`的文件中实现如下函数：

- `ItemUsageThink()` - 每帧被调用。负责发出物品使用行为。
- `AbilityUsageThink()` - 每帧被调用。负责发出技能使用行为。
- `CourierUsageThink()` - 每帧被调用。负责发出信使的相关命令。
- `BuybackUsageThink()` - 每帧被调用。负责发出购回指令。

这些函数中未被重写的，会自动采用默认的C++实现。

你也可以仅重写某个特定英雄对技能/物品使用的逻辑，比如火女(Lina)，写在文件名为`ability_item_usage_lina.lua`的文件中。如果你想在特定英雄对技能/物品使用的逻辑重写时调用泛用的逻辑代码，请参考附件A的实现细节。

### 物品购买

如果你只想重写在购买物品时的决策，你可以在文件名为`item_purchase_generic.lua`的文件中实现如下函数：

- `ItemPurchaseThink()` - 每帧被调用。负责物品购买。

你也可以仅重写某个特定英雄的物品购买逻辑，比如火女(Lina)，写在文件名为`item_purchase_lina.lua`的文件中。

### 团队级别需求

如果你想提供团队级别需求，你可以在文件名为`team_desires.lua`的文件中实现如下函数：

- `TeamThink()` - 每帧被调用。为你的整个队伍提供一次思考调用。
- `UpdatePushLaneDesires()` - 每帧被调用。返回多个0到1之间的浮点值，分别表示推进上，中，下路的需求值。
- `UpdateDefendLaneDesires()` - 每帧被调用。返回多个0到1之间的浮点值，分别表示防守上，中，下路的需求值。
- `UpdateFarmLaneDesires()` - 每帧被调用。返回多个0到1之间的浮点值，分别表示在上，中，下路打钱的需求值。
- `UpdateRoamDesire()` - 每帧被调用。返回一个0到1之间的浮点值和一个目标句柄，表示某人游走gank特定目标的需求值。
- `UpdateRoshanDesire()` - 每帧被调用。返回一个0到1之间的浮点值，表示团队去杀肉山的需求值。

这些函数中未被重写的，会自动采用默认的C++实现。

### 英雄选择

如果你想控制英雄选择和分路，你可以在文件名为`hero_selection.lua`的文件中实现如下函数：

- `Think()` - 每帧被调用。负责机器人选择英雄。
- `UpdateLaneAssignments()` - 在游戏开始前的每一帧被调用。返回玩家ID-分路的值对。
- `GetBotNames()` - 调用一次，返回玩家名字表。

## API参考

有两种基本级别的API可用：全局的和对特定单位的。以下是这两个级别的函数列表：

### 全局

（细节待完善）

- GetBot
- GetTeam
- GetTeamMember

- DotaTime
- GameTime
- RealTime

- GetUnitToUnitDistance
- GetUnitToLocationDistance
- GetWorldBounds
- IsLocationPassable
- GetHeightLevel
- GetLocationAlongLane
- GetNeutralSpawners
- GetItemCost
- IsItemPurchasedFromSecretShop
- IsItemPurchasedFromSideShop
- GetItemStockCount

- GetPushLaneDesire
- GetDefendLaneDesire
- GetFarmLaneDesire
- GetRoamDesire
- GetRoamTarget
- GetRoshanDesire

- `int GetGameState()` - Returns the current game state
- `float GetGameStateTimeRemaining()` - Returns how much time is remaining in the current game state, if applicable
- `int GetGameMode()` - Returns the current game mode
- `int GetHeroPickState()` - Returns the current hero pick state

- IsPlayerInHeroSelectionControl
- SelectHero
- GetSelectedHeroName

- IsInCMBanPhase
- IsInCMPickPhase
- GetCMPhaseTimeRemaining
- GetCMCaptain
- SetCMCaptain
- IsCMBannedHero
- IsCMPickedHero
- CMBanHero
- CMPickHero

- RandomInt
- RandomFloat
- RandomYawVector
- RollPercentage
- Min
- Max
- Clamp
- RemapVal
- RemapValClamped

- DebugDrawLine
- DebugDrawCircle
- DebugDrawText

### 单位作用域

- Action_ClearActions
- Action_MoveToLocation
- Action_MoveToUnit
- Action_AttackUnit
- Action_AttackMove
- Action_UseAbility
- Action_UseAbilityOnEntity
- Action_UseAbilityOnLocation
- Action_UseAbilityOnTree
- Action_PickUpRune
- Action_PickUpItem
- Action_DropItem
- Action_PurchaseItem
- Action_SellItem
- Action_Buyback
- Action_LevelAbility

- GetDifficulty
- GetUnitName
- GetPlayer
- IsHero
- IsCreep
- IsTower
- IsBuilding
- IsFort
- IsIllusion

- CanBeSeen
- GetActiveMode
- GetActiveModeDesire
- GetHealth
- GetMaxHealth
- GetMana
- GetMaxMana
- IsAlive
- GetRespawnTime
- HasBuyback
- GetGold
- GetStashValue
- GetCourierValue
- GetLocation
- GetFacing
- GetGroundHeight
- GetAbilityByName
- GetItemInSlot
- IsChanneling
- IsUsingAbility
- GetVelocity
- GetAttackTarget
- GetLastSeenLocation
- GetTimeSinceLastSeen

- IsRooted
- IsDisarmed
- IsAttackImmune
- IsSilenced
- IsMuted
- IsStunned
- IsHexed
- IsInvulnerable
- IsMagicImmune
- IsNightmared
- IsBlockDisabled
- IsEvadeDisabled
- IsUnableToMiss
- IsSpeciallyDeniable
- IsDominated
- IsBlind
- HasScepter

- WasRecentlyDamagedByAnyHero
- WasRecentlyDamagedByHero
- TimeSinceDamagedByAnyHero
- TimeSinceDamagedByHero

- DistanceFromFountain
- DistanceFromSideShop
- DistanceFromSecretShop

- SetTarget
- GetTarget

- SetNextItemPurchaseValue
- GetNextItemPurchaseValue

- GetAssignedLane

- GetEstimatedDamageToTarget
- GetStunDuration
- GetSlowDuration
- HasBlink
- HasMinistunOnAttack
- HasSilence
- HasInvisibility
- UsingItemBreaksInvisibility

- GetNearbyHeroes
- GetNearbyTowers
- GetNearbyCreeps

- FindAoELocation

- GetExtrapolatedLocation
- GetMovementDirectionStability

- GetActualDamage

## 机器人难度

有五种机器人难度等级：

### 消极(Passive)

- 不能使用技能、物品和信使
- 一直停留在对线模式
- 当试图正补小兵和野怪时，估计的最佳攻击时间随机相差0.4秒
- 当试图反补小兵时，估计的最佳攻击时间随机相差0.2秒

### 简单(Easy)

- 对技能和物品使用有随机0.5到1秒的延迟
- 每隔8秒，技能和物品使用被限制6秒不能使用
- 当某技能或物品被使用时，限制技能和物品使用6秒
- 当试图正补小兵和野怪时，估计的最佳攻击时间随机相差0.4秒
- 当试图反补小兵时，估计的最佳攻击时间随机相差0.2秒

### 中等(Medium)

- 对技能和物品使用有随机0.3到0.6秒的延迟
- 每隔10秒，技能和物品使用被限制3秒不能使用
- 当某技能或物品被使用时，限制技能和物品使用3秒
- 当试图正补小兵和野怪时，估计的最佳攻击时间随机相差0.2秒
- 当试图反补小兵时，估计的最佳攻击时间随机相差0.1秒

### 困难(Hard)

- 对技能和物品使用有随机0.1到0.2秒的延迟

### 疯狂(Unfair)

- 对技能和物品使用有随机0.075到0.15秒的延迟
- 经验和金钱的获取将有25%的加成

## 调试

有很多命令可以帮助你调试脚本机器人的运行。

**dota_bot_debug_team**

`dota_bot_debug_team` 显示一个针对特定队伍的面板(2 is Radiant, 3 is Dire)，显示：

- 团队级别的需求值，关于推进(pushing)，防守(defending)，打钱(farming lanes)，肉山(Roshan)
- 机器人名字和等级
- 机器人当前和最大"战斗力"等级（关于战斗力的计算请参考附录D），可以被命令 `dota_bot_debug_team_power 0` 设置为关闭
- 当前激活模式，和其他模式的需求值
- 某一机器人的全部模式(可折叠显示)和所有模式的需求值
- 机器人当前行为以及行为目标(如果存在的话)
- 全队所有机器人的执行时间计算，以及单独每个机器人的执行时间

也支持 `dota_bot_select_debug` 对特定队伍的线-球绘制。

**dota_bot_debug_grid**

`dota_bot_debug_grid`
`dota_bot_debug_grid_cycle`
`dota_bot_debug_minimap`
`dota_bot_debug_minimap_cycle`

在地图或小地图上绘制网格。`*_cycle` 式的指令在不同值间循环，其他指令则直接设置显示模式。

- 0 - 关
- 1 - 不显示天辉
- 2 - 不显示夜魇
- 3 - 天辉的潜在敌人位置
- 4 - 夜魇的潜在敌人位置
- 5 - 天辉的可见敌人
- 6 - 夜魇的可见敌人
- 7 - 地形高度值
- 8 - 可通过体积

**dota_bot_select_debug**

激活光标选中机器人的如下信息显示：

- 当前机器人的模式和行为
- 当前路径的白色线条
- 上一个攻击目标的蓝色点-线图
- 当前攻击目标的红色点-线图

**dota_bot_select_debug_attack**

显示光标选中机器人对周围敌人的攻击欲望值

**dota_bot_debug_clear**

清除 `dota_bot_select_debug` 指令和 `dota_bot_select_debug_attack` 指令显示的光标选中单位的状态。

**dota_bot_debug_lanes**

显示对线路径，并以圆圈的形式显示"前线"区域。

**dota_bot_debug_ward_locations**

以黄色圆圈显示机器人可能考虑插眼的位置。

## 潜在位置

一个对机器人脚本很有用的函数 `GetUnitPotentialValue()`，能够返回一个0到255之间的值，表示在某一特定位置的特定半径内是否有英雄在内。这个值是基于机器人游戏中潜在的坐标网格。

它的运作机制如下：

- 当队伍丢失一个英雄的视野时，会有一条路径通过地图上的可通过区域，和该英雄的移动速度相同。
- 这个"潜在位置"将开始高亮，然后随着潜在位置圈变得越大越淡而降低。
- 该过程对所有敌方英雄独立进行

它也有一些限制：

- 它不考虑英雄通过传送或其他加速方式进行的位移（如狼人的变身，敌法师的闪烁，等等）
- 它不包括任何关于英雄消失原因和移动目标的估计逻辑——它假定在战争迷雾中的英雄走各条路径有平均可能性。

它仍是在决策时非常有用的功能，尤其是当潜在位置值较高时。你显然不想在英雄离开视野时就不再顾虑它，那么通过潜在坐标网格就可以帮助你估计一个位置是否足够安全。

## 英雄战斗力

你经常需要知道一个队伍中的机器人有多强，或是一个敌人多有威胁。英雄战斗力这个概念就是一个粗略的估计值，对每个英雄在每帧都会刷新该数值。

它的计算方法如下（对每个英雄）：

- 对每个英雄，计算在一个时间段内对敌方英雄造成的总伤害值。
- 这个时间段被定义为5秒，如果英雄能击晕对方将延长一倍，如果能减速对方就延长一半。
- 这个伤害包括攻击伤害加上技能伤害。
- 攻击伤害包括累积和负面效果。
- 技能伤害基于可用的法力值，施法时间，冷却时间，被沉默状态等等。
- 该伤害为对所有敌方英雄取平均值。

此外，我们也计算了每个英雄的原始战斗力，即不考虑冷却时间和英雄状态（法力值，buff效果，等等）的战斗力。它更多地表示在给定时间内该英雄理论上的强度。

需要注意战斗力仅仅意味着输出能力，与坦克和续航能力无关。

`GetRawOffensivePower()` 函数（得到原始战斗力）能对你看到的队友和敌人使用。
`GetOffensivePower()` 函数（得到英雄战斗力）只能对友方使用。

## 附录A - 链接到一个泛用的Lua脚本实现

如果你实现了一个泛用的模式或是技能/物品使用脚本，你应该在你的泛用文件头部加入如下代码（需根据实现模块的名字作调整）：

```lua
_G._savedEnv = getfenv()
module( "mode_generic_defend_ally", package.seeall )
```

然后你要在尾部加入如下代码：

```lua
for k,v in pairs( mode_generic_defend_ally ) do
    _G._savedEnv[k] = v
end
```

那么在你的某个特定英雄的脚本中，你可以在文件头部加入：

```lua
require( GetScriptDirectory().."/mode_defend_ally_generic" )
```

这将允许你在特定英雄脚本中调用如下函数：

```lua
mode_generic_defend_ally.OnStart();
```

## 附录B - 可用常量列表

### 机器人模式

- BOT_MODE_NONE
- BOT_MODE_LANING
- BOT_MODE_ATTACK
- BOT_MODE_ROAM
- BOT_MODE_RETREAT
- BOT_MODE_SECRET_SHOP
- BOT_MODE_SIDE_SHOP
- BOT_MODE_PUSH_TOWER_TOP
- BOT_MODE_PUSH_TOWER_MID
- BOT_MODE_PUSH_TOWER_BOT
- BOT_MODE_DEFEND_TOWER_TOP
- BOT_MODE_DEFEND_TOWER_MID
- BOT_MODE_DEFEND_TOWER_BOT
- BOT_MODE_ASSEMBLE
- BOT_MODE_TEAM_ROAM
- BOT_MODE_FARM
- BOT_MODE_DEFEND_ALLY
- BOT_MODE_EVASIVE_MANEUVERS
- BOT_MODE_ROSHAN
- BOT_MODE_ITEM
- BOT_MODE_WARD

### 行为需求值

这对于保证所有行为的需求值使用统一语言描述很有帮助。

- BOT_ACTION_DESIRE_NONE - 0.0
- BOT_ACTION_DESIRE_VERYLOW - 0.1
- BOT_ACTION_DESIRE_LOW - 0.25
- BOT_ACTION_DESIRE_MODERATE - 0.5
- BOT_ACTION_DESIRE_HIGH - 0.75
- BOT_ACTION_DESIRE_VERYHIGH - 0.9
- BOT_ACTION_DESIRE_ABSOLUTE - 1.0

### 模式需求值

这对于保证所有模式的需求值使用统一语言描述很有帮助。

- BOT_MODE_DESIRE_NONE - 0
- BOT_MODE_DESIRE_VERYLOW - 0.1
- BOT_MODE_DESIRE_LOW - 0.25
- BOT_MODE_DESIRE_MODERATE - 0.5
- BOT_MODE_DESIRE_HIGH - 0.75
- BOT_MODE_DESIRE_VERYHIGH - 0.9
- BOT_MODE_DESIRE_ABSOLUTE - 1.0

### 伤害类型

- DAMAGE_TYPE_PHYSICAL
- DAMAGE_TYPE_MAGICAL
- DAMAGE_TYPE_PURE
- DAMAGE_TYPE_ALL

### 难度等级

- DIFFICULTY_INVALID
- DIFFICULTY_PASSIVE
- DIFFICULTY_EASY
- DIFFICULTY_MEDIUM
- DIFFICULTY_HARD
- DIFFICULTY_UNFAIR

### 物品购买结果

- PURCHASE_ITEM_SUCCESS
- PURCHASE_ITEM_OUT_OF_STOCK
- PURCHASE_ITEM_DISALLOWED_ITEM
- PURCHASE_ITEM_INSUFFICIENT_GOLD
- PURCHASE_ITEM_NOT_AT_HOME_SHOP
- PURCHASE_ITEM_NOT_AT_SIDE_SHOP
- PURCHASE_ITEM_NOT_AT_SECRET_SHOP
- PURCHASE_ITEM_INVALID_ITEM_NAME

### 游戏模式

- GAMEMODE_NONE
- GAMEMODE_AP
- GAMEMODE_CM
- GAMEMODE_RD
- GAMEMODE_SD
- GAMEMODE_AR
- GAMEMODE_REVERSE_CM
- GAMEMODE_MO
- GAMEMODE_CD
- GAMEMODE_ABILITY_DRAFT
- GAMEMODE_ARDM
- GAMEMODE_1V1MID
- GAMEMODE_ALL_DRAFT (aka Ranked All Pick)

### 队伍

- TEAM_RADIANT
- TEAM_DIRE
- TEAM_NEUTRAL
- TEAM_NONE

### 路

- LANE_NONE
- LANE_TOP
- LANE_MID
- LANE_BOT

### 游戏状态

- GAME_STATE_INIT
- GAME_STATE_WAIT_FOR_PLAYERS_TO_LOAD
- GAME_STATE_HERO_SELECTION
- GAME_STATE_STRATEGY_TIME
- GAME_STATE_PRE_GAME
- GAME_STATE_GAME_IN_PROGRESS
- GAME_STATE_POST_GAME
- GAME_STATE_DISCONNECT
- GAME_STATE_TEAM_SHOWCASE
- GAME_STATE_CUSTOM_GAME_SETUP
- GAME_STATE_WAIT_FOR_MAP_TO_LOAD
- GAME_STATE_LAST

### 英雄选择状态

- HEROPICK_STATE_NONE
- HEROPICK_STATE_AP_SELECT
- HEROPICK_STATE_SD_SELECT
- HEROPICK_STATE_CM_INTRO
- HEROPICK_STATE_CM_CAPTAINPICK
- HEROPICK_STATE_CM_BAN1
- HEROPICK_STATE_CM_BAN2
- HEROPICK_STATE_CM_BAN3
- HEROPICK_STATE_CM_BAN4
- HEROPICK_STATE_CM_BAN5
- HEROPICK_STATE_CM_BAN6
- HEROPICK_STATE_CM_BAN7
- HEROPICK_STATE_CM_BAN8
- HEROPICK_STATE_CM_BAN9
- HEROPICK_STATE_CM_BAN10
- HEROPICK_STATE_CM_SELECT1
- HEROPICK_STATE_CM_SELECT2
- HEROPICK_STATE_CM_SELECT3
- HEROPICK_STATE_CM_SELECT4
- HEROPICK_STATE_CM_SELECT5
- HEROPICK_STATE_CM_SELECT6
- HEROPICK_STATE_CM_SELECT7
- HEROPICK_STATE_CM_SELECT8
- HEROPICK_STATE_CM_SELECT9
- HEROPICK_STATE_CM_SELECT10
- HEROPICK_STATE_CM_PICK
- HEROPICK_STATE_AR_SELECT
- HEROPICK_STATE_MO_SELECT
- HEROPICK_STATE_FH_SELECT
- HEROPICK_STATE_CD_INTRO
- HEROPICK_STATE_CD_CAPTAINPICK
- HEROPICK_STATE_CD_BAN1
- HEROPICK_STATE_CD_BAN2
- HEROPICK_STATE_CD_BAN3
- HEROPICK_STATE_CD_BAN4
- HEROPICK_STATE_CD_BAN5
- HEROPICK_STATE_CD_BAN6
- HEROPICK_STATE_CD_SELECT1
- HEROPICK_STATE_CD_SELECT2
- HEROPICK_STATE_CD_SELECT3
- HEROPICK_STATE_CD_SELECT4
- HEROPICK_STATE_CD_SELECT5
- HEROPICK_STATE_CD_SELECT6
- HEROPICK_STATE_CD_SELECT7
- HEROPICK_STATE_CD_SELECT8
- HEROPICK_STATE_CD_SELECT9
- HEROPICK_STATE_CD_SELECT10
- HEROPICK_STATE_CD_PICK
- HEROPICK_STATE_BD_SELECT
- HERO_PICK_STATE_ABILITY_DRAFT_SELECT
- HERO_PICK_STATE_ARDM_SELECT
- HEROPICK_STATE_ALL_DRAFT_SELECT
- HERO_PICK_STATE_CUSTOMGAME_SELECT
- HEROPICK_STATE_SELECT_PENALTY

### 神符

- RUNE_DOUBLEDAMAGE
- RUNE_HASTE
- RUNE_ILLUSION
- RUNE_INVISIBILITY
- RUNE_REGENERATION
- RUNE_BOUNTY
- RUNE_ARCANE

### 神符状态

- RUNE_STATUS_UNKNOWN
- RUNE_STATUS_AVAILABLE
- RUNE_STATUS_MISSING
