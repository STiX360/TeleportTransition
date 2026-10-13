local core = require('openmw.core')
local types = require('openmw.types')
local world = require('openmw.world')
local util = require('openmw.util')
local supplied = false

local function stagePlayer(data)
    types.Player.setTeleportingEnabled(data.player, not data.blocked)
    if data.outOfRegion then
        data.player:teleport('Seyda Neen', util.vector3(-12257.532, -69657.063, 93.869), {onGround = true})
    else
        data.player:teleport(world.getExteriorCell(-101, 11),
            util.vector3(-820375.4375, 94423.578125, 775.2520751953125), {onGround = true})
    end
end

return {
    engineHandlers = {
        onPlayerAdded = function(player)
            if supplied then return end
            local id = 't_nor_mys_kynesintervention'
            local spell = assert(core.magic.spells.records[id], 'Kyne test: spell missing')
            types.Actor.spells(player):add(id)
            supplied = true
            local effects = {}
            for _, effect in ipairs(spell.effects) do effects[#effects + 1] = effect.id end
            assert(effects[1] == 't_intervention_kyne',
                'Kyne test: custom Intervention effect did not load; got ' .. tostring(effects[1]))
            print('[Kyne Test] Supplied ' .. spell.id .. '; name=' .. spell.name
                .. '; effects=' .. table.concat(effects, ',') .. '; API=' .. core.API_REVISION)
            stagePlayer({player = player})
        end,
        onSave = function() return {supplied = supplied} end,
        onLoad = function(data)
            supplied = data == nil or (type(data) == 'table' and data.supplied == true)
        end,
    },
    eventHandlers = {
        TeleportTransitionKyneStage = stagePlayer,
    },
}
