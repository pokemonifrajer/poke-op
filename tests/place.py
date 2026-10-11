"""Inspect generated place structure, source fidelity and basic geometric access.
This is XML/static verification, NOT a Roblox Studio playtest.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import hashlib,json,re
root_dir=Path(__file__).resolve().parents[1]
root=E.parse(root_dir/'dist/HarborCity.rbxlx').getroot()
items=list(root.iter('Item'))
def name(el): return el.findtext("Properties/string[@name='Name']")
def child(el,n): return next(x for x in el.findall('Item') if name(x)==n)
def pos(el): return tuple(float(el.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{a}")) for a in 'XYZ')
def size(el): return tuple(float(el.findtext(f"Properties/Vector3[@name='size']/{a}")) for a in 'XYZ')
workspace=child(root,'Workspace'); city=child(workspace,'City'); markers=child(city,'Markers')
marker_names={name(x) for x in markers.findall('Item')}
source='\n'.join(p.read_text() for p in (root_dir/'src/server').glob('*.lua'))
required=set(re.findall(r':bind\("(\w+)"',source))|{'VaultDoor','GarageCar','PoliceCar','PrisonSpawn','PrisonOutside','TunnelStart','HomeInside','AirportDesk',
    'HomeDesk','HomeEnter','HomeLeave','WestwoodHomeDesk','WestwoodHomeEnter','WestwoodHomeInside','WestwoodHomeLeave',
    'NorthHillHomeDesk','NorthHillHomeEnter','NorthHillHomeInside','NorthHillHomeLeave','AutohausBusiness','CourierBusiness'}
assert required<=marker_names,required-marker_names
assert workspace.findtext("Properties/bool[@name='StreamingEnabled']")=='true'
traffic=child(city,'TrafficLights')
signals=[x for x in traffic.findall('Item') if x.get('class')=='Model' and name(x)=='Signal']
assert len(signals)>=10
for signal in signals:
    assert {'Red','Amber','Green'} <= {name(x) for x in signal.findall('Item')}
assert len({x.get('referent') for x in items})==len(items)
for branch,folder in [('shared',child(child(root,'ReplicatedStorage'),'Shared')),('server',child(child(root,'ServerScriptService'),'Server')),('client',child(child(child(root,'StarterPlayer'),'StarterPlayerScripts'),'Client'))]:
    for path in (root_dir/'src'/branch).glob('*.lua'):
        expected=path.stem.replace('.server','').replace('.client','')
        node=child(folder,expected)
        assert node.findtext("Properties/ProtectedString[@name='Source']")==path.read_text(),path
        assert node.get('class')==('Script' if '.server.' in path.name else 'LocalScript' if '.client.' in path.name else 'ModuleScript')
# Walkable doorway and terminal/vault geometry checks. Door is meant to block the vault.
solid=[]
for obj in items:
    if obj.get('class') in ('Part','SpawnLocation','Seat') and obj.findtext("Properties/bool[@name='CanCollide']")=='true':
        solid.append((obj,pos(obj),size(obj)))
def inside(point,obj,center,extent,pad=0):
    # Authored collidable parts are axis aligned except one decorative fountain sculpture.
    return all(abs(point[i]-center[i])<extent[i]/2+pad for i in range(3))
for marker_name in ('BankTerminal','BankLoot','PrisonLaundry','PrisonExit','TunnelExit','JobDepot','PoliceDesk'):
    mark=child(markers,marker_name); x,y,z=pos(mark)
    # A player approaches the south face from 5 studs away at standing center height.
    approach=(x,max(y,3),z+5)
    assert not any(inside(approach,obj,c,s,0.3) for obj,c,s in solid),f'Blocked approach: {marker_name}'
for point in [(-84,4,-47),(-84,4,-43),(84,4,-55),(84,4,-51),(-85,4,119),(-85,4,123),(-267,4,115),(390,4,372),(390,4,376),(-350,4,277),(320,4,-316)]:
    assert not any(inside(point,obj,c,s,0.2) for obj,c,s in solid),f'Blocked entrance: {point}'
for x in range(0,136,5):
    assert not any(inside((x,-10,-367),obj,c,s,0.2) for obj,c,s in solid),'Tunnel obstructed'
for obj,c,s in solid:
    assert all(v>0 for v in s),name(obj)
    assert obj.find("Properties/Color3uint8[@name='Color3uint8']") is not None
scripts=[x for x in items if x.get('class') in ('Script','LocalScript','ModuleScript')]
assert all('require(\"http' not in (x.findtext("Properties/ProtectedString[@name='Source']") or '') for x in scripts)
manifest=json.loads((root_dir/'dist/build-manifest.json').read_text())
assert manifest['sha256']==hashlib.sha256((root_dir/'dist/HarborCity.rbxlx').read_bytes()).hexdigest()
assert manifest['runtime_tested'] is False
print(f'PLACE STATIC TESTS PASSED: {len(items)} instances, {len(scripts)} scripts, {len(required)} required markers; source matches; entrances and tunnel clear.')
