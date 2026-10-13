"""Exercise the teleport controller with OpenMW API doubles."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-tools'))
from lupa.lua51 import LuaRuntime


class TeleportTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, loads, playing, mode = 0, 0, true, nil
            enabledTeleport, stance, effect = true, 'spell', 'recall'
            values, chain = {}, {{name='POTI'}}
            spellId, spellName = nil, nil
            shader = {uniforms={}}
            function shader:enable()
                if not self.active then table.insert(chain,self); self.active=true end
            end
            function shader:disable()
                for i=#chain,1,-1 do if chain[i]==self then table.remove(chain,i) end end
                self.active=false
            end
            function shader:setFloat(k,v) self.uniforms[k]=v end
            shader.setBool=shader.setFloat
            section={get=function(_,k) return values[k] end,
                set=function(_,k,v) values[k]=v end}
            package.preload['openmw.storage']=function()
                return {playerSection=function() return section end}
            end
            package.preload['openmw.interfaces']=function()
                return {Settings={registerPage=function() end,registerGroup=function(g)
                    for _,s in ipairs(g.settings) do values[s.key]=s.default end
                end},UI={getMode=function() return mode end},SkillProgression={
                    SKILL_USE_TYPES={Spellcast_Success=0},
                    addSkillUsedHandler=function(fn) skillHandler=fn end}}
            end
            package.preload['openmw.core']=function()
                return {getSimulationTime=function() return now end,
                    magic={SPELL_TYPE={Spell='spell'},EFFECT_TYPE={Recall='recall',
                        AlmsiviIntervention='almsiviintervention',DivineIntervention='divineintervention'}}}
            end
            package.preload['openmw.types']=function()
                return {Actor={STANCE={Spell='spell'},getStance=function() return stance end,
                    getSelectedEnchantedItem=function() return enchanted end,
                    getSelectedSpell=function()
                        if absent then return nil end
                        return {id=spellId,name=spellName,type=spellType or 'spell',effects={{id=effect}}}
                    end},Player={isTeleportingEnabled=function() return enabledTeleport end}}
            end
            package.preload['openmw.animation']=function()
                return {hasAnimation=function() return true end,isPlaying=function() return playing end}
            end
            package.preload['openmw.postprocessing']=function()
                return {load=function(name)
                    assert(name=='teleport_transition'); loads=loads+1
                    if broken then error('compile failure') end
                    return shader
                end}
            end
            package.preload['openmw.self']=function() return {} end
            package.preload['openmw.ui']=function()
                return {screenSize=function() return {x=3440,y=1440} end,
                    showMessage=function() end}
            end
            package.preload['openmw.input']=function() return {KEY={F11=11}} end
            function cast() skillHandler('mysticism',{useType=0}) end
        """)
        self.mod = self.lua.execute((ROOT / 'scripts/teleport_transition/player.lua').read_text())
        self.lua.globals().h = self.mod.engineHandlers
        self.lua.globals().api = self.mod.interface

    def run_lua(self, code):
        self.lua.execute(code)

    def test_all_spells_and_both_callback_orders(self):
        self.run_lua("""
            for _,id in ipairs({'recall','almsiviintervention','divineintervention'}) do
                effect=id; cast(); assert(not shader.active)
                h.onTeleported(); assert(not shader.active); h.onFrame(0)
                assert(shader.active and #chain==2)
                h.onFrame(0.9); assert(shader.uniforms.transitionProgress==0.5)
                assert(shader.uniforms.transitionAspect==3440/1440)
                h.onFrame(0.9); assert(not shader.active and #chain==1)
                h.onTeleported(); cast(); h.onFrame(0); assert(shader.active)
                h.onFrame(2); assert(not shader.active)
            end
            assert(loads==1 and chain[1].name=='POTI')
        """)

    def test_non_spell_travel_and_failed_casts(self):
        self.run_lua("""
            playing=false; h.onTeleported(); cast(); assert(not shader.active)
            now=1; h.onFrame(0)
            playing=true; skillHandler('mysticism',{useType=1}); h.onTeleported()
            assert(not shader.active)
            now=2; h.onFrame(0); effect='mark'; cast(); h.onTeleported()
            assert(not shader.active)
            effect='recall'; enchanted={}; cast(); h.onTeleported(); assert(not shader.active)
            enchanted=nil; stance='weapon'; cast(); h.onTeleported(); assert(not shader.active)
            stance='spell'; spellId='greater mark'; spellName='Greater Mark'; effect='summon'
            cast(); h.onTeleported(); assert(not shader.active)
        """)

    def test_missing_destination_blocked_and_stale_events(self):
        self.run_lua("""
            cast(); now=1; h.onFrame(0); playing=false; h.onTeleported()
            assert(not shader.active)
            enabledTeleport=false; playing=true; cast(); h.onTeleported()
            assert(not shader.active)
            enabledTeleport=true; now=2; h.onFrame(0); cast()
            now=3; h.onTeleported(); assert(not shader.active)
        """)

    def test_settings_preview_cleanup_and_save_load(self):
        self.run_lua("""
            h.onFrame(0); values.reducedMotion=true; values.strength=99
            assert(api.play()); h.onFrame(0.1)
            assert(shader.uniforms.transitionReducedMotion and shader.uniforms.transitionStrength==3)
            values.enabled=false; h.onFrame(0); assert(not shader.active)
            assert(not api.play()); saved=h.onSave(); h.onLoad(saved); h.onFrame(0)
            assert(values.enabled==false and values.reducedMotion)
            values.enabled=true; api.play(); h.onLoad(nil); h.onFrame(0)
            assert(not shader.active and values.enabled and not values.reducedMotion)
            h.onKeyPress({code=11,withCtrl=true,withShift=true}); assert(shader.active)
            h.onFrame(0.1); h.onKeyPress({code=11,withCtrl=true,withShift=true})
            assert(shader.uniforms.transitionProgress>0)
            h.onKeyRelease({code=11}); api.stop(); mode='Settings'
            h.onKeyPress({code=11,withCtrl=true,withShift=true}); assert(not shader.active)
        """)

    def test_repeated_requests_restart_without_duplicate_chain_entries(self):
        self.run_lua("""
            api.play(); h.onFrame(0.3); api.play()
            assert(#chain==2 and shader.uniforms.transitionProgress==0)
            h.onFrame(2); assert(#chain==1)
        """)

    def test_load_failure_is_reported_once(self):
        self.run_lua("""
            broken=true; assert(not api.play()); assert(not api.play())
            assert(loads==1 and #chain==1)
        """)

    def test_new_controls_migration_and_independent_speed(self):
        self.run_lua("""
            h.onLoad({enabled=true,strength=0.99,duration=0.8,reducedMotion=false}); h.onFrame(0)
            assert(values.distortion==3 and values.colour=='Purple' and values.tint==0.85)
            assert(values.recallColour=='Default' and values.almsiviColour=='Default')
            values.distortion=2.4; values.ripples=3; values.colour='Purple'
            values.tint=0.65; values.fringe=0.35; values.duration=0.4
            api.play(); h.onFrame(0.2)
            assert(shader.uniforms.transitionProgress==0.5)
            assert(shader.uniforms.transitionDistortion==2.4 and shader.uniforms.transitionRipples==3)
            assert(shader.uniforms.transitionBlue==1 and shader.uniforms.transitionRed==0.68)
            assert(shader.uniforms.transitionTint==0.65 and shader.uniforms.transitionFringe==0.35)
            saved=h.onSave(); h.onLoad(saved); h.onFrame(0)
            assert(values.colour=='Purple' and values.ripples==3)
            values.ripples=99; values.distortion=-1; values.colour='invalid'; values.tint=99
            api.play()
            assert(shader.uniforms.transitionRipples==5 and shader.uniforms.transitionDistortion==0)
            assert(shader.uniforms.transitionRed==1 and shader.uniforms.transitionTint==1)
        """)

    def test_multimark_menu_window_and_per_spell_colours(self):
        self.run_lua("""
            h.onFrame(0)
            values.colour='Neutral'; values.recallColour='Green'
            mode='Teleport menu'; effect='recall'; cast()
            now=5; h.onFrame(0); assert(not shader.active)
            mode=nil; h.onTeleported(); h.onFrame(0); assert(shader.active)
            assert(shader.uniforms.transitionGreen==1 and shader.uniforms.transitionRed==0.25)
            h.onFrame(2); assert(not shader.active)

            now=6; values.divineColour='Gold'; effect='summon'
            spellId='da_lmm_greater_recall'; spellName='Greater Recall'
            cast(); h.onTeleported(); h.onFrame(0); assert(shader.active)
            assert(shader.uniforms.transitionGreen==1 and shader.uniforms.transitionRed==0.25)
            h.onFrame(2)

            saved=h.onSave(); assert(saved.recallColour=='Green')
        """)

    def test_scripted_teleport_defers_shader_and_cleans_pending_requests(self):
        self.run_lua("""
            h.onFrame(0); cast()
            local original=shader.setFloat
            shader.setFloat=function() error('nested delayed action') end
            h.onTeleported(); assert(not shader.active)
            shader.setFloat=original; h.onFrame(0); assert(shader.active)
            api.stop(); cast(); h.onTeleported(); values.automatic=false
            h.onFrame(0); assert(not shader.active)
            values.automatic=true; cast(); h.onTeleported(); h.onLoad(nil)
            h.onFrame(0); assert(not shader.active)
        """)

    def test_optional_kyne_custom_effect_and_fallback(self):
        self.run_lua("""
            h.onFrame(0); values.colour='Blue'; values.divineColour='Gold'
            spellId='T_Nor_Mys_KynesIntervention'; spellName='Divine Intervention'
            effect='divineintervention'; cast(); h.onTeleported(); h.onFrame(0)
            assert(shader.uniforms.transitionRed==0.2 and shader.uniforms.transitionBlue==1)
            h.onFrame(2); spellId='custom'; spellName='Translated spell'
            effect='t_intervention_kyne'; h.onTeleported(); cast(); h.onFrame(0)
            assert(shader.active and shader.uniforms.transitionRed==0.2)
            h.onFrame(2); cast(); now=1; h.onFrame(0)
            assert(not shader.active)
        """)

    def test_failed_cast_door_and_transport_events_never_enable(self):
        self.run_lua("""
            playing=false
            for i=1,3 do h.onTeleported(); h.onFrame(0.1); now=now+1 end
            assert(not shader.active and loads==0)
            playing=true; skillHandler('mysticism',{useType=1}); h.onTeleported()
            h.onFrame(0.1); assert(not shader.active and loads==0)
        """)

    def test_screenshot_defaults_and_automatic_off_external_calls(self):
        self.run_lua("""
            h.onFrame(0)
            assert(values.strength==2.4 and values.duration==1.8 and values.distortion==3)
            assert(values.ripples==3 and values.colour=='Purple' and values.tint==0.85)
            assert(values.fringe==0.6 and not values.reducedMotion and values.automatic)
            values.automatic=false; cast(); h.onTeleported(); h.onFrame(0)
            assert(not shader.active)
            assert(api.play()); h.onFrame(0.1); assert(shader.active)
            saved=h.onSave(); assert(not saved.automatic)
            h.onLoad(saved); h.onFrame(0); assert(not values.automatic)
            assert(api.play()); values.enabled=false; h.onFrame(0); assert(not shader.active)
            assert(not api.play())
        """)


if __name__ == '__main__':
    unittest.main()
