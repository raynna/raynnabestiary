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
        lua.execute('''
        local create=CreateFrame
        function CreateFrame(kind,name,parent,template)
            local f=create(kind,name,parent,template)
            if template=='OptionsSliderTemplate' then f.Low=create();f.High=create();f.Text=create() end
            return f
        end
        ''')
        lua.execute('B = {}; T = {}; RaynnaTrackerDB = {bestiary={scale=0.8}, appearance={paper=false}, recentPortraitNPCs={587}}')
        if existing:
            lua.execute('RaynnaBestiaryDB = {bestiary={scale=1.2},items={scale=0.7,history={3371}}}')
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
            local itemRow
            for _,row in ipairs(Frames) do
                if row.parent==B.Items.frame and row.entry and row.OnClick then itemRow=row; break end
            end
            assert(itemRow, 'clickable item row')
            itemRow.OnEnter(itemRow)
            assert(itemRow.actionHint:IsShown() and itemRow.actionHint.labelText=='View item >')
            assert(itemRow.detail:IsShown()~=false, 'chance remains visible beside hint')
            itemRow.OnLeave(itemRow)
            assert(not itemRow.actionHint:IsShown() and itemRow.title:GetWidth()==194)
            local clickedItem=itemRow.entry.itemID
            itemRow.OnClick(itemRow)
            assert(B.Items.currentItem==clickedItem and B.Items.frame:IsShown(), 'loot opens item in shared panel')
            B.Items.GoBack()
            assert(B.Items.currentNPC and B.Items.frame:IsShown(), 'Back restores monster')
            B.BestiaryDemo()
            assert(B.Items.frame:IsShown() and not RaynnaBestiaryFrame:IsShown())
            assert(B.ReferenceMonster(269175).drops[256037].rate == 81.3)
            B.OpenBrowser({{npcID=587,name='Bloodscalp Warrior'},{npcID=269175,name='Carnivorous Weed'}})
            assert(B.browser:IsShown())
            assert(not B.browser.all:IsShown() and not B.browser.recent:IsShown())
            for _,row in ipairs(Frames) do
                if row.parent==B.browser and row.entry and row:IsShown() then
                    assert(row.entry.id==587 or row.entry.id==269175, 'only tracked monsters displayed')
                end
            end
            B.browser.clear.OnClick()
            assert(B.browser.all:IsShown(), 'Clear restores full browser')
            assert(#B.FindNPCs('','tracked')==2, 'Clear preserves supplied tracker history')
            B.OpenBrowser({{npcID=587,name='Bloodscalp Warrior'},{npcID=269175,name='Carnivorous Weed'}})
            B.OpenBrowser()
            assert(not B.browser.all:IsShown(), 'Browse retains tracker filter')
            assert(#B.FindNPCs('carnivorous','all')>0)
            assert(#B.FindNPCs('269175','all')==1)
            assert(#B.FindNPCs('','tracked')==2)
            local selected=false
            for _,row in ipairs(Frames) do
                if row.entry and row.entry.id and row.parent==B.browser then
                    row.OnClick(); selected=true; break
                end
            end
            assert(selected and B.browser:IsShown() and B.Items.frame:IsShown(), 'selection retains NPC chooser')
            SlashCmdList.RAYNNABESTIARY('hide')
            assert(not B.browser:IsShown())
            SlashCmdList.RAYNNABESTIARY('')
            assert(B.browser:IsShown() and B.browser.all:IsShown(), '/rb opens full NPC browser')
            B.OpenBrowser({})
            for _,row in ipairs(Frames) do
                if row.parent==B.browser and row.entry then assert(not row:IsShown(), 'empty tracker stays empty') end
            end
            GameTooltip.GetItem = function() return 'Silk Cloth', 'item:4306' end
            SlashCmdList.RAYNNABESTIARY('hide')
            GameTooltip:Show(); ALT_DOWN = true
            ITEM_TOOLTIP_CALLBACK(GameTooltip, {id=4306})
            assert(B.Items.frame:IsShown() and B.Items.currentItem==4306, 'merged Alt-hover item reference works')
        ''')
        if existing:
            assert lua.eval('B.Items.db.scale') == 0.7
            assert lua.eval('B.Items.db.history[1]') == 4306
        assert lua.eval('B.db.bestiary.scale') == (1.2 if existing else 0.8)
print('PASS: standalone Bestiary, optional Tracker coexistence, saved migration and own settings')

if (ROOT/'RaynnaTracker').is_dir():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(mock)
    lua.execute('T={}')
    load(lua,'RaynnaTracker','T')
    lua.execute('''
    T.events.OnEvent(nil,'ADDON_LOADED','RaynnaTracker')
    T.events.OnEvent(nil,'PLAYER_LOGIN')
    assert(not RaynnaBestiaryFrame and not SlashCmdList.RAYNNABESTIARY)
    assert(not T.BuildBestiary and not T.ShowBestiary)
    T.OpenTrackedBestiary()
    assert(not RaynnaBestiaryFrame)
    ''')
    toc=(ROOT/'RaynnaTracker/RaynnaTracker.toc').read_text()
    assert '\nBestiary.lua' not in toc and '## Dependencies:' not in toc
    print('PASS: Tracker alone has no Bestiary UI, hover handler, command or required addon dependency')

# Deterministic reference merge test, without UI or player tracking.
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("A={LootReference={creatures={},names={},refs={},loot={}},BundledMetadata={Item={[900001]={}}}}")
lua.execute("""
A.ReferenceMetadata={Item={Get=function(id,field)
 if field=='npcDrops' then return {900002} end
 if field=='name' then return 'Forever test item' end
end},Npc={Get=function(id,field) if field=='name' then return 'Forever test creature' end end}}
""")
lua.execute((ROOT/'RaynnaBestiary/LootSources.lua').read_text(), 'Test', lua.globals().A)
lua.execute("""
local result=A.ReferenceMonster(900002)
assert(result.drops[900001] and result.drops[900001].rate==nil)
assert(result.mixedReference and result.name=='Forever test creature')
A.ForeverReference={[900002]={name='Corrected',drops={[900001]={rate=17}}}}
assert(A.ReferenceMonster(900002).drops[900001].rate==17)
assert(A.ReferenceItem(900001).drops[900002].rate==17)
""")
print('PASS: Forever-only forward sources, unknown percentages and explicit correction precedence')

# Cold hover must never complete the full reverse index on the caller's frame.
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
A={LootReference={creatures={[1]={1,"Test",10,10}},names={},refs={},loot={[1]={}}},
   BundledMetadata={Item={}}, ForeverReference={[1]={drops={[7]={rate=88}}}}}
for i=1,300 do A.BundledMetadata.Item[i]={}; A.LootReference.loot[1][i]={i,1,0,1,1,0} end
calls=0
A.ReferenceMetadata={Item={Get=function(id,field)
 if field=='npcDrops' then calls=calls+1;return {1} end
end}}
CreateFrame=function() worker={SetScript=function(self,_,fn)self.tick=fn end,Hide=function()end};return worker end
""")
lua.execute((ROOT/'RaynnaBestiary/LootSources.lua').read_text(),'Test',lua.globals().A)
lua.execute("""
A.WarmLootIndex()
local subject=A.ReferenceMonster(1,nil,nil,true)
assert(calls==0 and subject.loadingDrops and subject.drops[7].rate==88)
worker:tick();A.AdvanceHoverLoot(subject)
assert(calls<=48 and subject.loadingDrops and subject.classicJob)
for i=1,500 do
 if worker.tick then worker:tick() end
 A.AdvanceHoverLoot(subject)
 if not subject.loadingDrops then break end
end
assert(not subject.loadingDrops and calls==300)
local expected=A.ReferenceMonster(1)
for id,entry in pairs(expected.drops) do assert(subject.drops[id].rate==entry.rate) end
assert(subject.drops[7].rate==88)
""")
print('PASS: cold hover opens immediately, yields during indexing and loot resolution, then matches complete loot')
