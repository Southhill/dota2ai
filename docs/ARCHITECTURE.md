# Agent2026 — 架构设计文档

## 一、项目概述

本项目是一个基于 Valve 官方 Dota2 Bot 框架的增强 AI 脚本，使用 Lua 语言编写。它通过覆写 Valve 提供的 Bot 接口函数，实现了更智能的英雄行为、团队协作和游戏决策。

### 技术栈
- **语言**: Lua 5.x (嵌入在 Dota2 的 Source 引擎中)
- **框架**: Valve Dota Bot Scripting API
- **许可证**: GPLv3

---

## 二、总体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      Dota2 游戏引擎                              │
│  (提供 API: GetBot(), GetUnitList(), ActionImmediate_* 等)       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ 回调
┌──────────────────────────▼──────────────────────────────────────┐
│                    入口层 (Entry Points)                          │
│  hero_selection.lua    │  ability_item_usage_*.lua               │
│  (选人 + 分路)          │  (技能使用 + 加点)                       │
│                        │  item_purchase_*.lua                   │
│                        │  (出装)                                 │
└──────────┬─────────────┴────────────┬───────────────────────────┘
           │                          │
           ▼                          ▼
┌──────────────────────┐  ┌───────────────────────────────────────┐
│   通用逻辑层           │  │   游戏模式层 (Game Modes)              │
│  ability_item_usage_  │  │  mode_farm_generic.lua               │
│  generic.lua          │  │  mode_laning_generic.lua             │
│  (加点/符文/买活/卡住)  │  │  mode_push_tower_*.lua              │
│                       │  │  mode_team_roam_generic.lua          │
│                       │  │  mode_ward_generic.lua               │
│                       │  │  mode_rune_generic.lua               │
│                       │  │  mode_retreat_*.lua                  │
│                       │  │  mode_side_shop_generic.lua          │
│                       │  │  team_desires.lua                    │
└──────────┬────────────┘  └──────────────────┬───────────────────┘
           │                                  │
           └──────────┬───────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     工具层 (Utilities)                            │
│                                                                  │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────────────┐  │
│  │ Ability     │ │ ItemPurchase │ │ CourierSystem.lua        │  │
│  │ Abstraction │ │ System.lua   │ │ (信使管理)               │  │
│  │ .lua        │ │ (出装引擎)   │ └──────────────────────────┘  │
│  │ (函数式工具) │ └──────────────┘ ┌──────────────────────────┐  │
│  └─────────────┘ ┌──────────────┐ │ PushUtility.lua          │  │
│  ┌─────────────┐ │ ItemUsage    │ │ (推进逻辑)               │  │
│  │ Utility.lua │ │ System.lua   │ └──────────────────────────┘  │
│  │ (通用工具)   │ │ (物品使用)   │ ┌──────────────────────────┐  │
│  └─────────────┘ └──────────────┘ │ WardUtility.lua          │  │
│  ┌─────────────┐ ┌──────────────┐ │ (插眼系统)               │  │
│  │ Ability     │ │ RoleUtility  │ └──────────────────────────┘  │
│  │ Helper.lua  │ │ .lua         │ ┌──────────────────────────┐  │
│  │ (技能辅助)   │ │ (角色定位)   │ │ CampUtility.lua          │  │
│  └─────────────┘ └──────────────┘ │ (野怪管理)               │  │
│  ┌─────────────┐ ┌──────────────┐ └──────────────────────────┘  │
│  │ ChatSystem  │ │ BotName      │ ┌──────────────────────────┐  │
│  │ .lua        │ │ Utility.lua  │ │ MinionUtility.lua        │  │
│  │ (聊天系统)   │ │ (命名系统)   │ │ NewMinionUtil.lua        │  │
│  └─────────────┘ └──────────────┘ │ (召唤物/幻象控制)        │  │
│  ┌─────────────┐ ┌──────────────┐ └──────────────────────────┘  │
│  │ BinDecHex   │ │ Tools.lua    │                               │
│  │ .lua        │ │ (基础工具)   │                               │
│  └─────────────┘ └──────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、分层架构详解

### 3.1 入口层 (Entry Points)

每个英雄对应两套脚本文件，由 Dota2 引擎按文件名自动加载：

#### `ability_item_usage_<hero_name>.lua`（技能与物品使用）
每个英雄一份，约 110+ 个文件。结构统一：
1. **初始化段** — 声明技能/天赋列表，定义加点顺序表 `AbilityToLevelUp`
2. **加点表** — 30 级完整加点方案，用 `Abilities[n]` 引用技能，"talent" 表示天赋，"nil" 表示属性奖励
3. **天赋树** — `TalentTree` 数组，每个条目是一个返回天赋名称的函数
4. **技能考虑函数** `Consider[n]` — 每个技能一个函数，计算施放欲望值 `(0 ~ BOT_ACTION_DESIRE_HIGH)`
5. **物品使用** — 调用通用物品使用逻辑

#### `item_purchase_<hero_name>.lua`（出装方案）
每个英雄一份。定义出装顺序列表，调用 `ItemPurchaseSystem`。

#### `bot_<hero_name>.lua`（特殊行为）
为有特殊机制的英雄准备的独立行为脚本。分为两类使用模式：

- **完整实现**：如 `bot_brewmaster.lua`（熊猫酒仙），在文件内直接实现完整的 `MinionThink` 逻辑，
  分别控制熊猫的三个分身（风暴/大地/火焰）的技能施放、攻击、移动和撤退。
- **委托实现**：如 `bot_enchantress.lua` 和 `bot_chen.lua`（魅惑魔女/陈），仅为薄封装层，
  将 `MinionThink` 委托给 `MinionUtility.MinionThink()` 复用共享的召唤物 AI。

**注意**：`MinionThink(hMinionUnit)` 是 Dota2 引擎的标准回调函数，引擎自动为每个非英雄单位
（召唤物、野怪、幻象）调用。
该函数与 `Think()` / `AbilityUsageThink()` 并列，由引擎按文件名自动发现。

#### `hero_selection.lua`（选人系统）
- 维护全英雄池 `hero_pool`
- 根据角色定位（核心/辅助/劣单等）智能选人
- 支持队长模式（CM）的 BP 顺序
- 通过聊天频道手动选人

### 3.2 通用逻辑层

#### `ability_item_usage_generic.lua`
核心通用逻辑，被所有英雄文件 `require`。包含：
- **防御符文** — 监测防御塔血量变化，自动使用 Glyph
- **卡住检测** — 记录位置变化，检测 Bot 是否卡在地形中
- **买活系统** — 关键建筑被攻击时自动买活，35分钟后自动买活
- **技能加点引擎** — 按预设表逐级加点，含错误恢复机制
- **连招计算** — `GetComboDamage()` / `GetComboMana()`
- **技能施放引擎** — `ConsiderAbility()` 根据欲望值执行技能
- **遗迹告警** — 遗迹血量过低时发信号

#### `team_desires.lua`（团队决策）
- `GetCommonPushLaneDesires()` — 根据装备和游戏时间计算团队推进欲望
- 考虑装备：王者之戒、玄冥盾牌、回复头巾、梅肯、笛子、大鞋、强袭、冰甲、不朽盾、死灵书等

### 3.3 游戏模式层 (Game Modes)

每个模式文件实现 `GetDesire()` 和 `Think()` 两个核心函数：

| 模式文件                       | 功能          |
| ------------------------------ | ------------- |
| `mode_laning_generic.lua`      | 对线期行为    |
| `mode_farm_generic.lua`        | 打钱/刷野行为 |
| `mode_push_tower_*.lua`        | 三路推进/防守 |
| `mode_retreat_*.lua`           | 撤退逻辑      |
| `mode_team_roam_generic.lua`   | 团队游走抓人  |
| `mode_rune_generic.lua`        | 神符拾取      |
| `mode_ward_generic.lua`        | 插眼巡逻      |
| `mode_side_shop_generic.lua`   | 边路商店购物  |
| `mode_secret_shop_generic.lua` | 神秘商店购物  |

**核心机制**: 每个模式返回一个 **欲望值 (Desire)**，Dota2 引擎比较所有模式返回的欲望值，选择最高者作为当前行为。

### 3.4 工具层 (Utilities)

#### `AbilityAbstraction.lua` — 函数式抽象库
- 类似 C# LINQ 的函数式工具（Map/Filter/Reduce/GroupBy 等）
- 统一使用自定义元表 `magicTable` 支持链式调用
- Bot 行为判定：`IsFarmingOrPushing()`、`IsLaning()`、`IsRetreating()` 等
- 技能格挡检测：`PreventEnemyTargetAbilityUsageAtAbilityBlock()` 处理林肯/莲花/回音盾
- 幻象保护：`PreventAbilityAtIllusion()` 防止浪费技能在幻象上
- 开关技能适配：`ToggleFunctionToAction()` / `ToggleFunctionToAutoCast()`

#### `Utility.lua` — 通用工具库
- 施法判定：`NCanCast` / `UCanCast` / `MiCanCast`（普通/魔免/通用）
- 距离计算：`PointToPointDistance` / `GetDistance`
- 向量操作：`GetForwardVector` / `GetUnitsTowardsLocation`
- 单位查找：`GetWeakestUnit` / `GetStrongestUnit`
- 建筑管理：`GetAllBuilding` / `GetNearestBuilding`
- 卡住检测：`IsStuck`
- 逃生位置：`GetEscapeLoc`

#### `ItemPurchaseSystem.lua` — 出装引擎
- **物品配方展开**: `Transfer()` 递归展开合成配方
- **智能购买**: 区分普通商店/神秘商店/信使购买
- **格子管理**: `SellExtraItem()` / `SellSpecifiedItem()` 自动出售低价值物品
- **TP 管理**: `WeNeedTpscroll()` 确保英雄有 TP，`NoNeedTpscrollForTravelBoots()` 飞鞋替代 TP
- **物品名快捷引用**: `ItemName` 表通过 `__index` 元方法实现 `ItemName.tango → "item_tango"` 自动补全，但当前项目中无实际使用，属死代码

#### `ItemUsageSystem.lua` — 物品使用引擎
- 魔法棒/大魔棒使用
- 假腿切换（根据主属性）
- TP 使用决策（对线/防守/推进/支援/撤退）
- 卡住检测与 TP 脱困
- 吃树分享（给中单）

#### `CourierSystem.lua` — 信使系统
- 信使分配（哪个英雄使用哪个信使）
- 物品拾取（提前从 stash 取出）
- 危险规避（检测敌方英雄/防御塔）
- 飞行信使升级

#### `PushUtility.lua` — 推进工具
- `GetLane()` — 判断英雄所在分路
- `IsThisLaneNeedToClean()` — 判断是否需要收线
- `GetUnitPushLaneDesire()` — 综合计算推进欲望（等级/血量/蓝量/角色/距离/TP）
- `isNoCreeps()` — 判断兵线位置防止越塔

#### `WardUtility.lua` — 插眼系统
- 预定义眼位坐标（天辉/夜魇各 20+ 个）
- 关键路口眼、塔后眼、进攻眼
- 塔倒自动补眼
- 根据防御塔状态选择眼位

#### 其他工具
| 工具                 | 功能                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------- |
| `CampUtility.lua`    | 野怪营地管理（刷新时间、拉野点坐标）                                                  |
| `RoleUtility.lua`    | 英雄角色评分（carry/support/nuker 等 9 个维度）                                       |
| `BotNameUtility.lua` | 从 TI 职业战队数据生成 Bot 名称                                                       |
| `MinionUtility.lua`  | 召唤物控制（死灵书、野怪、幻象），通过 `MinionThink` 回调被引擎自动调用               |
| `NewMinionUtil.lua`  | 新召唤物系统（熊灵、豪猪、战鹰、地狱火等），提供 `IsBear()`/`IsHawk()` 等类型判断工具 |
| `ChatSystem.lua`     | 版本公告/聊天消息                                                                     |
| `BinDecHex.lua`      | 二进制/十六进制转换（MIT 协议）                                                       |

### 3.5 常量与配置层

| 文件               | 功能                         |
| ------------------ | ---------------------------- |
| `const/config.lua` | 全局配置（debugMode 开关等） |
| `const/enum.lua`   | 枚举数据（隐身英雄列表等）   |
| `const/text.lua`   | TI 职业战队/选手名称数据库   |

---

## 四、核心设计模式

### 4.1 欲望值系统 (Desire System)

这是整个 AI 决策的**核心模式**。每个行为模式返回一个 `[0, 1]` 的欲望值：

```
GetDesire() → BOT_MODE_DESIRE_NONE(0) ~ BOT_MODE_DESIRE_ABSOLUTE(1)
```

**决策流程**:
1. 所有模式同时计算各自的欲望值
2. Dota2 引擎选择欲望值最高的模式
3. 选中模式的 `Think()` 函数被执行
4. 每个技能/物品也有自己的欲望值计算

```
应用场景举例:
  mode_laning    → 0.33 (前期对线)
  mode_farm      → 0.50 (中期刷钱)
  mode_team_roam → 0.80 (团队抓人)
  → 引擎选择 团队游走 模式
```

### 4.2 模块化英雄设计

每个英雄的脚本遵循相同的模板结构：

```
ability_item_usage_<hero>.lua
├── InitAbility()           ← 扫描技能槽
├── AbilityToLevelUp[]      ← 30级加点顺序表
├── TalentTree[]            ← 天赋选择
├── Consider[1..n]          ← 每个技能的施放考虑函数
│   ├── 返回 desire, target
│   └── 内部使用 CanCast/utility 判断
├── AbilityLevelUpThink()   ← 加点主入口
├── GetComboDamage()        ← 连招伤害
└── GetComboMana()          ← 连招蓝耗
```

### 4.3 函数式编程风格

`AbilityAbstraction.lua` 实现了类似 C# LINQ 的函数式工具链：

```lua
-- 链式调用示例
AbilityExtensions
  :Filter(heroes, isEnemy)
  :Map(getHealth)
  :Max()
```

使用自定义元表 `magicTable` 使所有表都自动继承这些方法。

### 4.4 Dota2 7.41c 兼容性适配

项目于 2026年5月完成了 Dota2 7.41c 的兼容性适配，主要变更：

#### 已废弃 API 替换

| 已移除的 API                             | 替换方案                                                               | 影响范围                 |
| ---------------------------------------- | ---------------------------------------------------------------------- | ------------------------ |
| `module()` / `getfenv()`                 | 手动创建模块表 + 函数前缀 (`模块名 = {}` + `function 模块名.函数名()`) | 3 个核心模块文件         |
| `dofile()`                               | `require()` (Dota2 沙箱禁用)                                           | 100+ 文件                |
| `BotsInit.CreateGeneric()` + `setfenv()` | `local M = {}`                                                         | 7 个 util 文件           |
| `RandomFloat()`                          | `math.random()`                                                        | `AbilityAbstraction.lua` |

#### 新增安全包装函数

- `utility.GetNearbyVisibleHeroes()` — 自动过滤不可见单位，避免 `GetHealth()`/`GetMana()` 等调用触发引擎警告
- `GetWeakestUnit()` / `GetStrongestUnit()` — 增加了 `CanBeSeen()` 检查

#### 模块加载安全问题修复

修复了多个文件在模块加载时直接调用 `GetBot()` 导致 nil 引用崩溃的问题，加了 nil 安全检查。

---

### 4.5 错误恢复机制

技能加点系统具有健壮的错误恢复：
- `incorrectAbilityLevelUpNumber` — 记录加点偏移量
- 当技能名无效时自动跳过并记录
- 脚本重载时 `abilityInited` 标志确保状态重置

### 4.6 装饰器模式 (函数包装)

`AbilityAbstraction.lua` 通过包装原技能考虑函数来附加功能：

```
原始 Consider 函数
    ↓
PreventAbilityAtIllusion()    ← 防止对幻象施法
    ↓
PreventEnemyTargetAbilityUsageAtAbilityBlock()  ← 处理林肯法球
    ↓
最终施放决定
```

---

## 五、数据流

### 游戏主循环（每帧执行）

```
Dota2 Engine Tick
    │
    ├─ CourierUsageThink()        ← 信使 + 符文 + 遗迹告警
    │
    ├─ BuybackUsageThink()        ← 买活决策
    │
    ├─ AbilityLevelUpThink()      ← 技能加点
    │
    ├─ ItemPurchaseThink()        ← 物品购买
    │
    ├─ MinionThink(hMinionUnit)   ← 每个非英雄单位的 AI 回调（召唤物/野怪/幻象）
    │
    └─ GetDesire() × N 个模式     ← 选择当前行为模式
         │
         └─ Think()               ← 执行模式逻辑
              │
              └─ Consider[1..n]   ← 计算技能欲望
                   │
                   └─ ActionImmediate_*()  ← 执行操作
```

### 技能施放数据流

```
Consider[n]()
  │  读取: npcBot状态、敌方/友方位置、技能CD、蓝量
  │  计算: 伤害、控制时间、危险程度
  ▼
返回 (desire, target)
  │
ConsiderAbility()
  │  比较所有技能的 desire
  ▼
ActionImmediate_UseAbility(ability, target)
```

---

## 六、模块依赖关系

```
ability_item_usage_<hero>.lua
  ├── utility/Utility.lua
  ├── utility/AbilityAbstraction.lua
  │     └── utility/BinDecHex.lua
  └── ability_item_usage_generic.lua
        ├── utility/Utility.lua
        ├── utility/AbilityAbstraction.lua
        ├── util/ItemUsageSystem.lua
        │     ├── utility/AbilityAbstraction.lua
        │     └── util/RoleUtility.lua
        │           ├── util/Tools.lua
        │           └── const/enum.lua
        └── util/ChatSystem.lua

item_purchase_<hero>.lua
  └── util/ItemPurchaseSystem.lua
        └── utility/AbilityAbstraction.lua

bot_<hero>.lua
  └── utility/MinionUtility.lua（委托实现时）
        └── utility/Utility.lua

mode_*.lua
  ├── utility/Utility.lua
  ├── utility/AbilityAbstraction.lua
  └── util/RoleUtility.lua / CampUtility.lua / WardUtility.lua / PushUtility.lua

hero_selection.lua
  ├── util/RoleUtility.lua
  ├── util/BotNameUtility.lua
  │     └── const/text.lua
  └── const/config.lua
```

---

## 七、已知问题与技术债务

1. ~~**`Tools.lua` 中的 `pairs` bug** — `GenEnumArray` 中 `pairs` 缺少参数 `(t)`，导致隐身英雄列表无法正确生成，影响反隐物品购买判断~~ ✅ **已修复** — `pairs(t)` 参数已补全，`src/util/Tools.lua` 中函数已正常工作
2. **神符模式已禁用** — `mode_rune_generic.lua` 的 `GetDesire()` 直接返回 0，所有神符相关逻辑被注释
3. **臂章已移除** — v1.7.5 因性能问题移除了臂章使用逻辑
4. **团队游走系统暂时关闭** — v1.6e 中注释了开雾抓人系统
5. **部分英雄被移出池子** — 齐天大圣、小小等因 bug 被暂时禁用
6. ~~**`Trim` 函数缺少 `end`** — `AbilityAbstraction.lua` 中 `Trim` 函数的 else 分支缺少一个 `end`，可能导致解析错误~~ ✅ **已修复** — `src/util/AbilityAbstraction.lua` 中所有 `end` 已补全，函数结构正确
7. **死亡的代码存在** — 多处注释掉的旧代码（神泉系统、信使购买等）
8. **`ItemPurchaseUtility.ItemName` 死代码** — 通过 `__index` 元方法实现 `item_` 前缀自动补全，但项目中无任何调用方
9. **文件命名不一致** — 部分英雄使用原名（`nevermore`、`rattletrap`），部分使用新名

---

## 八、扩展指南

### 添加新英雄

1. 创建 `src/ability_item_usage_<英雄名>.lua`（技能使用）
2. 创建 `src/item_purchase_<英雄名>.lua`（出装方案）
3. 在 `ability_item_usage_generic.lua` 中定义加点顺序和天赋树
4. 在 `hero_selection.lua` 的 `hero_pool` 中添加英雄名
5. 在 `RoleUtility.lua` 中添加角色评分
6. （可选）在 `src/bot_<英雄名>.lua` 中添加特殊行为

### 添加新模式

1. 创建 `src/mode_<新模式名>.lua`
2. 实现 `GetDesire()` 返回欲望值
3. 实现 `Think()` 执行模式逻辑
4. 在 `team_desires.lua` 中注册（如需团队级决策）
