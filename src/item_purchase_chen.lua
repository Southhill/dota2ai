----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.6b
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
local ItemPurchaseSystem = require(GetScriptDirectory() .. "/base/ItemPurchaseSystem") --导入通用函数�?

local ItemsToBuy =
{
	"item_tango",
	"item_clarity",
	"item_branches",
	"item_branches",
	"item_boots",
	"item_flask",
	"item_magic_wand", --大魔�?.14
	"item_arcane_boots",
	"item_mekansm", --梅肯
	"item_ghost",
	"item_guardian_greaves", --卫士胫甲
	"item_ultimate_scepter",
	"item_force_staff",
	"item_lotus_orb",
}

ItemPurchaseSystem:CreateItemInformationTable(GetBot(), ItemsToBuy)
 --检查装备列�?

function ItemPurchaseThink()
	ItemPurchaseSystem.BuySupportItem() --购买辅助物品	对于辅助英雄保留这一�?--购买信使		对于5号位保留这一�?
	ItemPurchaseSystem:ItemPurchaseExtend()
 --购买装备
end
