local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local storage = require('openmw.storage')
local postprocessing = require('openmw.postprocessing')
local I = require('openmw.interfaces')
local time, stage, checkedReduced = 0, 0, false
local baseline, pulseCount

local function chainNames()
    local names = {}
    for _, item in ipairs(postprocessing.getChain()) do names[#names + 1] = item.name end
    return table.concat(names, ',')
end

local function active()
    for _, item in ipairs(postprocessing.getChain()) do
        if item.name == 'teleport_transition' then return true end
    end
    return false
end

local function update(dt)
    time = time + dt
    if time > 20 then error('Fixture or shader timed out') end
    if stage == 0 then
        if not I.TeleportTransitionTest.isReady() then return end
        for _, id in ipairs({'mark', 'recall', 'almsivi intervention', 'divine intervention'}) do
            assert(types.Actor.spells(self)[id], 'Missing supplied spell ' .. id)
        end
        assert(types.Actor.stats.dynamic.magicka(self).current == 500, 'Magicka setup failed')
        assert(storage.playerSection('SettingsPlayerTeleportTransition'):get('enabled') ~= false)
        local settings = storage.playerSection('SettingsPlayerTeleportTransition')
        assert(settings:get('strength') == 2.4 and settings:get('duration') == 1.8,
            'Screenshot defaults were not applied')
        assert(settings:get('colour') == 'Purple' and settings:get('tint') == 0.85,
            'Screenshot colour defaults were not applied')
        settings:set('automatic', false)
        baseline = chainNames()
        print('TT_SMOKE_BASELINE: ' .. baseline)
        I.TeleportTransitionTest.run('pronounced')
        assert(I.TeleportTransition.play(), 'Shader could not load')
        stage, time = 1, 0
    elseif stage == 1 and time >= 0.15 then
        assert(active(), 'Preview shader missing from chain')
        stage = 2
    elseif stage == 2 and time >= 1.2 then
        assert(not active(), 'Preview did not clean up')
        assert(chainNames() == baseline, 'Existing chain changed after pronounced preview')
        local settings = storage.playerSection('SettingsPlayerTeleportTransition')
        settings:set('reducedMotion', true)
        assert(I.TeleportTransition.play(), 'Reduced-motion preview failed')
        checkedReduced, stage, time = true, 3, 0
    elseif stage == 3 and time >= 0.15 then
        assert(active(), 'Reduced-motion shader missing')
        stage = 4
    elseif stage == 4 and time >= 1.2 then
        assert(checkedReduced and not active(), 'Reduced-motion cleanup failed')
        assert(chainNames() == baseline, 'Existing chain changed after reduced preview')
        pulseCount = I.TeleportTransitionTest.getPulseCount()
        core.sendGlobalEvent('TeleportTransitionTestAction', {player = self.object, command = 'home'})
        stage = 5
        time = 0
    elseif stage == 5 and time >= 0.6 then
        assert(not active() and I.TeleportTransitionTest.getPulseCount() == pulseCount,
            'Scripted home travel incorrectly triggered a pulse')
        assert(chainNames() == baseline, 'Existing chain changed after scripted travel')
        local settings = storage.playerSection('SettingsPlayerTeleportTransition')
        settings:set('automatic', true)
        settings:set('reducedMotion', false)
        types.Actor.setSelectedSpell(self, core.magic.spells.records['recall'])
        types.Actor.setStance(self, types.Actor.STANCE.Spell)
        stage, time = 6, 0
    elseif stage == 6 and time >= 0.1 then
        I.SkillProgression.skillUsed('mysticism', {
            skillGain = 3, useType = I.SkillProgression.SKILL_USE_TYPES.Spellcast_Success,
        })
        -- Reproduce Multi Mark's success notification followed by a global teleport.
        core.sendGlobalEvent('TeleportTransitionTestAction', {player = self.object, command = 'home'})
        stage, time = 7, 0
    elseif stage == 7 and time >= 0.15 then
        assert(active(), 'Scripted Recall arrival did not activate the shader')
        assert(I.TeleportTransitionTest.getPulseCount() == pulseCount + 1,
            'Scripted Recall arrival must produce exactly one pulse')
        stage = 8
    elseif stage == 8 and time >= 1.2 then
        assert(not active() and chainNames() == baseline, 'Scripted Recall did not clean up')
        print('TT_SMOKE_PASS: defaults, previews, chain preservation, scripted Recall delayed-action regression')
        stage = 9
        core.quit()
    end
end

return {engineHandlers = {onFrame = function(dt)
    if stage == 9 then return end
    local ok, message = pcall(update, dt)
    if not ok then
        print('TT_SMOKE_FAIL: ' .. tostring(message))
        stage = 9
        core.quit()
    end
end}}
