#!/usr/bin/env python3
"""Deterministic .rbxlx authoring. Standard library only, no external assets or plugins.
The place contains the static environment and every script before Studio opens it.
"""
from pathlib import Path
import math, json, hashlib, xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[1]
REF=0
MATERIAL={'plastic':256,'neon':288,'concrete':816,'brick':848,'slate':800,'metal':1088,'wood':512,'grass':1280,'sand':1296,'glass':1568,'asphalt':1376}
C={'ink':(26,35,48),'navy':(36,53,68),'stone':(167,169,161),'light':(215,213,200),'teal':(72,151,160),'gold':(226,174,97),'road':(49,55,62),'walk':(148,153,151),'grass':(78,109,93),'glass':(78,116,135),'wood':(115,86,62),'slate':(82,91,98)}
root=E.Element('roblox',{'version':'4'})
E.SubElement(root,'External').text='null'; E.SubElement(root,'External').text='nil'
def prop(item,typ,name,val):
    props=item.find('Properties'); p=E.SubElement(props,typ,{'name':name})
    if typ in ('Vector3','Color3'):
        tags=('X','Y','Z') if typ=='Vector3' else ('R','G','B')
        for tag,x in zip(tags,val): E.SubElement(p,tag).text=str(x)
    elif typ=='CoordinateFrame':
        x,y,z,yaw=val; co,si=math.cos(yaw),math.sin(yaw)
        for tag,v in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],[x,y,z,co,0,si,0,1,0,-si,0,co]): E.SubElement(p,tag).text=str(v)
    elif typ=='Content': E.SubElement(p,'url').text=val
    elif typ=='bool': p.text='true' if val else 'false'
    else: p.text=str(val)
    return p

def item(parent,cls,name):
    global REF
    REF+=1; el=E.SubElement(parent,'Item',{'class':cls,'referent':f'RBX{REF:08d}'})
    E.SubElement(el,'Properties'); prop(el,'string','Name',name); return el

def folder(parent,name): return item(parent,'Folder',name)
def part(parent,name,pos,size,color='stone',mat='concrete',yaw=0,collide=True,trans=0,cls='Part'):
    p=item(parent,cls,name)
    prop(p,'Vector3','size',size); prop(p,'CoordinateFrame','CFrame',(*pos,yaw))
    rgb=C.get(color,color); prop(p,'Color3uint8','Color3uint8',(255<<24)|(rgb[0]<<16)|(rgb[1]<<8)|rgb[2])
    prop(p,'token','Material',MATERIAL[mat]); prop(p,'bool','Anchored',True)
    prop(p,'bool','CanCollide',collide); prop(p,'bool','CanTouch',collide)
    prop(p,'bool','CanQuery',collide); prop(p,'float','Transparency',trans)
    prop(p,'token','TopSurface',0); prop(p,'token','BottomSurface',0)
    return p

def sign(parent,text,pos,width=18,height=3,color='light',bg='ink',yaw=0):
    p=part(parent,'Sign_'+text,pos,(width,height,0.35),bg,'metal',yaw,False)
    gui=item(p,'SurfaceGui','Typography'); prop(gui,'token','Face',5); prop(gui,'float','PixelsPerStud',40); prop(gui,'token','SizingMode',1)
    label=item(gui,'TextLabel','Label'); prop(label,'string','Text',text); prop(label,'float','BackgroundTransparency',1)
    prop(label,'bool','TextScaled',True); prop(label,'token','Font',4)
    prop(label,'Color3','TextColor3',tuple(x/255 for x in C.get(color,color)))
    size=E.SubElement(label.find('Properties'),'UDim2',{'name':'Size'})
    for tag,value in [('XS',1),('XO',0),('YS',1),('YO',0)]: E.SubElement(size,tag).text=str(value)
    return p

def marker(name,pos,size=(2,2,2),color='teal',visible=True):
    p=part(markers,name,pos,size,color,'metal',collide=False,trans=0 if visible else 1)
    if visible:
        light=item(p,'PointLight','InteractionGlow'); prop(light,'float','Brightness',0.4); prop(light,'float','Range',10); prop(light,'Color3','Color',(0.38,0.77,0.78))
    return p

def building(name,x,z,w,d,h,color='stone',interior=False):
    model=item(blocks,'Model',name)
    if not interior:
        part(model,'Core',(x,h/2+0.5,z),(w,h,d),color)
    else:
        part(model,'Floor',(x,0.6,z),(w,1,d),'light')
        part(model,'Back',(x,h/2+0.6,z-d/2),(w,h,1),color)
        part(model,'West',(x-w/2,h/2+0.6,z),(1,h,d),color)
        part(model,'East',(x+w/2,h/2+0.6,z),(1,h,d),color)
        # Entrance faces south (+Z), a wide open actual doorway, not a texture.
        width=(w-10)/2
        for side in (-1,1): part(model,'Front',(x+side*(5+width/2),h/2+0.6,z+d/2),(width,h,1),color)
        part(model,'EntranceLintel',(x,h-2,z+d/2),(10,5,1),color)
    part(model,'Cornice',(x,h+0.8,z),(w+2,1.4,d+2),'light')
    part(model,'Roof',(x,h+1.7,z),(w,0.5,d),'ink','slate')
    if h>22:
        for floor in range(8,int(h)-3,10):
            for xx in range(int(-w/2)+5,int(w/2)-2,9):
                for side in (-1,1): part(model,'FacadeGlazing',(x+xx,floor,z+side*(d/2+0.08)),(5.2,5.8,0.15),'glass','glass',collide=False)
            for zz in range(int(-d/2)+5,int(d/2)-2,10):
                for side in (-1,1): part(model,'SideGlazing',(x+side*(w/2+0.08),floor,z+zz),(0.15,5.8,5.5),'glass','glass',collide=False)
    return model

def bench(parent,x,z,yaw=0):
    part(parent,'BenchSeat',(x,2,z),(7,0.5,2),'wood','wood',yaw)
    part(parent,'BenchBack',(x,3.2,z+0.8),(7,1.6,0.35),'wood','wood',yaw)
    for dx in (-2.7,2.7): part(parent,'BenchLeg',(x+dx,1,z),(0.35,2,1.8),'ink','metal')

def tree(x,z,scale=1):
    part(land,'Trunk',(x,4*scale,z),(1.5*scale,8*scale,1.5*scale),'wood','wood')
    p=part(land,'Canopy',(x,10*scale,z),(10*scale,12*scale,10*scale),'grass','grass',collide=False)
    prop(p,'token','shape',0)

def lamp(x,z):
    part(lights,'Pole',(x,7,z),(0.45,14,0.45),'ink','metal')
    part(lights,'Arm',(x+1.5,14,z),(3.5,0.4,0.5),'ink','metal')
    p=part(lights,'Lamp',(x+3,13.7,z),(1.8,0.2,1),'light','neon',collide=False)
    l=item(p,'PointLight','StreetLight'); prop(l,'float','Range',32); prop(l,'float','Brightness',1.1); prop(l,'bool','Shadows',False); prop(l,'bool','Enabled',False); prop(l,'Color3','Color',(1,0.84,0.64))

def add_script(parent,path):
    name=path.stem; cls='ModuleScript'
    if name.endswith('.server'): name=name[:-7]; cls='Script'
    elif name.endswith('.client'): name=name[:-7]; cls='LocalScript'
    obj=item(parent,cls,name); prop(obj,'ProtectedString','Source',path.read_text()); return obj

workspace=item(root,'Workspace','Workspace'); prop(workspace,'bool','StreamingEnabled',True); prop(workspace,'int','StreamingMinRadius',96); prop(workspace,'int','StreamingTargetRadius',384); prop(workspace,'float','Gravity',196.2)
city=item(workspace,'Model','City'); markers=folder(city,'Markers'); blocks=folder(city,'Buildings'); roads=folder(city,'Roads'); land=folder(city,'Landscape'); lights=folder(city,'StreetLights'); traffic=folder(city,'TrafficLights'); alarms=folder(city,'AlarmLights')
# Ground is split around the underground prison route so the tunnel is physically empty.
part(land,'DowntownGround',(0,-2,60),(860,4,680),'grass','grass')
part(land,'PrisonGroundWest',(-220,-2,-365),(420,4,170),'grass','grass')
part(land,'PrisonGroundEast',(291,-2,-365),(278,4,170),'grass','grass')
part(land,'PrisonNorth',(70,-2,-412),(160,4,76),'grass','grass')
part(land,'PrisonSouth',(70,-2,-317),(160,4,86),'grass','grass')
part(land,'TunnelRoof',(65,-0.5,-367),(164,1,15),'stone')
# Ocean and promenade on the east edge.
part(land,'HarborWater',(378,-1.1,30),(102,1,710),(48,95,112),'glass',collide=False,trans=0.2)
part(land,'Quay',(309,0.3,10),(34,1,720),'walk')
part(land,'Seawall',(327,-0.5,10),(2,5,720),'stone')
for z in range(-320,360,28):
    part(land,'QuayBollard',(323,1.5,z),(1,2.7,1),'ink','metal')
# Ordered street grid with pedestrian sidewalks and crossing markings.
for axis in ('x','z'):
    for offset in (-180,0,180):
        pos=(0,0.12,offset) if axis=='x' else (offset,0.12,40)
        size=(640,0.24,36) if axis=='x' else (36,0.24,720)
        part(roads,'Boulevard',pos,size,'road','asphalt')
        for side in (-1,1):
            spos=(0,0.4,offset+side*23) if axis=='x' else (offset+side*23,0.4,40)
            ssize=(640,0.8,10) if axis=='x' else (10,0.8,720)
            part(roads,'Sidewalk',spos,ssize,'walk')
        for k in range(-300,351,18):
            if min(abs(k-v) for v in (-180,0,180))>26:
                p=(k,0.27,offset) if axis=='x' else (offset,0.27,k)
                s=(8,0.04,0.35) if axis=='x' else (0.35,0.04,8)
                part(roads,'LaneMark',p,s,'light','plastic',collide=False)
for x in (-180,0,180):
    for z in (-180,0,180):
        for side in (-1,1):
            for k in range(-13,14,4):
                part(roads,'Crosswalk',(x+k,0.28,z+side*25),(2.4,0.04,7),'light','plastic',collide=False)
                part(roads,'Crosswalk',(x+side*25,0.28,z+k),(7,0.04,2.4),'light','plastic',collide=False)
            part(traffic,'SignalPole',(x+side*25,5,z+side*25),(0.5,10,0.5),'ink','metal')
            part(traffic,'Signal',(x+side*25,9,z+side*25),(1.1,1.6,1.1),(91,201,143),'neon',collide=False)
for x in (-155,155):
    for z in range(-220,341,70): lamp(x,z)
for z in (-155,155):
    for x in range(-290,301,70): lamp(x,z)
# Civic Bank: walkable lobby, security terminal, separate vault.
bank=building('CIVIC BANK',-84,-84,88,72,20,'light',True)
sign(bank,'C I V I C   B A N K',(-84,15,-47.6),60,4,'ink','light',math.pi)
part(bank,'VaultWallL',(-108,8,-91),(36,16,1),'navy')
part(bank,'VaultWallR',(-63,8,-91),(34,16,1),'navy')
part(bank,'VaultLintel',(-85,15,-91),(10,2,1),'navy')
vault=part(markers,'VaultDoor',(-85,7,-91),(10,14,1.5),'ink','metal')
for x in (-112,-56):
    part(bank,'Counter',(x,2.5,-70),(18,5,6),'wood','wood')
    part(bank,'CounterTop',(x,5.1,-70),(18.5,0.35,6.5),'ink','metal')
for x in (-108,-97,-72,-61):
    part(bank,'DepositBox',(x,5,-113),(8,9,2),'stone','metal')
marker('BankTerminal',(-115,4,-86),(2,3,1)); sign(bank,'SECURITY',(-115,7,-85),10,1.4,'teal','ink',math.pi)
marker('BankLoot',(-84,2,-105),(8,3,4),'gold'); marker('BankATM',(-53,4,-48),(3,5,2),'navy')
part(alarms,'BankAlarm',(-84,11,-47),(2,0.5,0.6),'teal','neon',collide=False)
# Police station and functional duty counter.
station=building('HARBOR POLICE',84,-88,86,64,22,'navy',True)
sign(station,'H A R B O R   P O L I C E',(84,15,-55.6),67,4,'light','navy',math.pi)
part(station,'Desk',(72,2.4,-83),(27,4.8,5),'stone'); marker('PoliceDesk',(83,4,-79),(2,1.5,2))
for x in (56,66,110): bench(station,x,-101)
marker('PoliceCar',(105,0.5,-35),visible=False)
# Garage: open bay, showroom strip and repair station.
garage=building('ASTER AUTOHAUS',-85,86,87,65,18,'stone',True)
sign(garage,'A S T E R   /   A U T O H A U S',(-85,13,118.8),73,3.6,'gold','ink',math.pi)
marker('GarageDesk',(-110,4,105),(4,5,3),'ink'); marker('GarageCar',(-88,0.5,139),visible=False)
marker('CarRepair',(-53,1,138),(4,1.5,4),'gold')
part(roads,'GarageApron',(-85,0.25,135),(96,0.5,26),'walk')
for x in (-112,-86,-60): part(garage,'ServiceStripe',(x,0.9,85),(0.4,0.1,36),'gold','plastic',collide=False)
# Plaza and reliable neutral spawn.
part(land,'CivicPlaza',(85,0.3,80),(124,0.6,122),'walk')
part(land,'FountainBasin',(89,1.5,82),(24,3,24),'stone')
part(land,'FountainWater',(89,3.1,82),(21,0.2,21),'teal','glass',collide=False)
part(land,'FountainSculpture',(89,8,82),(3,11,3),'gold','metal',math.pi/4)
for x,z in [(48,40),(126,40),(48,122),(126,122)]: tree(x,z,0.8); bench(land,x+10,z)
sign(land,'H A R B O R   C I T Y',(82,7,136),49,4,'ink','light',math.pi)
spawn=part(workspace,'CitySpawn',(70,0.6,66),(5,1,5),'walk',cls='SpawnLocation',trans=1,collide=False)
prop(spawn,'bool','Neutral',True); prop(spawn,'float','Duration',0)
# Background architecture varies by block and shares a material palette.
for spec in [('NORTH QUAY',-266,-87,67,85,68,'stone'),('MERIDIAN',267,-85,63,78,94,'navy'),('HARBOR HOTEL',-90,268,94,63,75,'stone'),('CITY HOSPITAL',-266,268,65,61,29,'light'),('OFFICES',266,-261,58,64,49,'stone'),('LOFTS',-270,-258,66,62,37,'brick')]:
    name,x,z,w,d,h,col=spec
    b=building(name,x,z,w,d,h,'stone' if col=='brick' else col)
    sign(b,name,(x,7,z+d/2+0.3),w-8,3.5,'light','ink',math.pi)
# Courier depot and port with gantry, containers and an escape hand-in.
depot=building('HARBOR EXPRESS',-267,82,65,64,16,'light',True)
sign(depot,'HARBOR EXPRESS',(-267,11,114.4),53,3,'gold','ink',math.pi)
marker('JobDepot',(-267,3.5,104),(5,5,3),'gold')
for x in (-286,-279,-252): part(depot,'Parcel',(x,1.6,74),(4,3,4),'wood','wood')
part(roads,'DepotApron',(-267,0.3,134),(85,0.6,37),'walk')
part(land,'PortHardstanding',(264,0.4,82),(73,0.8,124),'walk')
for x,z,h,col in [(242,45,3,'navy'),(267,45,3,'teal'),(242,68,3,'gold'),(267,68,3,'navy'),(242,45,9,'stone')]:
    part(blocks,'FreightContainer',(x,h,z),(18,6,12),col,'metal')
    for dx in range(-8,9,2): part(blocks,'ContainerRib',(x+dx,h,z+6.12),(0.2,5.6,0.2),'ink','metal',collide=False)
for x in (248,299): part(blocks,'GantryLeg',(x,20,9),(3,40,4),'gold','metal')
part(blocks,'GantryBeam',(273,40,9),(58,4,5),'gold','metal')
part(blocks,'CraneCable',(280,28,9),(0.25,20,0.25),'ink','metal',collide=False)
marker('Dropoff',(289,3,115),(3,4,3),'teal'); sign(blocks,'QUAY 04',(289,8,116),17,2,'light','ink',math.pi)
marker('DeliveryDrop',(241,3,118),(4,5,3),'gold')
# One furnished apartment interior, explicitly shared alpha interior in documentation.
home=building('MARINA RESIDENCE',84,270,82,64,17,'light',True)
sign(home,'MARINA RESIDENCE',(84,12,302.6),67,3,'ink','light',math.pi)
marker('HomeDesk',(72,3,310),(2,4,2),'navy'); marker('HomeEnter',(84,4,305),visible=False)
marker('HomeInside',(84,2,265),visible=False); marker('HomeLeave',(84,4,294),(2,3,1),'teal')
part(home,'Sofa',(60,1.8,253),(16,3,5),'teal'); part(home,'SofaBack',(60,4,251),(16,2.5,1.2),'teal')
part(home,'CoffeeTable',(60,2,264),(9,0.5,5),'wood','wood')
for x in (57,63): part(home,'TableLeg',(x,1,264),(0.5,2,3),'ink','metal')
part(home,'Kitchen',(108,3,247),(22,6,7),'navy'); part(home,'Counter',(108,6.2,247),(22,0.4,7),'light')
part(home,'Bed',(108,1.8,276),(12,3,16),'stone'); part(home,'Mattress',(108,3.6,276),(11.7,0.7,15.5),'light')
seat=part(home,'Seat',(60,3.45,254),(5,0.3,3),'teal',cls='Seat',trans=1,collide=False)
# Prison: surrounding walls, towers, accessible cells, yard, mess hall, laundry.
prison=item(blocks,'Model','NORTHGATE CORRECTIONAL')
part(prison,'PrisonFloor',(-2,0.3,-359),(198,0.6,146),'walk')
for x in (-101,101): part(prison,'Perimeter',(x,8,-359),(2,16,150),'stone')
part(prison,'NorthWall',(0,8,-435),(204,16,2),'stone')
part(prison,'SouthWall',(0,8,-283),(204,16,2),'stone')
for x in (-92,92):
    for z in (-426,-292):
        part(prison,'WatchTower',(x,12,z),(12,24,12),'navy')
        part(prison,'TowerGlass',(x,22,z),(14,6,14),'glass','glass')
        part(prison,'TowerRoof',(x,26,z),(17,1,17),'ink','metal')
part(prison,'CellWingRoof',(-41,13,-410),(96,1,42),'stone')
part(prison,'CellWingBack',(-41,6,-430),(96,12,1),'light')
for x in (-79,-59,-39,-19):
    part(prison,'CellPartition',(x-10,6,-411),(0.8,12,36),'light')
    part(prison,'BedFrame',(x,1.3,-420),(8,2,5),'ink','metal')
    part(prison,'PrisonMattress',(x,2.5,-420),(8,0.5,5),'stone')
    # Open cell door leaves a six-stud passage.
    for bx in (-8,-6,6,8): part(prison,'CellBars',(x+bx,6,-393),(0.25,12,0.25),'ink','metal')
    sign(prison,str(x+100),(x,10,-392.6),4,2,'ink','light',math.pi)
part(prison,'CafeteriaFloor',(42,0.7,-408),(78,0.8,39),'light')
part(prison,'CafeteriaRoof',(42,13,-408),(80,1,41),'navy')
for x in (13,76): part(prison,'CafeteriaPillar',(x,6,-402),(1.5,12,1.5),'stone')
for x in (23,57):
    part(prison,'DiningTable',(x,3,-410),(17,1,5),'stone'); bench(prison,x,-404); bench(prison,x,-416)
part(prison,'ExerciseCourt',(-40,0.8,-330),(95,0.2,55),(108,124,119))
for x in (-73,-40,-7): part(prison,'CourtLine',(x,0.94,-330),(0.3,0.03,52),'light','plastic',collide=False)
part(prison,'LaundryShelves',(68,3,-325),(16,6,6),'navy')
marker('PrisonLaundry',(66,4,-319),(3,3,2),'gold'); marker('PrisonExit',(95,4,-350),(2,4,3),'teal')
marker('PrisonSpawn',(-58,1,-380),visible=False); marker('PrisonOutside',(124,1,-344),visible=False)
sign(prison,'NORTHGATE CORRECTIONAL',(0,12,-281.7),68,4,'light','navy',math.pi)
# The drain route is below the physical map, under a thin roof rather than solid terrain.
marker('TunnelDig',(-4,1.3,-367),(4,1,4),'ink')
part(prison,'TunnelFloor',(66,-15,-367),(157,1,12),'slate','slate')
for z in (-374,-360): part(prison,'TunnelWall',(66,-9,z),(158,12,1),'slate','slate')
for x in (-13,145): part(prison,'TunnelEnd',(x,-9,-367),(1,12,15),'slate','slate')
marker('TunnelStart',(-4,-13,-367),visible=False); marker('TunnelExit',(135,-11,-367),(3,4,3),'gold')
for x in (0,35,70,105,137):
    p=part(prison,'TunnelLamp',(x,-3,-367),(2,0.2,1),'gold','neon',collide=False)
    light=item(p,'PointLight','Light'); prop(light,'float','Range',30); prop(light,'float','Brightness',1); prop(light,'Color3','Color',(0.94,0.69,0.36))
# Neighborhood vegetation, benches, curbs and distant skyline.
for x,z in [(-230,155),(-310,-145),(-310,160),(220,260),(272,282),(280,320),(-134,228),(-138,312),(132,223),(135,334),(-243,-310),(230,-310),(-343,10),(-343,80),(-342,-100)]: tree(x,z)
for x in range(-350,301,65): tree(x,375,1.5)
# Invisible edge barriers stop players falling off the authored alpha area.
for pos,size in [((-430,30,-25),(2,60,890)),((430,30,-25),(2,60,890)),((0,30,-465),(860,60,2)),((0,30,410),(860,60,2))]: part(land,'WorldBoundary',pos,size,'ink',trans=1)
lighting=item(root,'Lighting','Lighting'); prop(lighting,'float','ClockTime',15.5); prop(lighting,'float','Brightness',2.3); prop(lighting,'bool','GlobalShadows',True); prop(lighting,'token','Technology',3); prop(lighting,'Color3','Ambient',(0.24,0.29,0.34)); prop(lighting,'Color3','OutdoorAmbient',(0.48,0.51,0.54)); prop(lighting,'float','EnvironmentDiffuseScale',0.7); prop(lighting,'float','EnvironmentSpecularScale',0.6)
atmos=item(lighting,'Atmosphere','CoastalAtmosphere'); prop(atmos,'float','Density',0.25); prop(atmos,'float','Offset',0.1); prop(atmos,'Color3','Color',(0.79,0.86,0.9)); prop(atmos,'Color3','Decay',(0.47,0.55,0.61)); prop(atmos,'float','Haze',1)
cc=item(lighting,'ColorCorrectionEffect','CoastalGrade'); prop(cc,'float','Contrast',0.08); prop(cc,'float','Saturation',-0.08); prop(cc,'Color3','TintColor',(1,0.98,0.94))
bloom=item(lighting,'BloomEffect','SoftHighlights'); prop(bloom,'float','Intensity',0.1); prop(bloom,'float','Size',20); prop(bloom,'float','Threshold',1.5)
replicated=item(root,'ReplicatedStorage','ReplicatedStorage'); shared=folder(replicated,'Shared')
server=item(root,'ServerScriptService','ServerScriptService'); server_folder=folder(server,'Server')
starter=item(root,'StarterPlayer','StarterPlayer'); prop(starter,'float','CharacterWalkSpeed',16); prop(starter,'float','CameraMaxZoomDistance',55)
client=item(starter,'StarterPlayerScripts','StarterPlayerScripts'); client_folder=folder(client,'Client')
for dirname,parent in [('shared',shared),('server',server_folder),('client',client_folder)]:
    for path in sorted((ROOT/'src'/dirname).glob('*.lua')): add_script(parent,path)
item(root,'StarterGui','StarterGui'); item(root,'Teams','Teams'); item(root,'SoundService','SoundService'); item(root,'ServerStorage','ServerStorage')
output=ROOT/'dist'/'HarborCity.rbxlx'; output.parent.mkdir(exist_ok=True)
E.indent(root,space='  '); E.ElementTree(root).write(output,encoding='utf-8',xml_declaration=True)
manifest={'title':'Harbor City','version':'0.1.0-alpha','instances':REF,'parts':sum(1 for x in root.iter('Item') if x.get('class') in ('Part','SpawnLocation','Seat')),'scripts':sum(1 for x in root.iter('Item') if x.get('class') in ('Script','LocalScript','ModuleScript')),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'runtime_tested':False,'external_assets':0}
(ROOT/'dist'/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest))
