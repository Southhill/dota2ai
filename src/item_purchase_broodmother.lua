----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.6b
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
local ItemPurchaseSystem = require(GetScriptDirectory() .. "/util/ItemPurchaseSystem")

local ItemsToBuy =
{
	"item_tango",
	"item_quelling_blade", --补刀�?
	"item_boots",
	"item_magic_wand", --大魔�?.14
    "item_power_treads",
	"item_soul_ring",
	"item_solar_crest", --大勋�?.20
	"item_orchid", --紫苑
	"item_black_king_bar", --bkb
	"item_hyperstone",
	"item_recipe_bloodthorn", --血�?
	"item_assault", --强袭
}

ItemPurchaseSystem:CreateItemInformationTable(GetBot(), ItemsToBuy)


function ItemPurchaseThink()
	ItemPurchaseSystem:ItemPurchaseExtend()

end
