----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.3 New Structure
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
--------------------------------------
-- General Initialization
--------------------------------------
local utility = require(GetScriptDirectory() .. "/util/Utility")
require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")

local npcBot = GetBot()
local Talents = {}
local Abilities = {}
local AbilitiesReal = {}

ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)

local AbilityToLevelUp = {
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[4],
	Abilities[1],
	Abilities[3],
	Abilities[3],
	"talent",
	Abilities[2],
	Abilities[4],
	Abilities[2],
	Abilities[2],
	"talent",
	Abilities[2],
	"nil",
	Abilities[4],
	"nil",
	"talent",
	"nil",
	"nil",
	"nil",
	"nil",
	"talent"
}
local TalentTree = {
	function()
		return Talents[2]
	end,
	function()
		return Talents[4]
	end,
	function()
		return Talents[5]
	end,
	function()
		return Talents[8]
	end
}
--------------------------------------
-- Level Ability and Talent
--------------------------------------

utility.CheckAbilityBuild(AbilityToLevelUp)

function AbilityLevelUpThink()
	ability_item_usage_generic.AbilityLevelUpThink2(AbilityToLevelUp, TalentTree)
end

function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink()
end
