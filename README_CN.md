<p align="center">
  <a href="./README_CN.md">中文</a> | <a href="./README.md">English</a>
</p>

<h1 align="center">🎮 团队节奏 AI — Dota2 Bot 脚本</h1>

<p align="center">
  <strong>基于 Valve 默认 AI 深度改进的 Dota2 Bot 脚本，拥有更智能的行为和更广泛的英雄支持。</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.7.5-blue.svg" alt="版本 1.7.5"/>
  <img src="https://img.shields.io/badge/license-GPLv3-green.svg" alt="许可证 GPLv3"/>
  <img src="https://img.shields.io/badge/language-Lua-orange.svg" alt="语言 Lua"/>
</p>

---

## 📖 介绍

**团队节奏 AI** 是一个基于 Valve 默认 AI 深度改进的 Dota2 Bot 脚本项目。它为无法在线游戏的玩家提供一个良好的单机练习环境，帮助提高游戏水平。

核心亮点：

- **100+ 已实现的英雄** — 每个英雄都拥有自定义的技能使用、出装方案和加点策略
- **更智能的团队协作** — 游走抓人、插眼、推进、分路系统全面升级
- **高级决策系统** — 神符识别、信使管理、防御符文、神泉使用
- **多种模式支持** — 全英雄选择、队长模式、全英雄随机、中路模式、快速模式等
- **聊天控制** — 在游戏内通过聊天频道为 AI 指定英雄或分路
- **职业选手名称** — 使用 TI 历史上的职业选手名称作为 Bot 命名

> 适合想要离线练习、提升个人技术的 Dota2 玩家。

---

## ✨ 功能特性

| 功能 | 描述 |
|------|------|
| **🤖 英雄脚本** | 100+ 英雄拥有独立的技能使用（`ability_item_usage_*.lua`）和出装逻辑（`item_purchase_*.lua`） |
| **🛠️ 工具系统** | 信使管理、插眼系统、出装系统、推塔/打钱/撤退模式 |
| **🎯 游走抓人** | AI 会购买并使用诡计之雾来协调击杀敌方英雄 |
| **🏃 智能分路** | 自动选择最适合的分路，并为玩家让出想走的路 |
| **🔮 神符系统** | AI 识别神符类型，拾取最适合的神符，并规避危险 |
| **🏰 推进系统** | 合理的站位和时机选择来推塔 |
| **🛡️ 防御系统** | 防御符文、神泉使用、买活决策 |
| **📡 聊天指令** | 游戏中输入英雄名或分路指令即可控制 Bot |
| **🏆 队长模式** | 完整支持，按位置顺序选拔英雄（劣单→辅助→中单→辅助→大哥） |

---

## 🗂️ 项目结构

```
dota2ai/
├── src/                          # 主要源代码
│   ├── ability_item_usage_*.lua  # 各英雄技能与物品使用（110+ 文件）
│   ├── item_purchase_*.lua       # 各英雄出装逻辑（110+ 文件）
│   ├── bot_*.lua                 # 特殊英雄行为逻辑（陈、维萨吉等）
│   ├── mode_*.lua                # 游戏模式行为
│   │   ├── mode_farm_generic.lua      # 打钱模式
│   │   ├── mode_laning_generic.lua    # 对线模式
│   │   ├── mode_push_tower_*.lua      # 推塔模式
│   │   ├── mode_retreat_*.lua         # 撤退模式
│   │   ├── mode_rune_generic.lua      # 神符模式
│   │   ├── mode_team_roam_generic.lua # 团队游走模式
│   │   ├── mode_ward_generic.lua      # 插眼模式
│   │   └── ...
│   ├── hero_selection.lua        # 智能选人系统
│   ├── team_desires.lua          # 团队决策系统
│   ├── const/                    # 常量与配置
│   │   ├── config.lua
│   │   ├── enum.lua
│   │   └── text.lua
│   └── util/                     # 工具模块
│       ├── AbilityAbstraction.lua  # 函数式编程辅助
│       ├── CourierSystem.lua       # 信使管理
│       ├── ItemPurchaseSystem.lua  # 智能出装
│       ├── ItemUsageSystem.lua     # 物品使用逻辑
│       ├── PushUtility.lua         # 推进/防守逻辑
│       ├── WardUtility.lua         # 插眼
│       ├── RoleUtility.lua         # 角色分配
│       ├── ChatSystem.lua
│       ├── Utility.lua             # 核心工具函数
│       └── ...
├── dev/                          # 开发与测试脚本
├── changelog/                    # 版本更新日志（中英文）
├── LICENSE                       # GPLv3 开源协议
├── README.md                     # 英文说明文档
└── README_CN.md                  # 本文件
```

---

## 🚀 快速开始

1. **下载或克隆** 本仓库到 Dota 2 的 Bot 脚本文件夹：
   - Windows: `Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/`
2. **启动 Dota 2**，创建一个本地房间。
3. 在 Bot 选择下拉菜单中选择 **"Agent2026"**。
4. **开始游戏！** AI 会自动选择英雄、购买装备，并以改进后的智能进行游戏。

> 💡 **提示：** 你可以在游戏内通过聊天频道控制 AI 的选人和分路。详见下方的 [聊天指令](#-聊天指令) 章节。

---

## 💬 聊天指令

### 选择英雄
在选人阶段，在**团队聊天**（为队友选）或**全体聊天**（为对手选）中输入英雄内部名称：

```
# 示例：为队友选择幻影刺客
团队聊天: phantom_assassin

# 示例：为对手选择屠夫
全体聊天: pudge
```

> 无需输入完整的英雄内部名称，部分匹配即可生效！

### 分路指定
游戏开始前，在聊天频道中输入 5 个分路名称（用空格分隔）：

```
# 示例：你在一号位，想独自走劣势路
团队聊天: top mid bot bot bot
```

> 可选分路：`top`（上路）、`mid`（中路）、`bot`（下路）

---

## 🔗 参考资料

### 官方文档
- [Valve Dota Bot 脚本 API](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting)（右上角可切换语言）
- [Mod Dota Lua Bot 教程](http://docs.moddota.com/lua_bots/)
- [Dota 2 开发者论坛](http://dev.dota2.com/forumdisplay.php?f=497)
- [英雄内部名称列表](https://dota2.gamepedia.com/Cheats#Hero_names)

### 中文教程
- [百度贴吧 — Dota2 AI 开发教程](https://tieba.baidu.com/p/4909536751)
- [个人博客 — Dota2 AI 开发教程](http://www.adamqqq.com/ai/dota2-ai-devlopment-tutorial.html)

---

## 📜 更新日志

完整的版本历史请查看 [changelog/changelog_zh_cn.txt](./changelog/changelog_zh_cn.txt)。

**最新版本：v1.7.5**（2021.05.17）
- 修复了插眼系统的问题
- 暂时移除了臂章以解决游戏卡顿的问题

重要历史里程碑：
- **v1.7.0~1.7.5** — 更新至 7.28c~7.29，新增火猫，修复大量错误
- **v1.6.0~1.6f** — 全面支持 7.20~7.23，新增聊天指令，新神符/打钱系统
- **v1.5.0~1.5h** — 新增 15+ 英雄，优化撤退/技能逻辑
- **v1.4.0~1.4i** — 新增 20 个英雄，改进推进系统，基于角色选人
- **v1.3.0~1.3c** — 全新推进系统，改进插眼，支持队长模式
- **v1.2.0~1.2b** — 团队游走系统，改进神符/分路/信使系统
- **v1.1.0~1.1h** — 新增 30+ 英雄，神泉使用，信使优化
- **v1.0（2017.2.3）** — 初始 Beta 发布

---

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request！
请访问 [GitHub 项目主页](https://github.com/Southhill/dota2ai) 参与贡献。

---

## 📄 开源协议

本项目基于 **GNU General Public License v3.0** 协议开源 — 详见 [LICENSE](./LICENSE) 文件。

---

## 🙏 致谢

- **adamqqq** — 项目原作者
- **zmcmcc** — 主要贡献者（v1.4e ~ v1.5g）
- **AaronSong321** — 7.28c+ 版本更新维护者（v1.7.x）
- **Arizona Fauzie** — BOT EXPERIMENT 作者，提供大量有价值的参考代码
- **DblTap** — 基于角色选人系统
- **pilaoda** — Army Bots 作者，推进系统参考
- **Valve** — 原始 Dota 2 Bot 框架
