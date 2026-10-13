local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local stage, started, deadline, origin, pulses = 0, nil, nil, nil, nil

local function update()
    local now = core.getRealTime()
    started = started or now
    assert(now - started < 20, 'Daisy smoke timed out')
    if stage == 0 then
        if not I.TeleportTransitionTest.isReady() then return end
        assert(I.LMM and I.LMM.getMarkDataLength() == 0, 'Daisy test must start without marks')
        assert(types.Actor.spells(self)['multimark_recall_spell'], 'Greater Recall not supplied')
        origin = self.position
        pulses = I.TeleportTransitionTest.getPulseCount()
        I.LMM.saveMarkLoc()
        core.sendGlobalEvent('TeleportTransitionDaisyMove', {player = self.object, position = origin})
        stage, deadline = 1, now + 0.3
    elseif stage == 1 and now >= deadline then
        assert((self.position - origin):length() > 100, 'Second mark staging move failed')
        I.LMM.saveMarkLoc()
        assert(I.LMM.getMarkDataLength() == 2, 'Two Daisy marks were not saved')
        types.Actor.setSelectedSpell(self, core.magic.spells.records['multimark_recall_spell'])
        types.Actor.setStance(self, types.Actor.STANCE.Spell)
        stage, deadline = 2, now + 0.1
    elseif stage == 2 and now >= deadline then
        assert(I.TeleportTransitionTest.getPulseCount() == pulses, 'Mark or staging move caused a pulse')
        -- Native casting is manual acceptance; this test supplies its success notification.
        I.SkillProgression.skillUsed('mysticism', {
            skillGain = 3, useType = I.SkillProgression.SKILL_USE_TYPES.Spellcast_Success,
        })
        I.LMM.openMarkMenu()
        stage, deadline = 3, now + 1
    elseif stage == 3 and now >= deadline then
        assert(I.UI.getMode() ~= nil, 'Daisy destination menu did not open')
        assert(I.TeleportTransitionTest.getPulseCount() == pulses, 'Menu caused an early pulse')
        I.LMM.doRecall(1)
        stage, deadline = 4, now + 0.4
    elseif stage == 4 and now >= deadline then
        assert((self.position - origin):length() < 100, 'Daisy destination teleport failed')
        assert(I.TeleportTransitionTest.getPulseCount() == pulses + 1,
            'Daisy destination arrival did not produce exactly one pulse')
        stage, deadline = 5, now + 2
    elseif stage == 5 and now >= deadline then
        assert(I.TeleportTransitionTest.getPulseCount() == pulses + 1, 'Duplicate Daisy pulse')
        print('TT_SMOKE_PASS: real Daisy mark/menu/destination flow with synthetic cast success')
        stage = 6
        core.quit()
    end
end

return {engineHandlers = {onFrame = function()
    if stage == 6 then return end
    local ok, message = pcall(update)
    if not ok then
        print('TT_SMOKE_FAIL: ' .. tostring(message))
        stage = 6
        core.quit()
    end
end}}
