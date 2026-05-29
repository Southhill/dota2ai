----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.6b
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
local ItemPurchaseSystem = require(GetScriptDirectory() .. "/base/ItemPurchaseSystem")

local ItemsToBuy =
{
	"item_tango",
	"item_tango",
	"item_flask",
	"item_clarity",
	"item_arcane_boots", --秘法
	"item_magic_wand", --大魔�?.14
	"item_blink", --跳刀
	"item_force_staff", --推推7.14
	"item_ultimate_scepter", --蓝杖
	"item_black_king_bar",
}

ItemPurchaseSystem:CreateItemInformationTable(GetBot(), ItemsToBuy)
 --检查装备列�?

function ItemPurchaseThink()
	ItemPurchaseSystem.BuySupportItem() --购买辅助物品	对于辅助英雄保留这一�?--购买信使		对于5号位保留这一�?
	ItemPurchaseSystem:ItemPurchaseExtend()
 --购买装备
end
