----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.6b
--	Author: adamqqq		Email:adamqqq@163.com
--	敌法师 (Anti-Mage) 出装方案
----------------------------------------------------------------------------
local ItemPurchaseSystem = dofile(GetScriptDirectory() .. "/util/ItemPurchaseSystem")

-- 出装顺序列表（按优先级从高到低）
-- 出门装 → 补刀斧 → 天鹰戒 → 假腿 → 腐蚀之球 → 狂战斧 → 分身斧 → 大晕锤 → BKB → 蝴蝶 → A杖 → 银月
local p = {
    "item_tango",           -- 吃树
    "item_tango",           -- 吃树
    "item_flask",           -- 大药
    "item_quelling_blade",  -- 补刀斧
    "item_wraith_band",     -- 天鹰之戒
    "item_power_treads",    -- 假腿（动力鞋）
    "item_orb_of_corrosion",-- 腐蚀之球
    "item_bfury",           -- 狂战斧
    "item_manta",           -- 分身斧
    "item_abyssal_blade",   -- 深渊之刃（大晕锤）
    "item_black_king_bar",  -- 黑皇杖
    "item_butterfly",       -- 蝴蝶
    "item_ultimate_scepter",-- 阿哈利姆神杖
    "item_recipe_ultimate_scepter", -- 神杖配方
    "item_moon_shard",      -- 银月之晶
}
ItemPurchaseSystem:CreateItemInformationTable(GetBot(), p)

-- 物品购买主循环
function ItemPurchaseThink()
    ItemPurchaseSystem:ItemPurchaseExtend()
end
