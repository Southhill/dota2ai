----------------------------------------------------------------------------------------------------
-- BOT EXPERIMENT Author:Arizona Fauzie Link:http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
-- 角色工具模块 —定义每个英雄的角色定位
----------------------------------------------------------------------------------------------------

local RoleUtility = {}

local Tools = require(GetScriptDirectory() .. "/util/Tools")
local Enum = require(GetScriptDirectory() .. "/const/enum")
local Roles = require(GetScriptDirectory() .. "/const/roles")
local Heroes = require(GetScriptDirectory() .. "/const/heroes")

-- 从常量模块加载英雄角色数据
RoleUtility["hero_roles"] = Roles.hero_roles
RoleUtility["bottle"] = Roles.bottle
RoleUtility["phase_boots"] = Roles.phase_boots
RoleUtility["off"] = Tools.GenEnumArray(Heroes.off)
RoleUtility["mid"] = Tools.GenEnumArray(Heroes.mid)
RoleUtility["safe"] = Tools.GenEnumArray(Heroes.safe)
RoleUtility["supp"] = Tools.GenEnumArray(Heroes.supp)

function RoleUtility.IsCarry(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["carry"] > 0
end

function RoleUtility.IsDisabler(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["disabler"] > 0
end

function RoleUtility.IsDurable(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["durable"] > 0
end

function RoleUtility.HasEscape(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["escape"] > 0
end

function RoleUtility.IsInitiator(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["initiator"] > 0
end

function RoleUtility.IsJungler(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["jungler"] > 0
end

function RoleUtility.IsNuker(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["nuker"] > 0
end

function RoleUtility.IsSupport(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["support"] > 0
end

function RoleUtility.IsPusher(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return RoleUtility["hero_roles"][hero]["pusher"] > 0
end

function RoleUtility.IsMelee(attackRange)
	return attackRange <= 320
end

function RoleUtility.BetterBuyPhaseBoots(hero)
	return RoleUtility["phase_boots"][hero] == 1
end

function RoleUtility.GetRoleLevel(hero, role)
	return RoleUtility["hero_roles"][hero][role]
end

function RoleUtility.IsRemovedFromSupportPoll(hero)
	return hero == "npc_dota_hero_alchemist" or hero == "npc_dota_hero_naga_siren" or
		hero == "npc_dota_hero_skeleton_king" or
		hero == "npc_dota_hero_alchemist"
end

--OFFLANER
function RoleUtility.CanBeOfflanerOld(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return hero == "npc_dota_hero_bounty_hunter" or hero == "npc_dota_hero_nyx_assassin" or
		hero == "npc_dota_hero_magnataur" or
		hero == "npc_dota_hero_sand_king" or
		hero == "npc_dota_hero_shredder" or
		hero == "npc_dota_hero_tusk" or
		hero == "npc_dota_hero_dark_seer" or
		hero == "npc_dota_hero_techies" or
		hero == "npc_dota_hero_batrider" or
		(RoleUtility["hero_roles"][hero]["initiator"] > 0 and RoleUtility["hero_roles"][hero]["disabler"] > 0 and
			RoleUtility["hero_roles"][hero]["durable"] > 0 and
			RoleUtility["hero_roles"][hero]["support"] == 0)
end

function RoleUtility.CanBeOfflaner(heroName)
	return RoleUtility["off"][heroName]
end

--MIDLANER
function RoleUtility.CanBeMidlanerOld(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return hero == "npc_dota_hero_zuus" or hero == "npc_dota_hero_templar_assassin" or
		hero == "npc_dota_hero_ember_spirit" or
		hero == "npc_dota_hero_puck" or
		hero == "npc_dota_hero_pugna" or
		(RoleUtility["hero_roles"][hero]["carry"] > 0 and (RoleUtility["hero_roles"][hero]["nuker"] > 0 or RoleUtility["hero_roles"][hero]["pusher"] > 0))
end

function RoleUtility.CanBeMidlaner(heroName)
	return RoleUtility["mid"][heroName]
end

--SAFELANER
function RoleUtility.CanBeSafeLaneCarryOld(hero)
	if RoleUtility["hero_roles"][hero] == nil or hero == "npc_dota_hero_obsidian_destroyer" or hero == "npc_dota_hero_storm_spirit" then
		return false
	end
	return RoleUtility["hero_roles"][hero]["carry"] > 1 and
		((RoleUtility["hero_roles"][hero]["nuker"] < 3 and RoleUtility["hero_roles"][hero]["pusher"] < 3) or
			(RoleUtility["hero_roles"][hero]["escape"] > 0 and RoleUtility["hero_roles"][hero]["nuker"] < 2) or
			RoleUtility["hero_roles"][hero]["nuker"] < 2 or
			RoleUtility["hero_roles"][hero]["jungler"] == 1)
end

function RoleUtility.CanBeSafeLaneCarry(heroName)
	return RoleUtility["safe"][heroName]
end

--SUPPORT
function RoleUtility.CanBeSupportOld(hero)
	if RoleUtility["hero_roles"][hero] == nil then
		return false
	end
	return not RoleUtility.IsRemovedFromSupportPoll(hero) and RoleUtility["hero_roles"][hero]["support"] > 0 and
		(RoleUtility["hero_roles"][hero]["carry"] < 2 or RoleUtility["hero_roles"][hero]["nuker"] > 0 or RoleUtility["hero_roles"][hero]["disabler"] > 0)
end

function RoleUtility.CanBeSupport(heroName)
	return RoleUtility["supp"][heroName]
end

function RoleUtility.GetCurrentSuitableRole(bot, hero)
	local lane = bot:GetAssignedLane()

	if RoleUtility.CanBeSupport(hero) and lane ~= LANE_MID then
		return "support"
	elseif RoleUtility.CanBeMidlaner(hero) and lane == LANE_MID then
		return "midlaner"
	elseif
		RoleUtility.CanBeSafeLaneCarry(hero) and
		((GetTeam() == TEAM_RADIANT and lane == LANE_BOT) or (GetTeam() == TEAM_DIRE and lane == LANE_TOP))
	then
		return "carry"
	elseif
		RoleUtility.CanBeOfflaner(hero) and
		((GetTeam() == TEAM_RADIANT and lane == LANE_TOP) or (GetTeam() == TEAM_DIRE and lane == LANE_BOT))
	then
		return "offlaner"
	elseif hero == "npc_dota_hero_wisp" then
		return "support"
	elseif hero == "npc_dota_hero_elder_titan" then
		return "offlaner"
	else
		return "unknown"
	end
end

function RoleUtility.CountValue(hero, role)
	local highest = 0
	local TeamMember = GetTeamPlayers(GetTeam())
	for i = 1, #TeamMember do
	end
	return highest
end

RoleUtility["invisEnemyExist"] = false

local globalEnemyCheck = false
local lastCheck = -90

function RoleUtility.UpdateInvisEnemyStatus(bot)
	if globalEnemyCheck == false then
		local players = GetTeamPlayers(GetOpposingTeam())
		for i = 1, #players do
			if Enum.invisHeroes[GetSelectedHeroName(players[i])] then
				RoleUtility["invisEnemyExist"] = true
				break
			end
		end
		globalEnemyCheck = true
	elseif globalEnemyCheck == true and DotaTime() > 10 * 60 and DotaTime() > lastCheck + 3.0 then
		local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if #enemies > 0 then
			for i = 1, #enemies do
				if enemies[i] ~= nil and enemies[i]:IsNull() == false and enemies[i]:CanBeSeen() == true then
					local SASlot = enemies[i]:FindItemSlot("item_shadow_amulet")
					local GCSlot = enemies[i]:FindItemSlot("item_glimmer_cape")
					local ISSlot = enemies[i]:FindItemSlot("item_invis_sword")
					local SESlot = enemies[i]:FindItemSlot("item_silver_edge")
					if SASlot >= 0 or GCSlot >= 0 or ISSlot >= 0 or SESlot >= 0 then
						RoleUtility["invisEnemyExist"] = true
						break
					end
				end
			end
		end
		lastCheck = DotaTime()
	end
end

function RoleUtility.IsTheLowestLevel(bot)
	local lowestLevel = 26
	local lowestID = -1
	local players = GetTeamPlayers(GetTeam())
	for i = 1, #players do
		if GetHeroLevel(players[i]) < lowestLevel then
			lowestLevel = GetHeroLevel(players[i])
			lowestID = players[i]
		end
	end
	return bot:GetPlayerID() == lowestID
end

RoleUtility["supportExist"] = nil
function RoleUtility.UpdateSupportStatus(bot)
	if bot.theRole == "support" then
		RoleUtility["supportExist"] = true
	end
	local TeamMember = GetTeamPlayers(GetTeam())
	for i = 1, #TeamMember do
		local ally = GetTeamMember(i)
		if ally == nil or ally:IsAlive() == false or ally.theRole == nil then
			RoleUtility["supportExist"] = nil
		end
	end
	for i = 1, #TeamMember do
		local ally = GetTeamMember(i)
		if ally ~= nil and ally:IsHero() and ally.theRole == "support" then
			RoleUtility["supportExist"] = true
		end
	end
	return false
end

RoleUtility["lastbbtime"] = -90

function RoleUtility.ShouldBuyBack()
	return DotaTime() > RoleUtility["lastbbtime"] + 2.0
end

function RoleUtility.GetHighestValueRoles(bot)
	local maxVal = -1
	local role = ""
	print("=========" .. bot:GetUnitName() .. "=========")
	for key, value in pairs(RoleUtility.hero_roles[bot:GetUnitName()]) do
		print(tostring(key) .. " : " .. tostring(value))
		if value >= maxVal then
			maxVal = value
			role = key
		end
	end
	print("Highest value role => " .. role .. " : " .. tostring(maxVal))
end

return RoleUtility
