"""Fixture lifecycle and console helper tests; not gameplay acceptance."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-tools'))
from lupa.lua51 import LuaRuntime


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            supplied, messages, events, values = {}, {}, {}, {}
            records = {}
            for _,id in ipairs({'mark','recall','almsivi intervention','divine intervention'}) do
                records[id]={id=id}
            end
            magicka={base=100,current=100}; fatigue={base=100,current=50}
            player={type='player',cell={name='Seyda Neen'},position={x=1,y=2,z=3}}
            player.object=player
            function player:sendEvent(name,data) table.insert(events,{name=name,data=data}) end
            function player:teleport(cell,pos) teleported={cell=cell,pos=pos} end
            spells={add=function(_,id) table.insert(supplied,id) end}
            npc={stats={skills={mysticism=function() return skill end},attributes={
                willpower=function() return willpower end,luck=function() return luck end}}}
            skill,willpower,luck={},{},{}
            types={Player={setTeleportingEnabled=function(_,v) blocked=not v end},NPC=npc,
                Actor={spells=function() return spells end,
                    setSelectedSpell=function(_,v) selected=v end,
                    getSelectedSpell=function() return selected end,
                    STANCE={Spell='spell'},setStance=function(_,v) stance=v end,
                    stats={dynamic={magicka=function() return magicka end,
                        fatigue=function() return fatigue end}}}}
            player.type=types.Player
            core={magic={spells={records=records}},sendGlobalEvent=function(name,data)
                table.insert(events,{name=name,data=data}) end}
            section={get=function(_,k) return values[k] end,set=function(_,k,v) values[k]=v end}
            interfaces={UI={getMode=function() return mode end},TeleportTransition={
                play=function() previews=(previews or 0)+1 end}}
            chain={}
            package.preload['openmw.self']=function() return player end
            package.preload['openmw.core']=function() return core end
            package.preload['openmw.types']=function() return types end
            package.preload['openmw.world']=function() return {} end
            package.preload['openmw.util']=function()
                return {vector3=function(x,y,z) return {x=x,y=y,z=z} end}
            end
            package.preload['openmw.storage']=function()
                return {playerSection=function() return section end}
            end
            package.preload['openmw.interfaces']=function() return interfaces end
            package.preload['openmw.ui']=function()
                return {showMessage=function(m) table.insert(messages,m) end}
            end
            package.preload['openmw.postprocessing']=function()
                return {getChain=function() return chain end}
            end
        """)

    def load_script(self, name, binding):
        path = ROOT / 'scripts/teleport_transition' / name
        self.lua.globals()[binding] = self.lua.execute(path.read_text())

    def test_supplies_once_and_home_survives_save_load(self):
        self.load_script('test_fixtures.lua', 'fixture')
        self.lua.execute("""
            fixture.engineHandlers.onPlayerAdded(player)
            fixture.engineHandlers.onPlayerAdded(player)
            assert(#supplied==4 and #events==1)
            saved=fixture.engineHandlers.onSave()
            fixture.engineHandlers.onLoad(saved)
            fixture.engineHandlers.onPlayerAdded(player); assert(#supplied==4)
            fixture.eventHandlers.TeleportTransitionTestAction({player=player,command='home'})
            assert(teleported.cell=='Seyda Neen' and teleported.pos.z==3)
            fixture.eventHandlers.TeleportTransitionTestAction({player=player,command='blocked'})
            assert(blocked)
            fixture.eventHandlers.TeleportTransitionTestAction({player=player,command='unblocked'})
            assert(not blocked)
        """)

    def test_unrelated_save_does_not_supply_fixture(self):
        self.load_script('test_fixtures.lua', 'fixture')
        self.lua.execute("""
            fixture.engineHandlers.onLoad(nil)
            fixture.engineHandlers.onPlayerAdded(player); assert(#supplied==0)
        """)

    def test_queued_preview_stats_and_saved_counter(self):
        self.load_script('test_player.lua', 'helper')
        self.lua.execute("""
            helper.eventHandlers.TeleportTransitionFixtureReady()
            assert(helper.interface.isReady() and selected.id=='mark' and stance=='spell')
            assert(magicka.current==500 and skill.base==100)
            helper.interface.run('preview'); mode='Console'; helper.engineHandlers.onFrame(1)
            assert(not previews); mode=nil; helper.engineHandlers.onFrame(0); assert(not previews)
            helper.engineHandlers.onFrame(0.1); assert(previews==1)
            chain={{name='teleport_transition'}}; helper.engineHandlers.onFrame(0.1)
            helper.engineHandlers.onFrame(0.1); assert(helper.interface.getPulseCount()==1)
            chain={}; helper.engineHandlers.onFrame(0.1)
            saved=helper.engineHandlers.onSave(); helper.engineHandlers.onLoad(saved)
            assert(helper.interface.getPulseCount()==1 and helper.interface.isReady())
            helper.interface.run('fail'); assert(magicka.current==0)
            helper.interface.run('ready'); assert(magicka.current==500)
            helper.interface.run('disabled'); assert(values.enabled==false)
            helper.interface.run('reduced'); assert(values.reducedMotion==true)
            helper.interface.run('pronounced')
            assert(values.colour=='Purple' and values.distortion==2.4 and values.duration==0.65)
            helper.interface.run('baseline'); assert(values.tint==0 and values.strength==0.65)
        """)


if __name__ == '__main__':
    unittest.main()
