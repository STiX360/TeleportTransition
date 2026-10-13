"""Run the downloaded mod's Recall handlers against the controller API doubles.

Set PURE_MULTIMARK_ARCHIVE to a local mod ZIP. No third-party code is vendored.
These checks do not establish native OpenMW event timing or visual acceptance.
"""
import os
import unittest
from zipfile import ZipFile

import test_teleport_transition


class PureMultiMarkTests(unittest.TestCase):
    def setUp(self):
        archive = os.environ.get('PURE_MULTIMARK_ARCHIVE')
        if not archive:
            self.skipTest('Set PURE_MULTIMARK_ARCHIVE to the downloaded mod ZIP')
        self.controller = test_teleport_transition.TeleportTests()
        self.controller.setUp()
        self.run_lua = self.controller.run_lua
        with ZipFile(archive) as package:
            source = package.read('puremultimark/scripts/puremultimark/PMM_p.lua').decode('utf-8')
            global_source = package.read('puremultimark/scripts/puremultimark/PMM_g.lua').decode('utf-8')
        # Execute the original registration and selection function, not a rewritten flow.
        start = source.index("I.AnimationController.addTextKeyHandler('',")
        end = source.index('function cancelCasting()', start)
        finalize_start = source.index('local function finalizeCast()')
        cancel_end = source.index('local function onFrame(dt)', end)
        load_start = global_source.index('local function loadLoc(data)')
        load_end = global_source.index('local function onLoad(data)', load_start)
        self.run_lua("""
            I=require('openmw.interfaces'); core=require('openmw.core')
            types=require('openmw.types'); self=require('openmw.self')
            Player=types.Player; animation=require('openmw.animation')
            ui=require('openmw.ui'); ambient={playSound=function() end}
            Player.getSelectedSpell=types.Actor.getSelectedSpell
            I.AnimationController={addTextKeyHandler=function(_,fn) textHandler=fn end}
            I.UI.setMode=function(value) mode=value end
            I.SkillProgression.skillUsed=function(skill,opts) skillHandler(skill,opts) end
            core.sendGlobalEvent=function(name,data)
                assert(name=='PMM_loadLoc'); queuedLocation=data
            end
            core.sound={isSoundPlaying=function() return false end}
            animation.setSpeed=function() end
            animation.cancel=function() playing=false end
            checkSpell=function() return {cost=0} end
            Player.stats={dynamic={magicka=function() return {current=100} end}}
            playerSection={get=function() return false end}
            package.preload['scripts.puremultimark.PMM_markWindow']=function() return {} end
            saveData={locations={{cell='First',position={}},{cell='Second',position={}}}}
            getMaxMarks=function() return 10 end
            getCastChance=function() return chance or 1 end
            silenceSpell='silence'; silenceEffect=0; recallSound='mysticism hit'
            activeSpells=setmetatable({}, {__index={
            add=function(self,data)
                self[1]={id=data.id,activeSpellId=1,effects={{id='silence'}}}
            end,
            remove=function(self,id) self[id]=nil end}})
            types.Actor.activeSpells=function() return activeSpells end
            types.Actor.activeEffects=function() return {modify=function() end} end
            function self:teleport(cell,position,options)
                arrivals=(arrivals or 0)+1; arrivedCell=cell; h.onTeleported()
            end
            world={getExteriorCell=function(x,y) return {x=x,y=y} end}
            h.onFrame(0); values.recallColour='Green'
        """)
        self.run_lua(source[finalize_start:start] + source[start:cancel_end])
        self.run_lua(global_source[load_start:load_end] + '\n deliverLocation=loadLoc')

    def test_two_marks_menu_and_scripted_recall(self):
        self.run_lua("""
            textHandler('spellcast','self start'); assert(mode=='Interface')
            now=30; h.onFrame(0); assert(not shader.active)
            selectedMark(2); assert(mode==nil)
            textHandler('spellcast','self release'); assert(queuedLocation)
            assert(not shader.active)
            playing=false; deliverLocation(queuedLocation)
            assert(not shader.active); h.onFrame(0)
            assert(arrivals==1 and arrivedCell=='Second' and shader.active)
            assert(shader.uniforms.transitionGreen==1 and shader.uniforms.transitionRed==0.25)
            h.onFrame(2); assert(not shader.active)
        """)

    def test_teleport_before_skill_callback(self):
        self.run_lua("""
            core.sendGlobalEvent=function(_,data) deliverLocation(data) end
            textHandler('spellcast','self start'); selectedMark(1)
            textHandler('spellcast','self release')
            h.onFrame(0)
            assert(arrivals==1 and shader.active)
        """)

    def test_latest_uses_native_recall(self):
        self.run_lua("""
            textHandler('spellcast','self start'); selectedMark(0)
            textHandler('spellcast','self release'); assert(not queuedLocation)
            cast(); h.onTeleported(); h.onFrame(0); assert(shader.active)
        """)

    def test_failed_roll_does_not_teleport(self):
        self.run_lua("""
            chance=0; textHandler('spellcast','self start')
            textHandler('spellcast','self release')
            assert(not queuedLocation and not arrivals and not shader.active)
        """)

    def test_cancelled_menu_does_not_arm_unrelated_travel(self):
        self.run_lua("""
            textHandler('spellcast','self start'); assert(mode=='Interface')
            now=30; h.onFrame(0)
            cancelCasting(); assert(mode==nil and not playing)
            h.onTeleported()
            assert(not shader.active and not queuedLocation)
        """)


if __name__ == '__main__':
    unittest.main()
