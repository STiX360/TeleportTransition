local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local storage = require('openmw.storage')
local postprocessing = require('openmw.postprocessing')
local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local section = storage.playerSection('SettingsPlayerTeleportTransition')
local pulses, active, queued, ready = 0, false, nil, false

local function readyCharacter()
    types.NPC.stats.skills.mysticism(self).base = 100
    types.NPC.stats.attributes.willpower(self).base = 100
    types.NPC.stats.attributes.luck(self).base = 100
    types.Actor.stats.dynamic.magicka(self).base = 500
    types.Actor.stats.dynamic.magicka(self).current = 500
    types.Actor.stats.dynamic.fatigue(self).current = types.Actor.stats.dynamic.fatigue(self).base
end

local function shaderActive()
    for _, item in ipairs(postprocessing.getChain()) do
        if item.name == 'teleport_transition' then return true end
    end
    return false
end

local function status()
    local spell = types.Actor.getSelectedSpell(self)
    local message = string.format('TT test: cell=%s; position=%s; spell=%s; magicka=%.1f; enabled=%s; shader=%s; observedPulses=%d',
        self.cell.name, tostring(self.position), spell and spell.id or 'none',
        types.Actor.stats.dynamic.magicka(self).current, tostring(section:get('enabled')),
        tostring(shaderActive()), pulses)
    print(message)
    ui.showMessage(message)
    return message
end

local function run(command)
    if command == 'ready' then readyCharacter()
    elseif command == 'fail' then types.Actor.stats.dynamic.magicka(self).current = 0
    elseif command == 'low-skill' then
        types.NPC.stats.skills.mysticism(self).base = 5
        types.NPC.stats.attributes.willpower(self).base = 5
        types.NPC.stats.attributes.luck(self).base = 5
        types.Actor.stats.dynamic.magicka(self).current = 500
    elseif command == 'preview' then queued = 'preview'
    elseif command == 'home' or command == 'blocked' or command == 'unblocked' then
        queued = command
    elseif command == 'enabled' then section:set('enabled', true)
    elseif command == 'disabled' then section:set('enabled', false)
    elseif command == 'reduced' then section:set('reducedMotion', true)
    elseif command == 'normal' then section:set('reducedMotion', false)
    elseif command == 'pronounced' or command == 'baseline' then
        local pronounced = command == 'pronounced'
        section:set('strength', pronounced and 1.8 or 0.65)
        section:set('distortion', pronounced and 2.4 or 1)
        section:set('ripples', pronounced and 3 or 1)
        section:set('duration', pronounced and 0.65 or 0.8)
        section:set('colour', pronounced and 'Purple' or 'Neutral')
        section:set('tint', pronounced and 0.65 or 0)
        section:set('fringe', pronounced and 0.35 or 0)
        section:set('reducedMotion', false)
    elseif command == 'status' then return status()
    else error('Unknown Teleport Transition test command: ' .. tostring(command)) end
end

return {
    interfaceName = 'TeleportTransitionTest',
    interface = {run = run, status = status, isReady = function() return ready end,
        getPulseCount = function() return pulses end},
    engineHandlers = {
        onFrame = function(dt)
            if queued and dt > 0 and I.UI.getMode() == nil then
                local command = queued
                queued = nil
                if command == 'preview' then I.TeleportTransition.play()
                else core.sendGlobalEvent('TeleportTransitionTestAction', {player = self.object, command = command}) end
            end
            local current = shaderActive()
            if current and not active then
                pulses = pulses + 1
                print('[Teleport Test] Pulse started #' .. pulses .. '; cell=' .. self.cell.name)
            elseif active and not current then print('[Teleport Test] Pulse ended') end
            active = current
        end,
        onSave = function() return {pulses = pulses, ready = ready} end,
        onLoad = function(data)
            pulses = type(data) == 'table' and data.pulses or 0
            ready = type(data) == 'table' and data.ready == true
            active, queued = false, nil
        end,
    },
    eventHandlers = {
        TeleportTransitionFixtureReady = function()
            readyCharacter()
            types.Actor.setSelectedSpell(self, core.magic.spells.records['mark'])
            types.Actor.setStance(self, types.Actor.STANCE.Spell)
            ready = true
            ui.showMessage('Teleport test ready: Mark selected; four spells supplied, high casting stats, 500 magicka.')
        end,
    },
}
