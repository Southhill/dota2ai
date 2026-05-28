----------------------------------------------------------------------------
--	聊天系统模块
----------------------------------------------------------------------------
local M = {}

local version = "0.0.1" -- Agent2026 版本号
local updateDate = "May 17, 2021" -- 最后更新

local announceFlag = false -- 防止重复发送

local detectedDotaVersion = nil -- 缓存检测到的 Dota2 版本

-- 待检测的英雄列表（按加入版本排序）
local HERO_CHECK_LIST = {
    -- 基础英雄（Dota 2 初始）
    base = {"npc_dota_hero_axe", "npc_dota_hero_crystal_maiden", "npc_dota_hero_drow_ranger",
            "npc_dota_hero_juggernaut", "npc_dota_hero_lina", "npc_dota_hero_pudge", "npc_dota_hero_sniper",
            "npc_dota_hero_sven", "npc_dota_hero_zeus"},
    -- 7.33+ 新增
    v7_33 = {"npc_dota_hero_muerta"},
    -- 7.35+ 新增
    v7_35 = {"npc_dota_hero_ringmaster"},
    -- 7.37+ 新增
    v7_37 = {"npc_dota_hero_kez"}
}

-- 待检测的物品列表
local ITEM_CHECK_LIST = {
    -- 基础物品
    base = {"item_tango", "item_flask", "item_clarity", "item_tpscroll", "item_branches", "item_circlet",
            "item_gauntlets", "item_slippers", "item_mantle", "item_boots", "item_quelling_blade"},
    -- 7.33 新增物品（如：Roshan掉落、新装备）
    v7_33 = {"item_aghanims_shard", "item_wraith_pact", "item_blood_grenade"},
    -- 7.34+ 新增/调整
    v7_34 = {"item_disperser", "item_harpoon", "item_philosophers_stone"},
    -- 7.36+ 新增（先天技能、命石相关物品）
    v7_36 = {"item_innate_ability_token"}
}

-- 待检测的神符列表
local RUNE_CHECK_LIST = {"rune_doubledamage", "rune_haste", "rune_illusion", "rune_invisibility", "rune_regeneration",
                         "rune_bounty", "rune_arcane", "rune_water", "rune_shield", "rune_wisdom"}

-- 待检测的中立物品
local NEUTRAL_ITEM_CHECK_LIST = { -- Tier 1
"item_trusty_shovel", "item_faded_broach", "item_arcane_ring", "item_broom_handle", "item_ironwood_tree",
"item_royal_jelly", "item_oaken_pledge", "item_seer_stone", "item_ogre_seal_totem", "item_doubloon",
"item_light_collector", -- Tier 2
"item_dragon_lance", "item_vengeances_shadow", "item_elven_tunic", "item_grove_bow", "item_vambrace",
"item_philosophers_stone", "item_pupils_gift", "item_telescope", "item_spider_legs", "item_quicksilver_amulet",
"item_eye_of_the_vizier", "item_glimmer_cape", "item_book_of_shadows", -- Tier 3
"item_illusionsts_cape", "item_guardian_greaves", "item_witch_blade", "item_mage_slayer", "item_paladin_sword",
"item_psychic_headband", "item_ceremonial_robe", "item_titan_sliver", "item_unwavering_ward", "item_lance_of_purgatory",
"item_ninja_gear", "item_orb_of_destruction", "item_ghostly_trickster_cloak", -- Tier 4
"item_timeless_relic", "item_phoenix_ash", "item_giants_ring", "item_spell_prism", "item_leveller",
"item_artifice_ring", "item_ascetic_aegis", "item_aegis_of_the_immortal", -- Tier 5
"item_book_of_shadows_5", "item_force_boots", "item_mirror_shield", "item_seer_stone_5", "item_fallen_sky"}

-- 遍历检查 API 函数是否存在（用于推断版本功能）
local API_CHECK_LIST = {"GetDotaScriptVersion", "GetHeroData", "GetItemData", "GetUnitData", "GetAbilityData",
                        "GetModifierData", "GetRuneData", "GetNeutralCampData"}

-- 打印分隔线
local function PrintSection(title)
    print("[Agent2026] ====== " .. title .. " ======")
end

-- 检测当前 Dota2 游戏版本（游戏启动时执行一次并缓存）
local function DetectDotaVersion()
    PrintSection("Dota2 Environment Detection Start")

    -- 方法 1: 检测可用的 API 函数
    PrintSection("Available API Functions")
    local apiAvailable = {}
    for _, apiName in ipairs(API_CHECK_LIST) do
        local ok, _ = pcall(_G[apiName])
        if ok then
            table.insert(apiAvailable, apiName)
            print("[Agent2026] [API] " .. apiName .. " = YES")
        else
            -- 函数不存在或调用失败
            if _G[apiName] ~= nil then
                print("[Agent2026] [API] " .. apiName .. " = exists but errored")
            else
                print("[Agent2026] [API] " .. apiName .. " = NO")
            end
        end
    end

    -- 方法 2: GetDotaScriptVersion() — 新版 Dota2 API 支持
    local ok, result = pcall(GetDotaScriptVersion)
    if ok and type(result) == "string" and result ~= "" then
        detectedDotaVersion = result
        print("[Agent2026] Dota2 Script Version: " .. result)
    else
        -- 方法 3: 检查地图名称
        local ok2, mapName = pcall(GetMapName)
        if ok2 and mapName then
            print("[Agent2026] Map: " .. mapName)
        end

        detectedDotaVersion = "unknown"
    end

    -- 方法 4: 检测英雄存在情况
    PrintSection("Hero Detection")
    local heroCount = 0
    for _, heroList in pairs(HERO_CHECK_LIST) do
        for _, heroName in ipairs(heroList) do
            local ok3, heroData = pcall(GetHeroData, heroName)
            if ok3 and heroData then
                print("[Agent2026] [HERO] " .. heroName .. " = EXISTS")
                heroCount = heroCount + 1
            else
                print("[Agent2026] [HERO] " .. heroName .. " = NOT_FOUND")
            end
        end
    end
    local heroTotal = #HERO_CHECK_LIST.base + (#HERO_CHECK_LIST.v7_33 or 0) + (#HERO_CHECK_LIST.v7_35 or 0) +
                          (#HERO_CHECK_LIST.v7_37 or 0)
    print("[Agent2026] Heroes detected: " .. heroCount .. "/" .. heroTotal)

    -- 方法 5: 检测物品存在情况
    PrintSection("Item Detection")
    local itemCount = 0
    local itemTotal = 0
    for _, itemList in pairs(ITEM_CHECK_LIST) do
        for _, itemName in ipairs(itemList) do
            itemTotal = itemTotal + 1
            local ok4, itemData = pcall(GetItemData, itemName)
            if ok4 and itemData then
                print("[Agent2026] [ITEM] " .. itemName .. " = EXISTS")
                itemCount = itemCount + 1
            else
                print("[Agent2026] [ITEM] " .. itemName .. " = NOT_FOUND")
            end
        end
    end
    print("[Agent2026] Items detected: " .. itemCount .. "/" .. itemTotal)

    -- 方法 6: 检测神符存在情况
    PrintSection("Rune Detection")
    local runeCount = 0
    for _, runeName in ipairs(RUNE_CHECK_LIST) do
        local ok5, runeData = pcall(GetRuneData, runeName)
        if ok5 and runeData then
            print("[Agent2026] [RUNE] " .. runeName .. " = EXISTS")
            runeCount = runeCount + 1
        else
            print("[Agent2026] [RUNE] " .. runeName .. " = NOT_FOUND")
        end
    end
    print("[Agent2026] Runes detected: " .. runeCount .. "/" .. #RUNE_CHECK_LIST)

    -- 方法 7: 检测中立物品存在情况
    PrintSection("Neutral Item Detection")
    local neutralCount = 0
    for _, neutralItemName in ipairs(NEUTRAL_ITEM_CHECK_LIST) do
        local ok6, neutralData = pcall(GetItemData, neutralItemName)
        if ok6 and neutralData then
            print("[Agent2026] [NEUTRAL] " .. neutralItemName .. " = EXISTS")
            neutralCount = neutralCount + 1
        else
            print("[Agent2026] [NEUTRAL] " .. neutralItemName .. " = NOT_FOUND")
        end
    end
    print("[Agent2026] Neutral items detected: " .. neutralCount .. "/" .. #NEUTRAL_ITEM_CHECK_LIST)

    -- 方法 8: 天赋检测 — 检查是否有 GetTalents API
    PrintSection("Talent Detection")
    local ok7, talentData = pcall(GetAbilityData, "special_bonus_attack_speed_15")
    if ok7 and talentData then
        print("[Agent2026] [TALENT] GetAbilityData(special_bonus) = AVAILABLE")
    else
        print("[Agent2026] [TALENT] GetAbilityData(special_bonus) = NOT_AVAILABLE")
    end

    -- 方法 9: 输出系统日期作为参考
    PrintSection("System Info")
    local sysDate = GetSystemDate()
    local sysTime = GetSystemTime()
    print("[Agent2026] System date: " .. sysDate .. " " .. sysTime)

    PrintSection("Detection Complete")
    print("[Agent2026] Summary: " .. heroCount .. " heroes, " .. itemCount .. " items, " .. runeCount .. " runes, " ..
              neutralCount .. " neutral items")

    if detectedDotaVersion == nil then
        detectedDotaVersion = "unknown (inferred)"
    end
end

-- 发送版本公告（游戏开始时执行一次）
function M.SendVersionAnnouncement()
    if announceFlag == false then
        announceFlag = true

        -- 首次运行时检测 Dota2 版本
        if detectedDotaVersion == nil then
            DetectDotaVersion()
        end

        local dotaVerStr = detectedDotaVersion or "unknown"
        print("[Agent2026] Agent2026 v" .. version .. " | Dota2: " .. dotaVerStr .. " | Date: " .. updateDate)

        for id = 1, 36, 1 do
            if (IsPlayerBot(id) == true and GetTeamForPlayer(id) == GetTeam()) then
                local npcBot = GetBot()
                if (npcBot:GetPlayerID() == id) then
                    npcBot:ActionImmediate_Chat("don't worry, be happy!", true)
                    npcBot:ActionImmediate_Chat("Agent2026  v" .. version .. ", Dota2: " .. dotaVerStr, true)
                end
                return
            end
        end
    end
end

return M
