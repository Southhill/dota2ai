# Dota2 Bot AI 新手开发指南

> 面向零基础玩家，教你如何从零开始编写 Dota2 机器人脚本。

---

## 目录

1. [准备工作](#一准备工作)
2. [理解 Bot 脚本的工作原理](#二理解-bot-脚本的工作原理)
3. [第一个 Bot：Hello World](#三第一个-bothello-world)
4. [核心概念：欲望值系统](#四核心概念欲望值系统)
5. [为英雄编写技能逻辑](#五为英雄编写技能逻辑)
6. [出装系统](#六出装系统)
7. [游戏模式详解](#七游戏模式详解)
8. [调试技巧](#八调试技巧)
9. [常见问题](#九常见问题)
10. [参考资料](#十参考资料)

---

## 一、准备工作

### 1.1 找到脚本目录

```
Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/
```

这个文件夹就是 Dota2 读取 Bot 脚本的地方。把你的 `.lua` 文件放进去即可生效。

### 1.2 工具准备

- **VS Code**（推荐）或任意文本编辑器
- **Lua 语法基础** — 会写函数、表、条件语句即可
- **Dota2 客户端** — 用于测试

### 1.3 快速测试方法

1. 启动 Dota2
2. 创建**私人房间**（Practice Lobby）
3. 在 Bot 选择下拉菜单中选中你的脚本
4. 开始游戏观察 Bot 行为

> 💡 **小技巧**：使用控制台命令 `dota_bot_reload_scripts` 可以在游戏中重载脚本，无需重启房间。

---

## 二、理解 Bot 脚本的工作原理

### 2.1 引擎回调机制

Dota2 的 Bot 系统是**回调驱动**的。游戏引擎每帧调用特定的函数，你的脚本只需要实现这些函数：

```
游戏引擎每帧执行:
    │
    ├─ 调用 AbilityLevelUpThink()    ← 你决定怎么加点
    ├─ 调用 ItemPurchaseThink()      ← 你决定买什么装备
    ├─ 调用 CourierUsageThink()      ← 你决定信使做什么
    │
    ├─ 调用 GetDesire() × N 次       ← 每个模式文件都调用一次
    │   └─ 选中最高的 Desire
    │       └─ 调用 Think()          ← 执行该模式的行为
    │
    └─ 引擎内部处理移动/攻击等
```

### 2.2 文件命名规则

| 文件名                                | 作用           |
| ------------------------------------- | -------------- |
| `bot_<英雄内部名>.lua`                | 英雄的行为逻辑 |
| `ability_item_usage_<英雄内部名>.lua` | 技能和物品使用 |
| `item_purchase_<英雄内部名>.lua`      | 出装方案       |
| `mode_<模式名>.lua`                   | 游戏模式行为   |

> 英雄内部名可在 [Hero Names](https://dota2.gamepedia.com/Cheats#Hero_names) 查到，例如 `antimage`、`pudge`、`crystal_maiden`。

### 2.3 关键的 API

```lua
-- 获取当前 Bot
local npcBot = GetBot()

-- 位置信息
npcBot:GetLocation()                    -- 当前位置
npcBot:GetHealth() / GetMaxHealth()     -- 血量/最大血量
npcBot:GetMana() / GetMaxMana()         -- 蓝量/最大蓝量
npcBot:GetLevel()                       -- 等级

-- 操作指令
npcBot:ActionImmediate_MoveToLocation(loc)           -- 移动到某地
npcBot:ActionImmediate_AttackUnit(target)            -- 攻击目标
npcBot:ActionImmediate_UseAbility(ability)           -- 使用技能
npcBot:ActionImmediate_UseAbilityOnTarget(ability, target)  -- 对目标使用技能
npcBot:ActionImmediate_PurchaseItem(item_name)       -- 购买物品
npcBot:ActionImmediate_LevelAbility(ability_name)    -- 升级技能
npcBot:ActionImmediate_Glyph()                       -- 使用防御符文

-- 获取单位列表
GetUnitList(UNIT_LIST_ENEMY_HEROES)     -- 敌方英雄
GetUnitList(UNIT_LIST_ALLIED_HEROES)    -- 友方英雄
GetUnitList(UNIT_LIST_ENEMY_CREEPS)     -- 敌方小兵

-- 检测函数
npcBot:IsAlive()                        -- 是否存活
npcBot:IsStunned()                      -- 是否眩晕
npcBot:IsMagicImmune()                  -- 是否魔免
npcBot:HasModifier("modifier_name")     -- 是否有某状态
npcBot:IsFullyCastable()                -- 技能是否可用
```

---

## 三、第一个 Bot：Hello World

创建一个最简单的 Bot 脚本，让英雄走到地图中间。

### 3.1 创建文件

在 `vscripts/` 下创建 `bot_myhero.lua`：

```lua
-- bot_myhero.lua —— 我的第一个 Dota2 Bot

function GetDesire()
    -- 返回一个中等欲望值，告诉引擎"我想做点什么"
    return BOT_MODE_DESIRE_MODERATE
end

function Think()
    local npcBot = GetBot()

    -- 如果 Bot 活着，就让它往地图中心走
    if npcBot:IsAlive() then
        npcBot:ActionImmediate_MoveToLocation(Vector(0, 0, 0))
    end
end
```

### 3.2 测试

1. 启动 Dota2 → 创建私人房间
2. 选择 Bot 时选 `myhero`
3. 开始游戏，你会看到英雄径直走向地图中心

### 3.3 加点

```lua
function AbilityLevelUpThink()
    local npcBot = GetBot()

    -- 如果有点数没用，就升第一个技能
    if npcBot:GetAbilityPoints() > 0 then
        local ability = npcBot:GetAbilityInSlot(0)
        if ability ~= nil then
            npcBot:ActionImmediate_LevelAbility(ability:GetName())
        end
    end
end
```

### 3.4 出装

```lua
function ItemPurchaseThink()
    local npcBot = GetBot()

    -- 钱够就买鞋
    if npcBot:GetGold() >= 500 then
        npcBot:ActionImmediate_PurchaseItem("item_boots")
    end
end
```

---

## 四、核心概念：欲望值系统

欲望值（Desire）是 Dota2 Bot AI **最重要的概念**。

### 4.1 什么是欲望值？

每个行为模式返回一个数字告诉引擎："我多想做这件事"

| 值      | 常量                       | 含义       |
| ------- | -------------------------- | ---------- |
| 0       | `BOT_MODE_DESIRE_NONE`     | 完全不想做 |
| 0~0.3   | —                          | 有点想     |
| 0.3~0.6 | `BOT_MODE_DESIRE_MODERATE` | 中等程度想 |
| 0.6~0.8 | `BOT_MODE_DESIRE_HIGH`     | 非常想     |
| 0.8~1.0 | `BOT_MODE_DESIRE_ABSOLUTE` | 一定要做   |

### 4.2 引擎如何决策

```
模式A: GetDesire() → 0.2 (对线)
模式B: GetDesire() → 0.7 (打钱)
模式C: GetDesire() → 0.4 (撤退)
                        ↓
            引擎选择最大值 → 模式B (打钱)
                        ↓
                执行 Think() ← 模式B的Think函数
```

### 4.3 写一个带条件的欲望函数

```lua
function GetDesire()
    local npcBot = GetBot()

    -- 如果不是英雄或者是幻象，不做
    if not npcBot:IsHero() or npcBot:IsIllusion() then
        return BOT_MODE_DESIRE_NONE
    end

    -- 血量低于 30% 时强烈想撤退
    if npcBot:GetHealth() / npcBot:GetMaxHealth() < 0.3 then
        return BOT_MODE_DESIRE_HIGH
    end

    -- 附近有敌方英雄时稍微想撤退
    local enemies = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
    if #enemies > 0 then
        return BOT_MODE_DESIRE_MODERATE
    end

    return BOT_MODE_DESIRE_NONE
end
```

### 4.4 技能施放也有欲望值

不仅模式有欲望值，技能施放也有：

```lua
local function ConsiderAbility1()
    local ability = npcBot:GetAbilityInSlot(0)

    -- 技能不可用，不想用
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- 附近有敌人，想用技能
    local target = GetWeakestEnemy()
    if target ~= nil then
        return BOT_ACTION_DESIRE_HIGH, target
    end

    return BOT_ACTION_DESIRE_NONE, nil
end
```

---

## 五、为英雄编写技能逻辑

### 5.1 完整的英雄脚本模板

这是本项目所有英雄文件遵循的模板。以敌法师为例：

```lua
-- ability_item_usage_antimage.lua
----------------------------------------------------------------------------
-- 1. 引用工具库
----------------------------------------------------------------------------
local utility = require(GetScriptDirectory() .. "/util/Utility")
require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")

----------------------------------------------------------------------------
-- 2. 扫描英雄的技能和天赋
----------------------------------------------------------------------------
local npcBot = GetBot()
local Talents = {}        -- 天赋列表
local Abilities = {}      -- 技能名称列表
local AbilitiesReal = {}  -- 技能对象列表

ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)

----------------------------------------------------------------------------
-- 3. 定义加点顺序（1~30级）
----------------------------------------------------------------------------
-- Abilities[1] = 1技能, [2] = 2技能, [3] = 3技能, [4] = 大招, [5] = 天赋
-- "talent" = 天赋, "nil" = 属性奖励
local AbilityToLevelUp = {
    Abilities[1],  -- 1级: 学1技能
    Abilities[2],  -- 2级: 学2技能
    Abilities[1],  -- 3级: 学1技能
    Abilities[3],  -- 4级: 学3技能
    Abilities[2],  -- 5级: 学2技能
    Abilities[4],  -- 6级: 学大招
    Abilities[2],  -- 7级: 学2技能
    Abilities[2],  -- 8级: 学2技能
    Abilities[1],  -- 9级: 学1技能
    "talent",      -- 10级: 天赋
    Abilities[1],  -- 11级: 学1技能
    Abilities[4],  -- 12级: 学大招
    Abilities[3],  -- 13级: 学3技能
    Abilities[3],  -- 14级: 学3技能
    "talent",      -- 15级: 天赋
    Abilities[3],  -- 16级: 学3技能
    "nil",         -- 17级: 属性奖励
    Abilities[4],  -- 18级: 学大招
    "nil",         -- 19级: 属性奖励
    "talent",      -- 20级: 天赋
    "nil",         -- 21~25级: 属性奖励
    "nil",
    "nil",
    "nil",
    "talent"
}

-- 天赋选择（按左-右-左-右的顺序）
local TalentTree = {
    function() return Talents[1] end,  -- 10级左
    function() return Talents[4] end,  -- 15级右
    function() return Talents[6] end,  -- 20级右
    function() return Talents[8] end,  -- 25级右
}

-- 检查加点表是否有效
utility.CheckAbilityBuild(AbilityToLevelUp)

-- 加点入口
function AbilityLevelUpThink()
    ability_item_usage_generic.AbilityLevelUpThink(AbilityToLevelUp, TalentTree)
end

----------------------------------------------------------------------------
-- 4. 定义技能施放逻辑
----------------------------------------------------------------------------
local cast = {}
cast.Desire = {}
cast.Target = {}
cast.Type = {}
local Consider = {}
local CanCast = {utility.NCanCast, utility.NCanCast, utility.NCanCast, utility.UCanCast, utility.NCanCast}

-- 技能1的考虑函数
Consider[1] = function()
    local ability = AbilitiesReal[1]

    -- 技能不可用则不施放
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- 找最近的敌方英雄
    local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE)
    if #enemies == 0 then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local target = enemies[1]

    -- 目标可以施法（可见、非魔免、非无敌）
    if CanCast[1](target) then
        return BOT_ACTION_DESIRE_MODERATE, target
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

-- ... 更多技能的 Consider[2], Consider[3] ...

----------------------------------------------------------------------------
-- 5. 连招辅助函数
----------------------------------------------------------------------------
function GetComboDamage()
    return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
    return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end
```

### 5.2 施法判定函数

这几个函数非常重要，几乎所有技能使用前都要调用：

```lua
-- 常规施法：目标可见、非魔免、非无敌、无免疫 buff
utility.NCanCast(target)

-- 通用施法（可对魔免目标）：目标可见、非无敌、无免疫 buff、非幻象
utility.UCanCast(target)

-- 检测目标是否被控制
utility.enemyDisabled(target)
```

### 5.3 技能考虑函数的最佳实践

一个好的技能考虑函数通常包含以下步骤：

```lua
Consider[1] = function()
    -- 步骤1：检查技能是否可用
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- 步骤2：检查蓝量是否足够
    if npcBot:GetMana() < ability:GetManaCost() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- 步骤3：查找合适的施法目标
    local enemies = npcBot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
    local target = FindBestTarget(enemies)

    -- 步骤4：检查目标是否可以施法
    if target == nil or not CanCast(target) then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- 步骤5：根据不同情景返回不同的欲望值
    -- 撤退时想用控制技能
    if npcBot:GetActiveMode() == BOT_MODE_RETREAT then
        return BOT_ACTION_DESIRE_HIGH, target
    end

    -- 正常对线时低欲望使用
    return BOT_ACTION_DESIRE_MODERATE, target
end
```

### 5.4 完整的技能执行流程

```
ConsiderAbility(AbilitiesReal, Consider)
    │
    ├─ 对每个技能调用 Consider[n]()
    │   └─ 返回 (desire, target, type)
    │
    ├─ 找出 desire 最高的技能
    │
    └─ 执行 ActionImmediate_UseAbility(ability, target)
```

---

## 六、出装系统

### 6.1 最简单的出装

```lua
-- item_purchase_myhero.lua

local ItemsToBuy = {
    "item_tango",           -- 吃树
    "item_flask",           -- 大药
    "item_boots",           -- 鞋子
    "item_magic_wand",      -- 大魔棒
    "item_black_king_bar",  -- 黑皇杖
}

function ItemPurchaseThink()
    local npcBot = GetBot()

    if #ItemsToBuy == 0 then
        return
    end

    local nextItem = ItemsToBuy[1]

    -- 钱够了就买
    if npcBot:GetGold() >= GetItemCost(nextItem) then
        npcBot:ActionImmediate_PurchaseItem(nextItem)
        table.remove(ItemsToBuy, 1)
    end
end
```

### 6.2 使用本项目的出装系统

本项目提供了完整的出装引擎 `ItemPurchaseSystem`，帮您处理配方展开、格子管理、TP 购买等复杂逻辑：

```lua
local ItemPurchaseSystem = dofile(GetScriptDirectory() .. "/util/ItemPurchaseSystem")

local p = {
    "item_tango",
    "item_flask",
    "item_quelling_blade",   -- 补刀斧
    "item_wraith_band",      -- 天鹰戒
    "item_power_treads",     -- 假腿
    "item_bfury",            -- 狂战斧
    "item_manta",            -- 分身斧
    "item_abyssal_blade",    -- 大晕锤
    "item_black_king_bar",   -- BKB
    "item_butterfly",        -- 蝴蝶
}

ItemPurchaseSystem:CreateItemInformationTable(GetBot(), p)

function ItemPurchaseThink()
    ItemPurchaseSystem:ItemPurchaseExtend()
end
```

### 6.3 常用物品的 Lua 名称

| 游戏物品 | Lua 名称              |
| -------- | --------------------- |
| 吃树     | `item_tango`          |
| 大药膏   | `item_flask`          |
| 净化药水 | `item_clarity`        |
| 魔棒     | `item_magic_stick`    |
| 大魔棒   | `item_magic_wand`     |
| 鞋子     | `item_boots`          |
| 假腿     | `item_power_treads`   |
| 相位鞋   | `item_phase_boots`    |
| 秘法鞋   | `item_arcane_boots`   |
| 跳刀     | `item_blink`          |
| 黑皇杖   | `item_black_king_bar` |
| 狂战斧   | `item_bfury`          |
| 分身斧   | `item_manta`          |
| 蝴蝶     | `item_butterfly`      |
| TP 卷轴  | `item_tpscroll`       |
| 侦查守卫 | `item_ward_observer`  |
| 显影之尘 | `item_dust`           |

---

## 七、游戏模式详解

### 7.1 模式文件结构

每个模式文件都包含两个核心函数：

```lua
-- 决定是否要进入这个模式
function GetDesire()
    -- 返回 0~1 的欲望值
    return desire
end

-- 进入模式后执行的行为
function Think()
    -- 移动、攻击、施法等操作
end
```

### 7.2 常用模式速查

| 模式文件                     | 用途     | 典型返回欲望的场景   |
| ---------------------------- | -------- | -------------------- |
| `mode_laning_generic.lua`    | 对线     | 游戏时间 < 8 分钟    |
| `mode_farm_generic.lua`      | 打钱刷野 | 需要经济、附近有野怪 |
| `mode_push_tower_*.lua`      | 推塔     | 有兵线、有装备优势   |
| `mode_retreat_*.lua`         | 撤退     | 血量低、被围攻       |
| `mode_team_roam_generic.lua` | 游走抓人 | 有烟雾、有团战机会   |
| `mode_ward_generic.lua`      | 插眼     | 有眼位需要补充       |
| `mode_rune_generic.lua`      | 捡符     | 神符刷新             |

### 7.3 模式之间的协作

```
mode_farm 欲望 = 0.5（打钱）
    ↓
队友发信号请求支援
    ↓
mode_team_roam 欲望 = 0.8（游走）
    ↓
引擎选中游走模式 → 执行 TeamRoamThink()
    ↓
敌方撤退, 我方血量低
    ↓
mode_retreat 欲望 = 0.9（撤退）
    ↓
引擎选中撤退模式 → 执行 RetreatThink()
```

---

## 八、调试技巧

### 8.1 在游戏中重载脚本

按 `` ` `` 打开控制台，输入：

```
dota_bot_reload_scripts
```

无需重启房间即可生效。

### 8.2 用聊天输出调试信息

```lua
-- 在游戏内发送聊天消息
npcBot:ActionImmediate_Chat("血量: " .. npcBot:GetHealth(), true)

-- 第二个参数 true = 只对友军可见
```

### 8.3 打印变量到控制台

```lua
print("当前游戏时间: " .. DotaTime())
print("英雄名称: " .. npcBot:GetUnitName())
print("当前模式: " .. npcBot:GetActiveMode())
print("技能CD: " .. ability:GetCooldownTimeRemaining())
```

### 8.4 使用本项目的调试工具

```lua
-- 调试聊天（默认关闭，改 config.lua 的 debugMode）
utility.DebugTalk("正在尝试使用技能")

-- 打印表格内容
utility.DebugTable({health = 100, mana = 50})

-- 打印技能名称
utility.PrintAbilityName(abilities)
```

### 8.5 常见的调试思路

```
Bot 不走？         → 检查 GetDesire() 是否返回了非零值
Bot 不放技能？     → 检查 IsFullyCastable() 和 CanCast()
Bot 一直买错装备？ → 检查 ItemsToBuy 列表和金钱判断
Bot 卡住了？      → 检查 stuckLoc 检测逻辑
```

---

## 九、常见问题

### Q1：为什么 Bot 不动？
- 检查 `GetDesire()` 是否返回 `> 0`
- 检查 Bot 是否被眩晕或控制
- 检查是否有 `ActionImmediate_*` 指令冲突

### Q2：为什么 Bot 不放技能？
- 技能是否在 CD？
- 蓝量是否足够？
- 目标是否满足施法条件（可见、非魔免）？
- `IsFullyCastable()` 是否返回 true？

### Q3：如何让 Bot 认识更多的物品？
在 `ItemUsageSystem.lua` 中添加物品使用逻辑，或在英雄的 `ability_item_usage_*.lua` 中添加物品使用考虑函数。

### Q4：如何添加新英雄？
参见 `ARCHITECTURE.md` 的"扩展指南"部分。

### Q5：脚本不生效怎么办？
1. 确认文件在正确的目录（`vscripts/` 下）
2. 确认文件命名正确（`bot_<内部名>.lua`）
3. 在控制台输入 `dota_bot_reload_scripts`
4. 检查游戏内 Bot 选择菜单中是否有你的脚本
5. 查看游戏控制台是否有 Lua 错误输出

---

## 十、参考资料

### 官方资源
- [Valve Dota Bot Scripting API](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting)
- [Mod Dota Lua Bots](http://docs.moddota.com/lua_bots/)
- [Dota 2 开发者论坛](http://dev.dota2.com/forumdisplay.php?f=497)
- [英雄内部名称列表](https://dota2.gamepedia.com/Cheats#Hero_names)

### 中文资源
- [百度贴吧 — Dota2 AI 开发教程](https://tieba.baidu.com/p/4909536751)
- [个人博客 — Dota2 AI 开发教程](http://www.adamqqq.com/ai/dota2-ai-devlopment-tutorial.html)

### 本项目资源
- [架构设计文档](./ARCHITECTURE.md) — 了解本项目结构
- `src/util/Utility.lua` — 通用工具函数
- `src/util/AbilityAbstraction.lua` — 函数式编程工具
- `src/ability_item_usage_generic.lua` — 通用逻辑（加点、买活、符文）
- `dev/DEV_ability_item_usage_normal.lua` — 开发测试模板

### 学习路线建议

```
1. 读本指南 → 理解基础概念
2. 运行 Hello World → 确认环境正常
3. 读 Utility.lua → 掌握工具函数
4. 读一个简单英雄的脚本（如骷髅王 skeleton_king）
5. 修改该英雄的加点/出装 → 测试效果
6. 尝试为未实现的英雄编写脚本
7. 读 mode_* 文件 → 理解模式系统
8. 修改或创建新模式
```
