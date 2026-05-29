----------------------------------------------------------------------------
--	野怪营地工具 —管理野怪刷新、堆叠计时等
----------------------------------------------------------------------------
local X = {}

local team = GetTeam();
local CStackTime = {55, 55, 55, 55, 55, 54, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55}
local CStackLoc = {Vector(1854.000000, -4469.000000, 0.000000), Vector(1249.000000, -2416.000000, 0.000000),
                   Vector(3471.000000, -5841.000000, 0.000000), Vector(5153.000000, -3620.000000, 0.000000),
                   Vector(-1846.000000, -2996.000000, 0.000000), Vector(-4961.000000, 559.000000, 0.000000),
                   Vector(-3873.000000, -833.000000, 0.000000), Vector(-3146.000000, 702.000000, 0.000000),
                   Vector(1141.000000, -3111.000000, 0.000000), Vector(660.000000, 2300.000000, 0.000000),
                   Vector(3666.000000, 1836.000000, 0.000000), Vector(482.000000, 4723.000000, 0.000000),
                   Vector(3173.000000, -861.000000, 0.000000), Vector(-3443.000000, 6098.000000, 0.000000),
                   Vector(-4353.000000, 4842.000000, 0.000000), Vector(-1083.000000, 3385.000000, 0.000000),
                   Vector(-922.000000, 4299.000000, 0.000000), Vector(4136.000000, -1753.000000, 0.000000)}

-- test hero
local jungler = {'npc_dota_hero_alchemist', 'npc_dota_hero_bloodseeker' -- 'npc_dota_hero_legion_commander',
-- 'npc_dota_hero_life_stealer'
-- 'npc_dota_hero_skeleton_king',
-- 'npc_dota_hero_ursa'
}

function X.GetCampMoveToStack(id)
    return CStackLoc[id]
end

function X.GetCampStackTime(camp)
    if camp.cattr.speed == "fast" then
        return 55;
    elseif camp.cattr.speed == "slow" then
        return 54;
    else
        return 55;
    end
end

function X.IsEnemyCamp(camp)
    return camp.team ~= GetTeam();
end

function X.IsAncientCamp(camp)
    return camp.type == "ancient";
end

function X.IsSmallCamp(camp)
    return camp.type == "small";
end

function X.IsMediumCamp(camp)
    return camp.type == "medium";
end

function X.IsLargeCamp(camp)
    return camp.type == "large";
end

function X.RefreshCamp(bot)
    local camps = GetNeutralSpawners();
    local AllCamps = {};
    for k, camp in pairs(camps) do
        if bot:GetLevel() <= 6 then
            if not X.IsEnemyCamp(camp) and not X.IsLargeCamp(camp) and not X.IsAncientCamp(camp) then
                table.insert(AllCamps, {
                    idx = k,
                    cattr = camp
                });
            end
        elseif bot:GetLevel() <= 10 then
            if not X.IsEnemyCamp(camp) and not X.IsAncientCamp(camp) then
                table.insert(AllCamps, {
                    idx = k,
                    cattr = camp
                });
            end
        else
            table.insert(AllCamps, {
                idx = k,
                cattr = camp
            });
        end
    end
    local nCamps = #AllCamps;
    return AllCamps, nCamps;
end

function X.IsStrongJungler(bot)
    local name = bot:GetUnitName();
    for _, n in pairs(jungler) do
        if name == n then
            return true;
        end
    end
    return false;
end

function X.PrintCamps()
    print("========CAMPS==========")
    local camps = GetNeutralSpawners();
    for i = 1, #camps do
        print("==============")
        for k, v in pairs(camps[i]) do
            print(tostring(k) .. ":" .. tostring(v))
        end
    end
end

function X.PingCamp(nCamp, nPId, nTeam, bot)
    if bot:GetTeam() == nTeam and bot:GetPlayerID() == nPId then
        local camps = GetNeutralSpawners();
        for i = 1, #camps do
            if i == nCamp then
                local cLoc = camps[i].location;
                bot:ActionImmediate_Ping(cLoc.x, cLoc.y, true);
            end
        end
    end
end

function X.GetClosestNeutralSpwan(bot, AvailableCamp)
    local minDist = 10000;
    local pCamp = nil;
    for _, camp in pairs(AvailableCamp) do
        local dist = GetUnitToLocationDistance(bot, camp.cattr.location);
        if X.IsTheClosestOne(bot, dist, camp.cattr.location) and dist < minDist then
            minDist = dist;
            pCamp = camp;
        end
    end
    return pCamp
end

function X.IsTheClosestOne(bot, bDis, loc)
    local dis = bDis;
    local closest = bot;
    for k, v in pairs(GetTeamPlayers(GetTeam())) do
        local member = GetTeamMember(k);
        if member ~= nil and not member:IsIllusion() and member:IsAlive() and member:GetActiveMode() == BOT_MODE_FARM then
            local dist = GetUnitToLocationDistance(member, loc);
            if dist < dis then
                dis = dist;
                closest = member;
            end
        end
    end
    return closest:GetUnitName() == bot:GetUnitName();
end

function X.FindFarmedTarget(Creeps)
    local minHP = 10000;
    local target = nil;
    for _, creep in pairs(Creeps) do
        local hp = creep:GetHealth();
        -- if team == TEAM_DIRE then print(tostring(creep:CanBeSeen())) end
        if creep ~= nil and not creep:IsNull() and creep:IsAlive() and hp < minHP then
            minHP = hp;
            target = creep;
        end
    end
    return target
end

function X.IsSuitableToFarm(bot)
    local mode = bot:GetActiveMode();
    if mode == BOT_MODE_RUNE or mode == BOT_MODE_DEFEND_TOWER_TOP or mode == BOT_MODE_DEFEND_TOWER_MID or mode ==
        BOT_MODE_DEFEND_TOWER_BOT or mode == BOT_MODE_ATTACK then
        return false;
    end
    return true;
end

function X.UpdateAvailableCamp(bot, preferedCamp, AvailableCamp)
    if preferedCamp ~= nil then
        for i = 1, #AvailableCamp do
            if AvailableCamp[i].cattr.location == preferedCamp.cattr.location or
                GetUnitToLocationDistance(bot, AvailableCamp[i].cattr.location) < 300 then
                table.remove(AvailableCamp, i);
                -- print("Updating available camp : "..tostring(#AvailableCamp))
                preferedCamp = nil;
                return AvailableCamp, preferedCamp;
            end
        end
    end
end

return X
