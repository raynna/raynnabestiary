"""Standalone Bestiary and coexistence regression tests; no game required."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
# Shared minimal game mock, without loading Tracker or running its tests.
mock = (ROOT / 'tests/wow_mock.lua').read_text()

def load(lua, folder, namespace):
    toc = ROOT / folder / (folder + '.toc')
    for line in toc.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            lua.execute('assert(loadstring(...))(..., ' + namespace + ')',
                        (ROOT / folder / line).read_text(), folder)

for coexist in ((False, True) if (ROOT / 'RaynnaTracker').is_dir() else (False,)):
    for existing in (False, True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(mock)
        lua.execute('B = {}; T = {}; RaynnaTrackerDB = {bestiary={scale=0.8}, appearance={paper=false}, recentPortraitNPCs={587}}')
        if existing:
            lua.execute('RaynnaBestiaryDB = {bestiary={scale=1.2}}')
        load(lua, 'RaynnaBestiary', 'B')
        lua.execute("B.events.OnEvent(nil, 'ADDON_LOADED', 'RaynnaBestiary')")
        if coexist:
            load(lua, 'RaynnaTracker', 'T')
            lua.execute("T.events.OnEvent(nil, 'ADDON_LOADED', 'RaynnaTracker')")
        lua.execute("B.events.OnEvent(nil, 'PLAYER_LOGIN')")
        lua.execute('SAVED_BESTIARY_FRAME = RaynnaBestiaryFrame; SAVED_COMMAND = SlashCmdList.RAYNNABESTIARY')
        if coexist:
            lua.execute("T.events.OnEvent(nil, 'PLAYER_LOGIN')")
        lua.execute('''
            assert(RaynnaBestiaryFrame == SAVED_BESTIARY_FRAME and SlashCmdList.RAYNNABESTIARY == SAVED_COMMAND,
                'Tracker does not create duplicate Bestiary UI or command')
            assert(RaynnaModsSettingsRegistry.pages.bestiary, 'independent settings page')
            assert(not B.events.events.PARTY_KILL, 'standalone Bestiary has no kill tracking')
            assert(B.db.bestiary ~= RaynnaTrackerDB.bestiary, 'migration does not alias Tracker saves')
            SlashCmdList.RAYNNABESTIARY('settings')
            assert(RaynnaModsSettingsRegistry.selected == 'bestiary')
            B.BestiaryDemo()
            assert(RaynnaBestiaryFrame.shown)
            assert(B.ReferenceMonster(269175).drops[256037].rate == 81.3)
            GameTooltip.GetItem = function() return 'Silk Cloth', 'item:4306' end
            SlashCmdList.RAYNNABESTIARY('hide')
            GameTooltip:Show(); ALT_DOWN = true
            ITEM_TOOLTIP_CALLBACK(GameTooltip, {id=4306})
            assert(RaynnaBestiaryFrame.section.labelText:find('SOURCES'), 'standalone inventory lookup works')
        ''')
        assert lua.eval('B.db.bestiary.scale') == (1.2 if existing else 0.8)
print('PASS: standalone Bestiary, optional Tracker coexistence, saved migration and own settings')
