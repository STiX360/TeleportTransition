"""Archive-backed checks of Daisy's real Greater Recall menu and teleport handlers."""
import os
import unittest
from zipfile import ZipFile

import test_teleport_transition


class DaisyMultiMarkTests(unittest.TestCase):
    def setUp(self):
        archive = os.environ.get('DAISY_MULTIMARK_ARCHIVE')
        if not archive:
            self.skipTest('Set DAISY_MULTIMARK_ARCHIVE to the downloaded mod ZIP')
        self.controller = test_teleport_transition.TeleportTests()
        self.controller.setUp()
        self.run_lua = self.controller.run_lua
        with ZipFile(archive) as package:
            source = package.read('scripts/LuaMultiMark/lmm_p.lua').decode('utf-8')
            greater = package.read('scripts/LuaMultiMark/GreaterMark.lua').decode('utf-8')
            global_source = package.read('scripts/LuaMultiMark/lmm_g.lua').decode('utf-8')
        self.run_lua("""
            I=require('openmw.interfaces'); core=require('openmw.core')
            types=require('openmw.types'); self=require('openmw.self'); ui=require('openmw.ui')
            core.API_REVISION=134; self.type=types.Player
            ui.showMessage=function(message) lastMessage=message end
            I.UI.setMode=function(value) mode=value end
            nearby={actors={}}; menuMode=false
            markData={{cell='First',position={}},{cell='Second',position={}}}
            playerSettings={get=function() return false end}
            getMarkDataLength=function() return #markData end
            compareNumVal=function() return false end
            contextCheck=function() return false end
            drawListMenu=function() end
            I.LMM={getListLength=function() return 10 end,getKeyBindings=function() return {} end}
            I.LMM_Window={createItemWindow=function(list)
                return {selectedPosY=1,getItemAt=function(_,index) return list[index] end,
                    destroy=function() destroyed=true end}
            end}
            I.LMM_MagicInterface={monitorEffect=function() end,registerSpell=function() end}
            function self:sendEvent(name) localEvent=name end
            function self:teleport(cell,position,rotation)
                arrived=cell; h.onTeleported()
            end
            world={getCellById=function(id) return id end}
            package.preload['openmw.world']=function() return world end
            package.preload['openmw.async']=function() return {} end
            core.sendGlobalEvent=function(name,data) queuedEvent={name=name,data=data} end
            h.onFrame(0); values.recallColour='Green'
            spellId='multimark_recall_spell'; spellName='Greater Recall'; effect='multimark_recall'
        """)
        spans = [('closeWindows', 'I.Settings.registerGroup'),
                 ('canTeleport', 'local lastWinState'),
                 ('doRecall', 'local function saveMarkOverwrite'),
                 ('openMarkMenu', 'local function trim')]
        # Compile together so the original local functions share one closure.
        blocks = []
        for name, boundary in spans:
            start = source.index('local function ' + name + '(')
            blocks.append(source[start:source.index(boundary, start)])
        self.run_lua('\n'.join(blocks) + '\nopenMenu=openMarkMenu; recall=doRecall; closeMenu=closeWindows; pause=setPauseMode')
        self.controller.lua.globals().greater = self.controller.lua.execute(greater)
        self.controller.lua.globals().daisy = self.controller.lua.execute(global_source)

    def test_greater_recall_menu_and_real_teleport_handler(self):
        self.run_lua("""
            cast(); greater.eventHandlers.EffectStarted({effectId='multimark_recall'})
            assert(localEvent=='openMarkMenu'); openMenu(); assert(mode=='Interface')
            now=30; h.onFrame(0); assert(not shader.active)
            recall(2); assert(mode==nil and destroyed)
            assert(queuedEvent.name=='LMM_TeleportToCell')
            daisy.eventHandlers.LMM_TeleportToCell(queuedEvent.data)
            assert(arrived=='Second' and not shader.active)
            h.onFrame(0); assert(shader.active and shader.uniforms.transitionRed==0.25)
        """)

    def test_translated_name_uses_custom_effect(self):
        self.run_lua("""
            spellId='localized_spell'; spellName='Translated name'
            cast(); openMenu(); now=30; h.onFrame(0); recall(1)
            daisy.eventHandlers.LMM_TeleportToCell(queuedEvent.data)
            h.onFrame(0); assert(shader.active)
        """)

    def test_greater_mark_does_not_trigger(self):
        self.run_lua("""
            spellId='multimark_mark_spell'; spellName='Greater Mark'; effect='multimark_mark'
            cast(); greater.eventHandlers.EffectStarted({effectId='multimark_mark'})
            assert(localEvent=='saveMarkLoc'); h.onTeleported(); h.onFrame(0)
            assert(not shader.active)
        """)

    def test_cancelled_menu_has_no_pulse_or_destination_event(self):
        self.run_lua("""
            cast(); openMenu(); now=30; h.onFrame(0)
            closeMenu(); pause(false); h.onFrame(0)
            assert(not shader.active and not queuedEvent)
            now=31; h.onFrame(0); playing=false; h.onTeleported(); h.onFrame(0)
            assert(not shader.active)
        """)


if __name__ == '__main__':
    unittest.main()
