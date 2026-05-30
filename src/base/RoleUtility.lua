----------------------------------------------------------------------------------------------------
-- BOT EXPERIMENT Author:Arizona Fauzie Link:http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
-- 角色工具模块 —定义每个英雄的角色定位
----------------------------------------------------------------------------------------------------

local X = {}

local Tools = require(GetScriptDirectory() .. "/util/Tools")
local Enum = require(GetScriptDirectory() .. "/const/enum")
local Roles = require(GetScriptDirectory() .. "/const/roles")
local Heroes = require(GetScriptDirectory() .. "/const/heroes")

-- 从常量模块加载英雄角色数据
X["hero_roles"] = Roles.hero_roles
X["bottle"] = Roles.bottle
X["phase_boots"] = Roles.phase_boots
X["off"] = Tools.GenEnumArray(Heroes.off)
X["mid"] = Tools.GenEnumArray(Heroes.mid)
X["safe"] = Tools.GenEnumArray(Heroes.safe)
X["supp"] = Tools.GenEnumArray(Heroes.supp)

function X.IsCarry(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["carry"] > 0
end

function X.IsDisabler(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["disabler"] > 0
end

function X.IsDurable(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["durable"] > 0
end

function X.HasEscape(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["escape"] > 0
end

function X.IsInitiator(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["initiator"] > 0
end

function X.IsJungler(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["jungler"] > 0
end

function X.IsNuker(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["nuker"] > 0
end

function X.IsSupport(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["support"] > 0
end

function X.IsPusher(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return X["hero_roles"][hero]["pusher"] > 0
end

function X.IsMelee(attackRange)
	return attackRange <= 320
end

function X.BetterBuyPhaseBoots(hero)
	return X["phase_boots"][hero] == 1
end

function X.GetRoleLevel(hero, role)
	return X["hero_roles"][hero][role]
end

function X.IsRemovedFromSupportPoll(hero)
	return hero == "npc_dota_hero_alchemist" or hero == "npc_dota_hero_naga_siren" or
		hero == "npc_dota_hero_skeleton_king" or
		hero == "npc_dota_hero_alchemist"
end

--OFFLANER
function X.CanBeOfflanerOld(hero)
	if X["hero_roles"][hero] == nil then
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
		(X["hero_roles"][hero]["initiator"] > 0 and X["hero_roles"][hero]["disabler"] > 0 and
			X["hero_roles"][hero]["durable"] > 0 and
			X["hero_roles"][hero]["support"] == 0)
end

function X.CanBeOfflaner(heroName)
	return X["off"][heroName]
end

--MIDLANER
function X.CanBeMidlanerOld(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return hero == "npc_dota_hero_zuus" or hero == "npc_dota_hero_templar_assassin" or
		hero == "npc_dota_hero_ember_spirit" or
		hero == "npc_dota_hero_puck" or
		hero == "npc_dota_hero_pugna" or
		(X["hero_roles"][hero]["carry"] > 0 and (X["hero_roles"][hero]["nuker"] > 0 or X["hero_roles"][hero]["pusher"] > 0))
end

function X.CanBeMidlaner(heroName)
	return X["mid"][heroName]
end

--SAFELANER
function X.CanBeSafeLaneCarryOld(hero)
	if X["hero_roles"][hero] == nil or hero == "npc_dota_hero_obsidian_destroyer" or hero == "npc_dota_hero_storm_spirit" then
		return false
	end
	return X["hero_roles"][hero]["carry"] > 1 and
		((X["hero_roles"][hero]["nuker"] < 3 and X["hero_roles"][hero]["pusher"] < 3) or
			(X["hero_roles"][hero]["escape"] > 0 and X["hero_roles"][hero]["nuker"] < 2) or
			X["hero_roles"][hero]["nuker"] < 2 or
			X["hero_roles"][hero]["jungler"] == 1)
end

function X.CanBeSafeLaneCarry(heroName)
	return X["safe"][heroName]
end

--SUPPORT
function X.CanBeSupportOld(hero)
	if X["hero_roles"][hero] == nil then
		return false
	end
	return not X.IsRemovedFromSupportPoll(hero) and X["hero_roles"][hero]["support"] > 0 and
		(X["hero_roles"][hero]["carry"] < 2 or X["hero_roles"][hero]["nuker"] > 0 or X["hero_roles"][hero]["disabler"] > 0)
end

function X.CanBeSupport(heroName)
	return X["supp"][heroName]
end

function X.GetCurrentSuitableRole(bot, hero)
	local lane = bot:GetAssignedLane()

	if X.CanBeSupport(hero) and lane ~= LANE_MID then
		return "support"
	elseif X.CanBeMidlaner(hero) and lane == LANE_MID then
		return "midlaner"
	elseif
		X.CanBeSafeLaneCarry(hero) and
		((GetTeam() == TEAM_RADIANT and lane == LANE_BOT) or (GetTeam() == TEAM_DIRE and lane == LANE_TOP))
	then
		return "carry"
	elseif
		X.CanBeOfflaner(hero) and
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

function X.CountValue(hero, role)
	local highest = 0
	local TeamMember = GetTeamPlayers(GetTeam())
	for i = 1, #TeamMember do
	end
	return highest
end

X["invisEnemyExist"] = false

local globalEnemyCheck = false
local lastCheck = -90

function X.UpdateInvisEnemyStatus(bot)
	if globalEnemyCheck == false then
		local players = GetTeamPlayers(GetOpposingTeam())
		for i = 1, #players do
			if Enum.invisHeroes[GetSelectedHeroName(players[i])] then
				X["invisEnemyExist"] = true
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
						X["invisEnemyExist"] = true
						break
					end
				end
			end
		end
		lastCheck = DotaTime()
	end
end

function X.IsTheLowestLevel(bot)
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

X["supportExist"] = nil
function X.UpdateSupportStatus(bot)
	if bot.theRole == "support" then
		X["supportExist"] = true
	end
	local TeamMember = GetTeamPlayers(GetTeam())
	for i = 1, #TeamMember do
		local ally = GetTeamMember(i)
		if ally == nil or ally:IsAlive() == false or ally.theRole == nil then
			X["supportExist"] = nil
		end
	end
	for i = 1, #TeamMember do
		local ally = GetTeamMember(i)
		if ally ~= nil and ally:IsHero() and ally.theRole == "support" then
			X["supportExist"] = true
		end
	end
	return false
end

X["lastbbtime"] = -90

function X.ShouldBuyBack()
	return DotaTime() > X["lastbbtime"] + 2.0
end

function X.GetHighestValueRoles(bot)
	local maxVal = -1
	local role = ""
	print("=========" .. bot:GetUnitName() .. "=========")
	for key, value in pairs(X.hero_roles[bot:GetUnitName()]) do
		print(tostring(key) .. " : " .. tostring(value))
		if value >= maxVal then
			maxVal = value
			role = key
		end
	end
	print("Highest value role => " .. role .. " : " .. tostring(maxVal))
end

return X
