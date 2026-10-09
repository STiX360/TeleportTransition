local core = require('openmw.core')
local world = require('openmw.world')
local types = require('openmw.types')
local util = require('openmw.util')
local done, home = false, nil

return {
    engineHandlers = {
        onPlayerAdded = function(player)
            if done then return end
            for _, id in ipairs({'mark', 'recall', 'almsivi intervention', 'divine intervention'}) do
                assert(core.magic.spells.records[id], 'Teleport test: missing spell ' .. id)
                types.Actor.spells(player):add(id)
            end
            home = {cell = player.cell.name, x = player.position.x,
                y = player.position.y, z = player.position.z}
            done = true
            print('[Teleport Test] Vanilla spell kit supplied; home=' .. home.cell)
            player:sendEvent('TeleportTransitionFixtureReady', {})
        end,
        onSave = function() return {done = done, home = home} end,
        onLoad = function(data)
            -- Loading an unrelated save must never re-run character setup.
            done = data == nil or (type(data) == 'table' and data.done == true)
            home = type(data) == 'table' and data.home or nil
        end,
    },
    eventHandlers = {
        TeleportTransitionTestAction = function(data)
            local player = data.player
            if not player or player.type ~= types.Player then return end
            if data.command == 'home' and home then
                player:teleport(home.cell, util.vector3(home.x, home.y, home.z), {onGround = true})
            elseif data.command == 'blocked' then types.Player.setTeleportingEnabled(player, false)
            elseif data.command == 'unblocked' then types.Player.setTeleportingEnabled(player, true)
            end
        end,
    },
}
