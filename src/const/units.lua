----------------------------------------------------------------------------
--	单位分类常量模块 — 管理幻象/守卫/召唤物/中立生物等分类数据
--	来源：从 NewMinionUtil.lua 重构提取
----------------------------------------------------------------------------
local Units = {}

-- ========== 召唤物类型分类 ==========

-- 无技能的召唤物（无法施法）
Units.minionWithNoSkillSet = {
    ["npc_dota_lesser_eidolon"] = true,
    ["npc_dota_eidolon"] = true,
    ["npc_dota_greater_eidolon"] = true,
    ["npc_dota_dire_eidolon"] = true,
    ["npc_dota_furion_treant"] = true,
    ["npc_dota_furion_treant_large"] = true,
    ["npc_dota_invoker_forged_spirit"] = true,
    ["npc_dota_broodmother_spiderling"] = true,
    ["npc_dota_broodmother_spiderite"] = true,
    ["npc_dota_wraith_king_skeleton_warrior"] = true,
    ["npc_dota_warlock_golem_1"] = true,
    ["npc_dota_warlock_golem_2"] = true,
    ["npc_dota_warlock_golem_3"] = true,
    ["npc_dota_warlock_golem_scepter_1"] = true,
    ["npc_dota_warlock_golem_scepter_2"] = true,
    ["npc_dota_warlock_golem_scepter_3"] = true,
    ["npc_dota_beastmaster_boar"] = true,
    ["npc_dota_beastmaster_greater_boar"] = true,
    ["npc_dota_beastmaster_boar_1"] = true,
    ["npc_dota_beastmaster_boar_2"] = true,
    ["npc_dota_beastmaster_boar_3"] = true,
    ["npc_dota_beastmaster_boar_4"] = true,
    ["npc_dota_lycan_wolf1"] = true,
    ["npc_dota_lycan_wolf2"] = true,
    ["npc_dota_lycan_wolf3"] = true,
    ["npc_dota_lycan_wolf4"] = true,
    ["npc_dota_neutral_kobold"] = true,
    ["npc_dota_neutral_kobold_tunneler"] = true,
    ["npc_dota_neutral_kobold_taskmaster"] = true,
    ["npc_dota_neutral_centaur_outrunner"] = true,
    ["npc_dota_neutral_fel_beast"] = true,
    ["npc_dota_neutral_polar_furbolg_champion"] = true,
    ["npc_dota_neutral_ogre_mauler"] = true,
    ["npc_dota_neutral_giant_wolf"] = true,
    ["npc_dota_neutral_alpha_wolf"] = true,
    ["npc_dota_neutral_wildkin"] = true,
    ["npc_dota_neutral_jungle_stalker"] = true,
    ["npc_dota_neutral_elder_jungle_stalker"] = true,
    ["npc_dota_neutral_prowler_acolyte"] = true,
    ["npc_dota_neutral_rock_golem"] = true,
    ["npc_dota_neutral_granite_golem"] = true,
    ["npc_dota_neutral_small_thunder_lizard"] = true,
    ["npc_dota_neutral_gnoll_assassin"] = true,
    ["npc_dota_neutral_ghost"] = true,
    ["npc_dota_wraith_ghost"] = true,
    ["npc_dota_neutral_dark_troll"] = true,
    ["npc_dota_neutral_forest_troll_berserker"] = true,
    ["npc_dota_neutral_harpy_scout"] = true,
    ["npc_dota_neutral_black_drake"] = true,
    ["npc_dota_dark_troll_warlord_skeleton_warrior"] = true,
    ["npc_dota_necronomicon_warrior_1"] = true,
    ["npc_dota_necronomicon_warrior_2"] = true,
    ["npc_dota_necronomicon_warrior_3"] = true,
}

-- 有技能的召唤物（可施法）
Units.minionWithSkillSet = {
    ["npc_dota_neutral_centaur_khan"] = true,
    ["npc_dota_neutral_polar_furbolg_ursa_warrior"] = true,
    ["npc_dota_neutral_mud_golem"] = true,
    ["npc_dota_neutral_mud_golem_split"] = true,
    ["npc_dota_neutral_mud_golem_split_doom"] = true,
    ["npc_dota_neutral_ogre_magi"] = true,
    ["npc_dota_neutral_enraged_wildkin"] = true,
    ["npc_dota_neutral_satyr_soulstealer"] = true,
    ["npc_dota_neutral_satyr_hellcaller"] = true,
    ["npc_dota_neutral_prowler_shaman"] = true,
    ["npc_dota_neutral_big_thunder_lizard"] = true,
    ["npc_dota_neutral_dark_troll_warlord"] = true,
    ["npc_dota_neutral_satyr_trickster"] = true,
    ["npc_dota_neutral_forest_troll_high_priest"] = true,
    ["npc_dota_neutral_harpy_storm"] = true,
    ["npc_dota_neutral_black_dragon"] = true,
    ["npc_dota_necronomicon_archer_1"] = true,
    ["npc_dota_necronomicon_archer_2"] = true,
    ["npc_dota_necronomicon_archer_3"] = true,
}

-- 攻击性守卫类单位
Units.attackingWardSet = {
    ["npc_dota_shadow_shaman_ward_1"] = true,
    ["npc_dota_shadow_shaman_ward_2"] = true,
    ["npc_dota_shadow_shaman_ward_3"] = true,
    ["npc_dota_venomancer_plague_ward_1"] = true,
    ["npc_dota_venomancer_plague_ward_2"] = true,
    ["npc_dota_venomancer_plague_ward_3"] = true,
    ["npc_dota_venomancer_plague_ward_4"] = true,
    ["npc_dota_witch_doctor_death_ward"] = true,
}

-- 无法被操控的单位（AI无法控制其行为）
Units.cantBeControlledSet = {
    ["npc_dota_zeus_cloud"] = true,
    ["npc_dota_unit_tombstone1"] = true,
    ["npc_dota_unit_tombstone2"] = true,
    ["npc_dota_unit_tombstone3"] = true,
    ["npc_dota_unit_tombstone4"] = true,
    ["npc_dota_pugna_nether_ward_1"] = true,
    ["npc_dota_pugna_nether_ward_2"] = true,
    ["npc_dota_pugna_nether_ward_3"] = true,
    ["npc_dota_pugna_nether_ward_4"] = true,
    ["npc_dota_rattletrap_cog"] = true,
    ["npc_dota_rattletrap_rocket"] = true,
    ["npc_dota_broodmother_web"] = true,
    ["npc_dota_unit_undying_zombie"] = true,
    ["npc_dota_unit_undying_zombie_torso"] = true,
    ["npc_dota_weaver_swarm"] = true,
    ["npc_dota_death_prophet_torment"] = true,
    ["npc_dota_gyrocopter_homing_missile"] = true,
    ["npc_dota_plasma_field"] = true,
    ["npc_dota_wisp_spirit"] = true,
    ["npc_dota_beastmaster_axe"] = true,
    ["npc_dota_troll_warlord_axe"] = true,
    ["npc_dota_phoenix_sun"] = true,
    ["npc_dota_techies_minefield_sign"] = true,
    ["npc_dota_treant_eyes"] = true,
    ["npc_dota_death_prophet_exorcism_spirit"] = true,
    ["npc_dota_dark_willow_creature"] = true,
}

-- ========== 特定英雄召唤物分类 ==========

Units.frozeSigilSet = {
    ["npc_dota_tusk_frozen_sigil1"] = true,
    ["npc_dota_tusk_frozen_sigil2"] = true,
    ["npc_dota_tusk_frozen_sigil3"] = true,
    ["npc_dota_tusk_frozen_sigil4"] = true,
}

Units.hawkSet = {
    ["npc_dota_scout_hawk"] = true,
    ["npc_dota_greater_hawk"] = true,
    ["npc_dota_beastmaster_hawk"] = true,
    ["npc_dota_beastmaster_hawk_1"] = true,
    ["npc_dota_beastmaster_hawk_2"] = true,
    ["npc_dota_beastmaster_hawk_3"] = true,
    ["npc_dota_beastmaster_hawk_4"] = true,
}

Units.tornadoSet = {
    ["npc_dota_enraged_wildkin_tornado"] = true,
}

Units.healingWardSet = {
    ["npc_dota_juggernaut_healing_ward"] = true,
}

Units.bearSet = {
    ["npc_dota_lone_druid_bear1"] = true,
    ["npc_dota_lone_druid_bear2"] = true,
    ["npc_dota_lone_druid_bear3"] = true,
    ["npc_dota_lone_druid_bear4"] = true,
}

Units.familiarSet = {
    ["npc_dota_visage_familiar1"] = true,
    ["npc_dota_visage_familiar2"] = true,
    ["npc_dota_visage_familiar3"] = true,
}

-- ========== 特殊单位数组（用于遍历等场景）=========

Units.remnant = {
    "npc_dota_stormspirit_remnant",
    "npc_dota_ember_spirit_remnant",
    "npc_dota_earth_spirit_stone",
}

Units.trap = {
    "npc_dota_templar_assassin_psionic_trap",
    "npc_dota_techies_remote_mine",
    "npc_dota_techies_land_mine",
    "npc_dota_techies_stasis_trap",
}

Units.independent = {
    "npc_dota_brewmaster_earth_1",
    "npc_dota_brewmaster_earth_2",
    "npc_dota_brewmaster_earth_3",
    "npc_dota_brewmaster_storm_1",
    "npc_dota_brewmaster_storm_2",
    "npc_dota_brewmaster_storm_3",
    "npc_dota_brewmaster_fire_1",
    "npc_dota_brewmaster_fire_2",
    "npc_dota_brewmaster_fire_3",
}

return Units
