local Enum = {}

local Tools = require(GetScriptDirectory() .. "/util/Tools")

Enum.invisHeroes =
    Tools.GenEnumArray(
    {
        "npc_dota_hero_templar_assassin", -- 圣堂刺客
        "npc_dota_hero_clinkz", -- 骨弓
        "npc_dota_hero_mirana", -- 米拉娜（白虎）
        "npc_dota_hero_riki", -- 隐刺
        "npc_dota_hero_nyx_assassin", -- 小强
        "npc_dota_hero_bounty_hunter", -- 赏金猎人
        "npc_dota_hero_invoker", -- 祈求者
        "npc_dota_hero_sand_king", -- 沙王
        "npc_dota_hero_treant", -- 大树
        "npc_dota_hero_weaver" -- 编织者（蚂蚁）
    }
)

return Enum
