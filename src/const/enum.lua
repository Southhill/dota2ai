----------------------------------------------------------------------------
--	Ranked Matchmaking AI
--	枚举常量模块 —— 定义游戏中常用的枚举数据
----------------------------------------------------------------------------
local Enum = {}

local Tools = require(GetScriptDirectory() .. "/util/Tools")

-- 拥有隐身能力的英雄列表
Enum.invisHeroes =
    Tools.GenEnumArray(
    {
        "npc_dota_hero_templar_assassin", -- 圣堂刺客
        "npc_dota_hero_clinkz",           -- 克林克兹（骨弓）
        "npc_dota_hero_mirana",           -- 米拉娜（白虎）
        "npc_dota_hero_riki",             -- 力丸（隐刺）
        "npc_dota_hero_nyx_assassin",     -- 司夜刺客（小强）
        "npc_dota_hero_bounty_hunter",    -- 赏金猎人
        "npc_dota_hero_invoker",          -- 祈求者（卡尔）
        "npc_dota_hero_sand_king",        -- 沙王
        "npc_dota_hero_treant",           -- 树精卫士（大树）
        "npc_dota_hero_weaver"            -- 编织者（蚂蚁）
    }
)

return Enum
