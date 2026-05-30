----------------------------------------------------------------------------
--	物品购买系统 —管理英雄出装决策
----------------------------------------------------------------------------
local ItemPurchaseUtility = {}

require(GetScriptDirectory() .. "/base/Utility")

local AbilityExtensions = require(GetScriptDirectory() .. "/base/AbilityAbstraction")
local Timer = require(GetScriptDirectory() .. "/util/timer")

function ItemPurchaseUtility.SellExtraItem(ItemsToBuy)
    local npcBot = GetBot()
    local level = npcBot:GetLevel()
    local item_travel_boots = ItemPurchaseUtility.NoNeedTpscrollForTravelBoots()
    -- local item_travel_boots_1 = item_travel_boots[1];
    -- local item_travel_boots_2 = item_travel_boots[2];

    if (ItemPurchaseUtility.IsItemSlotsFull()) then
        if (GameTime() > 6 * 60 or level >= 6) then
            ItemPurchaseUtility.SellSpecifiedItem("item_faerie_fire")
            ItemPurchaseUtility.SellSpecifiedItem("item_tango")
            ItemPurchaseUtility.SellSpecifiedItem("item_clarity")
            ItemPurchaseUtility.SellSpecifiedItem("item_flask")
        end
        if (GameTime() > 25 * 60 or level >= 10) then
            ItemPurchaseUtility.SellSpecifiedItem("item_orb_of_venom")
            ItemPurchaseUtility.SellSpecifiedItem("item_enchanted_mango")
            ItemPurchaseUtility.SellSpecifiedItem("item_bracer")
            ItemPurchaseUtility.SellSpecifiedItem("item_null_talisman")
            ItemPurchaseUtility.SellSpecifiedItem("item_wraith_band")
        end
        if (GameTime() > 35 * 60 or level >= 15) then
            ItemPurchaseUtility.SellSpecifiedItem("item_branches")
            ItemPurchaseUtility.SellSpecifiedItem("item_bottle")
            ItemPurchaseUtility.SellSpecifiedItem("item_magic_wand")
            ItemPurchaseUtility.SellSpecifiedItem("item_flask")
            ItemPurchaseUtility.SellSpecifiedItem("item_ancient_janggo")
            ItemPurchaseUtility.SellSpecifiedItem("item_ring_of_basilius")
            ItemPurchaseUtility.SellSpecifiedItem("item_quelling_blade")
            ItemPurchaseUtility.SellSpecifiedItem("item_soul_ring")
            ItemPurchaseUtility.SellSpecifiedItem("item_buckler")
            ItemPurchaseUtility.SellSpecifiedItem("item_headdress")
        end
        if (GameTime() > 40 * 60 or level >= 20) then
            ItemPurchaseUtility.SellSpecifiedItem("item_vladmir")
            ItemPurchaseUtility.SellSpecifiedItem("item_urn_of_shadows")
            ItemPurchaseUtility.SellSpecifiedItem("item_drums_of_endurance")
            ItemPurchaseUtility.SellSpecifiedItem("item_hand_of_midas")
            ItemPurchaseUtility.SellSpecifiedItem("item_dust")
        end
        -- if(GameTime()>40*60 and npcBot:GetGold()>2500 and (item_travel_boots[1]==nil and item_travel_boots[2]==nil) and npcBot.HaveTravelBoots~=true )
        -- then
        --	table.insert(ItemsToBuy,"item_boots")
        --	table.insert(ItemsToBuy,"item_recipe_travel_boots")
        --	npcBot.HaveTravelBoots=true
        --    if npcBot:GetGold() >= 4500 then
        --        table.insert(ItemsToBuy, "item_recipe_travel_boots")
        --    end
        -- end
    end

    if (item_travel_boots[1] ~= nil or item_travel_boots[2] ~= nil) then
        ItemPurchaseUtility.SellSpecifiedItem("item_boots")
        ItemPurchaseUtility.SellSpecifiedItem("item_arcane_boots")
        ItemPurchaseUtility.SellSpecifiedItem("item_phase_boots")
        ItemPurchaseUtility.SellSpecifiedItem("item_power_treads_agi")
        ItemPurchaseUtility.SellSpecifiedItem("item_power_treads_int")
        ItemPurchaseUtility.SellSpecifiedItem("item_power_treads_str")
        ItemPurchaseUtility.SellSpecifiedItem("item_tranquil_boots")
    end
end

local function isLeaf(Node)
    local recipe = GetItemComponents(Node)
    return next(recipe) == nil
end

local function nextNodes(Node)
    local recipe = GetItemComponents(Node)
    return recipe[1]
end

-- 递归展开物品合成树到所有基础组件（叶子节点）
local function ExpandToLeafItems(item)
    if isLeaf(item) then
        return { item }
    end
    local result = {}
    for _, component in pairs(nextNodes(item)) do
        local leaves = ExpandToLeafItems(component)
        for _, leaf in ipairs(leaves) do
            table.insert(result, leaf)
        end
    end
    return result
end

ItemPurchaseUtility.ExpandItemRecipe = function(self, itemTable)
    local output = {}
    for _, v in pairs(itemTable) do
        local leaves = ExpandToLeafItems(v)
        for _, leaf in ipairs(leaves) do
            table.insert(output, leaf)
        end
    end
    return output
end

function ItemPurchaseUtility.Transfer(itemtable)
    return ItemPurchaseUtility:ExpandItemRecipe(itemtable)
end

-- 购买物品
-- 每次购买物品时，都检查下是否要购买tp卷轴
function ItemPurchaseUtility.ItemPurchase(ItemsToBuy)
    if GetGameState() == DOTA_GAMERULES_STATE_POSTGAME then
        return
    end
    -- 限频：购买决策不需要每帧执行
    if DotaTime() < lastItemPurchaseTime + ItemPurchaseInterval then
        return
    end
    lastItemPurchaseTime = DotaTime()

    local npcBot = GetBot()

    -- buy item_tp scroll
    ItemPurchaseUtility.WeNeedTpscroll()

    -- 如果没有要买的物品，重置购买目标并返回
    if (#ItemsToBuy == 0) then
        npcBot:SetNextItemPurchaseValue(0)
        return
    end

    -- 获取下一个要购买的物品
    local sNextItem = ItemsToBuy[1]
    npcBot:SetNextItemPurchaseValue(GetItemCost(sNextItem))

    -- 出售不需要的装备腾出格子
    ItemPurchaseUtility.SellExtraItem(ItemsToBuy)

    -- 在泉水附近或血量低时退出神秘商店模式
    if npcBot:DistanceFromFountain() <= 2500 or npcBot:GetHealth() / npcBot:GetMaxHealth() <= 0.35 then
        npcBot.secretShopMode = false
    end

    -- 如果下一个物品不来自神秘商店，退出神秘商店模式
    if IsItemPurchasedFromSecretShop(sNextItem) == false then
        npcBot.secretShopMode = false
    end

    -- 钱够时尝试购买
    if (npcBot:GetGold() >= GetItemCost(sNextItem)) then
        -- 如果下一个物品来自神秘商店，进入神秘商店模式
        if npcBot.secretShopMode ~= true then
            if (IsItemPurchasedFromSecretShop(sNextItem) and sNextItem ~= "item_bottle") then
                npcBot.secretShopMode = true
            end
        end

        local PurchaseResult = -2               -- 购买结果初始化为 -2（未尝试）
        if (npcBot.secretShopMode == true) then -- 神秘商店模式
            -- 自己在神秘商店附近则自己购买
            if (npcBot:DistanceFromSecretShop() <= 250) then
                PurchaseResult = npcBot:ActionImmediate_PurchaseItem(sNextItem)
            end

            -- 否则让信使购买
            local courier = GetCourier(0)
            local ItemCount = ItemPurchaseUtility.GetItemSlotsCount2(courier)
            if (courier:DistanceFromSecretShop() <= 250 and ItemCount < 9) then
                PurchaseResult = GetCourier(0):ActionImmediate_PurchaseItem(sNextItem)
            end
        else
            -- 普通商店模式：直接购买
            PurchaseResult = npcBot:ActionImmediate_PurchaseItem(sNextItem)
        end

        -- 处理购买结果
        if (PurchaseResult == PURCHASE_ITEM_SUCCESS) then
            npcBot.secretShopMode = false
            table.remove(ItemsToBuy, 1) -- 移除已购买的物品
        elseif PurchaseResult ~= -2 then
            print("购买物品失败: " .. ItemsToBuy[1] .. ", 错误：" .. PurchaseResult)
        end

        -- 缺货时卖掉消耗品腾出格子和回收部分金钱
        if (PurchaseResult == PURCHASE_ITEM_OUT_OF_STOCK) then
            ItemPurchaseUtility.SellSpecifiedItem("item_dust")
            ItemPurchaseUtility.SellSpecifiedItem("item_faerie_fire")
            ItemPurchaseUtility.SellSpecifiedItem("item_tango")
            ItemPurchaseUtility.SellSpecifiedItem("item_clarity")
            ItemPurchaseUtility.SellSpecifiedItem("item_flask")
        end
        -- 无效物品名或禁用物品
        if (PurchaseResult == PURCHASE_ITEM_INVALID_ITEM_NAME or PurchaseResult == PURCHASE_ITEM_DISALLOWED_ITEM) then
            print("无效物品购买或禁用物品：" .. ItemsToBuy[1])
            table.remove(ItemsToBuy, 1)
        end
        -- 金钱不足时退出神秘商店模式
        if (PurchaseResult == PURCHASE_ITEM_INSUFFICIENT_GOLD) then
            npcBot.secretShopMode = false
        end
        -- 不在神秘商店时切换模式
        if (PurchaseResult == PURCHASE_ITEM_NOT_AT_SECRET_SHOP) then
            npcBot.secretShopMode = true
        end
        if (PurchaseResult == PURCHASE_ITEM_NOT_AT_HOME_SHOP) then
            npcBot.secretShopMode = false
        end
    else
        npcBot.secretShopMode = false
    end
end

-- 检查是否有飞鞋，有则卖掉多余的 TP 卷轴
function ItemPurchaseUtility.NoNeedTpscrollForTravelBoots()
    local npcBot = GetBot()

    local item_travel_boots = {}

    local item_travel_boots_1 = nil
    local item_travel_boots_2 = nil
    for i = 0, 8 do
        local sCurItem = npcBot:GetItemInSlot(i)
        if (sCurItem ~= nil and sCurItem:GetName() == "item_travel_boots_1") then
            item_travel_boots_1 = sCurItem
        end

        if (sCurItem ~= nil and sCurItem:GetName() == "item_travel_boots_2") then
            item_travel_boots_2 = sCurItem
        end
    end

    -- 有飞鞋时卖掉主背包/备用背包里的 TP 卷轴（专用 TP 隐藏槽位无法通过 GetItemInSlot 访问，此处仅覆盖主栏+背包）
    if (item_travel_boots_1 ~= nil or item_travel_boots_2 ~= nil) then
        for i = 0, 8 do
            local sCurItem = npcBot:GetItemInSlot(i)
            if (sCurItem ~= nil and sCurItem:GetName() == "item_tpscroll") then
                npcBot:ActionImmediate_SellItem(sCurItem)
            end
        end
    end

    item_travel_boots[1] = item_travel_boots_1
    item_travel_boots[2] = item_travel_boots_2
    return item_travel_boots
end

-- 确保英雄有 TP 卷轴（没有飞鞋时自动补充）
function ItemPurchaseUtility.WeNeedTpscroll()
    local npcBot = GetBot()

    local item_travel_boots = ItemPurchaseUtility.NoNeedTpscrollForTravelBoots()
    local item_travel_boots_1 = item_travel_boots[1]
    local item_travel_boots_2 = item_travel_boots[2]

    -- 有飞鞋时不需要 TP 卷轴
    if item_travel_boots_1 ~= nil or item_travel_boots_2 ~= nil then
        return
    end

    -- 开局 3 分钟内不购买 TP
    if DotaTime() <= 3 * 60 then
        return
    end

    -- 查找 TP 卷轴（兼容专用 TP 槽位）
    local tpItem = npcBot:FindItemByName("item_tpscroll")
    local iScrollCount = 0
    if tpItem ~= nil then
        iScrollCount = tpItem:GetCurrentCharges()
    end

    -- TP 不足时购买
    if iScrollCount == 0 or (iScrollCount <= 2 and DotaTime() >= 5 * 60) then
        npcBot:ActionImmediate_PurchaseItem("item_tpscroll")
        -- 泉水处且 20 分钟后买两个
        if npcBot:DistanceFromFountain() <= 200 and DotaTime() >= 20 * 60 then
            npcBot:ActionImmediate_PurchaseItem("item_tpscroll")
        end
    end
end

-- 出售指定的物品（主物品栏+备用背包物品数 > 5 且在商店附近时执行）
-- 主栏 0-5 + 背包 6-8
function ItemPurchaseUtility.SellSpecifiedItem(item_name)
    local npcBot = GetBot()
    local itemCount = 0
    local item = nil

    for i = 0, 8 do
        local sCurItem = npcBot:GetItemInSlot(i)
        if (sCurItem ~= nil) then
            itemCount = itemCount + 1
            if (sCurItem:GetName() == item_name) then
                item = sCurItem
                break
            end
        end
    end

    -- 格子满（主栏+背包 > 5 格）且商店附近时出售
    if (item ~= nil and itemCount > 5 and
            (npcBot:DistanceFromFountain() <= 600 or npcBot:DistanceFromSideShop() <= 200 or npcBot:DistanceFromSecretShop() <=
                200)) then
        npcBot:ActionImmediate_SellItem(item)
    end
end

-- 统计单位的物品栏格数
function ItemPurchaseUtility.GetItemSlotsCount2(npcBot)
    local itemCount = 0
    for i = 0, 8 do
        local sCurItem = npcBot:GetItemInSlot(i)
        if (sCurItem ~= nil) then
            itemCount = itemCount + 1
        end
    end
    return itemCount
end

-- 统计当前英雄的物品栏格数
function ItemPurchaseUtility.GetItemSlotsCount()
    local npcBot = GetBot()
    local itemCount = 0
    for i = 0, 8 do
        local sCurItem = npcBot:GetItemInSlot(i)
        if (sCurItem ~= nil) then
            itemCount = itemCount + 1
        end
    end

    return itemCount
end

function ItemPurchaseUtility.IsItemSlotsFull()
    return ItemPurchaseUtility.GetItemSlotsCount() >= 8
end

function ItemPurchaseUtility.checkItemBuild(ItemsToBuy)
    local ItemTableA = { "item_tango", "item_clarity", "item_faerie_fire", "item_enchanted_mango", "item_flask" }

    if (DotaTime() > 0) then
        for _, item in pairs(ItemTableA) do
            for _1, item2 in pairs(ItemsToBuy) do
                if (item == item2) then
                    table.remove(ItemsToBuy, _1)
                end
            end
        end

        local npcBot = GetBot()
        for _1, item2 in pairs(ItemsToBuy) do
            if (npcBot:FindItemSlot(item2) > 0) then
                table.remove(ItemsToBuy, _1)
            end
        end
    end
end

local Enum = require(GetScriptDirectory() .. "/const/enum")

local invisHeroes = Enum.invisHeroes
local invisibleHeroes = {}
for heroName, _ in pairs(invisHeroes) do
    table.insert(invisibleHeroes, heroName)
end

-- function M.GetItemIncludeBackpack( item_name )

-- local npcBot = GetBot();
-- local item = nil;
-- local i=-1
-- i = npcBot:FindItemSlot(item_name)
-- item = npcBot:GetItemInSlot(i)

-- return item;
-- end

function ItemPurchaseUtility.GetItemIncludeBackpack(item_name)
    local npcBot = GetBot()
    for i = 0, 8 do
        local item = npcBot:GetItemInSlot(i)
        if (item ~= nil) then
            if (item:GetName() == item_name) then
                return item
            end
        end
    end
    return nil
end

function ItemPurchaseUtility.IsItemAvailable(item_name)
    local npcBot = GetBot()

    for i = 0, 5, 1 do
        local item = npcBot:GetItemInSlot(i)
        if (item ~= nil) then
            if (item:GetName() == item_name) then
                return item
            end
        end
    end
    return nil
end

function ItemPurchaseUtility.GetOtherTeam()
    if GetTeam() == TEAM_RADIANT then
        return TEAM_DIRE
    else
        return TEAM_RADIANT
    end
end

function ItemPurchaseUtility.CheckInvisibleEnemy()
    local enemyTeam = ItemPurchaseUtility.GetOtherTeam()

    if (enemyTeam ~= nil) then
        for _, id in pairs(GetTeamPlayers(enemyTeam)) do
            for _, invisibleHeroName in pairs(invisibleHeroes) do
                if (GetSelectedHeroName(id) == invisibleHeroName) then
                    return true
                end
            end
        end
    end

    local enemys = GetUnitList(UNIT_LIST_ENEMY_HEROES)

    if (enemys ~= nil) then
        for _, npcEnemy in pairs(enemys) do
            if (npcEnemy:HasInvisibility(false)) then
                return true
            end
        end
    end

    return false
end

local hasInvisibleEnemy = false
local BuySupportItem_Timer = DotaTime()
local BuySupportPurchaseCooldown = 0

function ItemPurchaseUtility.BuySupportItem()
    local npcBot = GetBot()
    -- decide if there were several invisible enemy heroes.

    if (DotaTime() - BuySupportItem_Timer >= 10) then
        BuySupportItem_Timer = DotaTime()
        hasInvisibleEnemy = ItemPurchaseUtility.CheckInvisibleEnemy()
    end

    -- 购买冷却：防止在物品缺货时每帧重复尝试购买
    if DotaTime() < BuySupportPurchaseCooldown then
        return
    end

    if (ItemPurchaseUtility.GetItemSlotsCount() < 7) then
        local item_ward_dispenser = ItemPurchaseUtility.GetItemIncludeBackpack("item_ward_dispenser")

        if (item_ward_dispenser ~= nil) then
            local wardState = item_ward_dispenser:GetToggleState()

            local observerCount = item_ward_dispenser:GetCurrentCharges()
            local sentryCount = item_ward_dispenser:GetSecondaryCharges()
        end

        local item_ward_observer = ItemPurchaseUtility.GetItemIncludeBackpack("item_ward_observer")
        local item_ward_sentry = ItemPurchaseUtility.GetItemIncludeBackpack("item_ward_dispenser")
        local item_gem = ItemPurchaseUtility.GetItemIncludeBackpack("item_gem")
        local item_smoke = ItemPurchaseUtility.GetItemIncludeBackpack("item_smoke_of_deceit")
        if (DotaTime() >= 0 and hasInvisibleEnemy == true) then
            local item_dust = ItemPurchaseUtility.GetItemIncludeBackpack("item_dust")
            -- local item_ward_sentry = M.GetItemIncludeBackpack( "item_ward_sentry" )
            if (item_gem == nil and ItemPurchaseUtility.HaveGem() == false) then
                if (item_dust == nil and item_ward_sentry == nil and npcBot:GetGold() >= 2 * GetItemCost("item_dust") and
                        GetItemStockCount("item_dust") >= 1) then
                    npcBot:ActionImmediate_PurchaseItem("item_dust")
                    BuySupportPurchaseCooldown = DotaTime() + 1.0
                    return
                end

                if (DotaTime() >= 25 * 60 and npcBot:GetGold() >= GetItemCost("item_gem") and
                        GetItemStockCount("item_gem") >= 1) and AbilityExtensions:GetEmptyItemSlots(npcBot) >= 1 then
                    if AbilityExtensions:GetEmptyItemSlots(npcBot) >= 1 and
                        AbilityExtensions:GetEmptyBackpackSlots(npcBot) == 0 then
                        npcBot:ActionImmediate_PurchaseItem("item_gem")
                        BuySupportPurchaseCooldown = DotaTime() + 1.0
                        return
                    elseif AbilityExtensions:GetEmptyBackpackSlots(npcBot) >= 1 then
                        if AbilityExtensions:SwapCheapestItemToBackpack(npcBot) then
                            npcBot:ActionImmediate_PurchaseItem("item_gem")
                            BuySupportPurchaseCooldown = DotaTime() + 1.0
                            return
                        end
                    else
                    end
                end

                -- if ( item_ward_observer==nil and item_dust==nil and item_ward_sentry==nil and M.IsItemSlotsFull()==false and npcBot:GetGold() >= 2*GetItemCost("item_ward_sentry") ) then
                -- 	npcBot:ActionImmediate_PurchaseItem( "item_ward_sentry" );
                -- end
            end
        end

        if (DotaTime() >= 40 * 60 and npcBot:GetGold() >= GetItemCost("item_gem") and GetItemStockCount("item_gem") >= 1 and
                item_gem == nil and ItemPurchaseUtility.HaveGem() == false) then
            npcBot:ActionImmediate_PurchaseItem("item_gem")
            BuySupportPurchaseCooldown = DotaTime() + 1.0
            return
        end
        -- item_ward_observer==nil and
        if (item_ward_observer == nil and item_ward_sentry == nil and GetItemStockCount("item_ward_observer") >= 1 and
                npcBot:GetGold() >= GetItemCost("item_ward_observer")) then
            npcBot:ActionImmediate_PurchaseItem("item_ward_observer")
            BuySupportPurchaseCooldown = DotaTime() + 1.0
            return
        end

        if (item_smoke == nil and GetItemStockCount("item_smoke_of_deceit") >= 1 and npcBot:GetGold() >=
                GetItemCost("item_smoke_of_deceit")) then
            npcBot:ActionImmediate_PurchaseItem("item_smoke_of_deceit")
            BuySupportPurchaseCooldown = DotaTime() + 1.0
            return
        end
    end
end

function ItemPurchaseUtility.HaveGem()
    for _, hero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        local gem = hero:FindItemSlot("item_gem")
        if (gem > 0) then
            return true
        end
    end
    return false
end

ItemPurchaseUtility.ItemName = {}
setmetatable(ItemPurchaseUtility.ItemName, {
    __index = function(tb, f)
        return "item_" .. f
    end
})
ItemPurchaseUtility.Consumables = { "clarity", "enchanted_mango", "faerie_fire", "tome_of_knowledge", "tango", "flask",
    "bottle",
    "tpscroll" }
ItemPurchaseUtility.IsConsumableItem = function(self, item)
    return AbilityExtensions:Contains(self.Consumables, string.sub(item, 6))
end

ItemPurchaseUtility.CreateItemInformationTable = function(self, npcBot, itemTable)
    local function ExpandFirstLevel(item)
        if isLeaf(item) then
            return {
                name = item,
                isSingleItem = true
            }
        else
            return {
                name = item,
                recipe = nextNodes(item)
            }
        end
    end
    local function ExpandOnce(item)
        local g = {}
        local expandSomething = false
        for _, v in ipairs(item.recipe) do
            if isLeaf(v) then
                table.insert(g, v)
            else
                expandSomething = true
                for _, i in ipairs(nextNodes(v)) do
                    table.insert(g, i)
                end
            end
        end
        item.recipe = g
        return expandSomething
    end
    local function TranslateToEquivalentItem(tb)
        local k = "item_power_treads"
        tb = AbilityExtensions:Replace(tb, function(t)
            return #t > #k and string.sub(t, 1, #k) == k
        end, function(t)
            return k
        end)
        return tb
    end
    local function RemoveBoughtItems() -- used only when reloading scripts in game
        local boughtItems = AbilityExtensions:Map(AbilityExtensions:GetAllBoughtItems(npcBot), function(t)
            return t:GetName()
        end)
        boughtItems = TranslateToEquivalentItem(boughtItems)
        local function TryRemoveItemWithName(itemName, tbToRemoveFirst)
            if self:IsConsumableItem(itemName) then
                table.remove(tbToRemoveFirst, 1)
                return true
            end
            for i, boughtItem in ipairs(boughtItems) do
                if boughtItem and boughtItem == itemName then
                    table.remove(boughtItems, i)
                    table.remove(tbToRemoveFirst, 1)
                    return true
                end
            end
        end

        local function TryRemoveItem(item, tbToRemoveFirst)
            if self:IsConsumableItem(item.name) then
                table.remove(tbToRemoveFirst, 1)
                return true
            end
            for i, boughtItem in ipairs(boughtItems) do
                if boughtItem and boughtItem == item.name then
                    table.remove(boughtItems, i)
                    table.remove(tbToRemoveFirst, 1)
                    return true
                elseif item.usedAsRecipeOf and AbilityExtensions:Contains(boughtItems, item.usedAsRecipeOf) then
                    table.remove(tbToRemoveFirst, 1)
                    return true
                end
            end
        end
        local infoTable = npcBot.itemInformationTable
        while TryRemoveItem(infoTable[1], infoTable) do
        end
        while infoTable[1] and infoTable[1].recipe do
            while #infoTable[1].recipe > 0 and TryRemoveItemWithName(infoTable[1].recipe[1], infoTable[1].recipe) do
            end
            if #infoTable[1].recipe == 0 then
                table.remove(infoTable, 1)
            else
                break
            end
        end
        if npcBot:HasModifier("modifier_item_ultimate_scepter") then
            AbilityExtensions:Remove_Modify(infoTable, function(t)
                return t.name == "item_ultimate_scepter" or t.name == "item_recipe_ultimate_scepter"
            end)
        end
    end

    local g = {}
    for _, item in pairs(itemTable) do
        local itemInformation = ExpandFirstLevel(item)
        if itemInformation.isSingleItem then
        else
            ::h::
            local recipe = itemInformation.recipe
            local deletedKeys = {}
            for _, boughtItem in pairs(g) do
                if not boughtItem.usedAsRecipeOf then
                    for componentIndex, componentName in ipairs(recipe) do
                        if componentName == boughtItem.name then
                            table.insert(deletedKeys, componentName)
                            boughtItem.usedAsRecipeOf = itemInformation.name
                            break
                        end
                    end
                end
            end
            for _, v in pairs(deletedKeys) do
                for t1, t2 in ipairs(recipe) do
                    if t2 == v then
                        table.remove(recipe, t1)
                        break
                    end
                end
            end
            if ExpandOnce(itemInformation) then
                goto h
            end
        end
        table.insert(g, itemInformation)
    end
    npcBot.itemInformationTable = g
    if DotaTime() > -60 then
        RemoveBoughtItems()
    end
    -- print(npcBot:GetUnitName()..": item table:")
    -- AbilityExtensions:DebugArray(g)
    -- print("bought items: ")
    -- AbilityExtensions:DebugArray(AbilityExtensions:Map(AbilityExtensions:GetAllBoughtItems(npcBot), function(t) return t:GetName() end))
end

local sNextItem
local UseCourier = function()
    local npcBot = GetBot()
    local courier = AbilityExtensions:GetMyCourier(npcBot)
    if courier == nil then
        return
    end
    local courierState = GetCourierState(courier)
    if courierState == COURIER_STATE_DEAD then
        return
    end
    local courierItemNumber = #AbilityExtensions:GetCourierItems(courier)

    if not npcBot:IsAlive() then
        if courierState ~= COURIER_STATE_RETURNING_TO_BASE and courierState ~= COURIER_STATE_AT_BASE then
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN)
        end
        return
    end
    local nearSecretShop = courier:DistanceFromSecretShop() <= 180
    local function IsWaitingAtSecretShop()
        return courierState == COURIER_STATE_IDLE and nearSecretShop and npcBot:GetGold() >= GetItemCost(sNextItem) *
            0.9
    end

    if courier.returnWhenCarryingTooMany then
        if courier:DistanceFromFountain() <= 1200 and courierState == COURIER_STATE_AT_BASE and
            (courier.returnCarryNumber < courierItemNumber or #AbilityExtensions:GetStashItems(npcBot) > 0) then
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
            courier.returnWhenCarryingTooMany = nil
            return
        end
        if courierState == COURIER_STATE_AT_BASE and IsItemPurchasedFromSecretShop(sNextItem) and npcBot:GetGold() >=
            GetItemCost(sNextItem) * 0.9 then
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_SECRET_SHOP)
            return
        end
        npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN)
        return
    end

    -- 英雄格子满了且信使携带着物品 → 让信使回城，下次再处理送货
    if AbilityExtensions:GetEmptyItemSlots(npcBot) == 0 and courierItemNumber > 0 and
        GetUnitToUnitDistance(npcBot, courier) <= 400 then
        courier.returnCarryNumber = courierItemNumber
        courier.returnWhenCarryingTooMany = true
        npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN)
        return
    end

    if #AbilityExtensions:GetStashItems(npcBot) ~= 0 then
        if (courierState == COURIER_STATE_AT_BASE or courierState == COURIER_STATE_IDLE) and not IsWaitingAtSecretShop() then
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
            return
        end
    end
    if #AbilityExtensions:GetCourierItems(courier) ~= 0 then
        if courierState ~= COURIER_STATE_DELIVERING_ITEMS and not IsWaitingAtSecretShop() then
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_TRANSFER_ITEMS)
            return
        end
    end
    if IsItemPurchasedFromSecretShop(sNextItem) and npcBot:GetGold() >= GetItemCost(sNextItem) * 0.9 then
        courier.returnWhenCarryingTooMany = nil
        if courierState == COURIER_STATE_AT_BASE then
            -- print("courier usage a2")
            npcBot:ActionImmediate_Courier(courier, COURIER_ACTION_SECRET_SHOP)
            return
        end
        if nearSecretShop and npcBot:GetGold() >= GetItemCost(sNextItem) then
            -- 信使在神秘商店附近，由信使购买
            courier:ActionImmediate_PurchaseItem(sNextItem)
            return
        end
    end
end
UseCourier = Timer.EveryManySeconds(0.5, UseCourier)

local lastItemPurchaseTime = 0
local ItemPurchaseInterval = 0.3

ItemPurchaseUtility.ItemPurchaseExtend = function(self, ItemsToBuy)
    -- 限频：购买决策不需要每帧执行
    if DotaTime() < lastItemPurchaseTime + ItemPurchaseInterval then
        return
    end
    lastItemPurchaseTime = DotaTime()

    local function GetTopItemToBuy()
        local itemInformationTable = GetBot().itemInformationTable
        if #itemInformationTable == 0 then
            return nil
        elseif itemInformationTable[1].isSingleItem then
            return itemInformationTable[1].name
        else
            return itemInformationTable[1].recipe[1]
        end
    end
    local function RemoveTopItemToBuy()
        local itemInformationTable = GetBot().itemInformationTable
        if itemInformationTable[1].isSingleItem then
            table.remove(itemInformationTable, 1)
        else
            table.remove(itemInformationTable[1].recipe, 1)
            if #itemInformationTable[1].recipe == 0 then
                table.remove(itemInformationTable, 1)
            end
        end
    end

    if GetGameState() == DOTA_GAMERULES_STATE_POSTGAME then
        return
    end
    local npcBot = GetBot()

    local function RemoveInvisibleItemsWhenBountyHunter()
        local enemies = AbilityExtensions:Filter(GetBot():GetNearbyHeroes(1500, true, BOT_MODE_NONE), function(t)
            return AbilityExtensions:MayNotBeIllusion(GetBot(), t)
        end)
        if AbilityExtensions:Any(enemies, function(t)
                return t:GetUnitName() == AbilityExtensions:GetHeroFullName("bounty_hunter") or t:GetUnitName() ==
                    AbilityExtensions:GetHeroFullName("slardar") or t:GetUnitName() ==
                    AbilityExtensions:GetHeroFullName("rattletrap") and t:GetLevel() >= 18
            end) then
            ItemPurchaseUtility:RemoveInvisibleItemPurchase(GetBot())
        end
    end

    if npcBot:IsIllusion() then
        return
    end
    ItemPurchaseUtility.WeNeedTpscroll()

    if #GetBot().itemInformationTable == 0 then
        npcBot:SetNextItemPurchaseValue(0)
        return
    end

    -- RemoveInvisibleItemsWhenBountyHunter()
    sNextItem = GetTopItemToBuy()
    npcBot:SetNextItemPurchaseValue(GetItemCost(sNextItem))

    ItemPurchaseUtility.SellExtraItem(ItemsToBuy)

    if npcBot:DistanceFromFountain() <= 2500 or npcBot:GetHealth() / npcBot:GetMaxHealth() <= 0.35 then
        npcBot.secretShopMode = false
    end

    if IsItemPurchasedFromSecretShop(sNextItem) == false then
        npcBot.secretShopMode = false
    end

    if npcBot:GetGold() >= GetItemCost(sNextItem) then
        if sNextItem == "item_aghanims_shard" and GetItemStockCount(sNextItem) < 1 then
            return
        end
        if npcBot.secretShopMode ~= true then
            if (IsItemPurchasedFromSecretShop(sNextItem) and sNextItem ~= "item_bottle") then
                npcBot.secretShopMode = true
            end
        end

        local PurchaseResult = -2
        if (npcBot.secretShopMode == true) then
            if (npcBot:DistanceFromSecretShop() <= 250) then
                PurchaseResult = npcBot:ActionImmediate_PurchaseItem(sNextItem)
            end
            local courier = AbilityExtensions:GetMyCourier(npcBot)
            local ItemCount = ItemPurchaseUtility.GetItemSlotsCount2(courier)
            if (courier:DistanceFromSecretShop() <= 250 and ItemCount < 9) then
                PurchaseResult = courier:ActionImmediate_PurchaseItem(sNextItem)
            end
        else
            PurchaseResult = npcBot:ActionImmediate_PurchaseItem(sNextItem)
        end

        if (PurchaseResult == PURCHASE_ITEM_SUCCESS) then
            npcBot.secretShopMode = false
            RemoveTopItemToBuy()
        elseif PurchaseResult ~= -2 then
            print("purchase item failed: " .. sNextItem .. ", fail code: " .. PurchaseResult)
        end

        -- 缺货时卖掉消耗品腾出格子和回收部分金钱
        if (PurchaseResult == PURCHASE_ITEM_OUT_OF_STOCK) then
            ItemPurchaseUtility.SellSpecifiedItem("item_dust")
            ItemPurchaseUtility.SellSpecifiedItem("item_faerie_fire")
            ItemPurchaseUtility.SellSpecifiedItem("item_tango")
            ItemPurchaseUtility.SellSpecifiedItem("item_clarity")
            ItemPurchaseUtility.SellSpecifiedItem("item_flask")
        elseif PurchaseResult == PURCHASE_ITEM_INVALID_ITEM_NAME or PurchaseResult == PURCHASE_ITEM_DISALLOWED_ITEM then
            print("invalid item purchase or disallowed purchase: " .. sNextItem)
            RemoveTopItemToBuy()
        elseif (PurchaseResult == PURCHASE_ITEM_INSUFFICIENT_GOLD) then
            npcBot.secretShopMode = false
        elseif (PurchaseResult == PURCHASE_ITEM_NOT_AT_SECRET_SHOP) then
            npcBot.secretShopMode = true
        elseif (PurchaseResult == PURCHASE_ITEM_NOT_AT_HOME_SHOP) then
            npcBot.secretShopMode = false
        end
    else
        npcBot.secretShopMode = false
    end

    UseCourier()
end

ItemPurchaseUtility.RemoveItemPurchase = function(self, itemTable, itemName)
    local num = #itemTable
    local i = 1
    while i <= num do
        if itemTable[i].name == itemName then
            table.remove(itemTable, i)
            num = num - 1
        end
    end
end

ItemPurchaseUtility.InvisibleItemList = { "item_invis_sword", "item_silver_edge", "item_glimmer_cape" }
ItemPurchaseUtility.RemoveInvisibleItemPurchase = function(self, itemTable)
    AbilityExtensions:ForEach(self.InvisibleItemList, function(t)
        self:RemoveItemPurchase(itemTable, t)
    end)
end

return ItemPurchaseUtility
