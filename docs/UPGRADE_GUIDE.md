# 项目升级指南 —— 适配 Dota2 7.41c

> 本文档指导如何将本项目（基于 7.29 的 v1.7.5）升级到最新的 Dota2 7.41c 版本。

---

## 一、工作量评估

| 模块                     | 工作量     | 难度 | 说明                               |
| ------------------------ | ---------- | ---- | ---------------------------------- |
| **工具层** (util/)       | ⭐ 低       | 简单 | 核心 API 基本不变，少量调整即可    |
| **出装系统**             | ⭐⭐ 中      | 中等 | 物品名/配方变了，但框架可复用      |
| **英雄技能** (110+ 文件) | ⭐⭐⭐⭐⭐ 极高 | 复杂 | 每个英雄的技能名、数值、天赋全变了 |
| **英雄出装** (110+ 文件) | ⭐⭐⭐ 高     | 中等 | 物品名更新 + 出装思路调整          |
| **选人系统**             | ⭐ 低       | 简单 | 更新英雄池列表                     |
| **眼位坐标**             | ⭐⭐ 中      | 中等 | 地图可能有微调，需重新采集         |
| **野怪营地**             | ⭐⭐ 中      | 中等 | 拉野时间/坐标可能变化              |
| **游戏模式** (mode_*)    | ⭐⭐ 中      | 中等 | 逻辑可复用，数值需调整             |

**总估算**: 如果一个人全职做，大约 **2~4 周** 可以完成基础适配。

---

## 二、分阶段升级路线

### 🟢 第一阶段：基础验证（1~2 天）— ✅ 已完成

**目标**: 确认脚本能在 7.41c 下加载，不报错。

1. ✅ **部署最新源码** — 将 `src/` 复制到 `vscripts/`
2. ✅ **启动游戏测试** — 创建房间，看是否有 Lua 报错
3. ✅ **修复 API 兼容性** — 已修复以下兼容性问题：
   - ❌ `module()` / `getfenv()` 移除 → 改为手动表前缀模式
   - ❌ `dofile()` 禁用 → 全部替换为 `require()`
   - ❌ `BotsInit.CreateGeneric()` 内含移除的 `setfenv()` → 改为 `local M = {}`
   - ❌ `RandomFloat()` 移除 → 改为 `math.random()`

**关键检查点**:
```lua
-- 以下函数是否还存在？
GetBot()          -- ✅ 可用
GetUnitList()     -- ✅ 可用
ActionImmediate_* -- ✅ 可用
IsFullyCastable() -- ✅ 可用
GetAbilityInSlot()-- ✅ 可用
```

**预计产出**: ✅ 游戏能加载脚本，Bot 会动但行为可能异常。

---

### 🟡 第二阶段：工具层适配（2~3 天）— ⏳ 进行中

**目标**: 确保所有工具函数在 7.41c 下正常工作。

#### 2.1 `Utility.lua`
- 检查免疫 modifier 名称是否变化：
  ```lua
  -- 这些 modifier 名可能需要更新
  "modifier_abaddon_borrowed_time"
  "modifier_winter_wyvern_winters_curse"
  "modifier_obsidian_destroyer_astral_imprisonment_prison"
  ```
- 检查泉水坐标是否变化
- 测试 `IsStuck()` 检测逻辑

#### 2.2 `AbilityAbstraction.lua`
- 检查法术格挡 modifier（林肯、莲花、回音盾等）
  ```lua
  "modifier_antimage_counterspell"
  "modifier_item_sphere"
  "modifier_item_lotus_orb_active"
  "modifier_mirror_shield_delay"
  ```
- 检查新物品/新技能是否有新的格挡机制

#### 2.3 `ItemPurchaseSystem.lua`
- 更新物品配方展开逻辑：`Transfer()` 函数递归深度是否足够
- 检查 `IsItemPurchasedFromSecretShop()` 是否仍有效
- 确认 `IsItemPurchasedFromSideShop()` 逻辑

#### 2.4 `ItemUsageSystem.lua`
- 更新物品 modifier 名称：
  ```lua
  -- 假腿切换
  "modifier_power_treads"
  -- 其他物品
  ```
- 补充新物品的使用逻辑（7.29~7.41c 期间新增的物品）

#### 2.5 `CourierSystem.lua`
- 确认信使 API 是否变化
- 检查 `GetCourier()`, `ActionImmediate_DisassembleItem()` 等

---

### 🟠 第三阶段：数据采集（2~3 天）— ⏳ 待开始

**目标**: 收集 7.41c 版本的实际游戏数据。

#### 需要采集的数据清单

| 数据         | 采集方法                                  |
| ------------ | ----------------------------------------- |
| 英雄内部名称 | 游戏内 `dota_unit_serialize` 控制台命令   |
| 技能名称     | 每个英雄的技能面板截图或控制台            |
| 技能加点顺序 | 参考主流攻略（Dotabuff/Stratz）           |
| 天赋树       | 游戏内查看                                |
| 物品名称     | `item_xxx` 格式，通过控制台或 Wiki        |
| 出装思路     | 参考职业比赛 / 高分段路人                 |
| 眼位坐标     | 游戏内 `dota_vision_debug` 命令或手动记录 |
| 野怪营地坐标 | 控制台或社区资源                          |

#### 推荐工具

```
# Dota2 控制台命令
dota_unit_serialize              # 输出所有单位/技能信息
dota_vision_debug 1              # 显示视野范围
dota_bot_reload_scripts          # 重载脚本
-lua "print(GetBot():GetUnitName())"  # 执行 Lua 代码
```

#### 英雄技能名收集脚本

在游戏内创建一个测试 Bot，让它打印自己的技能信息：

```lua
-- debug_abilities.lua —— 放在 vscripts/ 下
function Think()
    local bot = GetBot()
    for i = 0, 25 do
        local ability = bot:GetAbilityInSlot(i)
        if ability ~= nil then
            print("Slot " .. i .. ": " .. ability:GetName())
        end
    end
end
```

---

### 🔵 第四阶段：英雄脚本重写（1~2 周）— ⏳ 待开始

**这是工作量最大的阶段**。需要逐个英雄更新 `ability_item_usage_*.lua`。

#### 4.1 按优先级排序

建议按以下顺序处理：

```
第一批（核心英雄，10 个）:
  → 骷髅王、宙斯、巫妖     ← 技能简单，容易调试
  → 敌法师、幻影刺客       ← 热门英雄，验证核心逻辑
  → 水晶室女、戴泽         ← 辅助代表

第二批（常用英雄，30 个）:
  → 按游戏位置分批: 核心/辅助/劣单

第三批（剩余 70+ 个）:
  → 逐个补齐
```

#### 4.2 更新技能加点表

```
旧版格式（30 级固定）:
  Abilities[1],  -- 1级
  Abilities[2],  -- 2级
  ...

新版需要:
  1. 确认技能槽位索引是否正确
  2. 确认天赋在 10/15/20/25 级的位置
  3. 更新 "nil" 为实际属性奖励技能名
```

#### 4.3 更新技能考虑函数

```
旧版代码中的问题:
  - 技能名可能变了 (如 nevermore → shadow_fiend)
  - 技能机制可能重做 (如猴子、小骷髅)
  - modifier 名称可能变化
  - 伤害类型可能变化

修复方法:
  - 对照新技能机制重写 Consider 函数
  - 使用新 modifier 名称
  - 调整伤害计算
```

#### 4.4 模板化更新策略

对于技能简单的英雄，可以使用自动化模板：

```lua
-- 模板: 指向性伤害技能
Consider[1] = function()
    local ability = AbilitiesReal[1]
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end
    local enemies = npcBot:GetNearbyHeroes(ability:GetCastRange(), true, BOT_MODE_NONE)
    local target = FindBestTarget(enemies)
    if target ~= nil and CanCast[1](target) then
        return BOT_ACTION_DESIRE_MODERATE, target
    end
    return BOT_ACTION_DESIRE_NONE, nil
end
```

---

### 🟣 第五阶段：出装方案更新（3~5 天）

#### 5.1 更新的物品名

7.29 → 7.41c 期间可能变更的物品：

```lua
-- 可能已移除或重命名的物品
"item_bfury"              -- 狂战斧配方可能变化
"item_manta"              -- 分身斧配方
"item_abyssal_blade"      -- 大晕锤
"item_black_king_bar"     -- BKB
-- 检查每个物品的当前状态
```

#### 5.2 检查新物品

7.29 之后可能新增的物品（举例，不完整）：

```lua
-- 需要确认是否存在及 Lua 名称
"item_"+新物品1
"item_"+新物品2
```

#### 5.3 更新 `SellExtraItem()` 逻辑

```lua
-- ItemPurchaseSystem.lua 中关于出售时机的判断
-- 游戏时间节点可能需要调整
GameTime() > 6 * 60    -- 6分钟
GameTime() > 25 * 60   -- 25分钟
GameTime() > 35 * 60   -- 35分钟
-- 这些时间点在新版本游戏中是否合理？
```

---

### 🔴 第六阶段：游戏模式调整（2~3 天）

#### 6.1 `mode_farm_generic.lua`
- 野怪营地坐标更新（`CampUtility.lua`）
- 拉野时间计算（`CStackTime` 数组）
- 中立生物装备（Neutral Items）的处理

#### 6.2 `mode_ward_generic.lua`
- 更新所有眼位坐标（地图可能改动）
- 新增/移除的眼位点
- 视野范围确认（`visionRad = 1600` 是否仍然是 1600）

#### 6.3 `mode_push_tower_*.lua` 和 `PushUtility.lua`
- 防御塔攻击力/护甲变化 → 调整推进时机判断
- 兵线交汇点位置变化

#### 6.4 `mode_rune_generic.lua`
- 神符刷新机制是否变化
- 赏金符数量/位置

#### 6.5 `mode_team_roam_generic.lua`
- 烟雾机制是否变化
- 野区地形变化（影响绕后路线）

---

### 🟤 第七阶段：选人系统更新（1 天）

#### 7.1 更新英雄池

```lua
-- hero_selection.lua 中 hero_pool 列表
-- 1. 添加新英雄
-- 2. 重命名的英雄（如 nevermore → shadow_fiend）
-- 3. 移除已删除的英雄
```

#### 7.2 更新角色评分

```lua
-- RoleUtility.lua 中 hero_roles 表
-- 每个英雄的 9 个维度评分可能需要调整
-- 新英雄需要添加评分
```

#### 7.3 添加新英雄的引用

```lua
-- 如果新增英雄有特殊行为，需要创建 bot_<新英雄>.lua
-- 确保新英雄在英雄池、角色表、技能脚本中一致
```

---

### ⚪ 第八阶段：测试与调优（持续）

#### 8.1 测试清单

```
□ 脚本无 Lua 报错加载
□ Bot 能正常选人进游戏
□ Bot 能正常加点
□ Bot 能购买装备
□ Bot 能使用技能
□ Bot 能正常对线
□ Bot 能打钱刷野
□ Bot 能推进/防守
□ Bot 能撤退求生
□ 信使正常工作
□ 买活逻辑正常
□ 防御符文正常
```

#### 8.2 批量测试方法

```lua
-- 创建一个测试脚本，让游戏自动运行并记录行为
-- 然后用控制台输出分析问题
```

#### 8.3 常见问题排查

| 症状                  | 可能原因                        |
| --------------------- | ------------------------------- |
| Bot 一级就有 6 个技能 | 技能槽索引变了                  |
| 技能点了没反应        | 技能名不对或已被移除            |
| 买不了装备            | 物品名不对或配方变了            |
| Bot 站在原地不动      | 模式函数报错导致 Think() 未执行 |
| 信使乱飞              | CourierSystem 中信使 API 变化   |
| 眼插在墙里            | 坐标不对或地形变化              |

---

## 三、推荐的工具和资源

### 开发工具
- **VS Code** + Lua 插件
- Dota2 控制台（`` ` `` 键）
- `dota_bot_reload_scripts` 命令（热重载）

### 数据来源
| 资源                                       | 用途                         |
| ------------------------------------------ | ---------------------------- |
| [Stratz](https://stratz.com)               | 英雄胜率、出装、加点热门数据 |
| [Dotabuff](https://dotabuff.com)           | 出装和加点统计               |
| [Liquipedia](https://liquipedia.net/dota2) | 版本更新日志                 |
| [Dota2 Wiki](https://dota2.fandom.com)     | 技能详细数值                 |
| 游戏内英雄展示                             | 技能名和天赋树               |

### 工作流程建议

```
1. 打开 Stratz 找一个英雄 → 看热门加点和出装
2. 在游戏内测试该英雄 → 用控制台获取技能名
3. 更新 ability_item_usage_<英雄>.lua
4. 更新 item_purchase_<英雄>.lua
5. 热重载脚本 → 观察行为
6. 调整数值 → 重复 5-6
```

---

## 四、项目维护建议

### 4.1 版本管理
- 创建 `archived/` 文件夹存放原始 v1.7.5 代码
- 在 `changelog/` 中记录你的适配日志
- 使用 Git 管理每次批量更新

### 4.2 自动化方案（进阶）

对于技能结构相似的英雄，可以考虑写一个**代码生成脚本**（用 Python 或 Lua）：

```
输入: 英雄名 + 技能类型模板（指向性/AOE/开关/被动）
输出: 自动生成 ability_item_usage_<英雄>.lua 框架代码
```

这样可以大幅减少重复劳动。

### 4.3 协作建议
如果多人协作，可以按位置分工：

| 人员     | 负责                     |
| -------- | ------------------------ |
| 开发者 A | 核心/Carry 英雄（30 个） |
| 开发者 B | 辅助英雄（30 个）        |
| 开发者 C | 劣单/打野英雄（30 个）   |
| 开发者 D | 工具层维护 + 测试        |
