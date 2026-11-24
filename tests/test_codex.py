"""Real generated data + mocked client tests; not an in-game visual certification."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / 'tests/wow_mock.lua').read_text())
lua.execute('''
A = {}; SHIFT=false
local create=CreateFrame
function CreateFrame(kind,name,parent,template)
 local frame=create(kind,name,parent)
 if template=='OptionsSliderTemplate' then frame.Low=create(); frame.High=create(); frame.Text=create() end
 function frame:SetChecked(value) self.checked=value end
 function frame:GetChecked() return self.checked end
 return frame
end
function IsShiftKeyDown() return SHIFT end
function UnitFactionGroup() return 'Horde' end
C_Item={GetItemInfo=function(id)
 if id==3371 then return 'Empty Vial','item:3371',1,1,1,'Trade Goods','Other',20,'',134793,1 end
end}
function GameTooltip:GetItem() return 'Empty Vial','item:3371' end
''')
folder = ROOT / 'RaynnaBestiary'
for line in (folder / 'RaynnaBestiary.toc').read_text().splitlines():
    if line and not line.startswith('#'):
        lua.execute('assert(loadstring(...))("RaynnaCodex", A)', (folder / line).read_text(encoding='utf8'))
lua.execute('''
assert(#A.Recipes == 2090 and A.RecipeBuild=='1.60.1.70888')
RaynnaCodexDB={scale=0.8, history={765,3371}, enabled=true}
for _,frame in ipairs(Frames) do
 if frame.events and frame.events.ADDON_LOADED then frame.OnEvent(frame,'ADDON_LOADED','RaynnaBestiary') end
end
A.events.OnEvent(nil,'PLAYER_LOGIN')
B=A; A=B.Items
assert(A.db ~= RaynnaCodexDB and A.db.history ~= RaynnaCodexDB.history)
assert(A.BundledMetadata==B.BundledMetadata and A.LootReference==B.LootReference)
assert(A.db.scale == 0.8 and A.db.history[1] == 765)
assert(RaynnaModsSettingsRegistry.pages.bestiary)
assert(A.ItemID('|Hitem:3371:0|h[Empty Vial]|h')==3371)
assert(A.ItemID(-1)==nil)
local uses=A.BuildUses(3371)
local minor=false
for _,row in ipairs(uses) do
 if row.recipe and row.recipe[1]==1244431 then
   minor=true
   assert(row.recipe[3]=='First Aid' and row.recipe[5]==118)
   local materials={}; for _,m in ipairs(row.recipe[6]) do materials[m[1]]=m[2] end
   assert(materials[3371]==1 and materials[2678]==1 and materials[2447]==1 and not materials[765])
 end
end
assert(minor, 'Empty Vial must explain Minor Healing Potion')
for _,recipe in ipairs(A.Recipes) do assert(recipe[1]~=57111, 'Turtle recipe contamination') end
assert(A.Summary(3371):find('several professions'))
assert(A.Summary(1708):find('1,345'))
local sources=A.BuildSources(3371)
local vendor=false
for _,row in ipairs(sources) do if row.kind=='Vendor' then vendor=true end end
assert(vendor, 'Vial vendors should be available standalone')
assert(A.BuildUses(99999999)[1].title=='No specific use recorded')
assert(#A.Search('Empty Vial')>0)
assert(A.Search('3371')[1].itemID==3371)
ALT_DOWN=true
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=3371})
assert(A.currentItem==3371 and A.frame:IsShown())
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=765})
assert(A.currentItem==3371, 'Alt locks item selection')
ALT_DOWN=false
RaynnaBestiaryFrame.OnEvent(nil,'MODIFIER_STATE_CHANGED','LALT',0)
A.frame.OnUpdate(A.frame,0.1)
assert(not A.frame:IsShown())
A.ShowItem(3371,true)
assert(A.db.history[1]==3371)
for id=1,60 do A.Remember(id) end
assert(#A.db.history==40 and A.db.history[1]==60)
A.SetScale(5); assert(A.db.scale==1.8)
A.SetScale(0); assert(A.db.scale==0.4)
SlashCmdList.RAYNNACODEX('3371'); assert(A.currentItem==3371)
SlashCmdList.RAYNNACODEX('hide'); assert(not A.frame:IsShown())
SlashCmdList.RAYNNACODEX('settings')
assert(RaynnaModsSettingsRegistry.selected=='bestiary')
RaynnaModsSettingsRegistry:SetAppearance('opacity',0.8)
assert(A.db.appearance.opacity==0.8)
A.ShowItem(3371,false)
for _,control in ipairs(Frames) do
 if control.parent==A.frame and control.labelText=='Recent' then control.OnClick() end
end
assert(not A.pinned, 'Recent must not pin the panel')
C_Map={GetAreaInfo=function(id) return id==12 and 'Elwynn Forest' or id==40 and 'Westfall' end,
 GetMapInfo=function(id) if id==37 then return {name='Elwynn Forest',mapType=3} elseif id==38 then return {name='Westfall',mapType=3} end end,
 CanSetUserWaypointOnMap=function(id) return id==37 end,
 SetUserWaypoint=function(point) WAYPOINT=point end,
 OpenWorldMap=function(id) OPEN_MAP=id end}
UiMapPoint={CreateFromCoordinates=function(map,x,y) return {map=map,x=x,y=y} end}
local ok=A.ShowSourceLocation({npcID=66})
assert(ok and OPEN_MAP==37 and WAYPOINT.map==37)
local chosen=A.DensestSpawn(A.SourceLocations(66))
assert(WAYPOINT.x==chosen.x/100 and WAYPOINT.y==chosen.y/100)
assert(not A.ShowSourceLocation({npcID=99999999}))
local get=A.ReferenceMetadata.Npc.Get
A.ReferenceMetadata.Npc.Get=function() return {} end
assert(#A.SourceLocations(66)==0,'Preserve explicit empty provider corrections')
A.ReferenceMetadata.Npc.Get=get
local sources=A.BuildSources(3371); local found=false
for _,row in ipairs(sources) do if row.npcID==66 then found=true end end
assert(found,'Vendor IDs must reach portrait and waypoint lookups')
InCombatLockdown=function() return true end
assert(not A.ShowSourceLocation({npcID=66}), 'Map actions must not run during combat')
InCombatLockdown=function() return false end
C_Map.CanSetUserWaypointOnMap=function() return false end
WAYPOINT=nil
assert(A.ShowSourceLocation({npcID=66}) and WAYPOINT==nil,'Unsupported pins still open the zone map')
C_TooltipInfo={GetItemByID=function() return {lines={{leftText='Use: Client-provided effect.'}}} end}
assert(A.ItemDescription(1708)=='Use: Client-provided effect.','Client description takes priority')
for _,control in ipairs(Frames) do
 if control.parent==A.frame and control.labelText=='Sources' then control.OnClick() end
end
local portrait=false
for _,row in ipairs(Frames) do
 if row.entry and row.entry.npcID then assert(row.portrait.portraitKey); portrait=true end
end
assert(portrait,'Visible source rows must bind NPC portraits')
local supplies=A.BuildSources(5838); local scroll=false
for _,row in ipairs(supplies) do
 if row.questID==1136 and row.kind=='Quest supply' then assert(row.npcID); scroll=true end
end
assert(scroll,'Kodo Skin Scroll must show its quest acceptance source')
assert(A.Summary(5838):find('Melor Stonehoof'))
local trout
for _,recipe in ipairs(A.Recipes) do if recipe[2]=='Mithril Head Trout' then trout=recipe end end
assert(trout and #trout[6]==1)
local rows=A.BuildUses(trout[5]); local made
for _,row in ipairs(rows) do if row.action=='ingredients' then made=row end end
assert(made and made.title:find('Raw Mithril Head Trout',1,true))
A.pinned=false
A.ShowItem(trout[5],false)
A.ShowIngredients(trout)
assert(A.currentItem==trout[6][1][1] and A.pinned)
A.GoBack(); assert(A.currentItem==trout[5])
local mana
for _,recipe in ipairs(A.Recipes) do if recipe[2]=='Lesser Mana Potion' then mana=recipe end end
assert(mana and #mana[6]>1)
A.ShowItem(mana[5],false); A.ShowIngredients(mana)
local materials=A.IngredientRows(mana)
assert(#materials==#mana[6] and materials[1].quantity==mana[6][1][2])
A.NavigateItem(materials[1].itemID)
assert(A.currentItem==materials[1].itemID and A.pinned)
A.GoBack(); assert(A.currentItem==mana[5])
local visibleMaterials=0
for _,row in ipairs(Frames) do if row.entry and row.entry.quantity then visibleMaterials=visibleMaterials+1 end end
assert(visibleMaterials==#mana[6], 'Back restores clickable ingredient list')
A.pinned=false
A.frame.OnDragStart(); assert(not A.pinned and A.dragging)
A.frame.OnDragStop(); assert(not A.pinned and not A.dragging)
for _,control in ipairs(Frames) do
 if control.parent==A.frame and control.labelText=='Links' then control.OnClick(); assert(not A.pinned) end
end
A.frame.search:SetText('Empty Vial'); A.frame.search.OnEnterPressed(A.frame.search); assert(not A.pinned)
A.frame.pin.OnClick(); assert(A.pinned)
A.frame.pin.OnClick(); assert(not A.pinned)
local containers,objects=0,0
for id in pairs(A.ExtraItems) do
 for _,row in ipairs(A.AdditionalSources(id)) do
  if row.kind=='Container' then assert(row.itemID); containers=containers+1 end
  if row.kind=='Object' then assert(row.objectID); objects=objects+1 end
 end
end
assert(containers>0 and objects>0)
''')
print('PASS: recipe data, vial uses/vendors, unknown coverage, search, persistence, hover locking, pinning, scale, settings and commands')
# Compile every shipped Lua file under the actual target language version.
for file in folder.glob('*.lua'):
    lua.execute('assert(loadstring(...))', file.read_text(encoding='utf8'))
print('PASS: all runtime files compile in Lua 5.1')
if (ROOT/'RaynnaTracker/SettingsRegistry.lua').exists():
    assert (folder/'SettingsRegistry.lua').read_bytes() == (ROOT/'RaynnaTracker/SettingsRegistry.lua').read_bytes()
else:
    assert lua.globals().RaynnaModsSettingsRegistry.version == 2
print('PASS: shared settings bootstrap matches the existing packages')

lua.execute("""
A.pinned=false; A.dismissed=true
assert(RaynnaCodexAPI.OpenItem(3371))
assert(A.currentItem==3371 and A.manualOpen and A.frame:IsShown())
assert(not A.pinned and not A.dismissed, 'external navigation never auto-pins')
assert(not RaynnaCodexAPI.OpenItem(-1))
""")
print('PASS: public Codex item opener, manual visibility, invalid ID and no auto-pin')

lua.execute("""
local source=CreateFrame('Frame')
source.GetFrameLevel=function() return 180 end
source.GetEffectiveScale=function() return 0.8 end
source.GetLeft=function() return 100 end
source.GetRight=function() return 400 end
source.GetTop=function() return 500 end
A.frame:SetScale(0.8)
local raised, point
A.frame.SetFrameLevel=function(_,level) raised=level end
A.frame.GetFrameLevel=function() return raised or 1 end
A.frame.SetPoint=function(_,...) point={...} end
RaynnaCodexAPI.OpenItem(3371,source)
assert(raised>=210, 'Codex above caller')
assert(point[1]=='TOPLEFT' and point[4]==410 and point[5]==500, 'scaled right placement')
source.GetLeft=function() return 2200 end
source.GetRight=function() return 2500 end
RaynnaCodexAPI.OpenItem(3371,source)
assert(point[4]==1840, 'left placement near screen edge')
A.NavigateItem(765)
assert(raised>=210, 'navigation preserves foreground priority')
""")
print('PASS: scaled adjacent placement, screen-edge placement and Codex foreground priority')

lua.execute("""
SlashCmdList.RAYNNABESTIARY('hide')
ALT_DOWN=false
RaynnaBestiaryFrame.OnEvent(nil,'MODIFIER_STATE_CHANGED','LALT',0)
GameTooltip.GetItem=function() return nil end
GameTooltip.GetUnit=function() return nil,'nameplate1' end
UnitGUID=function(unit) assert(unit=='nameplate1');return 'Creature-0-1-2-3-269175-1' end
UnitName=function() error('unavailable name') end
local secret={}
UnitLevel=function() return secret end
issecretvalue=function(value) return value==secret end
ALT_DOWN=true
RaynnaBestiaryFrame.OnEvent(nil,'UPDATE_MOUSEOVER_UNIT')
assert(A.frame:IsShown() and not RaynnaBestiaryFrame:IsShown(), 'readable dungeon ID opens shared panel')
assert(A.frame.name.labelText=='Carnivorous Weed')
SlashCmdList.RAYNNABESTIARY('hide')
UnitGUID=function() return secret end
RaynnaBestiaryFrame.OnEvent(nil,'UPDATE_MOUSEOVER_UNIT')
assert(not A.frame:IsShown(), 'restricted GUID is never inspected')
assert(not RaynnaModsSettingsRegistry.pages.codex, 'one settings entry')
""")
print('PASS: dungeon tooltip token, unavailable name/level, restricted GUID and single settings page')

lua.execute("""
local count,relationships=0,0
for _,dungeon in pairs(B.DungeonReference) do
 count=count+1
 for id,boss in pairs(dungeon.bosses) do
  for _,item in ipairs(boss.loot) do
   relationships=relationships+1
   assert(B.ReferenceMonster(id).drops[item], 'forward dungeon relationship')
  end
 end
end
assert(count==34 and relationships==1475)
local rows=A.BuildSources(286979)
local seen=false
for _,row in ipairs(rows) do
 assert(not row.detail:find('Lv 0',1,true), 'no zero levels')
 if row.npcID==256040 then
  seen=true;assert(row.detail:find('15-16',1,true) and row.detail:find('Ruins of Lordaeron',1,true))
 end
end
assert(seen)
assert(B.ReferenceMonster(256040).minLevel==15)
assert(B.BundledMetadata.sourceVersion=='1.1.3')
assert(B.LevelText({minLevel=0,maxLevel=0})=='?')
local dungeon=B.DungeonReference['ruins-of-lordaeron']
for id,boss in pairs(dungeon.bosses) do
 if #boss.loot>0 then assert(B.ReferenceItem(boss.loot[1]).drops[id]) end
end
""")
print('PASS: broad dungeon forward/reverse coverage, Forever levels/zones, missing level handling and snapshot version')

lua.execute("""
assert(B.PortraitDisplays[250622]==414 and B.PortraitDisplays[250624]==7550)
assert(B.ReferenceMonster(250622).minLevel==15)
assert(B.ReferenceMonster(250623).maxLevel==16)
local reference,additional=A.ReferenceItem,A.AdditionalSources
A.ReferenceItem=function() return {drops={ [1]={name='Unknown',foreverSource=true},[2]={name='Known low',rate=0.5},[3]={name='Known high',rate=20} }} end
A.AdditionalSources=function() return {{title='Chest',kind='Object'}} end
local sorted=A.BuildSources(99999999)
assert(sorted[1].title=='Known high' and sorted[2].title=='Known low')
assert(sorted[3].rate==nil and sorted[4].rate==nil)
A.ReferenceItem=reference;A.AdditionalSources=additional
""")
print('PASS: Forever portrait mappings, NPC levels, known rates ahead of unknown across source groups')

lua.execute("""
assert(A.SourceDetail({npcID=250622,detail='Chance unknown / Level unknown'}):find('|cffe68b8bChance unknown|r',1,true))
assert(A.SourceDetail({kind='Vendor',detail='Vendor / City'}):find('|cff65d9db[Vendor]|r',1,true))
assert(A.SourceStyle({title='[Quest] Example'})=='Quest')
assert(A.SourceStyle({recipe={}})=='Crafting')
""")
print('PASS: source labels, accessible missing-data colours and preserved sorting values')

lua.execute("""
local frost=A.EffectText('Equip: Increases damage done by Frost spells and effects by up to 32.')
assert(frost:find('|cff70cfffFrost|r',1,true))
assert(frost:find('|cff78df8732.',1,true))
assert(A.EffectText('Equip: Increases Arcane damage by 6.'):find('|cffc59bffArcane|r',1,true))
local existing='Restore |cff78df87100|r mana'
assert(A.EffectText(existing)==existing)
assert(A.EffectText('Increases damage taken by 5%'):find('|cffe68b8b5%|r',1,true))
assert(A.ColourMissing('No specific use recorded'):find('|cffe68b8b',1,true))
""")
print('PASS: school colours, beneficial/harmful amounts and existing markup preservation')

lua.execute("""
local colours={Strength='f28b82',Agility='8bdc73',Intellect='79b9ff',Stamina='f3bf70',Spirit='d6a0ed'}
for stat,colour in pairs(colours) do
 assert(A.EffectText('+8 '..stat):find('|cff'..colour..stat..'|r',1,true))
 assert(A.EffectText('Increases '..stat:lower()..' by 8'):find('|cff'..colour..stat:lower()..'|r',1,true))
end
assert(not A.HasStatText('Spiritual guidance'))
local line=CreateFrame('Frame');line:SetText('+8 Intellect')
_G.TestStatTipTextLeft1=line
A.ColourItemTooltip({GetName=function() return 'TestStatTip' end,NumLines=function() return 1 end})
assert(line:GetText():find('|cff79b9ffIntellect|r',1,true))
""")
print('PASS: primary-stat colours in descriptions and plain tooltip stat lines')

lua.execute("""
assert(A.EntryActionHint({url='https://example.com',itemID=3371})=='Select link >')
assert(A.EntryActionHint({action='ingredients',recipe={},itemID=3371})=='Ingredients >')
assert(A.EntryActionHint({itemID=3371})=='View item >')
assert(A.EntryActionHint({})==nil)
local lookup=A.SourceLocations
A.SourceLocations=function() return {{area=12,x=40,y=50}} end
assert(A.EntryActionHint({npcID=66})=='View NPC >')
A.SourceLocations=function() return {} end
assert(A.EntryActionHint({npcID=66})=='View NPC >')
A.SourceLocations=lookup
""")
print('PASS: hover action hints match click precedence and omit unavailable map actions')

lua.execute("""
B.BestiaryDemo()
local title=A.frame.name.labelText
B.OpenItem(3371,true,RaynnaBestiaryFrame)
assert(not RaynnaBestiaryFrame:IsShown() and A.frame:IsShown())
assert(A.frame.breadcrumb.labelText:find(title,1,true))
A.NavigateItem(765);A.GoBack()
assert(A.currentItem==3371 and A.frame:IsShown())
A.GoBack()
assert(A.frame:IsShown() and not RaynnaBestiaryFrame:IsShown())
assert(A.frame.name.labelText==title and A.currentNPC)
""")
print('PASS: in-place monster/item navigation, breadcrumb and nested Back history')

lua.execute("""
local point,n=A.DensestSpawn({{area=1,x=1,y=1},{area=1,x=50,y=50},{area=1,x=51,y=50},{area=1,x=52,y=50},{area=2,x=1,y=1}})
assert(n==3 and point.area==1 and point.x==50)
local p,count=A.DensestSpawn({{area=1,x=1,y=1},{area=1,x=1,y=1},{area=2,x=1,y=1}})
assert(count==1,'duplicates and other zones do not inflate density')
""")
print('PASS: densest spawn selection, deduplication and zone isolation')

lua.execute("""
WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
local canvas=CreateFrame('Frame');canvas:SetSize(1000,700)
WorldMapFrame.GetCanvas=function() return canvas end
WorldMapFrame.GetMapID=function() return 37 end
assert(A.ShowSpawnHighlights(37,{{area=12,x=40,y=50},{area=12,x=42,y=51}},12))
WorldMapFrame.GetMapID=function() return 38 end
assert(A.ShowSpawnHighlights(37,{{area=12,x=40,y=50}},12))
""")
print('PASS: map-canvas overlay initialization and different-map guard')

lua.execute("""
local sample={{title='Wolf',detail='Forest',npcID=1,rate=5},{title='Wolf',detail='Desert',npcID=2},{title='Vendor',detail='Forest',kind='Vendor'}}
assert(#A.FilterEntries(sample,'Forest','All',false)==2)
assert(#A.FilterEntries(sample,'','Monster drop',true)==1)
assert(#A.FilterEntries(sample,'Forest','Vendor',false)==1)
A.ShowItem(3371,true)
A.frame.saveItem.OnClick()
assert(A.db.favourites[3371] and #A.FavouriteEntries()==1)
A.frame.saveItem.OnClick()
assert(not A.db.favourites[3371])
local fullHeight=A.frame:GetHeight()
A.frame.listFilter:SetText('no_match_for_this_filter')
A.frame.listFilter.OnTextChanged(A.frame.listFilter)
assert(A.frame:GetHeight()==301 and not A.frame.scroll:IsShown())
A.frame.clearFilter.OnClick()
assert(A.frame.listFilter:GetText()=='')
""")
print('PASS: list filters, favourites toggle and compact no-match layout')

lua.execute("""
local exact='item:15309:0:0:0:0:0:760:0'
B.OpenItem(exact,true)
assert(A.currentLink==exact and A.currentItem==15309)
local received
A.tooltip.SetHyperlink=function(_,link) received=link end
A.frame.headerItem.OnEnter(A.frame.headerItem)
assert(received==exact)
A.NavigateItem(3371);A.GoBack();assert(A.currentLink==exact)
local saved=C_TooltipInfo
C_TooltipInfo={GetHyperlink=function(link)
    assert(link==exact)
    return {lines={{leftText='Item Level 15'},{leftText='+1 Intellect'}, {leftText='Equip: Increases damage by 5.'},{leftText='Set: Increases healing by 10.'}}}
end}
assert(#A.ItemDetailRows(exact)==4)
A.Refresh()
C_TooltipInfo=saved
local overlay=A.spawnOverlay
WorldMapFrame.GetMapID=function() return 37 end
overlay.OnUpdate(overlay,0.2)
assert(overlay.legend:IsShown())
WorldMapFrame.GetMapID=function() return 38 end
overlay.OnUpdate(overlay,0.2)
assert(not overlay.legend:IsShown())
overlay.legend.OnClick();assert(not overlay:IsShown())
""")
print('PASS: exact item suffix preservation, native tooltip, full item details, delayed map changes and clear highlights')

lua.execute("""
local list=A.BuildSources(3371)
local found=false
for _,entry in ipairs(list) do
    if entry.npcID then
        assert(entry.sourceLayout and type(entry.location)=='string' and type(entry.levelText)=='string')
        found=true
    end
end
assert(found)
""")
print('PASS: independent source name, location, level and chance fields')

lua.execute("""
local oldMap=C_Map
C_Map.GetBestMapForUnit=function() return 37 end
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .9,.5 end} end
C_Map.GetWorldPosFromMapPos=nil
local points=A.SourceLocations(66)
-- Existing map resolver fixture maps Elwynn Forest (area 12) to 37.
local pick=A.NearestSpawn({{area=12,x=10,y=50},{area=12,x=89,y=50}})
assert(pick and pick.x==89,'nearest location must win over first entry')
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
C_Map.GetWorldPosFromMapPos=function(map,vector)
    local x,y=vector:GetXY()
    return 1,CreateVector2D(x*1000+(map==38 and 1000 or 0),y*700)
end
local nearby=A.NearestSpawn({{area=12,x=10,y=50},{area=40,x=1,y=50}})
assert(nearby and nearby.area==40,'compare world distances across adjacent zones')
C_Map.GetPlayerMapPosition=function() return nil end
assert(A.NearestSpawn(points)==nil,'missing player position must use explicit fallback')
C_Map=oldMap
""")
print('PASS: nearest spawn selection and unavailable-player-position fallback')

lua.execute("""
local saved=C_TooltipInfo
C_TooltipInfo={GetHyperlink=function()
    local lines={{leftText='Item Level 15'},{leftText='+1 Intellect'}, {leftText='Set: Increases healing by 10.'}}
    for i=1,20 do lines[#lines+1]={leftText='Equip: Increases damage by '..i} end
    return {lines=lines}
end}
A.ShowItem('item:15309:0:0:0:0:0:760:0',true)
assert(A.frame.summary:GetText():find('Intellect',1,true))
assert(A.frame.summary:GetText():find('Set:',1,true))
assert(A.frame.summaryBar:IsShown() and A.frame.summaryRange>0)
assert(A.frame.headerShift==92)
C_TooltipInfo=saved
""")
print('PASS: inline item stats and set text, scrollable overflow and dynamic header layout')

lua.execute("""
local function plain(text) return text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
assert(plain(A.EffectText('Use: Restores 530 health. (1 |4Sec:Secs; Cooldown)'))=='Use: Restores 530 health. (1 Sec Cooldown)')
assert(plain(A.EffectText('(2 |4Min:Minutes; Cooldown)'))=='(2 Minutes Cooldown)')
assert(plain(A.EffectText('1 |4charge:charges; and 3 |4charge:charges;'))=='1 charge and 3 charges')
assert(A.EffectText('|4Sec:Secs;'):find('|4Sec:Secs;',1,true))
""")
print('PASS: cooldown plural markup, singular/plural units and unpaired control preservation')

lua.execute("""
local regions=A.BuildSpawnAreas({{area=12,x=10,y=10},{area=12,x=12,y=12},{area=12,x=80,y=80}})
assert(#regions==2,'distant camps must not be joined')
local spans=A.SpawnAreaSpans(regions)
assert(#spans>0)
for _,span in ipairs(spans) do
 assert(span.left>=0 and span.right<=100 and span.right>span.left)
 assert(not (span.top>20 and span.top<70),'do not fill the empty space between camps')
end
local clipped=A.BuildSpawnAreas({{area=12,x=0,y=0},{area=12,x=100,y=100}})
for _,polygon in ipairs(clipped) do
 for _,point in ipairs(polygon) do assert(point.x>=0 and point.x<=100 and point.y>=0 and point.y<=100) end
end
local single=A.SpawnAreaSpans({regions[1]})
local duplicate=A.SpawnAreaSpans({regions[1],regions[1]})
assert(#single==#duplicate,'overlapping regions should not stack opacity')
assert(#A.BuildSpawnAreas({})==0 and #A.SpawnAreaSpans({})==0)
""")
print('PASS: spawn-area grouping, separated camps, map clipping and overlap-union fill')

lua.execute("""
-- Explicit navigation pins the shared browser; hover alone does not.
A.pinned=false
B.ShowBestiary(B.ReferenceMonster(587),false,false)
assert(A.currentNPC.npcID==587 and A.frame:IsShown() and not RaynnaBestiaryFrame:IsShown())
assert(A.frame.navigationTabs.uses:GetText()=='Drops')
assert(A.frame.navigationTabs.sources:GetText()=='Show on map')
A.NavigateItem(3371)
A.NavigateNPC({npcID=66})
assert(A.currentNPC.npcID==66 and A.pinned)
A.GoBack();assert(A.currentItem==3371)
A.GoBack();assert(A.currentNPC.npcID==587)
A.frame.saveItem.OnClick();assert(A.db.favouriteNPCs[587])
assert(type(A.frame.scroll.Update)=='function' and type(A.frame.summaryBar.Update)=='function')
-- Switching from a monster to an item must not inherit a stale item lock.
A.pinned=false
ALT_DOWN=false;RaynnaBestiaryFrame.OnEvent(nil,'MODIFIER_STATE_CHANGED','LALT',0)
ALT_DOWN=true;B.ShowBestiary(B.ReferenceMonster(587),false,false)
GameTooltip.GetUnit=function() return nil end
GameTooltip.GetItem=function() return 'Vial','item:3371' end
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=3371})
assert(A.currentItem==3371 and not A.currentNPC)
ALT_DOWN=false;RaynnaBestiaryFrame.OnEvent(nil,'MODIFIER_STATE_CHANGED','LALT',0)
ALT_DOWN=true;B.ShowBestiary(B.ReferenceMonster(66),false,false)
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=765})
assert(A.currentItem==765 and not A.currentNPC)
-- Auto-focus occurs only once, after the requested map is actually active.
local calls,zoom=0,nil
WorldMapFrame.ScrollContainer={GetScaleForMinZoom=function() return 1 end,GetCanvasScale=function() return 1 end,
 SetZoomTarget=function(_,v) zoom=v end,SetPanTarget=function(_,x,y) calls=calls+1;assert(x==.4 and y==.5) end}
WorldMapFrame.GetMapID=function() return 38 end
A.ShowSpawnHighlights(37,{{area=12,x=40,y=50}},12,{title='Test wolf',levelText='Lv 10-12'},{area=12,x=40,y=50})
A.spawnOverlay.OnUpdate(A.spawnOverlay,.2);assert(calls==0)
WorldMapFrame.GetMapID=function() return 37 end
A.spawnOverlay.OnUpdate(A.spawnOverlay,.2)
assert(calls==1 and zoom==1.25)
assert(A.spawnOverlay.regionLabels[1]:GetText()=='Test wolf\\nLv 10-12')
A.spawnOverlay.OnUpdate(A.spawnOverlay,7)
assert(calls==1 and not A.spawnOverlay.pulse:IsShown())
local region=A.BuildSpawnAreas({{area=12,x=50,y=50}})[1]
assert(#region==32,'smooth padded outline')
local minX,maxX=100,0
for _,point in ipairs(region) do minX=math.min(minX,point.x);maxX=math.max(maxX,point.x) end
assert(maxX-minX>4,'larger shaded area')
""")
print('PASS: shared NPC/item navigation, gold scrollbars, repeated hover transitions, map label, one-shot zoom and finite pulse')

lua.execute("""
assert(A.IsQuestEntry({quest=true}))
assert(A.IsQuestEntry({title='|cffffd45c[Quest]|r Tusk'}))
assert(A.IsQuestEntry({kind='Quest reward'}))
assert(not A.IsQuestEntry({title='Silk Cloth'}))
""")
print('PASS: quest badge detection for drops, quest uses and quest rewards')

lua.execute("""
A.pinned=false;ALT_DOWN=false
A.ShowItem(3371,false)
A.NavigateItem(765)
assert(A.pinned and A.frame.pin:GetText()=='Unpin')
A.frame.OnUpdate(A.frame,.2)
assert(A.frame:IsShown(),'clicked destination survives cursor leaving a shorter panel')
A.frame.pin.OnClick()
assert(not A.pinned)
A.frame.OnUpdate(A.frame,.2)
assert(not A.frame:IsShown(),'unpin restores hover dismissal')
""")
print('PASS: navigation pins before resize and Unpin restores automatic dismissal')

lua.execute("""
assert(A.SourceDetail({lootLayout=true,detail='Quest item',referenceSource='cMaNGOS',conditional=true})=='Quest item')
assert(A.SourceDetail({lootLayout=true,detail=''})=='')
""")
print('PASS: clean loot-row labels without losing reference metadata')

lua.execute("""
local x,y,w,h=A.SpawnAreaLabelBounds({{x=10,y=10},{x=30,y=10},{x=30,y=30},{x=10,y=30}})
assert(x==20 and y==20 and w==20 and h==20)
WorldMapFrame.GetMapID=function() return 37 end
A.ShowSpawnHighlights(37,{{area=12,x=10,y=10},{area=12,x=80,y=80}},12,{title='Wolf',levelText='Lv 10'},{x=10,y=10})
assert(A.spawnOverlay.regionLabels[1]:IsShown() and A.spawnOverlay.regionLabels[2]:IsShown())
assert(A.spawnOverlay.regionLabels[2]:GetText()==A.spawnOverlay.regionLabels[1]:GetText())
A.ShowSpawnHighlights(37,{{area=12,x=10,y=10}},12,{title='Wolf',levelText='Lv 10'},{x=10,y=10})
assert(not A.spawnOverlay.regionLabels[2]:IsShown(),'unused region labels are hidden')
""")
print('PASS: centred labels on every region and stale-label cleanup')

lua.execute("""
local square={{x=10,y=10},{x=30,y=10},{x=30,y=30},{x=10,y=30}}
assert(A.SpawnAreaContains(square,20,20))
assert(not A.SpawnAreaContains(square,35,20))
A.spawnOverlay.legend.OnEnter(A.spawnOverlay.legend)
assert(A.spawnOverlay.areaTooltip:IsShown())
A.spawnOverlay.legend.OnLeave()
assert(not A.spawnOverlay.areaTooltip:IsShown())
A.spawnOverlay.legend.OnEnter(A.spawnOverlay.legend)
A.spawnOverlay.legend.OnClick()
assert(not A.spawnOverlay.areaTooltip:IsShown())
""")
print('PASS: polygon hover detection, Clear tooltip and tooltip cleanup')

lua.execute("""
A.pinned=false;ALT_DOWN=true
GameTooltip.GetUnit=function() return nil end
GameTooltip.GetItem=function() return 'Vial','item:3371' end
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=3371})
A.NavigateItem(765);assert(A.pinned)
A.frame:Hide()
assert(not A.pinned and not A.manualOpen)
ITEM_TOOLTIP_CALLBACK(GameTooltip,{id=3371})
assert(A.currentItem==3371 and A.frame:IsShown(),'hidden pin and item lock must not block next item')
A.frame:Hide()
GameTooltip.GetItem=function() return nil end
GameTooltip.GetUnit=function() return nil,'mouseover' end
UnitGUID=function() return 'Creature-0-1-2-3-587-1' end
UnitName=function() return 'Bloodscalp Warrior' end
UnitLevel=function() return 34 end
RaynnaBestiaryFrame.OnEvent(nil,'UPDATE_MOUSEOVER_UNIT')
assert(A.currentNPC and A.currentNPC.npcID==587 and A.frame:IsShown(),'NPC hover works after hidden navigation')
""")
print('PASS: hiding pinned navigation releases pin and Alt item lock for both hover modes')

lua.execute("""
local original=A.ItemInfo
local lookedUp={}
A.ItemInfo=function(id,...) lookedUp[id]=true;return original(id,...) end
A.ShowNPC(B.ReferenceMonster(587),false,false)
local calls=0
for _ in pairs(lookedUp) do calls=calls+1 end
assert(calls<=7,'first draw requested offscreen loot')
lookedUp={}
A.frame.OnEvent(A.frame,'GET_ITEM_INFO_RECEIVED',999999,true)
assert(not next(lookedUp),'unrelated item event rebuilt the creature panel')
A.ItemInfo=original
""")
print('PASS: opening a creature only requests visible items and ignores unrelated item events')
