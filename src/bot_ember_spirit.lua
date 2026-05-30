local NewMinionUtility = require(GetScriptDirectory() .. "/base/NewMinionUtil")

function MinionThink(minion)
    if minion:IsIllusion() then
        NewMinionUtility.IllusionThink(minion)
    elseif minion:GetUnitName() == "npc_dota_ember_spirit_remnant" then
        NewMinionUtility.CantBeControlledThink(minion)
    end
end
