----------------------------------------------------------------------------
--  开发工具：收集 Dota2 当前版本的英雄/技能/物品数据
--  用途：辅助升级脚本适配新版本（如 7.29 → 7.41c）
--  使用方法：
--    方法A（推荐）：在 hero_selection.lua 顶部添加一行：
--      require(GetScriptDirectory() .. "/dev_collect_game_data")
--      然后正常启动游戏，数据会自动收集并打印到控制台
--    方法B：进游戏后控制台执行：dota_bot_reload_scripts
--      确保此文件在 bots/ 目录下被 require 引用
--  输出：游戏内按 ~ 打开控制台查看打印的收集报告
--  然后运行：dota_unit_serialize  获取更多数据
----------------------------------------------------------------------------
local DevCollect = {}

-- 收集到的数据缓存
local CollectedData = {
    heroes = {},
    items = {},
    timestamp = os.date("%Y-%m-%d %H:%M:%S")
}

-- 已收集记录的英雄名（用于去重）
local RecordedHeroes = {}

----------------------------------------------------------------------------
-- 收集单个英雄的数据
----------------------------------------------------------------------------
function DevCollect.CollectHero(npcHero)
    if npcHero == nil then
        return
    end

    local heroName = npcHero:GetUnitName()
    if RecordedHeroes[heroName] then
        return
    end
    RecordedHeroes[heroName] = true

    local heroData = {
        name = heroName,
        level = npcHero:GetLevel(),
        abilities = {},
        attributes = {
            health = npcHero:GetMaxHealth(),
            mana = npcHero:GetMaxMana(),
            damage = math.floor(npcHero:GetAttackDamage()),
            armor = math.floor(npcHero:GetArmor() + 0.5),
            movespeed = npcHero:GetCurrentMovementSpeed()
        }
    }

    -- 遍历所有技能槽位 (0~25)
    for slot = 0, 25 do
        local ability = npcHero:GetAbilityInSlot(slot)
        if ability ~= nil then
            local abilName = ability:GetName()
            local abilLevel = ability:GetLevel()
            local abilType = "active"

            if ability:IsToggle() then
                abilType = "toggle"
            elseif ability:IsPassive() then
                abilType = "passive"
            elseif ability:IsChannel() then
                abilType = "channel"
            end

            if string.find(abilName, "special_bonus") or string.find(abilName, "talent") then
                abilType = "talent"
            elseif string.find(abilName, "attribute_bonus") then
                abilType = "attribute_bonus"
            end

            table.insert(heroData.abilities, {
                slot = slot,
                name = abilName,
                level = abilLevel,
                type = abilType,
                cooldown = ability:GetCooldownTimeRemaining(),
                manaCost = ability:GetManaCost(abilLevel)
            })
        end
    end

    -- 收集英雄物品栏
    heroData.items = {}
    for slot = 0, 5 do
        local item = npcHero:GetItemInSlot(slot)
        if item ~= nil then
            table.insert(heroData.items, {
                slot = slot,
                name = item:GetName(),
                cooldown = item:GetCooldownTimeRemaining()
            })
        end
    end

    CollectedData.heroes[#CollectedData.heroes + 1] = heroData
    print("[DEV] Collected: " .. heroName .. " (" .. #heroData.abilities .. " abilities)")
end

----------------------------------------------------------------------------
-- 收集所有可见英雄的数据
----------------------------------------------------------------------------
function DevCollect.CollectAllVisible()
    local bot = GetBot()
    if bot == nil then
        return
    end

    DevCollect.CollectHero(bot)

    local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    if allies ~= nil then
        for _, hero in ipairs(allies) do
            DevCollect.CollectHero(hero)
        end
    end

    local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    if enemies ~= nil then
        for _, hero in ipairs(enemies) do
            DevCollect.CollectHero(hero)
        end
    end
end

----------------------------------------------------------------------------
-- 输出收集报告
----------------------------------------------------------------------------
function DevCollect.PrintReport()
    print("")
    print("=====================================================")
    print("  RMMAI Data Collection Report")
    print("  Timestamp: " .. CollectedData.timestamp)
    print("  Heroes collected: " .. #CollectedData.heroes)
    print("=====================================================")

    for _, heroData in ipairs(CollectedData.heroes) do
        print("")
        print("--- " .. heroData.name .. " (Lv" .. heroData.level .. ") ---")
        print("  HP:" .. heroData.attributes.health .. " MP:" .. heroData.attributes.mana .. " DMG:" ..
                  heroData.attributes.damage .. " ARM:" .. heroData.attributes.armor)
        print("  Abilities:")
        for _, abil in ipairs(heroData.abilities) do
            print(string.format("    [%2d] %-40s Lv%d %s", abil.slot, abil.name, abil.level, abil.type))
        end
        if #heroData.items > 0 then
            print("  Items:")
            for _, item in ipairs(heroData.items) do
                print(string.format("    [%d] %s", item.slot, item.name))
            end
        end
    end

    print("")
    print("=====================================================")
    print("  Collection Complete! " .. #CollectedData.heroes .. " heroes recorded")
    print("  Next: run 'dota_unit_serialize' in console for full data")
    print("=====================================================")
end

return DevCollect
