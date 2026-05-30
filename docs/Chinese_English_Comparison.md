# DOTA2 Lua 脚本开发术语中英对照表

整理自 DOTA2 Lua 脚本开发中最常用的术语，覆盖**通用概念**、**Bot AI 脚本**、**API 函数**三类高频场景。

---

## 通用术语

| 英文术语       | 中文含义      | 常见使用场景                                                                 |
| -------------- | ------------- | ---------------------------------------------------------------------------- |
| ability        | 技能          | 描述英雄技能逻辑，如 `ability:GetLevel()`                                    |
| camp           | 野怪营地      | 地图上的中立野怪生成点，处理堆野/刷新逻辑                                    |
| creep          | 小兵/野怪     | 泛指所有非英雄单位，分 `neutral creep`（中立野怪）、`lane creep`（对线小兵） |
| GPM            | 每分钟金钱    | `GetGoldPerMin()`，统计英雄经济获取效率                                      |
| XPM            | 每分钟经验    | 统计英雄经验获取效率                                                         |
| gank           | 游走抓人      | 打野/中路英雄游走击杀敌方英雄的战术                                          |
| handler        | 处理器        | 处理特定事件的回调函数，如 `OnDamageHandler`                                 |
| hash/hashtable | 哈希表        | 使用 Lua 表实现的快速查找结构                                                |
| illusion       | 幻象          | 英雄召唤的镜像单位，如幻影长矛手的技能召唤物                                 |
| jul            | 装备/物品     | 口语化代指 item，正规写法用 item                                             |
| jungler/jg     | 打野/打野英雄 | 依赖野区资源发育，带动节奏的位置                                             |
| leash          | 拉野          | 将野怪从营地拉出，实现堆野的操作                                             |
| main           | 主入口        | 自定义游戏的主入口脚本，一般是 `addon_game_mode.lua`                         |
| modifier       | 增益/减益效果 | 单位身上的状态效果，如加速、减速、眩晕                                       |
| neutral        | 中立          | `neutral item`（中立物品）、`neutral camp`（中立野区营地）                   |
| npc            | 非玩家单位    | 泛指小兵、野怪、Roshan 等非玩家控制的单位                                    |
| particle       | 特效粒子      | 技能释放的视觉特效，如 `particle:Create()`                                   |
| proc           | 触发          | 被动效果的触发，如 *this passive proc on hit*                                |
| Roshan/Rosh    | 肉山          | 地图中央河道的顶级中立 boss，掉落不朽盾                                      |
| spawn          | 刷新/生成     | 单位/野怪出生，如 `SpawnNeutralCreeps()`                                     |
| stack          | 堆野/叠加     | ① 堆野：同一营地多组野怪共存；② 叠加：技能效果层数叠加                       |
| tpscroll       | 回城卷轴      | 官方物品名 `item_tpscroll`，存放在隐藏消耗品槽位                             |
| tick           | 帧回调        | 每帧执行一次的逻辑                                                           |
| thinker        | 思考器        | 持续运行的逻辑定时器                                                         |
| tower          | 防御塔        | 各路线上的防御建筑                                                           |
| unit           | 单位          | 游戏中所有可互动实体的统称（英雄、小兵、野怪都属于单位）                     |
| vscript        | Valve 脚本    | DOTA2 使用的 Lua 脚本运行环境                                                |

---

## Bot AI 脚本术语

针对 Dota 2 AI (Bot) 脚本开发，除了通用术语外，还有一套专门用于控制机器人行为、决策和状态管理的术语。

### 1. 核心行为与动作 (Actions & Behavior)

| 英文术语        | 中文含义         | API/场景示例                           |
| --------------- | ---------------- | -------------------------------------- |
| ActionImmediate | 立即执行动作     | `npc:ActionImmediate_MoveToPosition()` |
| ActionPush      | 将动作推入队列   | `npc:ActionPush_UseAbility()`          |
| ActionClear     | 清空当前动作队列 | `npc:ActionClear()`                    |
| Retreat         | 撤退/回城补给    | `bot:Retreat()` 或自定义低血量逻辑     |
| Lane Push       | 推线             | 控制小兵进塔或清理兵线以获取优势       |
| Rotate          | 支援/转线        | 从一条路移动到另一条路参与战斗         |
| Farm            | 打钱/发育        | 优先攻击小兵或中立野怪以获取金钱经验   |
| Gank            | 抓人/游走        | 主动寻找并击杀落单敌方英雄             |
| Last Hit        | 补刀             | 对即将死亡的小兵进行最后一击以获取金钱 |
| Deny            | 反补             | 击杀己方半血以下小兵，阻止敌方获得经验 |

### 2. 状态与评估 (State & Evaluation)

| 英文术语       | 中文含义      | API/场景示例                                |
| -------------- | ------------- | ------------------------------------------- |
| Health Percent | 生命值百分比  | `npc:GetHealth() / npc:GetMaxHealth()`      |
| Mana Percent   | 魔法值百分比  | `npc:GetMana() / npc:GetMaxMana()`          |
| Cooldown       | 冷却时间      | `ability:GetCooldownTimeRemaining()`        |
| Range          | 攻击/施法距离 | `ability:GetCastRange()`                    |
| Vision         | 视野          | `npc:GetCurrentVisionRange()`               |
| Aggro          | 仇恨/吸引火力 | 吸引野怪或敌方英雄的攻击目标                |
| Threat         | 威胁度        | 评估敌方英雄对己方的危险程度                |
| Priority       | 优先级        | 决定先打谁（如：先杀辅助还是先杀核心）      |
| Desire         | 欲望值/倾向性 | Bot 框架中常用的概念，如 *desire to attack* |

### 3. 地图与导航 (Map & Navigation)

| 英文术语    | 中文含义        | API/场景示例                       |
| ----------- | --------------- | ---------------------------------- |
| Lane        | 兵线            | `LANE_TOP`, `LANE_MID`, `LANE_BOT` |
| Jungle      | 野区            | 中立生物生成的区域                 |
| Rune Spot   | 符点            | 赏金符、强化符生成位置             |
| Shop        | 商店            | 基地商店或边路秘密商店             |
| Pathing     | 寻路/路径规划   | `FindPathablePositionNearby()`     |
| Choke Point | 狭窄路口/瓶颈点 | 易守难攻的地形，常用于埋伏         |
| High Ground | 高地            | 具有视野优势和 miss 几率的地形     |
| Fog of War  | 战争迷雾        | 未探索或无视野的区域               |

---

### 4. 常用 Bot API 函数前缀

在编写 Bot 脚本时，你经常会看到以下对象和方法：

| 函数/对象            | 含义                                                     |
| -------------------- | -------------------------------------------------------- |
| `npcBot`             | 当前控制的机器人英雄实体                                 |
| `GetUnitList()`      | 获取所有单位列表（需过滤敌我）                           |
| `GetCouriers()`      | 获取信使                                                 |
| `GetItemInSlot()`    | 获取物品                                                 |
| `GetAbilityByName()` | 通过名称获取技能对象                                     |
| `GetLocation()`      | 获取当前位置向量                                         |
| `GetTeam()`          | 获取队伍 ID (`DOTA_TEAM_GOODGUYS` / `DOTA_TEAM_BADGUYS`) |

---

### 5. 常见逻辑结构示例

一个典型的 Bot 思考循环（Think Loop）通常包含以下步骤：

```lua
function Think()
    -- 1. 更新状态
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth()

    -- 2. 判断是否需要撤退
    if healthPercent < 0.3 and not HasTP() then
        Retreat()
        return
    end

    -- 3. 判断是否可以使用技能
    if CanUseStun() then
        CastStunOnEnemy()
        return
    end

    -- 4. 默认行为：推线或打钱
    PushLaneOrFarm()
end
```
