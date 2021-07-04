local textM = require(GetScriptDirectory() .. "/const/text")

local dota2team = textM.dota2team
local sponsorship = textM.sponsorship
local U = {}

function U.GetDota2Team()
	local bot_names = {}
	local rand = RandomInt(1, #dota2team)
	local srand = RandomInt(1, #sponsorship)
	if GetTeam() == TEAM_RADIANT then
		while rand % 2 ~= 0 do
			rand = RandomInt(1, #dota2team)
		end
	else
		while rand % 2 ~= 1 do
			rand = RandomInt(1, #dota2team)
		end
	end

	local team = dota2team[rand]

	local sponsorshipName = team.sponsorship or sponsorship[srand]

	for _, player in pairs(team.players) do
		table.insert(bot_names, team.alias .. "." .. player .. "." .. sponsorshipName)
	end

	return bot_names
end

return U
