local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local storage = require('openmw.storage')
local postprocessing = require('openmw.postprocessing')
local stage, started, deadline, origin, pulses = 0, nil, nil, nil, nil
local cases = {
    {name = 'override', travel = true, pulse = true, colour = 'Blue'},
    {name = 'default-colour', travel = true, pulse = true, colour = 'Default'},
    {name = 'disabled', travel = true, enabled = false},
    {name = 'automatic-off', travel = true, automatic = false},
    {name = 'blocked', blocked = true},
    {name = 'no-magicka', noMagicka = true},
    {name = 'failed-roll', failedRoll = true},
    {name = 'out-of-region', outOfRegion = true},
}
local caseIndex = 1

local function shaderActive()
    for _, shader in ipairs(postprocessing.getChain()) do
        if shader.name == 'teleport_transition' then return true end
    end
    return false
end

local function update()
    local now = core.getRealTime()
    started = started or now
    assert(now - started < 50, 'Kyne casting test timed out')
    local case = cases[caseIndex]
    self.controls.use = self.ATTACK_TYPE.NoAttack
    if stage == 0 then
        if not I.TeleportTransitionTest.isReady() then return end
        assert(core.magic.spells.records['t_nor_mys_kynesintervention'].effects[1].id == 't_intervention_kyne')
        local settings = storage.playerSection('SettingsPlayerTeleportTransition')
        assert(settings:get('kyneColour') ~= nil, 'Conditional Kyne setting did not register')
        settings:set('kyneColour', case.colour or 'Default')
        settings:set('enabled', case.enabled ~= false)
        settings:set('automatic', case.automatic ~= false)
        I.TeleportTransitionTest.run('ready')
        if case.failedRoll then
            types.NPC.stats.skills.mysticism(self).base = 0
            types.NPC.stats.attributes.willpower(self).base = 0
            types.NPC.stats.attributes.luck(self).base = 0
        end
        types.Actor.stats.dynamic.magicka(self).current = case.noMagicka and 0 or 500
        I.Controls.overrideCombatControls(true)
        types.Actor.setSelectedSpell(self, core.magic.spells.records['t_nor_mys_kynesintervention'])
        types.Actor.setStance(self, types.Actor.STANCE.Spell)
        pulses = I.TeleportTransitionTest.getPulseCount()
        core.sendGlobalEvent('TeleportTransitionKyneStage', {
            player = self.object, blocked = case.blocked, outOfRegion = case.outOfRegion,
        })
        stage, deadline = 1, now + 0.8
    elseif stage == 1 and now >= deadline then
        types.Actor.setStance(self, types.Actor.STANCE.Spell)
        stage, deadline = 4, now + 0.3
    elseif stage == 4 and now >= deadline then
        print('[Kyne Test] Native cast case=' .. case.name .. '; position=' .. tostring(self.position))
        assert(not types.NPC.isSwimming(self), 'Kyne test staging position is underwater')
        assert(types.Actor.getStance(self) == types.Actor.STANCE.Spell, 'Spell stance was not restored')
        origin = self.position
        self.controls.use = self.ATTACK_TYPE.Any
        stage, deadline = 2, now + 4
    elseif stage == 2 and now >= deadline then
        print('[Kyne Test] After cast: position=' .. tostring(self.position)
            .. '; pulses=' .. I.TeleportTransitionTest.getPulseCount()
            .. '; magicka=' .. types.Actor.stats.dynamic.magicka(self).current)
        local travelled = (self.position - origin):length() > 100
        assert(travelled == (case.travel == true), 'Wrong travel result for ' .. case.name)
        local expectedPulses = pulses + (case.pulse and 1 or 0)
        assert(I.TeleportTransitionTest.getPulseCount() == expectedPulses, 'Wrong pulse count for ' .. case.name)
        assert(not shaderActive(), 'Shader did not clean up for ' .. case.name)
        if case.failedRoll then
            assert(types.Actor.stats.dynamic.magicka(self).current < 500, 'Failed-roll case did not attempt a cast')
        end
        print('[Kyne Test] PASS ' .. case.name)
        caseIndex = caseIndex + 1
        if cases[caseIndex] then
            stage = 0
        else
            print('TT_SMOKE_PASS: eight native Kyne casting cases, arrival, controls, no false pulses, cleanup')
            stage = 3
            I.Controls.overrideCombatControls(false)
            core.quit()
        end
    end
end

return {engineHandlers = {onFrame = function()
    if stage == 3 then return end
    local ok, message = pcall(update)
    if not ok then
        print('TT_SMOKE_FAIL: ' .. tostring(message))
        stage = 3
        I.Controls.overrideCombatControls(false)
        core.quit()
    end
end}}
