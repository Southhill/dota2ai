----------------------------------------------------------------------------
--	技能抽象层 —技能查询、Bot行为判断、能力信息映射等 Dota 特有逻辑
--	（函数式工具见 src/util/functional.lua）
----------------------------------------------------------------------------
local M = {}
local Func = require(GetScriptDirectory() .. "/util/functional")

-- 将 Func 的所有函数复制到 M 上，保持向后兼容（M:Concat、M:Filter 等仍可用）
-- 注意：包装一层以丢弃 self 参数，因为 Func 函数不期望 self
-- 例如 self:Filter(tb, fn) → M.Filter(self, tb, fn) → Func.Filter(tb, fn)
for k, v in pairs(Func) do
    M[k] = function(self, ...)
        return v(...)
    end
end

local binlib = require(GetScriptDirectory() .. "/util/BinDecHex")
local utility = require(GetScriptDirectory() .. "/base/Utility")
local NewTable = Func.NewTable

-- ========== 链式调用机制（元表 __index 详解）==========
--
-- Lua 的元表（metatable）可以拦截表的访问操作。
-- __index 是最常用的元方法：当访问表中不存在的字段时，
-- Lua 会自动去 __index 指向的表里查找。
--
-- 这里的 magicTable 把自己的 __index 设为自己：
--   magicTable.__index = magicTable
-- 意思是："如果 magicTable 自身没有这个字段，就去 magicTable 自身找"。
-- 因为下面 do...end 已经把 Func 的所有函数复制到了 magicTable 上，
-- 所以对 magicTable 的查找总能命中。
--
-- NewTable() 创建的表 t 的元表被设为 magicTable：
--   setmetatable(t, magicTable)
-- 当调用 t:Filter(...) 时，t 本身没有 Filter 方法，Lua 就去
-- t 的元表的 __index（即 magicTable）中找，找到了 Filter。
-- 这就实现了链式调用：t:Filter(...):Map(...):Sort(...)
--
-- 简单说：
--   表 t → 没有某方法 → 查元表 magicTable 的 __index
--   → __index = magicTable（自己）→ 上面有 Func 的所有函数 → 找到了
-- ====================================================
local magicTable = {}
magicTable.__index = magicTable
-- 把 Func 的所有函数（Filter、Map、Concat...）注册到 magicTable 上
-- 这样 NewTable() 创建的表就能通过 __index 找到它们，实现链式调用
-- 同时把 Lua 原生 table 库的函数也加上，方便直接使用
do
    local mt = magicTable
    for k, v in pairs(Func) do
        mt[k] = function(...)
            return v(...)
        end
    end
    for functionName, func in pairs(table) do
        mt[functionName] = func
    end
end

-- ========== Bot 行为模式相关函数 ==========

-- 将值限制在 [left, right] 范围
local Trim = function(v, left, right)
    if right >= left then
        if v > right then
            return right
        elseif v < left then
            return left
        else
            return v
        end
    else
        if v > left then
            return left
        elseif v < right then
            return right
        else
            return v
        end
    end
end

-- 将欲望值裁剪到 0~1 之间
M.TrimDesire = function(self, desire)
    return Trim(desire, 0, 1)
end

-- 根据技能冷却时间计算技能重要性（冷却越长=越重要）
M.GetAbilityImportance = function(self, cooldown)
    return Trim(cooldown / 120, 0, 1)
end

-- 判断 Bot 是否处于打钱或推进模式
M.IsFarmingOrPushing = function(self, npcBot)
    local mode = npcBot:GetActiveMode()
    return mode == BOT_MODE_FARM or mode == BOT_MODE_PUSH_TOWER_BOT or mode == BOT_MODE_PUSH_TOWER_MID or mode ==
        BOT_MODE_PUSH_TOWER_TOP or mode == BOT_MODE_DEFEND_TOWER_BOT or mode == BOT_MODE_DEFEND_TOWER_MID or mode ==
        BOT_MODE_DEFEND_TOWER_TOP
end

-- 判断 Bot 是否处于对线模式
M.IsLaning = function(self, npcBot)
    local mode = npcBot:GetActiveMode()
    return mode == BOT_MODE_LANING
end

-- 判断 Bot 是否处于攻击敌方模式
M.IsAttackingEnemies = function(self, npcBot)
    local mode = npcBot:GetActiveMode()
    return mode == BOT_MODE_ROAM or mode == BOT_MODE_TEAM_ROAM or mode == BOT_MODE_ATTACK or mode ==
        BOT_MODE_DEFEND_ALLY
end

-- 判断 Bot 是否处于撤退模式
M.IsRetreating = function(self, npcBot)
    return npcBot:GetActiveMode() == BOT_MODE_RETREAT
end

-- 判断 Bot 是否不处于撤退模式
M.NotRetreating = function(self, npcBot)
    return npcBot:GetActiveMode() ~= BOT_MODE_RETREAT
end

-- 判断是否有足够蓝量使用攻击附带类技能
M.HasEnoughManaToUseAttackAttachedAbility = function(self, npcBot, ability)
    local percent = self:GetManaPercent(npcBot)
    if percent >= 0.8 and npcBot:GetMana() >= 650 then
        return true
    end
    return percent >= 0.4 and npcBot:GetMana() >= 300 and npcBot:GetManaRegen() >= npcBot:GetAttackSpeed() / 100 *
        ability:GetManaCost() * 0.75
end

-- 将返回布尔值的函数转换为开关技能的动作函数
M.ToggleFunctionToAction = function(self, npcBot, oldConsider, ability)
    return function()
        local value, target, castType = oldConsider()
        if type(value) == "number" then
            return value, target, castType
        end
        if value ~= ability:GetToggleState() and ability:IsFullyCastable() then
            return BOT_ACTION_DESIRE_HIGH
        else
            return 0
        end
    end
end

-- 将返回布尔值的函数转换为自动施法切换函数
M.ToggleFunctionToAutoCast = function(self, npcBot, oldConsider, ability)
    return function()
        local value, target, castType = oldConsider()
        if type(value) == "number" then
            return value, target, castType
        end
        if ability:IsFullyCastable() and value ~= ability:GetAutoCastState() then
            ability:ToggleAutoCast()
        end
        return 0
    end
end

-- 包装原技能考虑函数，防止对幻象使用技能
M.PreventAbilityAtIllusion = function(self, npcBot, oldConsiderFunction, ability)
    return function()
        local desire, target, targetTypeString = oldConsiderFunction()
        if desire == 0 or target == nil or target == 0 or self:IsVector(target) or targetTypeString == "Location" then
            return desire, target, targetTypeString
        end
        if self:MustBeIllusion(npcBot, target) then
            return 0
        end
        return desire, target, targetTypeString
    end
end

-- 包装原技能考虑函数，防止在目标有法术格挡时浪费技能
M.PreventEnemyTargetAbilityUsageAtAbilityBlock = function(self, npcBot, oldConsiderFunction, ability)
    local newConsider = function()
        -- TODO: 考虑基础冷却还是修改后冷却（奥术符、玲珑心）？奥术符时是否要用大招破林肯？
        local desire, target, targetTypeString = oldConsiderFunction()
        if desire == 0 or target == nil or target == 0 or self:IsVector(target) or targetTypeString == "Location" then
            return desire, target, targetTypeString
        end
        local oldDesire = desire
        if npcBot:GetTeam() ~= target:GetTeam() then -- 有些技能可对友军和敌军施放（如亚巴顿迷雾缠绕）
            local cooldown = ability:GetCooldown()
            local abilityImportance = self:GetAbilityImportance(cooldown)

            if target:HasModifier("modifier_antimage_counterspell") then
                return 0
            end
            if target:HasModifier "modifier_item_sphere" or target:HasModifier("modifier_roshan_spell_block") or
                target:HasModifier("modifier_special_bonus_spell_block") then -- qop lv 25
                if cooldown >= 30 then
                    desire = desire - abilityImportance
                elseif cooldown <= 20 then
                    desire = desire + abilityImportance
                end
            end
            if target:HasModifier("modifier_item_sphere_target") then
                if cooldown >= 60 then
                    desire = 0
                elseif cooldown >= 30 then
                    desire = desire - abilityImportance + 0.1
                elseif cooldown <= 20 then
                    desire = desire + abilityImportance
                    if abilityImportance > 0.1 then
                        desire = desire - 0.1
                    end
                end
            end
            if target:HasModifier("modifier_item_lotus_orb_active") then
                if npcBot:GetActiveMode() == BOT_MODE_RETREAT then
                    desire = 0
                else
                    desire = desire - abilityImportance / 2
                end
            end
            if target:HasModifier("modifier_mirror_shield_delay") then
                desire = desire - abilityImportance * 1.5
            end

            desire = self:TrimDesire(desire)
        end
        return desire, target, targetTypeString
    end
    return newConsider
end

M.GetUsedAbilityInfo = function(self, ability, abilityInfoTable, considerTarget)
    abilityInfoTable.lastUsedTime = DotaTime()
    if ability:IsItem() then
        abilityInfoTable.lastUsedCharge = ability:GetCurrentCharges()
    end
    abilityInfoTable.lastUsedTarget = considerTarget
    abilityInfoTable.lastUsedRemainingCooldown = ability:GetCooldownTimeRemaining()
end

M.AddCooldownToChargeAbility = function(self, oldConsider, ability, abilityInfoTable, additionalCooldown)
    return function()
        if abilityInfoTable.lastUsedTime == nil then
            abilityInfoTable.lastUsedTime = DotaTime()
        end
        if ability:IsItem() then
            if not (ability:GetCurrentCharges() > 0 and ability:IsFullyCastable()) then
                return 0
            end
            if DotaTime() <= abilityInfoTable.lastUsedTime + additionalCooldown and abilityInfoTable.lastUsedCharge >=
                ability:GetCurrentCharges() and abilityInfoTable.lastUsedRemainingCooldown <=
                ability:GetCooldownTimeRemaining() then
                return 0
            end
        else
            if not ability:IsFullyCastable() then
                return 0
            end
            if DotaTime() <= abilityInfoTable.lastUsedTime + additionalCooldown then
                return 0
            end
        end
        return oldConsider()
    end
end

M.AutoModifyConsiderFunction = function(self, npcBot, considers, abilitiesReal)
    for index, ability in pairs(abilitiesReal) do
        if not binlib.Test(ability:GetBehavior(), ABILITY_BEHAVIOR_PASSIVE) and considers[index] == nil then
            print("Missing consider function " .. ability:GetName())
        elseif binlib.Test(ability:GetTargetTeam(), ABILITY_TARGET_TEAM_ENEMY) and binlib.Test(ability:GetTargetType(),
                binlib.Or(ABILITY_TARGET_TYPE_HERO, ABILITY_TARGET_TYPE_CREEP, ABILITY_TARGET_TYPE_BUILDING)) and
            binlib.Test(ability:GetBehavior(), ABILITY_BEHAVIOR_UNIT_TARGET) then
            considers[index] = self.PreventAbilityAtIllusion(self, npcBot, considers[index], ability)
            if not self:IgnoreAbilityBlock(ability) then
                considers[index] = self.PreventEnemyTargetAbilityUsageAtAbilityBlock(self, npcBot, considers[index],
                    ability)
            end
        end
    end
    npcBot.abilityRecords = {}
end

function M:InitAbility(npcBot)
    local abilities = NewTable()
    local abilityNames = NewTable()
    local talents = NewTable()
    for i = 0, 23 do
        local ability = npcBot:GetAbilityInSlot(i)
        if (ability ~= nil) then
            if (ability:GetName() ~= "generic_hidden") then
                if (ability:IsTalent() == true) then
                    table.insert(talents, ability:GetName())
                else
                    table.insert(abilityNames, ability:GetName())
                    table.insert(abilities, ability)
                end
            end
        end
    end
    npcBot.abilityInited = true
    return abilityNames, abilities, talents
end

-- ability information

local keysBeforeAbilityInformation = M:Keys(M)

M.UndisjointableProjectiles = { "alchemist_berser_potion", "alchemist_unstable_concoction_throw",
    "arc_warden_spark_wraith", "grimstroke_phantoms_embrace", "earthshaker_echoslam",
    "gyrocopter_homing_missile", "beastmaster_hawk_dive", "huskar_life_break",
    "lich_chain_frost", "medusa_cold_blooded", "medusa_mystic_snake", "mirana_starstorm",
    "necrolyte_death_pulse", "necrolyte_death_seeker", "oracle_fortunes_end",
    "queenofpain_scream_of_pain", "skywrath_mage_arcane_bolt", "snapfire_firesnap_cookie",
    "spectre_spectral_dagger", "tiny_toss", "tusk_snowball", "witch_doctor_paralyzing_cask" }

M.targetTrackingStunAbilities = { "alchemist_berser_potion", "alchemist_unstable_concoction_throw",
    "chaos_knight_chaos_bolt", "dragon_knight_dragon_tail", "gyrocopter_homing_missile",
    "morphling_adaptive_strike_str", "mud_golem_hurl_boulder",
    "skeleton_king_hellfire_blast", "sven_storm_hammer", "vengefulspirit_magic_missile",
    "windrunner_shackleshot" }

M.targetNonTrackingStunAbilities = { "bane_fiends_grip", "beastmaster_primal_roar", "dark_willow_cursed_crown",
    "enigma_malefice", "invoker_cold_snap", "item_abyssal_blade", "lich_sinister_gaze",
    "luna_lucent_beam", "necrolyte_reapers_scythe", "ogre_magi_fireblast",
    "ogre_magi_unrefined_fireblast", "pudge_dismember", "rubick_telekinesis",
    "shadow_shaman_shackles", "storm_spirit_electric_vortex" }

M.targetStunAbilities = M:Concat(M.targetTrackingStunAbilities, M.targetNonTrackingStunAbilities)

M.locationStunAbilities = { "axe_berserkers_call", "centaur_hoof_stomp", "dark_seer_vacuum", "dark_willow_cursed_crown",
    "dawnbreaker_fire_wreath", "dawnbreaker_solar_guardian", "earthshaker_fissure",
    "earthshaker_enchant_totem", "earthshaker_echoslam", "enigma_black_hole",
    "faceless_void_chronosphere", "jakiro_ice_path", "keeper_of_the_light_will_o_wisp",
    "kunkka_ghostship", "kunkka_torrent", "kunkka_torrent_storm", "lina_light_strike_array",
    "magnataur_skewer", "magnataur_horn_toss", "magnataur_reverse_polarity",
    "monkey_king_boundless_strike", "phoenix_supernova", "puck_dream_coil",
    "sand_king_burrowstrike", "slardar_slithereen_crush", "tidehunter_ravage" }

M.targetTrackingDisableAbilities = { "gleipnir_eternal_chains", "naga_siren_ensnare", "riki_sleeping_dart",
    "viper_viper_strike" }

M.targetNonTrackingDisableAbilities = { "bloodseeker_rupture", "doom_bringer_doom", "ember_spirit_searing_chains",
    "grimstroke_ink_creature", "grimstroke_soul_chain", "item_sheepstick",
    "lion_vex", "shadow_demon_purge", "shadow_shaman_voodoo" }

M.targetDisableAbilities = M:Concat(M.targetNonTrackingStunAbilities, M.targetTrackingDisableAbilities)

M.locationDisableAbilities = { "dark_willow_bramble_maze", "death_prophet_silence", "disruptor_kinetic_field",
    "disruptor_static_storm", "drow_ranger_wave_of_silence", "elder_titan_echo_stomp",
    "invoker_deafening_wave", "treant_overgrowth" }

M.targetTrackingHeavyDamageAbilities = { "item_ethereal_blade", "lich_chain_frost", "lion_finger_of_death",
    "morphling_adaptive_strike_agi", "sniper_assassinate" }

M.targetNonTrackingHeavyDamageAbilities = { "antimage_mana_void", "item_dagon", "lina_laguna_blade", "pugna_life_drain",
    "tinker_laser", "zuus_lightning_bolt" }

M.targetHeavyDamageAbilities = M:Concat(M.targetTrackingHeavyDamageAbilities, M.targetNonTrackingHeavyDamageAbilities)

M.locationHeavyDamageAbilities = { "ancient_apparition_ice_blast", "antimage_mana_void", "disruptor_static_storm",
    "invoker_chaos_meteor", "invoker_sun_strike", "jakiro_macropyre", "kunkka_ghostship",
    "nevermore_requiem_of_souls", "obsidian_destroyer_sanitys_eclipse", "phoenix_sun_ray",
    "puck_dream_coil", "pugna_nether_blast", "queenofpain_sonic_wave",
    "sand_king_epicenter", "skywrath_mage_mystic_flare", "venomancer_poison_nova" }

M.heavyDamageAbilities = M:Concat(M.targetTrackingHeavyDamageAbilities, M.locationHeavyDamageAbilities)

M.dodgeWorthAbilities = M:Concat(M.targetStunAbilities, M.locationStunAbilities, M.heavyDamageAbilities)

M.invisibleModifiers = { "modifier_bounty_hunter_wind_walk", "modifier_clinkz_wind_walk",
    "modifier_dark_willow_shadow_realm_buff", "modifier_item_glimmer_cape_glimmer",
    "modifier_invoker_ghost_walk_self", "modifier_nyx_assassin_vendetta",
    "modifier_item_phase_boots_active", "modifier_item_shadow_amulet_fade",
    "modifier_item_invisibility_edge_windwalk", "modifier_shadow_fiend_requiem_thinker",
    "modifier_item_silver_edge_windwalk", "modifier_windrunner_wind_walk",
    "modifier_storm_wind_walk", "modifier_templar_assassin_meld",
    "modifier_visage_silent_as_the_grave", "modifier_weaver_shukuchi" }

M.phaseModifiers = { "modifier_bounty_hunter_wind_walk", "modifier_clinkz_wind_walk",
    "modifier_dark_willow_shadow_realm_buff", "modifier_faceless_void_chronosphere_selfbuff",
    "modifier_item_glimmer_cape_glimmer", "modifier_invoker_ghost_walk_self",
    "modifier_nyx_assassin_vendetta", "modifier_item_phase_boots_active",
    "modifier_item_shadow_amulet_fade", "modifier_item_invisibility_edge_windwalk",
    "modifier_shadow_fiend_requiem_thinker", "modifier_item_silver_edge_windwalk",
    "modifier_slardar_sprint", "modifier_storm_wind_walk", "modifier_templar_assassin_meld",
    "modifier_weaver_shukuchi" }

M.phaseUnits = { "npc_dota_brewmaster_fire_1", "npc_dota_brewmaster_fire_2", "npc_dota_brewmaster_fire_3",
    "npc_dota_broodmother_web", "npc_dota_courier", "npc_dota_phoenix_sun",
    "npc_dota_juggernaut_healing_ward", "npc_dota_techies_land_mine", "npc_dota_techies_stasis_trap",
    "npc_dota_techies_remote_mine", "npc_dota_weaver_swarm" }

M.unobstructedMovementModifiers = { "modifier_batrider_firefly", "modifier_broodmother_spin_web",
    "modifier_centaur_stampede", "modifier_dragon_knight_dragon_form",
    "modifier_item_giants_ring_giants_foot", "modifier_lich_sinister_gaze",
    "modifier_legion_commander_duel", "modifier_nyx_assassin_vendetta",
    "modifier_spectre_spectral_dagger_path_phased", "modifier_item_spider_legs_active",
    "modifier_visage_silent_as_the_grave" }

M.flyingModifiers = { "modifier_rattletrap_jetpack", "modifier_night_stalker_darkness",
    "modifier_winter_wyvern_arctic_burn_flight" }

M.flyingUnits = { "npc_dota_visage_familiar1", "npc_dota_visage_familiar2", "npc_dota_visage_familiar3",
    "npc_dota_flying_courier", "npc_dota_beastmaster_hawk" }

M.positiveForceMovementModifiers = { "modifier_faceless_void_time_walk", "modifier_huskar_life_break_charge",
    "modifier_magnataur_skewer_movement", "modifier_monkey_king_bounce",
    "modifier_monkey_king_bounce_leap", "modifier_monkey_king_tree_dance_activity",
    "modifier_monkey_king_bounce_perch",
    "modifier_monkey_king_right_click_jump_activity", "modifier_pangolier_swashbuckle",
    "modiifer_pangolier_shield_crash_jump", "modifier_pangolier_rollup",
    "modifier_snapfire_firesnap_cookie", "modifier_snapfire_gobble_up",
    "modifier_sand_king_burrowstrike", "modifier_techies_suicide_leap" }

M.timeSensitivePositiveModifiers = { "modifier_item_black_king_bar", "modifier_faceless_void_chronosphere_selfbuff",
    "modifier_medusa_stone_gaze", "modifier_monkey_king_fur_army_soldier_in_position" }
-- sorted by importance, used by dispell abilities

M.basicDispellablePositiveModifiers = { "modifier_omniknight_guardian_angle", "modifier_ember_spirit_flame_guard",
    "modifier_legion_commander_press_the_attack", "modifier_windrunner_windrun",
    "modifier_lich_frost_shield", "modifier_oracle_purifying_flames",
    "modifier_ogre_magi_bloodlust", "modifier_treant_living_armor",
    "modifier_mirana_leap_buff", "modifier_necrolyte_death_seeker",
    "modifier_necrolyte_sadist_active", "modifier_pugna_decrepify",
    "modifier_item_ethereal_blade_ethereal", "modifier_ghost_state",
    "modifier_abaddon_frostmourne_buff", "modifier_item_mjollnir_static",
    "modifier_visage_silent_as_the_grave", "modifier_spirit_breaker_bulldoze",
    "modifier_item_spider_legs_active", "modifier_item_bullwhip_buff" }

M.basicDispellWorthPositiveModifiers = { "modifier_omniknight_guardian_angle", "modifier_ember_spirit_flame_guard",
    "modifier_legion_commander_press_the_attack", "modifier_windrunner_windrun",
    "modifier_lich_frost_shield", "modifier_oracle_purifying_flames",
    "modifier_ogre_magi_bloodlust", "modifier_treant_living_armor",
    "modifier_mirana_leap_buff", "modifier_necrolyte_death_seeker",
    "modifier_necrolyte_sadist_active", "modifier_pugna_decrepify",
    "modifier_item_ethereal_blade_ethereal", "modifier_ghost_state" }

M.basicDispellWorthNegativeModifiers = { "modifier_abaddon_frostmourne_debuff_bonus" }

M.basicDispellableNegativeModifiers = { "modifier_abaddon_frostmourne_debuff",
    "modifier_abaddon_frostmourne_debuff_bonus" }

M.unbreakableChannelAbilities = { "puck_phase_shift", "pangolier_gyroshell", "lone_druid_true_form", "phoenix_supernova",
    "lycan_shapeshift" }

M.nonIllusionModifiers = {}

M.valubleNeutrals = { "npc_dota_neutral_alpha_wolf", "npc_dota_neutral_centaur_khan",
    "npc_dota_neutral_polar_furbolg_ursa_warrior", "npc_dota_neutral_dark_troll_warlord",
    "npc_dota_neutral_mud_golem", "npc_dota_neutral_satyr_hellcaller" }

M.valubleAncientNeutrals = { "npc_dota_neutral_black_dragon", "npc_dota_neutral_rock_golem",
    "npc_dota_neutral_big_thunder_lizard" }

M.hypnosisModifiers = { "modifier_lich_sinister_gaze", "modifier_void_spirit_aether_remnant_pull",
    "modifier_keeper_of_the_light_will_o_wisp" }

M.fearModifiers = { "modifier_dark_willow_debuff_fear", "modifier_lone_druid_savage_roar",
    "modifier_shadow_fiend_requiem_fear", "modifier_terrorblade_fear" }

M.hexModifiers = { "modifier_lion_voodoo", "modifier_shadow_shaman_voodoo", "modifier_sheepstick_debuff",
    "modifier_item_princes_knife_hex", "modifier_hexxed" -- dazzle_poison_touch lv 25
}

M.silenceModifiers = { "modifier_abaddon_frostmourne_debuff_bonus", "modifier_silence", "modifier_bloodthorn_debuff",
    "modifier_disruptor_static_storm", "modifier_doom_bringer_doom",
    "modifier_drow_ranger_wave_of_silence", "modifier_earth_spirit_geomagnetic_grip_debuff",
    "modifier_enigma_black_hole_pull", "modifier_grimstroke_ink_creature_debuff",
    "modifier_legion_commander_duel", "modifier_item_mask_of_madness_berserk",
    "modifier_night_stalker_crippling_fear", "modifier_orchid_malevolence_debuff",
    "modifier_riki_smoke_screen", "modifier_silencer_global_silence", "modifier_silencer_last_word",
    "modifier_skywrath_mage_ancient_seal" }

M.timedSilenceModifiers = { "modifier_abaddon_frostmourne_debuff_bonus", "modifier_silence",
    "modifier_bloodthorn_debuff", "modifier_doom_bringer_doom",
    "modifier_drow_ranger_wave_of_silence", "modifier_earth_spirit_geomagnetic_grip_debuff",
    "modifier_grimstroke_ink_creature_debuff", "modifier_legion_commander_duel",
    "modifier_item_mask_of_madness_berserk", "modifier_orchid_malevolence_debuff",
    "modifier_silencer_global_silence", "modifier_silencer_last_word",
    "modifier_skywrath_mage_ancient_seal" }

M.magicImmuneModifiers = { "modifier_item_black_king_bar", "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury", "modifier_minotaur_horn_immune",
    "modifier_elder_titan_echo_stomp_magic_immune", "modifier_huskar_life_break_charge",
    "modifier_legion_commander_press_the_attack_immunity", "modifier_lion_mana_drain_immunity" }

M.muteModifiers = { "modifier_tusk_snowball", "modifier_doom_bringer_doom", "modifier_disruptor_static_storm_mute" }

M.breakModifiers = { -- "modifier_doom_bringer_doom",--only breaks with scepter
    "modifier_hoodwink_sharpshooter", "modifier_phantom_assassin_fan_of_knives",
    -- "modifier_shadow_demon_purge_slow",--only break with scepter
    "modifier_silver_edge_debuff", -- "modifier_spirit_breaker_greaterbash_break",--only break with shard
    "modifier_viper_nethertoxin" }
-- TODO: how to record he caster of these abilities

M.noTrueSightRootAbilityAssociation = {
    dark_willow_branble_maze = "modifier_dark_willow_bramble_maze",
    item_diffusal_blade = "modifier_rooted" -- most people don't know diffusal blade apply root on non-hero units
}

M.conditionalTrueSightRootAbilityAssociation = {
    dark_troll_warlord_ensnare = "modifier_dark_troll_warlord_ensnare",
    ember_spirit_searing_chains = "modifier_ember_spirit_searing_chains",
    oracle_fortunes_end = "modifier_oracle_fortunes_end_purge",
    item_rod_of_atos = "modifier_rod_of_atos_debuff"
}

M.permanentTrueSightRootAbilityAssociation = {
    broodmother_silken_bola = "modifier_broodmother_silken_bola",
    crystal_maiden_frostbite = "modfifier_crystal_maiden_frostbite",
    meepo_earthbind = "modifier_meepo_earthbind",
    naga_siren_ensnare = "modifier_naga_siren_ensnare",
    spirit_bear_entangling_claws = "modifier_lone_druid_spirit_bear_entangle_effect",
    techies_stasis_trap = "modifier_techies_stasis_trap_stunned",
    treant_overgrowth = "modifier_treant_overgrowth",
    troll_warlord_berserkers_rage = "modifier_troll_warlord_berserkers_rage_ensnare",
    abyssal_underlord_pit_of_malice = "modifier_abyssal_underlord_pit_of_malice_ensare"
}

M.rootAbilityAssociation = M:Concat(M.noTrueSightRootAbilityAssociation, M.conditionalTrueSightRootAbilityAssociation,
    M.permanentTrueSightRootAbilityAssociation)

local keysAfterAbilityInformation = M:Keys(M)
local abilityInformationKeys = keysAfterAbilityInformation:RemoveAll(keysBeforeAbilityInformation)
abilityInformationKeys:ForEach(function(t)
    setmetatable(M[t], magicTable)
end)
abilityInformationKeys = abilityInformationKeys:Filter(function(t)
    return t:match("AbilityAssociation")
end)

local function ExtendAssociation(association)
    return association:MapDic(function(key, value)
        return key
    end), association:Map(function(key, value)
        return value
    end):Distinct()
end
abilityInformationKeys:ForEach(function(t)
    local a, b = ExtendAssociation(M[t])
    local k = t:sub(1, #t - #"AbilityAssociation")
    M[k .. "Abilities"] = a
    M[k .. "Modifiers"] = b
end)

-- unit function

function M:IsRoshan(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan")
end

function M:IsHero(t)
    return t:IsHero()
end

function M:IsTempestDouble(npc)
    return npc:HasModifier("modifier_arc_warden_tempest_double")
end

function M:IsLoneDruidBear(npc)
    return string.match(npc:GetUnitName(), "npc_dota_lone_druid_bear")
end

function M:IsVisageFamiliar(npc)
    return string.match(npc:GetUnitName(), "npc_dota_visage_familiar")
end

function M:IsBrewmasterPrimalSplit(npc)
    local unitName = npc:GetUnitName()
    return string.match(unitName, "npc_dota_brewmaster_")
end

M.GetIncomingDodgeWorthProjectiles = function(self, npc)
    local health = npc:GetHealth()
    local projectiles = npc:GetIncomingTrackingProjectiles()
    projectiles = self:Filter(projectiles, function(t)
        if t.is_attack or npc:GetTeam() == t.caster:GetTeam() then
            return false
        end
        local ability = t.ability
        if ability then
            local abilityName = ability:GetName()
            if self:Contains(self.UndisjointableProjectiles, abilityName) then
                return false
            end
            if self:Contains(self.targetTrackingStunAbilities, abilityName) or
                self:Contains(self.targetTrackingDisableAbilities, abilityName) or
                self:Contains(self.targetTrackingHeavyDamageAbilities, abilityName) or npc:GetHealth() <=
                npc:GetActualIncomingDamage(ability:GetAbilityDamage(), ability:GetDamageType()) then
                return true
            end
            return false
        end
        return true
    end)
    return projectiles
end

M.GetTargetHealAmplifyPercent = function(self, npc)
    local modifiers = npc:FindAllModifiers()
    local amplify = 1
    for i = 1, npc:NumModifiers() do
        local modifierName = npc:GetModifierName(i)
        if modifierName == "modifier_ice_blast" then
            return 0
        end
        if modifierName == "modifier_item_spirit_vessel_damage" then
            amplify = amplify - 0.45
        end
        if modifierName == "modifier_holy_blessing" then
            amplify = amplify + 0.3
        end
        if modifierName == "modifier_necrolyte_sadist_active" then -- ghost shroud
            amplify = amplify + 0.75
        end
        if modifierName == "modifier_wisp_tether_haste" then
            amplify = amplify + 0.6 -- 0.8/1/1.2
        end
        if modifierName == "modifier_oracle_false_promise" then
            amplify = amplify + 1
        end
    end
    return amplify
end

M.IsChannelingItem = function(self, npc)
    return npc:HasModifier("modifier_item_meteor_hammer") or npc:HasModifier("modifier_teleporting") or
        npc:HasModifier("modifier_boots_of_travel_incoming")
end

M.IsChannelingAbility = function(self, npc)
    return npc:IsChanneling() and not self:IsChannelingItem(npc)
end

function M:IsChannelingBreakWorthAbility(npc)
    if not npc:IsChanneling() then
        return false
    end
    local ability = npc:GetCurrentActiveAbility()
    if ability == nil then
        if npc:HasModifier("modifier_teleporting") then
            return true
        end
        local item = self:GetAvailableItem(npc, "item_fallen_sky")
        return item ~= nil
    end
    local name = ability:GetName()
    if self:Contains(self.unbreakableChannelAbilities, name) then
        return false
    end
    return true
end

M.RadiantPlayerId = GetTeamPlayers(TEAM_RADIANT)
M.DirePlayerId = GetTeamPlayers(TEAM_DIRE)

M.GetTeamPlayers = function(self, team)
    if team == TEAM_RADIANT then
        return self.RadiantPlayerId
    else
        return self.DirePlayerId
    end
end

M.GetEnemyTeamMemberNames = function(self, npcBot)
    local enemies = self:GetEnemyHeroUnique(npcBot, GetUnitList(UNIT_LIST_ENEMY_HEROES))
    return self:Map(enemies, function(t)
        return t:GetUnitName()
    end)
end

M.enemyVisibleIllusionModifiers = { "modifier_illusion", -- "modifier_phantom_lancer_doppelwalk_illusion",
    -- "modifier_phantom_lancer_juxtapose_illusion",
    "modifier_terrorblade_conjureimage", "modifier_grimstroke_scepter_buff", "modifier_arc_warden_tempest_double",
    "modifier_skeleton_king_reincarnation_active",
    "modifier_vengefulspirit_hybrid_special" }

M.MustBeIllusion = function(self, npcBot, target)
    if npcBot:GetTeam() == target:GetTeam() then
        return target:IsIllusion() or self:HasAnyModifier(target, self.enemyVisibleIllusionModifiers)
    end
    if self:Contains(self:GetTeamPlayers(npcBot:GetTeam()), target:GetPlayerID()) or target.markedAsIllusion then
        return true
    end
    if target.markedAsRealHero then
        return false
    end
    if not IsHeroAlive(target:GetPlayerID()) then
        return true
    end
    return false
end
M.MayNotBeIllusion = function(self, npcBot, target)
    return not self:MustBeIllusion(npcBot, target)
end

function M:IsOnSameTeam(a, b)
    return a:GetTeam() == b:GetTeam()
end

function M:IsNonIllusionHero(npcBot, target)
    return self:MayNotBeIllusion(npcBot, target) and self:IsHero(target)
end

function M:HasNonIllusionModifier(npc)
    return self:HasAnyModifier(npc, self.nonIllusionModifiers)
end

function M:CanIllusionUseAbility(npc)
    local name = npc:GetUnitName()
    local ability = npc:GetCurrentActiveAbility()
    if ability == nil then
        return false
    end
    if name == "npc_dota_hero_bane" and self:HasScepter(npc) and ability:GetName() == "bane_fiends_grip" then
        return true
    end
end

M.DetectIllusion = function(self, npcBot)
    local nearbyEnemies = self:GetNearbyNonIllusionHeroes(npcBot, 1599)
    nearbyEnemies = self:Filter(nearbyEnemies, function(t)
        return string.match(t:GetUnitName(), "npc_dota_hero")
    end)
    local nearbyEnemyGroups = self:GroupBy(nearbyEnemies, function(t)
        return t:GetUnitName()
    end)
    nearbyEnemyGroups = self:Filter(nearbyEnemyGroups, function(t)
        return #t > 1
    end)
    self:ForEach(nearbyEnemyGroups, function(nearbyEnemyGroup)
        local castingEnemies = self:Filter(nearbyEnemyGroup, function(t)
            return (t:IsUsingAbility() or t:IsChanneling() or self:HasNonIllusionModifier(t) or t.markedAsRealHero) and
                not t.markedAsIllusion
        end)
        local castingEnemy = castingEnemies[1]
        if castingEnemy and not self:CanIllusionUseAbility(castingEnemy) then
            castingEnemy.markedAsRealHero = true
            castingEnemies = self:Remove(nearbyEnemyGroup, castingEnemy)
            self:ForEach(castingEnemies, function(t)
                t.markedAsIllusion = true
            end)
        end
    end)
end

M.GetNearbyHeroes = function(self, npcBot, range, getEnemy, botModeMask)
    range = range or 1200
    if getEnemy == nil then
        getEnemy = true
    end
    botModeMask = botModeMask or BOT_MODE_NONE
    local heroes = utility.GetNearbyVisibleHeroes(npcBot, range, getEnemy, botModeMask)
    return heroes
end

M.GetNearbyNonIllusionHeroes = function(self, npcBot, range, getEnemy, botModeMask)
    range = range or 1200
    if getEnemy == nil then
        getEnemy = true
    end
    botModeMask = botModeMask or BOT_MODE_NONE
    local heroes = utility.GetNearbyVisibleHeroes(npcBot, range, getEnemy, botModeMask)
    return self:Filter(heroes, function(t)
        return self:MayNotBeIllusion(npcBot, t)
    end)
end

function M:AttackOnceDamage(npcBot, target)
    return target:GetActualIncomingDamage(npcBot:GetAttackDamage() - npcBot:GetBaseDamageVariance() / 2,
        DAMAGE_TYPE_PHYSICAL)
end

function M:GetNearbyAttackableCreeps(npcBot, range, getEnemy)
    if getEnemy == nil then
        getEnemy = true
    end
    local creeps = npcBot:GetNearbyCreeps(range, getEnemy)
    if getEnemy then
        -- 过滤掉泉水金辉保护中的小兵（无敌不可攻击）
        creeps = self:Filter(creeps, function(t)
            return not t:HasModifier("modifier_fountain_glyph")
        end)
    end
    return creeps
end

M.GetNearbyAllUnits = function(self, npcBot, range)
    local h1 = utility.GetNearbyVisibleHeroes(npcBot, range, true, BOT_MODE_NONE)
    local h2 = self:Remove(utility.GetNearbyVisibleHeroes(npcBot, range, false, BOT_MODE_NONE), npcBot)
    local h3 = npcBot:GetNearbyCreeps(range, true)
    local h4 = npcBot:GetNearbyCreeps(range, false)
    return self:Concat(h1, h2, h3, h4)
end

function M:GetNearbyEnemyUnits(npc, range)
    local h1 = npc:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    local h3 = npc:GetNearbyCreeps(range, true)
    return self:Concat(h1, h3)
end

M.GetEnemyHeroUnique = function(self, npcBot, enemies)
    local p = self:Filter(enemies, function(t)
        self:MayNotBeIllusion(npcBot, t)
    end)
    local g = NewTable()
    local readNames = NewTable()
    for _, enemy in pairs(p) do
        local name = enemy:GetUnitName()
        if not self:Contains(readNames, name) then
            table.insert(readNames, name)
            table.insert(g, enemy)
        end
    end
    return g
end

M.GetMovementSpeedPercent = function(self, npc)
    return npc:GetCurrentMovementSpeed() / npc:GetBaseMovementSpeed()
end
M.CanHardlyMove = function(self, npc)
    return npc:IsStunned() or npc:IsRooted() or npc:GetCurrentMovementSpeed() <= 150
end

M.GetModifierRemainingDuration = function(self, npc, modifierName)
    local mod = npc:GetModifierByName(modifierName)
    if mod ~= -1 then
        return npc:GetModifierRemainingDuration(mod)
    end
    return 0
end

M.imprisonmentModifier = { "modifier_item_cyclone", "modifier_item_wind_waker", "modifier_shadow_demon_disruption",
    "modifier_obsidian_destroyer_astral_imprisonment_prison", "modifier_brewmaster_storm_cyclone",
    "modifier_invoker_tornado" -- "modifier_x_marks_the_target",
}
M.GetImprisonmentRemainingDuration = function(self, npc)
    return self:First(self:Map(self.imprisonmentModifier, function(t)
        return self:GetModifierRemainingDuration(npc, t)
    end), function(t)
        return t ~= 0
    end) or 0
end

function M:GetMagicImmuneRemainingDuration(npc)
    local remainingTime = self:Map(self.magicImmuneModifiers, function(t)
        return { t, self:GetModifierRemainingDuration(npc, t) }
    end)
    remainingTime = self:SortByMaxFirst(remainingTime, function(t)
        return t[2]
    end)
    remainingTime = remainingTime[1]
    return remainingTime and remainingTime[2] or 0
end

function M:GetSilenceRemainingDuration(npc)
    local silenceModifierRemainings = self:Map(self.timedSilenceModifiers, function(t)
        return self:GetModifierRemainingDuration(npc, t)
    end)
    if npc:HasModifier("modifier_disruptor_static_storm") then
        table.insert(silenceModifierRemainings, 1, 6)
    end
    if npc:HasModifier("modifier_enigma_black_hole_pull") or npc:HasModifier("modifier_riki_smoke_screen") then
        table.insert(silenceModifierRemainings, 1, 4)
    end
    silenceModifierRemainings = #silenceModifierRemainings ~= 0 and math.max(self:Unpack(silenceModifierRemainings)) or
        0
    return silenceModifierRemainings
end

function M:GetStunRemainingDuration(npc)
    return self:IsStunned(npc) and 1 or 0
end

M.GetEnemyHeroNumber = function(self, npcBot, enemies)
    return #self:GetEnemyHeroUnique(npcBot, enemies)
end

function M:HasPhasedMovement(npc)
    return self:HasAnyModifier(npc, self.phaseModifiers) or self:Contains(self.phaseUnits, npc:GetUnitName())
end

function M:HasUnobstructedMovement(npc)
    if self:HasAnyModifier(npc, self.flyingModifiers) or self:Contains(self.flyingUnits, npc:GetUnitName()) then
        if string.match(npc:GetUnitName(), "npc_dota_visage_familiar") then
            return npc:HasModifier("modifier_rooted")
        end
        return true
    end
    local activeFlyingModifiers = self:Filter(self.unobstructedMovementModifiers, function(t)
        return npc:HasModifier(t)
    end)
    if #activeFlyingModifiers ~= 0 then
        local dragonKnightDragonForm = self:IndexOf(activeFlyingModifiers, "modifier_dragon_knight_dragon_form")
        if dragonKnightDragonForm ~= -1 then
            local ability = npc:GetAbilityByName("dragon_knight_elder_dragon_form")
            if ability == nil or not (ability:GetLevel() == 4) then
                table.remove(activeFlyingModifiers, dragonKnightDragonForm)
            end
        end
        local stampede = self:IndexOf(activeFlyingModifiers, "modifier_centaur_stampede")
        if stampede ~= -1 then
            local ability = npc:GetAbilityByName("centaur_stampede")
            if ability == nil or not self:hasScepter(npc) then
                table.remove(activeFlyingModifiers, stampede)
            end
        end
    end
    return #activeFlyingModifiers ~= 0
end

-- item function

M.GetAvailableItem = function(self, npc, itemName)
    for i = 0, 5 do
        local item = npc:GetItemInSlot(i)
        if item ~= nil and item:GetName() == itemName then
            return item
        end
    end
end

local radianceAncientLocation = Vector(-7200, -6666)
local direAncientLocation = Vector(7137, 6548)

M.GetAncientLocation = function(self, npc)
    if npc:GetTeam() == TEAM_RADIANT then
        return radianceAncientLocation
    else
        return direAncientLocation
    end
end

M.GetDistanceFromAncient = function(self, npc)
    local fountain = self:GetAncientLocation(npc)
    return GetUnitToLocationDistance(npc, fountain)
end

M.TryUseTp = function(self, npc)
    local item = npc:GetItemInSlot(15)
    if item ~= nil and item:IsFullyCastable() and self:CanMove(npc) then
        local distanceFromFountain
        if npc:GetTeam() == TEAM_RADIANT then
            distanceFromFountain = radianceAncientLocation + Vector(400, 400)
        else
            distanceFromFountain = direAncientLocation + Vector(-400, -400)
        end
        npc:ActionImmediate_UseAbilityOnLocation(item, distanceFromFountain)
        return true
    end
end

M.GetAvailableBlink = function(self, npc)
    local blinks = { "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }
    return self:Aggregate(nil, blinks, function(a, blinkName)
        return a or self:GetAvailableItem(npc, blinkName)
    end)
end

function M:GetAvailableTravelBoots(npc)
    local travelBoots = { "item_travel_boots", "item_travel_boots_2" }
    return self:Aggregate(nil, travelBoots, function(seed, t)
        return seed or self:GetAvailableItem(npc, t)
    end)
end

M.GetEmptyInventorySlots = function(self, npc)
    local g = 0
    for i = 0, 5 do
        if npc:GetItemInSlot(i) == nil then
            g = g + 1
        end
    end
    return g
end

M.GetEmptyItemSlots = function(self, npc)
    local g = 0
    for i = 0, 8 do
        if npc:GetItemInSlot(i) == nil then
            g = g + 1
        end
    end
    return g
end

M.GetEmptyBackpackSlots = function(self, npc)
    local g = 0
    for i = 7, 9 do
        if npc:GetItemInSlot(i) == nil then
            g = g + 1
        end
    end
    return g
end

M.SwapItemToBackpack = function(self, npc, itemIndex)
    for i = 6, 8 do
        if npc:GetItemInSlot(i) == nil then
            npc:ActionImmediate_SwapItems(itemIndex, i)
            return true
        end
    end
    return false
end

M.GetCarriedItems = function(self, npc)
    local g = NewTable()
    for i = 0, 8 do
        local item = npc:GetItemInSlot(i)
        if item ~= nil then
            item.slotIndex = i
            table.insert(g, item)
        end
    end
    return g
end

M.GetInventoryItems = function(self, npc)
    local g = NewTable()
    for i = 0, 5 do
        local item = npc:GetItemInSlot(i)
        if item ~= nil then
            item.slotIndex = i
            table.insert(g, item)
        end
    end
    return g
end

M.GetInventoryItemNames = function(self, npc)
    local g = NewTable()
    for i = 0, 5 do
        local item = npc:GetItemInSlot(i)
        if item ~= nil then
            item.slotIndex = i
            table.insert(g, item:GetName())
        end
    end
    return g
end

M.GetStashItems = function(self, npc)
    local g = NewTable()
    for i = 9, 14 do
        local item = npc:GetItemInSlot(i)
        if item ~= nil then
            item.slotIndex = i
            table.insert(g, item)
        end
    end
    return g
end

function M:GetCourierItems(courier)
    local g = NewTable()
    for i = 0, 8 do
        local item = courier:GetItemInSlot(i)
        if item then
            table.insert(g, item)
        end
    end
    return g
end

function M:GetMyCourier(npcBot)
    if npcBot.courierIDNew == nil then
        self:FindCourier(npcBot)
    end
    return GetCourier(npcBot.courierIDNew)
end

function M:FindCourier(npcBot)
    for i = 0, 4 do
        local courier = GetCourier(i)
        if courier ~= nil then
            if courier:GetPlayerID() == npcBot:GetPlayerID() then
                npcBot.courierIDNew = i
            end
        end
    end
end

M.GetAllBoughtItems = function(self, npcBot)
    local g = NewTable()
    for i = 0, 15 do
        local item = npcBot:GetItemInSlot(i)
        if item then
            table.insert(g, item)
        end
    end
    if DotaTime() >= -70 then
        g = self:Concat(g, self:GetCourierItems(self:GetMyCourier(npcBot)))
    end
    return g
end

M.IsBoots = function(self, item)
    if type(item) ~= "string" then
        item = item:GetName()
    end
    return string.match(item, "boots") or item == "item_guardian_greaves" or #item >= 17 and string.sub(item, 17) ==
        "item_power_treads"
end

M.SwapCheapestItemToBackpack = function(self, npc)
    local cheapestItem = self:First(self:Sort(self:Filter(self:GetInventoryItems(npc), function(t)
        return not self:IsBoots(t) and not string.match(t:GetName(), "item_ward")
    end), function(a, b)
        return GetItemCost(a:GetName()) - GetItemCost(b:GetName())
    end))
    if cheapestItem == nil then
        return false
    end
    return self:SwapItemToBackpack(npc, cheapestItem.slotIndex)
end

M.SuitableForSilence = function(self, npc, target)
    return self:MayNotBeIllusion(npc, target) and not target:IsMagicImmune() and not self:IsInvulnerable(target)
end

M.GetHeroFullName = function(self, s)
    return "npc_dota_hero_" .. s
end
M.GetHeroShortName = function(self, s)
    return string.sub(s, 12)
end

M.IsMeleeHero = function(self, npc)
    local range = npc:GetAttackRange()
    local name = npc:GetUnitName()
    return
        range <= 210 or name == self:GetHeroFullName("tiny") or name == self:GetHeroFullName("doom_bringer") or name ==
        self:GetHeroFullName("pudge")
end

function M:HasAnyModifier(npc, modifierGroup)
    return self:First(modifierGroup, function(t)
        return npc:HasModifier(t)
    end)
end

M.AttackPassiveAbilities = { "doom_bringer_infernal_blade", "drow_ranger_frost_arrows", "clinkz_fire_arrows",
    "viper_poison_attack", "obsidian_destroyer_arcane_orb" }
M.OtherIgnoreAbilityBlockAbilities = { "batrider_flaming_lasso", "gyrocopter_homing_missile", "axe_culling_blade" }
M.IgnoreAbilityBlockAbilities = { "dark_seer_ion_shell", "grimstroke_soulbind", "rubick_spell_steal",
    "spectre_spectral_dagger", "morphling_morph", "urn_of_shadows_soul_release",
    "spirit_vessel_soul_release", "medallion_of_courage_valor", "solar_crest_armor_shine" }

M.IgnoreAbilityBlock = function(self, ability)
    local abilityName = ability:GetName()
    return self:Contains(self.AttackPassiveAbilities, abilityName) or
        self:Contains(self.IgnoreAbilityBlockAbilities, abilityName) or
        self:Contains(self.OtherIgnoreAbilityBlockAbilities, abilityName)
end

M.AbilityRetargetModifiers = { "modifier_antimage_counterspell", "modifier_item_lotus_orb_active",
    "modifier_nyx_assassin_spiked_carapace" -- "modifier_item_blade_mail",
}
M.HasAbilityRetargetModifier = function(self, npc)
    return self:HasAnyModifier(npc, self.AbilityRetargetModifiers)
end

M.CanMove = function(self, npc)
    return not npc:IsStunned() and not npc:IsRooted() and not self:IsNightmared(npc) and not self:IsTaunted(npc)
end

function M:CannotMove(npc)
    return -- npc:IsStunned() or self:IsNightmared(npc) or --actually still able to cast abilities or move while stunned or nightmared, but provides no dfference
        npc:IsRooted() or self:IsTaunted(npc) or self:IsHypnosed(npc) or self:IsFeared(npc)
end

function M:CannotTeleport(npc)
    return npc:IsRooted() or self:IsTaunted(npc) or self:IsHypnosed(npc) or self:IsFeared(npc)
end

function M:IsNightmared(npc)
    return npc:HasModifier("modifier_bane_nightmare") or npc:HasModifier("modifier_riki_poison_dart_debuff")
end

function M:IsTaunted(npc)
    return npc:HasModifier("modifier_axe_berserkers_call") or npc:HasModifier("modifier_legion_commander_duel")
end

function M:IsDuelCaster(npc)
    local function IsTaunting(_npc)
        local ability = _npc:GetAbilityByName("legion_commander_duel")
        return ability and ability:GetCooldownTimeRemaining() +
            self:GetModifierRemainingDuration(_npc, "modifier_legion_commander_duel") + 1 >=
            ability:GetCooldown()
    end
    local npcBot = GetBot()
    if npcBot:GetTeam() == npc:GetTeam() then
        return IsTaunting(npc)
    else
        local players = self:Map(self:Range(0, 4), GetTeamMember)
        local tauntingPlayer = self:First(players, function(t)
            return IsTaunting(t) and t:GetAttackTarget() == npc
        end)
        return not IsTaunting(tauntingPlayer)
    end
end

function M:IsMuted(npc)
    return npc:IsHexed() or self:HasAnyModifier(npc, self.muteModifiers)
end

function M:IsHypnosed(npc)
    return self:HasAnyModifier(npc, self.hypnosisModifiers)
end

function M:IsFeared(npc)
    return self:HasAnyModifier(npc, self.fearModifiers)
end

M.IsSeverelyDisabled = function(self, npc)
    return npc:IsStunned() or npc:IsHexed() or npc:IsRooted() or self:IsFeared(npc) or self:IsHypnosed(npc) or
        self:IsNightmared(npc) or npc:HasModifier("modifier_legion_commander_duel") and
        not self:IsDuelCaster(npc) or npc:HasModifier("modifier_axe_berserkers_call") or
        npc:HasModifier("modifier_shadow_demon_purge_slow") or npc:HasModifier("modifier_doom_bringer_doom")
end

M.IsSeverelyDisabledOrSlowed = function(self, npc)
    return self:IsSeverelyDisabled(npc) or self:GetMovementSpeedPercent(npc) <= 0.35
end

M.HasSeverelyDisableProjectiles = function(self, npc)
    local projectiles = self:GetIncomingDodgeableProjectiles(npc)
    return self:Any(projectiles, function(t)
        return self:Contains(self.targetTrackingStunAbilities, t.ability:GetName())
    end)
end

M.IsOrGoingToBeSeverelyDisabled = function(self, npc)
    return self:IsSeverelyDisabled(npc) or self:HasSeverelyDisableProjectiles(npc)
end

M.EtherealModifiers = { "modifier_ghost_state", "modifier_item_ethereal_blade_ethereal",
    "modifier_necrolyte_death_seeker", "modifier_necrolyte_sadist_active", "modifier_pugna_decrepify" }
M.IsEthereal = function(self, npc)
    return self:HasAnyModifier(npc, self.EtherealModifiers)
end

function M:NotBlasted(npc)
    return not npc:HasModifier("modifier_ice_blast")
end

M.CannotBeTargetted = function(self, npc)
    return self:HasAnyModifier(npc, self.CannotBeTargettedModifiers)
end

M.CanBeTargettedFunction = function(npc)
    return not M:CanBeTargetted(npc)
end

M.CannotBeAttacked = function(self, npc)
    return self:IsEthereal(npc) or self:IsInvulnerable(npc) or self:CannotBeTargetted(npc)
end

M.IsInvulnerable = function(self, npc)
    return npc:IsInvulnerable() or self:Any(self.IgnoreDamageModifiers, function(t)
        return npc:HasModifier(t)
    end)
end

M.MayNotBeSeen = function(self, npc)
    if not npc:IsInvisible() or npc:HasModifier("modifier_item_dust") or npc:HasModifier("modifier_bounty_hunter_track") or
        npc:HasModifier("modifier_slardar_amplify_damage") or npc:HasModifier("modifier_truesight") then
        return false
    end
    if self:HasAnyModifier(npc, self.permanentTrueSightRootModifiers) then
        return false
    end
    local enemies = self:GetNearbyHeroes(npc)
    return self:All(enemies, function(t)
        if t:HasItem("item_gem") then
            return false
        end
        if t:GetAttackTarget() == npc then
            return false
        end
        if t:IsUsingAbility() then
            local ability = t:GetCurrentActiveAbility()
            if binlib.Test(ability:GetBehavior(), ABILITY_BEHAVIOR_UNIT_TARGET) and
                t:IsFacingLocation(npc:GetLocation(), 10) then
                return false
            end
        end
        return true
    end) and not self:Any(npc:GetNearbyCreeps(1000, true), function(t)
        return t:GetUnitName() == "npc_dota_necronomicon_warrior_3"
    end)
end

M.ShouldNotBeAttacked = function(self, npc)
    return self:CannotBeAttacked(npc) or self:Any(self.IgnoreDamageModifiers, function(t)
        return npc:HasModifier(t)
    end) or self:Any(self.IgnorePhysicalDamageModifiers, function(t)
        return npc:HasModifier(t)
    end)
end

M.PhysicalCanCastFunction = function(npc)
    return not M:IsInvulnerable(npc) and not M:ShouldNotBeAttacked(npc) and not npc:IsMagicImmune()
end

M.IsPhysicalOutputDisabled = function(self, npc)
    return npc:IsDisarmed() or npc:IsBlind() and not npc:GetAvailableItem("item_monkey_king_bar") or
        self:IsEthereal(npc)
end

M.GetHealthPercent = function(self, npc)
    return npc:GetHealth() / npc:GetMaxHealth()
end

function M:GetPhysicalHealth(t)
    return t:GetHealth() * (1 + 0.06 * t:GetArmor()) / (1 - t:GetEvasion())
end

function M:GetBuildingPhysicalHealth(t)
    local h = self:GetPhysicalHealth(t)
    if t:HasModifier("modifier_fountain_glyph") then
        h = h + self:GetModifierRemainingDuration("modifier_fountain_glyph") * 200
    end
    return h
end

M.GetManaPercent = function(self, npc)
    return npc:GetMana() / npc:GetMaxMana()
end

M.GetHealthDeficit = function(self, npc)
    return npc:GetMaxHealth() - npc:GetHealth()
end

function M:GetManaDeficit(npc)
    return npc:GetMaxMana() - npc:GetMana()
end

function M:GetTargetIfGood(npc)
    local target = npc:GetTarget()
    if target ~= nil and target:IsHero() and self:MayNotBeIllusion(npc, target) then
        return target
    end
end

-- function M:GetAcrossAbilityStatusPerFrame(npc)
--     local g = {}
--     g.health = npc:GetHealth()
--     g.mana = npc:GetMana()
--     g.healthPercent = self:GetHealthPercent(npc)
--     g.manaPercent = self:GetManaPercent(npc)
--     g.attackRange = npc:GetAttackRange()
-- end

function M:IndexOfBasicDispellablePositiveModifier(npc)
    return self:Aggregate(nil, self.basicDispellWorthPositiveModifiers, function(seed, modifier, index)
        if seed then
            return seed
        end
        local b = npc:HasModifier(modifier)
        if b then
            return index
        else
            return nil
        end
    end) or -1
end

function M:HasBasicDispellablePositiveModifier(npc)
    return self:Any(self.basicDispellWorthPositiveModifiers, function(modifierName)
        return npc:HasModifier(modifierName)
    end)
end

function M:DontInterruptAlly(npc)
    return self:HasAnyModifier(npc, self.positiveForceMovementModifiers) or
        self:HasAnyModifier(npc, self.timeSensitivePositiveModifiers) or self:IsDuelCaster(npc)
end

M.MidLaneTowers = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 }
M.BotLaneTowers = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 }
M.TopLaneTowers = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 }

function M:GetLaningTower(npc)
    local team = npc:GetTeam()
    local lane = npc:GetAssignedLane()
    local function ToTower(t)
        return GetTower(team, t)
    end
    local function TowerExists(t)
        return t:GetHealth() > 0
    end
    if lane == LANE_BOT then
        local a = self:Map(self.BotLaneTowers, ToTower)
        return self:First(a, TowerExists)
    elseif lane == LANE_MID then
        return self:First(self:Map(self.MidLaneTowers, ToTower), TowerExists)
    elseif lane == LANE_TOP then
        return self:First(self:Map(self.TopLaneTowers, ToTower), TowerExists)
    end
end

-- debug functions

M.DebugTable = function(self, tb)
    local msg = "{ "
    local DebugRec
    DebugRec = function(tc)
        for k, v in pairs(tc) do
            if type(v) == "number" or type(v) == "string" then
                msg = msg .. k .. " = " .. v .. ", "
            elseif type(v) == "boolean" then
                msg = msg .. k .. " = " .. tostring(v) .. ", "
            elseif type(v) == "table" then
                msg = msg .. k .. " = " .. "{ "
                DebugRec(v)
                msg = msg .. "}, "
            end
        end
    end
    DebugRec(tb)
    msg = msg .. " }"
    print(msg)
end

M.DebugLongTable = function(self, tb)
    for k, v in pairs(tb) do
        if type(v) == "table" then
            print(tostring(k) .. " = ")
            self:DebugTable(v)
        else
            print(tostring(k) .. " = " .. tostring(v))
        end
    end
end

M.DebugArray = function(self, tb)
    for k, v in ipairs(tb) do
        if type(v) == "table" then
            self:DebugTable(v)
        else
            print(v)
        end
    end
end

M.PrintAbilities = function(self, npcBot)
    local abilityNames = "{\n"
    for i = 0, 23 do
        local ability = npcBot:GetAbilityInSlot(i)
        if ability ~= nil and ability:GetName() ~= "generic_hidden" then
            abilityNames = abilityNames .. '\t"' .. ability:GetName() .. '",\n'
        end
    end
    abilityNames = abilityNames .. "}"
    print(npcBot:GetUnitName())
    print(abilityNames)
end

-- ability function

function M:NormalCanCast(target, isPureDamageWithoutDisable, damageType, pierceMagicImmune, targetMustBeSeen,
                         mustBeTargettable)
    damageType = damageType or DAMAGE_TYPE_MAGICAL
    if pierceMagicImmune == nil then
        if damageType == DAMAGE_TYPE_MAGICAL then
            pierceMagicImmune = false
        else
            pierceMagicImmune = true
        end
    end
    if isPureDamageWithoutDisable == nil then
        isPureDamageWithoutDisable = true
    end
    if self:IsInvulnerable(target) then
        return false
    end
    if mustBeTargettable == nil then
        mustBeTargettable = true
    end
    if mustBeTargettable and self:CannotBeTargetted(target) then
        return false
    end
    if not pierceMagicImmune and target:IsMagicImmune() then
        return false
    end
    if targetMustBeSeen and not target:CanBeSeen() then
        return false
    end
    if isPureDamageWithoutDisable and
        (damageType == DAMAGE_TYPE_PHYSICAL and self:ShouldNotBeAttacked(target) or damageType == DAMAGE_TYPE_MAGICAL and
            (target:IsMagicImmune() or self:Contains(self.IgnoreMagicalDamageModifiers, function(t)
                target:HasModifier(t)
            end))) then
        return false
    end
    return true
end

M.NormalCanCastFunction = function(target)
    return M:NormalCanCast(target)
end

function M:SpellCanCast(target, pierceMagicImmune, targetMustBeSeen, mustBeTargettable)
    if targetMustBeSeen == nil then
        targetMustBeSeen = true
    end
    if mustBeTargettable == nil then
        mustBeTargettable = true
    end
    if target:IsInvulnerable() then
        return false
    end
    if mustBeTargettable and self:CannotBeTargetted(target) then
        return false
    end
    if not pierceMagicImmune and target:IsMagicImmune() then
        return false
    end
    return true
end

M.SpellCanCastFunction = function(target)
    return M:SpellCanCast(target)
end

function M:AllyCanCast(target, pierceMagicImmune)
    if pierceMagicImmune == nil then
        pierceMagicImmune = true
    end
    return not target:IsInvulnerable() and not self:CannotBeTargetted(target)
end

M.AllyCanCastFunction = function(target)
    return M:AllyCanCast(target)
end

function M:NeutralCanCast(target)
end

function M:EnemyAllyCanCast(target, isPureDamageWithoutDisable, damageType, pierceMagicImmune, targetMustBeSeen)
    if self:IsOnSameTeam(target, GetBot()) then
        return self:NormalCanCast(target, isPureDamageWithoutDisable, damageType, pierceMagicImmune, targetMustBeSeen)
    else
        return self:AllyCanCast(target, pierceMagicImmune, targetMustBeSeen)
    end
end

M.SpecialBonusAttributes = "special_bonus_attributes"
M.TalentNamePrefix = "special_bonus_"
M.IncorrectAbilityName = "incorrect_name"

M.IsTalent = function(self, ability)
    if ability == nil then
        return false
    end
    if type(ability) ~= "string" then
        ability = ability:GetName()
    end
    return ability ~= "special_bonus_attributes" and #ability >= #self.TalentNamePrefix and
        string.sub(ability, 1, #self.TalentNamePrefix) == self.TalentNamePrefix
end

M.GetAbilities = function(self, npcBot)
    local g = NewTable()
    for i = 0, 25 do
        local ability = npcBot:GetAbilityInSlot(i)
        if ability ~= nil and ability:GetName() ~= "generic_hidden" then
            table.insert(g, ability)
        end
    end
    return g
end

M.GetAbilityNames = function(self, npcBot)
    return self:Map(self:GetAbilities(npcBot), function(t)
        return t:GetName()
    end)
end

M.GetTalents = function(self, npcBot)
    return self:Filter(self:GetAbilities(npcBot), function(t)
        return self:IsTalent(t)
    end)
end

M.GetAbilityLevelUpIndex = function(self, npcBot)
    return npcBot:GetLevel() - npcBot:GetAbilityPoints() + 1 + npcBot.abilityTable.incorrectAbilityLevelUpNumber
end


M.ExecuteAbilityLevelUp = function(self, npcBot)
    local abilityTable = npcBot.abilityTable
    if abilityTable.justLevelUpAbility then
        if abilityTable.abilityPoints == npcBot:GetAbilityPoints() then
            abilityTable.incorrectAbilityLevelUpNumber = abilityTable.incorrectAbilityLevelUpNumber + 1
        end
        abilityTable.justLevelUpAbility = false
    end
    abilityTable.abilityPoints = npcBot:GetAbilityPoints()
    if npcBot:GetAbilityPoints() < 1 + abilityTable.incorrectAbilityLevelUpNumber or GetGameState() ~=
        GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
        return
    end
    local abilityName = abilityTable[self:GetAbilityLevelUpIndex(npcBot)]
    if abilityName == self.IncorrectAbilityName or abilityName == self.SpecialBonusAttributes then
        abilityTable.incorrectAbilityLevelUpNumber = abilityTable.incorrectAbilityLevelUpNumber + 1
    end
    npcBot:ActionImmediate_LevelAbility(abilityName)
    abilityTable.justLevelUpAbility = true
end

-- geometry

M.IsVector = function(self, object)
    return
        type(object) == "userdata" and type(object.x) == "number" and type(object.y) == "number" and type(object.z) ==
        "number"
end
M.ToStringVector = function(self, object)
    return string.format("(%d,%d,%d)", object.x, object.y, object.z)
end

M.GetLine = function(self, a, b)
    if a.x == b.x then
        return {
            a = 1,
            b = 0,
            c = -a.x
        }
    end
    local k = (a.y - b.y) / (a.x - b.x)
    local bb = a.y - k * a.x
    return {
        a = k,
        b = -1,
        c = bb
    }
end

M.GetPointToLineDistance = function(self, point, line)
    local up = math.abs(line.a * point.x + line.b * point.y + line.c)
    local down = math.sqrt(line.a * line.a + line.b * line.b)
    return up / down
end

M.GetPointToPointDistance = function(self, a, b)
    return ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) ^ 0.5
end

-- Get the location on the line determined by startPoint and endPoint, with distance from startPoint to the target location
M.GetPointFromLineByDistance = function(self, startPoint, endPoint, distance)
    local distanceTo = self:GetPointToPointDistance(startPoint, endPoint)
    local divide = (endPoint - startPoint) / distanceTo * distance
    return startPoint + divide
end

M.GetCos = function(self, b, c, a)
    return (b ^ 2 + c * 2 - a * 2) / 2 / b / c
end
M.GetLocationToLocationDistance = function(self, a, b)
    return ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) ^ 0.5
end

function M:GetDegree(loc1, loc2)
    local y = loc2.y - loc1.y
    local x = loc2.x - loc1.x
    return math.atan2(y, x) * 180 / math.pi
end

-- Find the location to use a aoe at a single target with the least distance the hero needs to walk before casting
-- M.FindAOELocationAtSingleTarget = function(self, npcBot, target, radius, castRange, castPoint)
--    if self:CanMove(target) then
--        radius = radius * 0.8
--    end
--    local g
--    GeneratePath(npcBot:GetLocation(), target:GetLocation(), {}, function(distance, waypoints)
--        if waypoints == 0 then
--            waypoints = { npcBot:GetLocation(), target:GetLocation() }
--        end
--        for i = 1, #waypoints-1 do
--            local waypoint1 = waypoints[i]
--            local waypoint2 = waypoints[i+1]
--            local dis1 = GetUnitToLocationDistance(target, waypoint1)
--            local dis2 = GetUnitToLocationDistance(target, waypoint2)
--            if dis1 > dis2 then
--                if radius >= dis1 then
--                    g = waypoint1
--                    return
--                elseif radius >= dis2 then
--                    local waypointDis = self:GetLocationToLocationDistance(waypoint1, waypoint2)
--                    local cosine = self:GetCos(dis2, waypointDis, dis1)
--                    local walkDis = dis1*cosine - (dis1^2-radius*2)^0.5
--                    local targetLocation = self:GetPointFromLineByDistance(waypoint1, waypoint2, walkDis)
--                    g = targetLocation
--                    return
--                end
--            else
--                if radius >= dis1 then
--                    g = waypoint1
--                    return
--                end
--            end
--        end
--        g = waypoints[#waypoints]
--    end)
--    return g
-- end
M.FindAOELocationAtSingleTarget = function(self, npcBot, target, radius, castRange, castPoint)
    radius = radius - 80
    local distance = GetUnitToUnitDistance(npcBot, target)
    if distance < radius + castRange then
        return self:GetPointFromLineByDistance(npcBot:GetLocation(), target:GetLocation(), castRange)
    else
        return self:GetPointFromLineByDistance(target:GetLocation(), npcBot:GetLocation(), radius)
    end
end

M.PreventHealAtHealSuppressTarget = function(self, npcBot, oldConsiderFunction, ability)
    return function()
        local desire, target, targetTypeString = oldConsiderFunction()
        if desire == 0 or target == nil or target == 0 or targetTypeString == "Location" then
            return desire, target, targetTypeString
        end
        if npcBot:GetTeam() == target:GetTeam() then
            desire = desire * self:GetTargetHealAmplifyPercent(target)
        end
        desire = self:TrimDesire(desire)
        return desire, target, targetTypeString
    end
end

M.PURCHASE_ITEM_OUT_OF_STOCK = 82
M.PURCHASE_ITEM_INVALID_ITEM_NAME = 33
M.PURCHASE_ITEM_DISALLOWED_ITEM = 78
M.PURCHASE_ITEM_INSUFFICIENT_GOLD = 63
M.PURCHASE_ITEM_NOT_AT_SECRET_SHOP = 62
M.PURCHASE_ITEM_NOT_AT_HOME_SHOP = 67
M.PURCHASE_ITEM_SUCCESS = -1

-- specified ability is not actually an ability (2)
-- invalid order(3) unrecognised order name
-- invalid order(40) order not allowed for illusions
-- unit is dead (20)
-- target tree is not active (43)
-- ability is still in cooldown (15)
-- ability is hidden
-- cannot cast ability on tree
-- cannot cast ability on target
-- target is unselectable
-- order requires a physical item target, but specified target is not a physical item (9)
-- item cannot be used from stash (37)
-- does not have enough mana to cast ability (14)
-- item is still in cooldown
-- can't cast attack ability on target, target is attack immune (32)
-- order invalid for units with attack ability DOTA_UNIT_CAP_NO_ATTACK (41)
-- can't cast on target, ability cannot target enemies (30)
-- can't cast on target, ability cannot target creeps (56)
-- unit can't perform command, unit has commands restricted (74)
-- hero does not have enough ability points to upgrade ability (13)
-- ability is hidden (60)

M.IgnoreDamageModifiers = { "modifier_abaddon_borrowed_time", "modifier_item_aeon_disk_buff",
    "modifier_winter_wyvern_winters_curse", "modifier_winter_wyvern_winters_curse_aura",
    "modifier_skeleton_king_reincarnation_scepter_active" }

M.CannotKillModifiers = { "modifier_dazzle_shadow_grave", "modifier_troll_warlord_battle_trance" }

M.CannotBeTargettedModifiers = { "modifier_slark_shadow_dance", "modifier_item_book_of_shadows",
    "modifier_dark_willow_shadow_realm_buff" }

M.IgnorePhysicalDamageModifiers = { "modifier_winter_wyvern_cold_embrace" }
M.IgnoreMagicalDamageModifiers = { "modifier_oracle_fates_edict" }

M.LastForAtLeastSeconds = function(self, predicate, time, infoTable)
    if infoTable.lastTrueTime == nil then
        infoTable.lastTrueTime = DotaTime()
    end
    if predicate() then
        if DotaTime() - infoTable.lastTrueTime >= time then
            return true
        else
            return false
        end
    else
        infoTable.lastTrueTime = nil
        return false
    end
end

M.GoodIllusionHero = { "antimage", "spectre", "terrorblade", "naga_siren" }
M.ModerateIllusionHero = { "abaddon", "axe", "chaos_knight", "arc_warden", "juggernaut", "luna", "medusa", "morphling",
    "phantom_lancer", "sniper", "wraith_king", "phantom_assassin" }
M.GetIllusionBattlePower = function(self, npc)
    local name = self:GetHeroShortName(npc:GetUnitName())
    if npc:HasModifier("modifier_arc_warden_tempest_double") or
        npc:HasModifier("modifier_skeleton_king_reincarnation_active") then
        return 0.8
    end
    if npc:HasModifier("modifier_vengefulspirit_hybrid_special") then
        return 1.05
    end
    local t = 0.1
    if self:Contains(self.GoodIllusionHero, name) then
        t = 0.25
    elseif self:Contains(self.ModerateIllusionHero, name) then
        t = 0.4
    elseif t:IsRanged() then
        t = t + t:GetAttackRange() / 600
    end
    local inventory = self:Map(self:GetInventoryItems(npc), function(t)
        return t:GetName()
    end)
    if self:Contains(inventory, "item_radiance") then
        t = t + 0.07
    end
    if self:Contains(inventory, "item_diffusal_blade") then
        t = t + 0.05
    end
    if self:Contains(inventory, "item_lesser_crit") then
        t = t + 0.04
    end
    if self:Contains(inventory, "item_greater_crit") then
        t = t + 0.08
    end
    if npc:HasModifier("modifier_special_bonus_mana_break") then -- mirana talent[5]
        t = t + 0.04
    end
    return t
end

M.GetNetWorth = function(self, npc, isEnemy)
    if isEnemy then
        local itemCost = self:Map(self:GetInventoryItems(npc), function(t)
            return GetItemCost(t:GetName())
        end)
        return self:Aggregate(0, itemCost, function(a, b)
            return a + b
        end)
    else
        return npc:GetNetWorth()
    end
end

function M:GetBattlePower(npc)
    local power = 0
    local name = npc:GetUnitName()
    if string.match(name, "npc_dota_hero") then
        power = npc:GetNetWorth() + npc:GetLevel() * 1000
        if npc:GetLevel() >= 25 then
            power = power + 1000
        end
        if npc:GetLevel() >= 30 then
            power = power + 1000
        end
    elseif string.match(name, "npc_dota_lone_druid_bear") then
        local heroLevel = GetHeroLevel(npc:GetPlayerID())
        power = name[#"npc_dota_lone_druid_bear" + 1] * 2000 - 1000
        power = power + heroLevel * 250
        power = power + npc:GetNetWorth()
    end
    if npc:HasModifier("modifier_item_assault_positive") and not npc:HasModifier("modifier_item_assault_positive_aura") then
        power = power + 1500
    end
    local items = self:GetInventoryItemNames(npc)
    if npc:HasModifier("modifier_item_pipe_aura") and not self:Contains(items, "item_pipe") then
        power = power + 400
    end
    if npc:HasModifier("modifier_item_vladmir_aura") and not self:Contains(items, "item_vladmir") then
        power = power + 300
    end
    if npc:HasModifier("modifier_item_guardian_greaves_aura") and not self:Contains(items, "item_guardian_greaves") then
        power = power + 1000
    elseif npc:HasModifier("modifier_item_mekansm_aura") and not self:Contains(items, "item_mekansm") then
        power = power + 500
    end
    return power
end

M.GetHeroGroupBattlePower = function(self, npcBot, heroes, isEnemy)
    local function A(tb)
        local battlePowerMap = self:Map(tb, function(t)
            return { t:GetUnitName(), self:GetBattlePower(t) }
        end)
        battlePowerMap = self:SortByMaxFirst(battlePowerMap, function(t)
            return t[2]
        end)
        battlePowerMap = self:Map(battlePowerMap, function(t, index)
            return t[2] * (1.15 - 0.15 * index)
        end)
        local g = NewTable()
        for _, v in ipairs(battlePowerMap) do
            g[v[1]] = v[2]
        end
        return g
    end
    local enemyNetWorthMap = A(self:GetEnemyHeroUnique(npcBot, heroes))
    local netWorth = 0
    local readNames = NewTable()
    for _, enemy in pairs(heroes) do
        local name = enemy:GetUnitName()
        if not self:Contains(readNames, name) then
            table.insert(readNames, name)
            -- TODO: enemyNetWorthMap[name] should not be null
            if enemyNetWorthMap[name] then
                netWorth = netWorth + enemyNetWorthMap[name]
            end
        else
            if enemyNetWorthMap[name] then
                netWorth = netWorth + enemyNetWorthMap[name] * self:GetIllusionBattlePower(enemy)
            end
        end
    end
    return netWorth
end

M.Outnumber = function(self, npcBot, friends, enemies)
    return self:GetHeroGroupBattlePower(npcBot, friends, false) >= self:GetHeroGroupBattlePower(npcBot, enemies, true) *
        1.8
end

M.CannotBeKilledNormally = function(self, target)
    return target:IsInvulnerable() or self:Any(self.IgnoreDamageModifiers, function(t)
        target:HasModifier(t)
    end) or target:HasModifier("modifier_dazzle_shallow_grave")
end

M.HasScepter = function(self, npc)
    return npc:HasScepter() or npc:HasModifier("modifier_wisp_tether_scepter") or
        npc:HasModifier("modifier_item_ultimate_scepter") or
        npc:HasModifier("modifier_item_ultimate_scepter_consumed_alchemist")
end

-- ability record

local locationAOEAbilities = {
    cone = { "lina_dragon_slave" },
    circle = { "lina_light_strike_array" },
    isoscelesTrapezoid = { "kunkka_tidebringer" }
}

function M:RecordAbility(npc, index, target, castType, abilities)
    local abilityRecords = npc.abilityRecords
    if index ~= nil then
        abilityRecords[index] = {}
        if castType == "Location" then
            abilityRecords[index].location = target
        elseif castType == "Target" then
            abilityRecords[index].target = target
        elseif castType == "Tree" then
            abilityRecords[index].targetTree = target
        elseif self:IsVector(target) then
            abilityRecords[index].location = target
        elseif target ~= nil then
            abilityRecords[index].target = target
        end
        abilityRecords.usingAbilityIndex = index
        abilityRecords[index].beginCastTime = DotaTime()
        return
    end
    if not npc:IsUsingAbility() and not npc:IsChanneling() then
        if abilityRecords.usingAbilityIndex ~= nil and not abilities[abilityRecords.usingAbilityIndex]:IsCooldownReady() then
            abilityRecords.lastUsedAbilityIndex = abilityRecords.usingAbilityIndex
            abilityRecords.usingAbilityIndex = nil
            abilityRecords.lastUsedAbilityTime = DotaTime()
        end
    end
end

local Timer = require(GetScriptDirectory() .. "/util/timer")

-- 将 Timer 中的函数包装到 M 上，保持向后兼容（原有调用方改为 Timer.xxx 即可）
M.GetFrameNumber = function(self) return Timer.GetFrameNumber() end
M.EveryManyFrames = function(self, ...) return Timer.EveryManyFrames(...) end
M.EveryManySeconds = function(self, ...) return Timer.EveryManySeconds(...) end
M.SingleForTeam = function(self, ...) return Timer.SingleForTeam(...) end
M.SingleForAllBots = function(self, ...) return Timer.SingleForAllBots(...) end
M.CalledOnThisFrame = function(self, ...) return Timer.CalledOnThisFrame(...) end
M.TickFromDota = function(self) Timer.TickFromDota() end
M.RegisterSlowFunction = function(self, ...) return Timer.RegisterSlowFunction(...) end
M.ResumeUntilReturn = function(self, ...) return Timer.ResumeUntilReturn(...) end
M.StartCoroutine = function(self, ...) return Timer.StartCoroutine(...) end
M.WaitForSeconds = function(self, ...) return Timer.WaitForSeconds(...) end
M.StopCoroutine = function(self, ...) Timer.StopCoroutine(...) end

-- ========== 技能属性快捷访问（语法糖）==========
--
-- 安装 __index 元方法到 CDOTABaseAbility_BotScript（所有技能的基类），
-- 使得可以直接用 ability.aoe_radius 替代 ability:GetSpecialValueInt("aoe_radius")
--
-- 原理：当访问 ability 上不存在的字段（如 aoe_radius）时，Lua 会去
-- 元表的 __index 查找。我们把 GetDataFromAbility 挂到 __index 上，
-- 它自动调用 GetSpecialValueInt / GetSpecialValueFloat 获取技能数据。
--
-- Append__Index 负责链式挂载：如果引擎已经给技能基类设置了 __index，
-- 不会覆盖它，而是把新旧两个 __index 串联起来（先查旧的，没有再查新的）。
-- ==================================================
local function GetDataFromAbility(ability, valueName)
    local intVal = ability:GetSpecialValueInt(valueName)
    -- GetSpecialValueInt 对浮点数会返回 0，此时改用 GetSpecialValueFloat
    return intVal == 0 and ability:GetSpecialValueFloat(valueName) or intVal
end

local function Append__Index(tb, newIndex)
    local mt = getmetatable(tb)
    if mt == nil then
        mt = {}
        setmetatable(tb, mt)
    end
    local oldIndex = mt.__index
    if oldIndex == nil then
        -- 没有旧 __index，直接设置
        mt.__index = newIndex
    elseif type(oldIndex) == "function" then
        -- 旧 __index 是函数：串联，先查旧函数，查不到再用新的
        mt.__index = function(ability, key)
            local oldResult = { oldIndex(ability, key) }
            if oldResult[1] == nil then
                return newIndex(ability, key)
            else
                return M.Unpack(oldResult)
            end
        end
    elseif type(oldIndex) == "table" then
        if oldIndex == mt then
            -- 旧 __index 指向自身（自引用模式）：包裹一层
            mt.__index = function(tbl, key)
                local newResult = { newIndex(tbl, key) }
                if newResult[1] == nil then
                    return oldIndex[key]
                else
                    return M.Unpack(newResult)
                end
            end
        else
            -- 旧 __index 是另一张表：递归处理
            Append__Index(oldIndex, newIndex)
        end
    end
end
Append__Index(CDOTABaseAbility_BotScript, GetDataFromAbility)

function M:pcall(func, ...)
    local result = { func(...) }
    if result[1] then
        table.remove(result, 1)
        return self:Unpack(result)
    else
        error(result[2])
        DebugPause()
    end
end

-- M.debug = true
function M:DebugPause()
    if self.debug then
        DebugPause()
    end
end

return M
