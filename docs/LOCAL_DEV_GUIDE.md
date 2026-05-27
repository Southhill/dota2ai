# 本地开发指南

## 项目结构

```
dota2ai/
├── scripts/                    # 部署脚本
│   ├── deploy_agent2026.bat    # 部署（批处理）
│   └── deploy_agent2026.ps1    # 部署（PowerShell，推荐）
├── src/                        # Lua 源码
│   ├── hero_selection.lua      # 英雄选择 & 主入口
│   ├── team_desires.lua        # 团队决策
│   ├── ability_item_usage_*.lua # 各英雄技能/物品使用
│   ├── item_purchase_*.lua     # 各英雄出装逻辑
│   ├── mode_*.lua              # 游戏模式行为
│   ├── const/                  # 常量配置
│   │   ├── config.lua
│   │   ├── enum.lua
│   │   └── text.lua
│   └── util/                   # 工具模块
│       ├── Utility.lua         # (含 GetNearbyVisibleHeroes)
│       ├── CourierSystem.lua
│       ├── ItemPurchaseSystem.lua
│       └── ...
├── dev/                        # 开发测试脚本
├── changelog/                  # 更新日志
└── docs/                       # 文档
    ├── ARCHITECTURE.md         # 架构说明
    ├── BEGINNER_GUIDE.md       # 新手开发指南
    ├── DEVELOP.md              # Dota2 VScript 开发参考
    ├── LOCAL_DEV_GUIDE.md      # 本地开发指南
    └── UPGRADE_GUIDE.md        # Dota2 7.41c 升级计划
```

## Dota2 7.41c 重要变更

此项目已针对 Dota2 7.41c 的 Lua 引擎变更进行了兼容性修复。关键注意事项：

### 不使用的 API
- ❌ **`module()` / `getfenv()`** — 已移除，使用表前缀模式替代
- ❌ **`dofile()`** — 已禁用，使用 `require()` 替代
- ❌ **`setfenv()`** — 已移除，使用 `local M = {}` 模式
- ❌ **`RandomFloat()` / `RandomInt()`** — 已移除，使用 `math.random()` 替代
- ❌ **`BotsInit.CreateGeneric()`** — 已移除，使用 `local M = {}` 替代

### 编码规范
- 所有模块使用 `local M = {}` + `function M.FuncName()` 模式
- 加载其他模块请使用 `local mod = require(GetScriptDirectory() .. "/path/to/mod")`
- 对不可见的敌方单位调用属性方法（`GetHealth()`、`GetMana()` 等）会触发引擎警告
- 使用 `utility.GetNearbyVisibleHeroes()` 替代 `npcBot:GetNearbyHeroes()` 自动过滤不可见单位

## 部署流程

### 1. 部署到 Dota2

在项目根目录打开 PowerShell，运行：

```powershell
.\scripts\deploy_agent2026.ps1
```

或者双击 `scripts\deploy_agent2026.bat`。

部署脚本会：将 `src/` 下的所有文件复制到 `D:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots\`

### 2. 在 Dota2 中测试

1. 启动 Dota2
2. 创建私人房间（Practice Lobby）
3. 在 Bot 设置中选择 **"本地开发脚本"**
4. 开始游戏

### 3. 验证是否运行你的 AI

**控制台确认：**
- 进游戏后按 `` ` `` 打开控制台
- 如果看到以下输出，说明跑的是你的 AI：
  ```
  ============================================
  [Agent2026] 已加载!
  [Agent2026] 当前脚本路径: scripts/vscripts/bots
  ============================================
  ```

**游戏内确认：**
- 开局后 Bot 会在公屏发送消息：
  ```
  [Agent2026] 已启动!
  ```

## 修改代码后的更新流程

每次修改代码后，只需要重新部署即可：

```powershell
.\scripts\deploy_agent2026.ps1
```

然后退出当前游戏房间 → 重新创建房间 → 选"本地开发脚本" → 开始游戏。

> **提示：** Dota2 在比赛开始时才加载脚本，所以需要重新开房间，不需要重启游戏。

## 常见问题

### Q: 部署脚本需要管理员权限吗？
不需要。目标路径在 D 盘，普通用户权限即可。

### Q: 选不到 "本地开发脚本" 怎么办？
确保已经成功运行了部署脚本，然后退出房间重新创建。

### Q: 控制台刷 SteamLearn 错误怎么办？
这是 Dota2 服务端的机器学习系统报错，与你的 Bot 代码无关，可以忽略。

### Q: 如何只测试特定英雄？
修改 `src/hero_selection.lua` 中的 `hero_pool_test` 列表，将你想测试的英雄加入其中。

## 创意工坊发布（开发完成后）

1. 将 `src/` 内容打包
2. 在 Steam 创意工坊创建页面，命名为 **Agent2026**
3. 上传并发布
4. 之后玩家可以在 Dota2 Bot 菜单中直接搜索订阅
