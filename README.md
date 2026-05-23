<p align="center">
  <a href="./README_CN.md">中文</a> | <a href="./README.md">English</a>
</p>

<h1 align="center">🎮 Team Rhythm AI — Dota2 Bot Script</h1>

<p align="center">
  <strong>A powerful Dota2 bot script based on Valve's default AI, significantly improved with smarter behaviors and broader hero coverage.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.7.5-blue.svg" alt="Version 1.7.5"/>
  <img src="https://img.shields.io/badge/license-GPLv3-green.svg" alt="License GPLv3"/>
  <img src="https://img.shields.io/badge/language-Lua-orange.svg" alt="Language Lua"/>
</p>

---

## 📖 Introduction

**Team Rhythm AI (团队节奏 AI)** is a comprehensive Dota2 bot scripting project that builds upon Valve's default AI to provide a much smarter practice environment. It features:

- **100+ fully implemented heroes** — each with custom ability usage, item builds, and skill builds
- **Smarter team coordination** — ganking, warding, pushing, and laning systems
- **Advanced decision making** — rune recognition, courier management, glyph usage, shrine usage
- **Multi-mode support** — All Pick, Captain Mode, All Random, 1v1 Mid, Turbo Mode, Mid Only
- **Chat-based controls** — assign lanes or pick heroes via in-game chat
- **Professional player names** from TI history as bot names

> Designed for players who want to practice offline and improve their game level.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **🤖 Hero Scripts** | 100+ heroes with custom ability usage (`ability_item_usage_*.lua`) and item purchase logic (`item_purchase_*.lua`) |
| **🛠️ Utility Systems** | Courier system, ward placement, item purchase, push/farm/retreat modes |
| **🎯 Team Gank System** | AI buys and uses Smoke of Deceit to coordinate ganks |
| **🏃 Lane Assignment** | Intelligent lane selection respecting player's preferred lane |
| **🔮 Rune System** | AI identifies rune types, picks optimal runes, and avoids danger |
| **🏰 Push System** | Proper positioning and timing for tower pushes |
| **🛡️ Defense System** | Glyph usage, shrine activation, buyback decisions |
| **📡 Chat Commands** | Type hero names or lane assignments in chat to control bots |
| **🏆 Captain Mode** | Full support with role-based pick order (offlaner → support → mid → support → carry) |

---

## 🗂️ Project Structure

```
dota2ai/
├── src/                          # Main source code
│   ├── ability_item_usage_*.lua  # Per-hero ability & item usage (110+ files)
│   ├── item_purchase_*.lua       # Per-hero item purchase logic (110+ files)
│   ├── bot_*.lua                 # Specialized bot behaviors (Chen, Visage, etc.)
│   ├── mode_*.lua                # Game mode behaviors
│   │   ├── mode_farm_generic.lua
│   │   ├── mode_laning_generic.lua
│   │   ├── mode_push_tower_*.lua
│   │   ├── mode_retreat_*.lua
│   │   ├── mode_roam_spirit_breaker.lua
│   │   ├── mode_rune_generic.lua
│   │   ├── mode_secret_shop_generic.lua
│   │   ├── mode_side_shop_generic.lua
│   │   ├── mode_team_roam_generic.lua
│   │   └── mode_ward_generic.lua
│   ├── hero_selection.lua        # Role-aware hero selection system
│   ├── team_desires.lua          # Team-level decision making
│   ├── const/                    # Constants & configuration
│   │   ├── config.lua
│   │   ├── enum.lua
│   │   └── text.lua
│   └── util/                     # Utility modules
│       ├── AbilityAbstraction.lua  # Functional programming helpers
│       ├── AbilityHelper.lua
│       ├── CourierSystem.lua       # Courier management
│       ├── CourierUtility.lua
│       ├── ItemPurchaseSystem.lua  # Smart item purchasing
│       ├── ItemUsageSystem.lua     # Item usage logic
│       ├── PushUtility.lua         # Push/defense logic
│       ├── WardUtility.lua         # Ward placement
│       ├── RoleUtility.lua         # Role assignment
│       ├── ChatSystem.lua
│       ├── BotNameUtility.lua
│       ├── Utility.lua             # Core utility functions
│       └── ...
├── dev/                          # Development/test scripts
├── changelog/                    # Version changelog (EN & CN)
├── LICENSE                       # GPLv3
├── README.md                     # This file
└── README_CN.md                  # Chinese README
```

---

## 🚀 Getting Started

1. **Clone or download** this repository to your Dota 2 bot scripts folder:
   - Windows: `Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/`
2. **Launch Dota 2** and start a local lobby with bots.
3. Select **"Agent2026"** in the bot selection dropdown.
4. **Enjoy!** The bots will automatically pick heroes, buy items, and play with improved AI.

> 💡 **Tip:** You can control bot hero selection and lane assignment via in-game chat. See the [Chat Commands](#-chat-commands) section below.

---

## 💬 Chat Commands

### Hero Selection
During the strategy phase, type a hero name in **Team Chat** (for allies) or **All Chat** (for enemies):

```
# Example: Pick Phantom Assassin for ally
Team Chat: phantom_assassin

# Example: Pick Pudge for enemy
All Chat: pudge
```

> You don't need to type the full hero internal name — just a partial match works!

### Lane Assignment
Before the game starts, type 5 lane names separated by spaces:

```
# Example: You are Radiant slot 1, want to solo offlane
Team Chat: top mid bot bot bot
```

> Valid lanes: `top`, `mid`, `bot`

---

## 🔗 Reference Links

### Official Documentation
- [Valve Dota Bot Scripting API](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting)
- [Mod Dota Lua Bots](http://docs.moddota.com/lua_bots/)
- [Dota 2 Dev Forums](http://dev.dota2.com/forumdisplay.php?f=497)
- [Hero Internal Names](https://dota2.gamepedia.com/Cheats#Hero_names)

### Chinese Resources
- [百度贴吧教程](https://tieba.baidu.com/p/4909536751)
- [个人博客教程](http://www.adamqqq.com/ai/dota2-ai-devlopment-tutorial.html)

---

## 📜 Changelog

See [changelog/changelog_en.txt](./changelog/changelog_en.txt) for the full version history.

**Latest version: v1.7.5** (2021.05.17)
- Fixed warding system
- Temporarily removed armlet to fix game slowdown

Key past milestones:
- **v1.7.0-1.7.5** — Updated to 7.28c-7.29, added Ember Spirit, fixed numerous bugs
- **v1.6.0-1.6f** — Full 7.20-7.23 support, chat commands, new rune/farming systems
- **v1.5.0-1.5h** — Added 15+ new heroes, optimized retreat/ability logic
- **v1.4.0-1.4i** — Added 20 new heroes, improved push system, role-based hero selection
- **v1.3.0-1.3c** — New push system, warding improvements, Captain Mode support
- **v1.2.0-1.2b** — Team gank system, improved rune/lane/courier systems
- **v1.1.0-1.1h** — 30+ heroes added, shrine usage, courier optimization
- **v1.0 (2017.2.3)** — Initial beta release

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
Feel free to open an issue on [GitHub](https://github.com/Southhill/dota2ai/issues).

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](./LICENSE) file for details.

---

## 🙏 Acknowledgments

- **adamqqq** — Original author and creator
- **zmcmcc** — Major contributor (v1.4e ~ v1.5g)
- **AaronSong321** — Updated for 7.28c+ (v1.7.x)
- **Arizona Fauzie** — BOT EXPERIMENT author, provided valuable code references
- **DblTap** — Role-based hero selection system
- **pilaoda** — Army Bots author, push system references
- **Valve** — Original Dota 2 bot framework
