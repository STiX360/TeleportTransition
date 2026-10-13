local core = require('openmw.core')
local types = require('openmw.types')
local util = require('openmw.util')
local supplied = false

return {
    engineHandlers = {
        onPlayerAdded = function(player)
            if supplied then return end
            for _, kind in ipairs({'mark', 'recall'}) do
                local id = 'multimark_' .. kind .. '_spell'
                local spell = assert(core.magic.spells.records[id], 'Daisy test: missing ' .. id)
                assert(spell.effects[1].id == 'multimark_' .. kind, 'Daisy test: wrong custom effect')
                types.Actor.spells(player):add(id)
                print('[Daisy Test] Supplied ' .. id .. '; effect=' .. spell.effects[1].id)
            end
            supplied = true
        end,
        onSave = function() return {supplied = supplied} end,
        onLoad = function(data)
            supplied = data == nil or (type(data) == 'table' and data.supplied == true)
        end,
    },
    eventHandlers = {
        TeleportTransitionDaisyMove = function(data)
            data.player:teleport(data.player.cell,
                data.position + util.vector3(256, 0, 0), {onGround = true})
        end,
    },
}
