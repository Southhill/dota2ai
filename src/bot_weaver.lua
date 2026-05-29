local minionutils = dofile( GetScriptDirectory().."/base/NewMinionUtil" )

function MinionThink(  hMinionUnit ) 
	local name = hMinionUnit:GetUnitName()
	if string.match(name, "npc_dota_weaver_swarm") then
		return
	end
	if minionutils.IsValidUnit(hMinionUnit) then
		if hMinionUnit:IsIllusion() then
			minionutils.IllusionThink(hMinionUnit);
		elseif minionutils.CantBeControlled(hMinionUnit:GetUnitName()) then
			minionutils.CantBeControlledThink(hMinionUnit);
		else
			return;
		end
	end
end	