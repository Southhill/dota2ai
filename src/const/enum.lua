----------------------------------------------------------------------------
--	枚举常量模块 —定义游戏中常用的枚举数据
----------------------------------------------------------------------------
local Enum = {}

local Tools = require(GetScriptDirectory() .. "/util/Tools")

----------------------------------------------------------------------------
-- 英雄分类列表
----------------------------------------------------------------------------

-- 拥有隐身能力的英雄列表
Enum.invisHeroes =
    Tools.GenEnumArray(
        {
            "npc_dota_hero_templar_assassin",
            "npc_dota_hero_clinkz",
            "npc_dota_hero_mirana",
            "npc_dota_hero_riki",
            "npc_dota_hero_nyx_assassin",
            "npc_dota_hero_bounty_hunter",
            "npc_dota_hero_invoker",
            "npc_dota_hero_sand_king",
            "npc_dota_hero_treant",
            "npc_dota_hero_weaver"
        }
    )

-- 分身系英雄（拥有制造幻象的技能）
Enum.illusionHeroes =
    Tools.GenEnumArray(
        {
            "npc_dota_hero_antimage",       -- 敌法师
            "npc_dota_hero_chaos_knight",   -- 混沌骑士
            "npc_dota_hero_crystal_maiden", -- 水晶室女
            "npc_dota_hero_naga_siren",     -- 娜迦海妖
            "npc_dota_hero_phantom_lancer", -- 幻影长矛手
            "npc_dota_hero_spectre",        -- 幽鬼
            "npc_dota_hero_terrorblade",    -- 恐怖利刃
            "npc_dota_hero_troll_warlord"   -- 巨魔战将
        }
    )

----------------------------------------------------------------------------
-- Modifier 名称常量
-- 集中管理modifier 字符串，便于版本升级时统一更新
----------------------------------------------------------------------------

-- 法术格挡相关 modifier
Enum.ModifierSpellBlock = {
    "modifier_antimage_counterspell",
    "modifier_item_sphere",
    "modifier_item_sphere_target",
    "modifier_item_lotus_orb_active",
    "modifier_mirror_shield_delay",
    "modifier_roshan_spell_block",
    "modifier_special_bonus_spell_block",
    "modifier_nyx_assassin_spiked_carapace",
}

-- 隐身 modifier
Enum.ModifierInvisibility = {
    "modifier_bounty_hunter_wind_walk",
    "modifier_clinkz_wind_walk",
    "modifier_dark_willow_shadow_realm_buff",
    "modifier_item_glimmer_cape_glimmer",
    "modifier_invoker_ghost_walk_self",
    "modifier_nyx_assassin_vendetta",
    "modifier_item_invisibility_edge_windwalk",
    "modifier_item_silver_edge_windwalk",
    "modifier_templar_assassin_meld",
    "modifier_visage_silent_as_the_grave",
    "modifier_weaver_shukuchi",
}

-- 移动速度加成/相位 modifier
Enum.ModifierMovement = {
    "modifier_batrider_firefly",
    "modifier_broodmother_spin_web",
    "modifier_centaur_stampede",
    "modifier_dragon_knight_dragon_form",
    "modifier_item_giants_ring_giants_foot",
    "modifier_lich_sinister_gaze",
    "modifier_legion_commander_duel",
    "modifier_nyx_assassin_vendetta",
    "modifier_spectre_spectral_dagger_path_phased",
    "modifier_item_spider_legs_active",
    "modifier_visage_silent_as_the_grave",
}

-- 飞行/高空 modifier
Enum.ModifierFlight = {
    "modifier_rattletrap_jetpack",
    "modifier_night_stalker_darkness",
    "modifier_winter_wyvern_arctic_burn_flight",
}

-- 强制位移 modifier
Enum.ModifierForcedMovement = {
    "modifier_faceless_void_time_walk",
    "modifier_huskar_life_break_charge",
    "modifier_magnataur_skewer_movement",
    "modifier_monkey_king_bounce",
    "modifier_monkey_king_bounce_leap",
    "modifier_monkey_king_tree_dance_activity",
    "modifier_monkey_king_bounce_perch",
    "modifier_monkey_king_right_click_jump_activity",
}

-- 免疫类减益 modifier（施法判定时需排除的目标状态）
Enum.ModifierImmuneDebuff = {
    "modifier_abaddon_borrowed_time",
    "modifier_winter_wyvern_winters_curse",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_winter_wyvern_winters_curse_aura",
}

return Enum
