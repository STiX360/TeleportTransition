local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local animation = require('openmw.animation')
local postprocessing = require('openmw.postprocessing')
local storage = require('openmw.storage')
local input = require('openmw.input')
local ui = require('openmw.ui')
local I = require('openmw.interfaces')

local group = 'SettingsPlayerTeleportTransition'
local defaults = {enabled = true, automatic = true, strength = 2.4, duration = 1.8, reducedMotion = false,
    distortion = 3, ripples = 3, colour = 'Purple', recallColour = 'Default', almsiviColour = 'Default',
    divineColour = 'Default', tint = 0.85, fringe = 0.6}
local kyneInstalled = core.magic.spells and core.magic.spells.records['t_nor_mys_kynesintervention'] ~= nil
if kyneInstalled then defaults.kyneColour = 'Default' end
local colours = {Neutral = {1, 1, 1}, Purple = {0.68, 0.24, 1},
    Blue = {0.2, 0.65, 1}, Green = {0.25, 1, 0.55}, Gold = {1, 0.7, 0.2}}
local colourItems = {'Default', 'Neutral', 'Purple', 'Blue', 'Green', 'Gold'}
I.Settings.registerPage {key = 'TeleportTransition', l10n = 'TeleportTransition', name = 'PageName'}
local settingsGroup = {
    key = group, page = 'TeleportTransition', l10n = 'TeleportTransition', name = 'Treatment',
    permanentStorage = false,
    settings = {
        {key = 'enabled', renderer = 'checkbox', name = 'Enabled', description = 'EnabledDescription', default = defaults.enabled},
        {key = 'automatic', renderer = 'checkbox', name = 'Automatic', description = 'AutomaticDescription', default = defaults.automatic},
        {key = 'strength', renderer = 'number', name = 'Strength', description = 'StrengthRange', default = defaults.strength, argument = {min = 0, max = 3}},
        {key = 'duration', renderer = 'number', name = 'Duration', description = 'DurationRange', default = defaults.duration, argument = {min = 0.2, max = 2}},
        {key = 'distortion', renderer = 'number', name = 'Distortion', description = 'DistortionRange', default = defaults.distortion, argument = {min = 0, max = 4}},
        {key = 'ripples', renderer = 'number', name = 'Ripples', description = 'RipplesRange', default = defaults.ripples, argument = {min = 1, max = 5}},
        {key = 'colour', renderer = 'select', name = 'Colour', default = defaults.colour,
            argument = {l10n = 'TeleportTransition', items = {'Neutral', 'Purple', 'Blue', 'Green', 'Gold'}}},
        {key = 'recallColour', renderer = 'select', name = 'RecallColour', default = defaults.recallColour,
            argument = {l10n = 'TeleportTransition', items = colourItems}},
        {key = 'almsiviColour', renderer = 'select', name = 'AlmsiviColour', default = defaults.almsiviColour,
            argument = {l10n = 'TeleportTransition', items = colourItems}},
        {key = 'divineColour', renderer = 'select', name = 'DivineColour', default = defaults.divineColour,
            argument = {l10n = 'TeleportTransition', items = colourItems}},
        {key = 'tint', renderer = 'number', name = 'Tint', description = 'TintRange', default = defaults.tint, argument = {min = 0, max = 1}},
        {key = 'fringe', renderer = 'number', name = 'Fringe', description = 'FringeRange', default = defaults.fringe, argument = {min = 0, max = 1}},
        {key = 'reducedMotion', renderer = 'checkbox', name = 'ReducedMotion', default = false},
    },
}
if kyneInstalled then
    table.insert(settingsGroup.settings, 11, {
        key = 'kyneColour', renderer = 'select', name = 'KyneColour', default = defaults.kyneColour,
        argument = {l10n = 'TeleportTransition', items = colourItems},
    })
end
I.Settings.registerGroup(settingsGroup)
local settings = storage.playerSection(group)
local shader, failed, elapsed, duration, castTime, teleportTime, castCategory, teleportCategory, activeCategory, pendingPlay
local restored, pending, held = nil, true, false

local function number(key, low, high)
    local value = settings:get(key)
    if type(value) ~= 'number' or value ~= value then value = defaults[key] end
    return math.max(low, math.min(value, high))
end

local function initialise()
    if not pending then return end
    pending = false
    for key, default in pairs(defaults) do
        local value = restored and restored[key]
        if value == nil then value = default end
        settings:set(key, value)
    end
    restored = nil
end

local function stop()
    if shader then shader:disable() end
    elapsed = nil
    pendingPlay = nil
end

local function colourSetting(category)
    local key = ({recall = 'recallColour', almsivi = 'almsiviColour',
        divine = 'divineColour', kyne = kyneInstalled and 'kyneColour' or nil})[category]
    local value = key and settings:get(key) or 'Default'
    if value == 'Default' or not colours[value] then value = settings:get('colour') end
    return colours[value] or colours.Neutral
end

local function applySettings(category)
    local size = ui.screenSize()
    local colour = colourSetting(category)
    shader:setFloat('transitionAspect', size.x / math.max(size.y, 1))
    shader:setFloat('transitionStrength', number('strength', 0, 3))
    shader:setFloat('transitionDistortion', number('distortion', 0, 4))
    shader:setFloat('transitionRipples', math.floor(number('ripples', 1, 5) + 0.5))
    shader:setFloat('transitionTint', number('tint', 0, 1))
    shader:setFloat('transitionFringe', number('fringe', 0, 1))
    shader:setFloat('transitionRed', colour[1])
    shader:setFloat('transitionGreen', colour[2])
    shader:setFloat('transitionBlue', colour[3])
    shader:setBool('transitionReducedMotion', settings:get('reducedMotion') == true)
end

local function play(options)
    initialise()
    if settings:get('enabled') == false or failed then return false end
    if not shader then
        local ok, result = pcall(postprocessing.load, 'teleport_transition')
        if not ok or not result then
            failed = true
            print('[Teleport Transition] Shader load failed: ' .. tostring(result))
            ui.showMessage('Teleport Transition could not load. Check openmw.log.')
            return false
        end
        shader = result
    end
    if type(options) == 'table' then
        activeCategory = options.category
    elseif type(options) == 'string' then
        activeCategory = options
    else
        activeCategory = nil
    end
    elapsed, duration = 0, number('duration', 0.2, 2)
    applySettings(activeCategory)
    shader:setFloat('transitionProgress', 0)
    shader:enable()
    return true
end

local function spellText(spell)
    return string.lower(tostring((spell and (spell.id or spell.name)) or '') .. ' '
        .. tostring((spell and spell.name) or ''))
end

local function classifySpell(spell)
    if not spell or spell.type ~= core.magic.SPELL_TYPE.Spell then return nil end
    if types.Actor.getStance(self) ~= types.Actor.STANCE.Spell then return false end
    local text = spellText(spell)
    -- Tamriel Data's record has a Divine fallback before its custom effect loads.
    if text:find('kyne', 1, true) and text:find('intervention', 1, true) then return 'kyne' end
    for _, effect in ipairs(spell.effects or {}) do
        if string.lower(tostring(effect.id)) == 'multimark_recall' then return 'recall' end
        if string.lower(tostring(effect.id)) == 't_intervention_kyne' then return 'kyne' end
        if effect.id == core.magic.EFFECT_TYPE.Recall then return 'recall' end
        if effect.id == core.magic.EFFECT_TYPE.AlmsiviIntervention then return 'almsivi' end
        if effect.id == core.magic.EFFECT_TYPE.DivineIntervention then return 'divine' end
    end
    if text:find('mark', 1, true) and not text:find('recall', 1, true) then return nil end
    if text:find('almsivi', 1, true) and text:find('intervention', 1, true) then return 'almsivi' end
    if text:find('divine', 1, true) and text:find('intervention', 1, true) then return 'divine' end
    if text:find('recall', 1, true) then return 'recall' end
    return nil
end

local function selectedTeleportCategory()
    if types.Actor.getSelectedEnchantedItem(self) then return nil end
    return classifySpell(types.Actor.getSelectedSpell(self))
end

local function casting()
    return animation.hasAnimation(self) and animation.isPlaying(self, 'spellcast')
end

local function matchTeleport()
    -- The skill and teleport callbacks can arrive in either order within a frame.
    if settings:get('automatic') ~= false and castTime and teleportTime
        and math.abs(castTime - teleportTime) <= 0.25 then
        local category = teleportCategory or castCategory
        castTime, teleportTime, castCategory, teleportCategory = nil, nil, nil, nil
        -- Scripted teleport callbacks run inside an engine delayed action.
        pendingPlay = {category = category}
    end
end

I.SkillProgression.addSkillUsedHandler(function(skill, options)
    initialise()
    if skill ~= 'mysticism' or not options
        or options.useType ~= I.SkillProgression.SKILL_USE_TYPES.Spellcast_Success
        or settings:get('enabled') == false or settings:get('automatic') == false
        or not types.Player.isTeleportingEnabled(self) then return end
    local category = selectedTeleportCategory()
    if not category then return end
    castTime = core.getSimulationTime()
    castCategory = category
    matchTeleport()
end)

I.AnimationController.addTextKeyHandler('spellcast', function(_, key)
    if key ~= 'self release' then return end
    initialise()
    if settings:get('enabled') == false or settings:get('automatic') == false
        or not types.Player.isTeleportingEnabled(self)
        or selectedTeleportCategory() ~= 'kyne' then return end
    -- Skill progression may stop at the cap; require a real arrival as well.
    castTime = core.getSimulationTime()
    castCategory = 'kyne'
    matchTeleport()
end)

return {
    interfaceName = 'TeleportTransition',
    interface = {version = 1, play = play, stop = stop},
    eventHandlers = {TeleportTransitionPlay = play},
    engineHandlers = {
        onFrame = function(dt)
            initialise()
            if settings:get('automatic') == false or settings:get('enabled') == false then
                castTime, teleportTime, castCategory, teleportCategory = nil, nil, nil, nil
                pendingPlay = nil
            end
            if pendingPlay then
                local request = pendingPlay
                pendingPlay = nil
                play(request)
            end
            local now = core.getSimulationTime()
            if I.UI.getMode() ~= nil then
                if castTime then castTime = now end
                if teleportTime then teleportTime = now end
            else
                if castTime and now - castTime > 0.25 then castTime, castCategory = nil, nil end
                if teleportTime and now - teleportTime > 0.25 then teleportTime, teleportCategory = nil, nil end
            end
            if elapsed == nil then return end
            if settings:get('enabled') == false then stop(); return end
            elapsed = elapsed + math.max(dt, 0)
            if elapsed >= duration then stop(); return end
            applySettings(activeCategory)
            shader:setFloat('transitionProgress', elapsed / duration)
        end,
        onTeleported = function()
            initialise()
            if settings:get('enabled') == false or settings:get('automatic') == false then return end
            local category = selectedTeleportCategory()
            if not castTime and not (casting() and category) then return end
            teleportTime = core.getSimulationTime()
            teleportCategory = category
            matchTeleport()
        end,
        onLoad = function(data)
            stop()
            restored, pending, failed, held = data, true, false, false
            castTime, teleportTime, castCategory, teleportCategory, activeCategory = nil, nil, nil, nil, nil
        end,
        onSave = function()
            initialise()
            local saved = {enabled = settings:get('enabled') ~= false,
                automatic = settings:get('automatic') ~= false,
                strength = number('strength', 0, 3), duration = number('duration', 0.2, 2),
                distortion = number('distortion', 0, 4), ripples = number('ripples', 1, 5),
                colour = colours[settings:get('colour')] and settings:get('colour') or 'Neutral',
                recallColour = colours[settings:get('recallColour')] and settings:get('recallColour') or 'Default',
                almsiviColour = colours[settings:get('almsiviColour')] and settings:get('almsiviColour') or 'Default',
                divineColour = colours[settings:get('divineColour')] and settings:get('divineColour') or 'Default',
                tint = number('tint', 0, 1), fringe = number('fringe', 0, 1),
                reducedMotion = settings:get('reducedMotion') == true}
            if kyneInstalled then
                saved.kyneColour = colours[settings:get('kyneColour')] and settings:get('kyneColour') or 'Default'
            end
            return saved
        end,
        onKeyPress = function(key)
            if key.code ~= input.KEY.F11 or held then return end
            held = true
            if key.withCtrl and key.withShift and not key.withAlt and not key.withSuper
                and I.UI.getMode() == nil then play() end
        end,
        onKeyRelease = function(key)
            if key.code == input.KEY.F11 then held = false end
        end,
    },
}
