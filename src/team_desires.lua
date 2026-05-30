local utility = require(GetScriptDirectory() .. "/base/Utility")
local AbilityExtensions = require(GetScriptDirectory() .. "/base/AbilityAbstraction")
local Timer = require(GetScriptDirectory() .. "/util/timer")
local ChatSystem = require(GetScriptDirectory() .. "/base/ChatSystem")

local function NotNilOrDead(unit)
	if unit == nil or unit:IsNull() then
		return false;
	end
	if unit:IsAlive() then
		return true;
	end
	return false;
end

local function IsMega()
	local enemyTeam = GetOpposingTeam()
	for i = 1, 6 do
		local barrack = GetBarracks(enemyTeam, i)
		if NotNilOrDead(barrack) then
			return false
		end
	end
	return true
end

-- 计算推线的基础需求值
function GetCommonPushLaneDesires()
	local common = 0.25

	local mega = IsMega()
	if mega then
		common = 0.4
	end

	local time = DotaTime()
	if (time > 5 * 60)
	then
		common = common + (time / 60 - 12) * 0.01
	end

	local itemtable = GetItemCount()

	if itemtable["item_ring_of_basilius"] ~= nil then
		common = common + 45 / time
	end

	if itemtable["item_buckler"] ~= nil then
		common = common + 45 / time
	end

	if itemtable["item_headdress"] ~= nil then
		common = common + 45 / time
	end

	if itemtable["item_drums_of_endurance"] ~= nil then
		common = common + 60 / time
	end

	if itemtable["item_pipe"] ~= nil then
		common = common + 90 / time
	end

	if itemtable["item_vladmir"] ~= nil then
		common = common + 90 / time
	end

	if itemtable["item_crimson_guard"] ~= nil then
		common = common + 90 / time
	end

	if itemtable["item_mekansm"] ~= nil then
		common = common + 120 / time
	end

	if itemtable["item_medallion_of_courage"] ~= nil then
		common = common + itemtable["item_medallion_of_courage"].count * 60 / time
	end

	if itemtable["item_glimmer_cape"] ~= nil then
		common = common + itemtable["item_glimmer_cape"].count * 60 / time
	end

	if itemtable["item_force_staff"] ~= nil then
		common = common + itemtable["item_force_staff"].count * 60 / time
	end

	if itemtable["item_solar_crest"] ~= nil then
		common = common + itemtable["item_solar_crest"].count * 90 / time
	end

	if itemtable["item_arcane_boots"] ~= nil then
		common = common + itemtable["item_arcane_boots"].count * 60 / time
	end

	if itemtable["item_guardian_greaves"] ~= nil then
		common = common + 300 / time
	end

	if itemtable["item_assault"] ~= nil then
		common = common + 180 / time
	end

	if itemtable["item_shivas_guard"] ~= nil then
		common = common + 180 / time
	end

	if itemtable["item_aegis"] ~= nil then
		local remain = 300 - (time - GetRoshanKillTime())
		common = common + 0.001 * remain
	end

	if itemtable["item_necronomicon"] ~= nil then
		common = common + 150 * itemtable["item_necronomicon"].count / time
	end

	if itemtable["item_necronomicon2"] ~= nil then
		common = common + 180 * itemtable["item_necronomicon2"].count / time
	end

	if itemtable["item_necronomicon3"] ~= nil then
		common = common + 210 * itemtable["item_necronomicon3"].count / time
	end

	return common
end

function GetItemCount()
	local itemtable = {}
	local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
	for _, ally in pairs(allies) do
		for i = 0, 5, 1 do
			local item = ally:GetItemInSlot(i);
			if (item ~= nil) then
				local itemname = item:GetName()
				if (itemtable[itemname] == nil)
				then
					itemtable[itemname] = {}
					itemtable[itemname].count = 1
				else
					itemtable[itemname].count = itemtable[itemname].count + 1
				end
			end
		end
	end
	return itemtable
end

local function GetRealHero(Candidates)
	if Candidates == nil or #Candidates == 0 then
		return nil;
	end

	local q = false;
	for i, unit in pairs(Candidates) do
		if unit.isIllusion == nil or (not unit.isIllusion) then
			q = true;
		end
	end

	if not q then
		for i, unit in pairs(Candidates) do
			if unit.isRealHero ~= nil and unit.isRealHero then
				return i, unit;
			end
		end
		return nil;
	end

	for i, unit in pairs(Candidates) do
		if unit:HasModifier("modifier_bloodseeker_thirst_vision") then
			return i, unit;
		end
	end

	for i, unit in pairs(Candidates) do
		local int = unit:GetAttributeValue(2);
		local baseRegen = 0.01;
		if unit:GetUnitName() == "npc_dota_hero_techies" then
			baseRegen = 0.02;
		end

		if math.abs(unit:GetManaRegen() - (baseRegen + 0.04 * int)) > 0.001 then
			return i, unit;
		end
	end

	local hpRegen = Candidates[1]:GetHealthRegen();
	local suspectind = 1;
	local suspect = Candidates[1];

	for i, unit in pairs(Candidates) do
		if hpRegen < unit:GetHealthRegen() then
			suspect = unit;
			hpRegen = unit:GetHealthRegen();
			suspectind = i;
		end
	end

	for _, unit in pairs(Candidates) do
		if hpRegen > unit:GetHealthRegen() then
			return suspectind, suspect;
		end
	end

	for i, unit in pairs(Candidates) do
		if unit:IsUsingAbility() or unit:IsChanneling() then
			return i, unit;
		end
	end

	if #Candidates == 1 and (Candidates[1].isIllusion == nil or (not Candidates[1].isIllusion)) then
		return 1, Candidates[1];
	end

	return nil;
end

local function IsRealHero(unit)
	if unit and unit.isIllusion then
		return false;
	elseif unit:IsMinion() or not unit:IsHero() then
		return false;
	end
	return true;
end

-- 每 0.1 秒重建一次敌方真实英雄列表（避免每帧重复调用 GetUnitList）
local GetEnemyTeam = Timer.EveryManySeconds(0.1, function()
	local result = {}
	local seen = {}

	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if not NotNilOrDead(unit) or seen[unit:GetUnitName()] then
			-- continue
		else
			seen[unit:GetUnitName()] = true
			local candidates = {}
			for _, unit2 in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
				if NotNilOrDead(unit2) and unit2:GetUnitName() == unit:GetUnitName() then
					table.insert(candidates, unit2)
				end
			end

			local _, hero = GetRealHero(candidates)
			if hero ~= nil and (hero.isIllusion == nil or not hero.isIllusion) then
				for _, can in pairs(candidates) do
					can.isIllusion = true
					can.isRealHero = false
				end
				hero.isIllusion = false
				hero.isRealHero = true
				table.insert(result, hero)
			end
		end
	end

	return result
end)


local function GetWealth(hero)
	if not hero or not IsRealHero(hero) then
		return 0
	end
	local heroTeam = hero:GetTeam()
	local team = GetTeam()
	local isEnemy = false

	if heroTeam ~= team then
		isEnemy = true
	end

	local wealth = 0
	for i = 0, 8, 1 do
		local item = hero:GetItemInSlot(i);
		if item then
			-- print(item:GetName())
			local prize = GetItemCost(item:GetName())
			if item:GetName() == "item_aegis" then
				prize = 5000
			end
			wealth = wealth + prize
		end
	end

	return wealth
end

local function GetLaneRacks(lane, bMelee)
	local i = 0;
	if bMelee == true then
		i = i + 1;
	end
	if lane == LANE_MID then
		i = i + 2;
	end
	if lane == LANE_BOT then
		i = i + 4;
	end
	return GetBarracks(GetOpposingTeam(), i);
end

local function GetLaneTower(team, lane, i)
	if i > 3 and i < 6 then
		return GetTower(team, 5 + i);
	end
	local j = i - 1;
	if lane == LANE_MID then
		j = j + 3;
	elseif lane == LANE_BOT then
		j = j + 6;
	end
	if (j < 9 and j > -1 and (lane == LANE_BOT or lane == LANE_MID or lane == LANE_TOP)) then
		return GetTower(team, j);
	end

	return nil;
end

local function HasItem(hero, item_name)
	for i = 0, 5, 1 do
		local item = hero:GetItemInSlot(i);
		if (item ~= nil) then
			if (item:GetName() == item_name) then
				return true
			end
		end
	end
	return false
end

-- 每帧被调用。返回多个0到1之间的浮点值，分别表示推进上，中，下路的需求值
function UpdatePushLaneDesires()
	local mega = IsMega()
	local time = DotaTime()
	local common = GetCommonPushLaneDesires()

	if (time <= 6 * 60) then
		return { 0, 0, 0 }
	end

	local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)

	for _, ally in pairs(allies) do
		if not ally:IsAlive() and not ally:IsIllusion() then
			common = common - math.max(ally:GetRespawnTime() / 600, 0.75)
		end
	end

	--enemy team is always alive

	for _, enemyID in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if not IsHeroAlive(enemyID) then
			common = common + 0.1
		end
	end

	local lanes = { common, common, common }
	local enemyTeam = GetOpposingTeam()
	local brokenLane = 0
	for lane_number, lane in pairs(lanes) do
		-- local GetLaneFrontAmount(GetTeam(), lane, false)
		-- { amount, distance } GetAmountAlongLane( nLane, vLocation )


		for _, ally in pairs(allies) do
			local dist = 1
			if NotNilOrDead(ally) then
				local location = ally:GetLocation()
				local dist = GetAmountAlongLane(lane_number, location).distance
				if dist < 1200 then
					lane = lane + 0.2 * GetWealth(ally) / ((time + 1) * 50)
				end
			end
		end

		local enemies = GetEnemyTeam()
		for _, enemy in pairs(enemies) do
			local dist = 1
			if NotNilOrDead(enemy) then
				local location = enemy:GetExtrapolatedLocation(1)
				local dist = GetAmountAlongLane(lane_number, location).distance
				local tp = HasItem(enemy, "item_tpscroll")
				local travel = HasItem(enemy, "item_travel_boots")
				local plus = 0.2 * GetWealth(enemy) / ((time + 1) * 50)
				if dist < 1000 then
					lane = lane - 0.5 * plus
				elseif dist > 4000 then
					lane = lane + plus
					if not tp and not travel then
						lane = lane + plus
					end
				end
			end
		end

		for i = 1, 3 do
			local tower = GetLaneTower(enemyTeam, lane_number, i)
			if not NotNilOrDead(tower) then
				lane = lane - 0.07
			else
				lane = lane + 0.07 * (1 - tower:GetHealth() / tower:GetMaxHealth())
			end
		end
		local highTower = GetLaneTower(enemyTeam, lane_number, 3)
		local meleeBarrack = GetLaneRacks(lane_number, true)
		local rangeBarrack = GetLaneRacks(lane_number, false)
		local melee = NotNilOrDead(meleeBarrack)
		local range = NotNilOrDead(rangeBarrack)

		if not NotNilOrDead(highTower) then
			lane = common + 0.3
		end

		if not melee and not range then
			lane = 0
			brokenLane = brokenLane + 1
		elseif melee and not range then
			lane = 0.9 * lane + 0.2 * (1 - meleeBarrack:GetHealth() / meleeBarrack:GetMaxHealth())
		elseif range and not melee then
			lane = 0.5 * lane + 0.1 * (1 - rangeBarrack:GetHealth() / rangeBarrack:GetMaxHealth())
		else
			lane = lane + 0.2 * (1 - meleeBarrack:GetHealth() / meleeBarrack:GetMaxHealth()) +
				0.1 * (1 - rangeBarrack:GetHealth() / rangeBarrack:GetMaxHealth())
		end

		if not mega then
			lanes[lane_number] = lane
		end
	end

	local has1 = false
	for lane_number, lane in pairs(lanes) do
		if lane > 0 then
			lanes[lane_number] = lane + brokenLane * 0.2
		end
		if lane >= 1 then
			has1 = true
		elseif lane < 0 then
			lanes[lane_number] = 0
		end
	end

	if has1 then
		local maxDesire = math.max(lanes[1], lanes[2], lanes[3])
		for lane_number, lane in pairs(lanes) do
			lanes[lane_number] = lane / maxDesire
		end
	end

	local Maxdesire = 0
	for i, lane in pairs(lanes)
	do
		if (lane > Maxdesire)
		then
			Maxdesire = lane
		end
	end
	if (Maxdesire > 0.8)
	then
		lanes[1] = lanes[1] / Maxdesire * 0.8
		lanes[2] = lanes[2] / Maxdesire * 0.8
		lanes[3] = lanes[3] / Maxdesire * 0.8
	end

	return lanes;
end

----------------------------------------------------------------------------------------------------
--  团队级操作（引擎每帧调用一次，代替逐 bot 执行）
----------------------------------------------------------------------------------------------------

local towerId = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3, TOWER_MID_1, TOWER_MID_2, TOWER_MID_3, TOWER_BOT_1, TOWER_BOT_2,
	TOWER_BOT_3, TOWER_BASE_1, TOWER_BASE_2 }
local towerHealthHistory = {}

-- 每 0.5 秒记录一次防御塔血量变化
local RefreshBuildingHealth = Timer.SingleForTeam(
	Timer.EveryManySeconds(0.5, function()
		for _, id in ipairs(towerId) do
			local tower = GetTower(GetTeam(), id)
			if tower ~= nil and tower:GetHealth() > 0 then
				local towerKey = tostring(GetTeam()) .. "_" .. tostring(id)
				if towerHealthHistory[towerKey] == nil then
					towerHealthHistory[towerKey] = {}
				end
				local history = towerHealthHistory[towerKey]
				history.health0SecondsAgo = tower:GetHealth()
				if tower:IsAlive() then
					for _, i in ipairs({ 0.5, 1, 1.5, 2 }) do
						history["health" .. tostring(i) .. "SecondsAgo"] =
							history["health" .. tostring(i - 0.5) .. "SecondsAgo"]
					end
				end
			end
		end
	end))

-- 考虑是否使用防御符文
local function ConsiderGlyph()
	RefreshBuildingHealth()
	if GetGlyphCooldown() > 0 then
		return
	end

	for _, BuildingID in ipairs(towerId) do
		local tower = GetTower(GetTeam(), BuildingID)
		if tower ~= nil and tower:GetHealth() > 0 then
			local nearbyEnemies = utility.GetEnemiesNearLocation(tower:GetLocation(), 700)
			local towerKey = tostring(GetTeam()) .. "_" .. tostring(BuildingID)
			local history = towerHealthHistory[towerKey]
			if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and history ~= nil and
				history["health1SecondsAgo"] and tower:GetHealth() - history["health1SecondsAgo"] >= 7.5 * DotaTime() /
				60 and DotaTime() >= 12 * 60 then
				GetBot():ActionImmediate_Glyph()
			end
			if tower:GetHealth() >= 200 and tower:GetHealth() <= 1000 and #nearbyEnemies >= 2 then
				GetBot():ActionImmediate_Glyph()
				break
			end
		end
	end
end

-- 判断遗迹血量是否低于指定值
local function AncientBelow(team, health)
	local ancient = GetAncient(team)
	if ancient == nil or not ancient:CanBeSeen() then
		return false
	end
	return not ancient:IsInvulnerable() and ancient:GetHealth() < health
end

-- 遗迹告警节流：每 10 秒检查一次（避免每帧刷屏）
local WarnAncientLow = Timer.EveryManySeconds(10, function()
	local bot = GetBot()
	if AncientBelow(TEAM_RADIANT, 1500) or AncientBelow(TEAM_DIRE, 1500) then
		ChatSystem.AnnounceAncientWarning(bot, 1500)
	elseif AncientBelow(TEAM_RADIANT, 1200) or AncientBelow(TEAM_DIRE, 1200) then
		ChatSystem.AnnounceAncientWarning(bot, 1200)
	end
end)

-- 遗迹相关逻辑
--   1. ConsiderGlyph() — 防御符文决策
--      监控全队所有防御塔血量，在塔残血或遭集火时自动开符文
--   2. WarnAncientLow() — 遗迹血量告警
--      兵营被破后每秒检查一次遗迹血量，低于阈值时公屏提醒
local function ancientThink()
	ConsiderGlyph()
	WarnAncientLow()
end

-- 团队 Think：引擎每帧调用一次（整个队伍共享）
--
-- 这是 Dota 2 Bot API 为 team_desires.lua 提供的特殊入口函数。
-- 与每个英雄各自的 Think() 不同，TeamThink() 在整个队伍中
-- 每帧只执行一次，适合放置团队级别的逻辑。
--
-- 职责分工：
--   1. Timer.TickFromDota() — 驱动全局帧计数器、节流器、协程
--      所有 Timer.EveryManySeconds / SingleForTeam 等节流函数
--      依赖它推进时间，必须每帧调用一次
--
-- 注意：不要在 TeamThink 中放置每个 bot 各自的操作（如技能施放、
-- 物品使用、走位等），这些应该放在各个英雄脚本的 Think()执行。
function TeamThink()
	if GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return
	end

	Timer.TickFromDota()

	ancientThink()
end
