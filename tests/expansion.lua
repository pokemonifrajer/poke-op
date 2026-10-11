-- Real modules with controlled engine boundaries: no claim of a Studio playtest.
local Config=dofile("src/shared/Config.lua")
local D=dofile("src/shared/Domain.lua")
local passed=0
local function test(name,fn) fn(); passed=passed+1; print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local now=1000
local function fresh() return D.default(Config) end
test("founding validates catalog/name and charges only once",function()
    local d=fresh(); assert(not D.foundCompany(d,"invalid",1,Config,now)); assert(not D.foundCompany(d,"logistics",0/0,Config,now)); eq(d.Bank,5000)
    assert(D.foundCompany(d,"logistics",2,Config,now)); eq(d.Bank,2500); eq(D.companyName(d.Company,Config),"MERIDIAN Logistics")
    assert(not D.foundCompany(d,"motors",1,Config,now)); eq(d.Bank,2500); assert(D.validate(d,Config))
end)
test("company money remains separate and completed contracts cannot pay twice",function()
    local d=fresh(); D.foundCompany(d,"logistics",1,Config,now)
    assert(D.companyReward(d,"a",Config,now)); assert(not D.companyReward(d,"a",Config,now)); eq(d.Company.Treasury,700); eq(d.Bank,2500); eq(d.Cash,1500)
    assert(D.withdrawCompany(d,Config,now)); eq(d.Bank,3200); eq(d.Company.Treasury,0); assert(not D.withdrawCompany(d,Config,now)); eq(d.Bank,3200)
end)
test("company upgrades have caps and server rewards",function()
    local d=fresh(); d.Bank=50000; D.foundCompany(d,"motors",1,Config,now)
    D.upgradeCompany(d,Config,now); D.upgradeCompany(d,Config,now); assert(not D.upgradeCompany(d,Config,now)); eq(d.Company.Level,3); eq(d.Bank,33500)
    D.companyReward(d,"b",Config,now); eq(d.Company.Treasury,1350)
    d.Company.Treasury=Config.Company.MaxTreasury; assert(not D.companyReward(d,"c",Config,now))
    d.Bank=Config.MaxBalance; assert(not D.withdrawCompany(d,Config,now)); eq(d.Company.Treasury,Config.Company.MaxTreasury)
end)
test("company schema corruption fails closed and old profiles migrate",function()
    local d=fresh(); d.Company=nil; d.Arrests=nil; assert(D.validate(d,Config)); D.normalize(d,Config); eq(d.Company,false); eq(d.Arrests,0)
    D.foundCompany(d,"motors",3,Config,now)
    for _,field in ipairs({"Level","Brand","Completed","Treasury","Industry"}) do local copy=D.copy(d); copy.Company[field]="bad"; assert(not D.validate(copy,Config),field) end
end)
local Vec={}
Vec.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) elseif k=="Unit" then return v*(1/v.Magnitude) else return Vec[k] end end
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},Vec) end
Vec.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
Vec.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
Vec.__mul=function(a,b) return vector(a.X*b,a.Y*b,a.Z*b) end
local function fixture(path)
    local p={UserId=1,Parent=true,DisplayName="Officer",Character={}}
    local q={UserId=2,Parent=true,DisplayName="Target",Character={}}
    local data={[p]=fresh(),[q]=fresh()}; local players={p,q}
    local roots={[p]={Position=vector(0,4,0),AssemblyLinearVelocity=vector(0,0,0)},[q]={Position=vector(4,4,0),AssemblyLinearVelocity=vector(0,0,0)}}
    local markers={}; for _,name in ipairs({"CompanyDesk","CompanyCargo","CompanyPort","CompanyParts","CompanyWorkshop","PrisonGate","PrisonSpawn","PrisonOutside","TunnelStart","VentStart"}) do markers[name]={Position=vector(0,4,0)} end
    local callbacks={}; local los=true; local guid=0
    local util={root=function(who) return roots[who],{Health=100,MaxHealth=100} end,near=function(who,pos,radius) return roots[who] and (roots[who].Position-pos).Magnitude<=radius end,los=function() return los end}
    local c={Data={Profiles={},get=function(_,who) return data[who] end},Roles={},Jobs={},Heist={snapshot=function() return nil end,remove=function() end},Vehicles={remove=function() end},Teams={Prisoner="Prisoner",Civilian="Civilian"},RespawnAt={},valid=function(_,who) return roots[who]~=nil end,bind=function(_,name,a,o,h,fn) callbacks[name]=fn end,notify=function() end,push=function() end,teleport=function(_,who,pos) roots[who].Position=pos end,Remotes={OpenPanel={FireClient=function() end}}}
    for who,d in pairs(data) do c.Data.Profiles[who]={Ready=true,Data=d} end
    p.LoadCharacter=function() p.Reloaded=true end; q.LoadCharacter=p.LoadCharacter
    local env=setmetatable({},{__index=_G})
    env.os={time=function() return now end,clock=function() return now end}
    env.Vector3={new=vector}; env.CFrame={new=function(...) local a={...}; return type(a[1])=="table" and a[1] or vector(...) end}
    env.Color3={fromRGB=function() return {} end}; env.Enum={PathWaypointAction={Jump="Jump"}}
    env.math=setmetatable({clamp=function(n,a,b) return math.min(b,math.max(a,n)) end},{__index=math})
    env.workspace={City={Markers=markers}}; env.script={Parent={Util="Util",Guard="Guard"}}
    env.game={GetService=function(_,name)
        if name=="ReplicatedStorage" then return {WaitForChild=function() return {Config="Config",Domain="Domain"} end} end
        if name=="Players" then return {GetPlayers=function() return players end,GetPlayerByUserId=function(_,id) for _,who in ipairs(players) do if who.UserId==id then return who end end end} end
        if name=="HttpService" then return {GenerateGUID=function() guid=guid+1; return "guid:"..guid end} end
    end}
    env.require=function(name) if name=="Config" then return Config elseif name=="Domain" then return D elseif name=="Util" then return util elseif name=="Guard" then return {allow=function() return true end} end end
    local module=assert(loadfile(path,"t",env))()
    return module,c,p,q,data,roots,callbacks,function(v) los=v end,markers
end
local function companyFixture()
    local b,c,p,q,d,roots,callbacks=fixture("src/server/BusinessService.lua"); b:init(c); return b,c,p,d[p],roots,callbacks
end
test("registration requires office proximity and a clean civilian",function()
    local b,c,p,d,r=companyFixture(); c.Roles[p]="Police"; assert(not b:found(p,{Industry="logistics",Brand=1})); c.Roles[p]="Civilian"
    r[p].Position=vector(100,4,0); assert(not b:found(p,{Industry="logistics",Brand=1})); r[p].Position=vector(0,4,0)
    assert(b:found(p,{Industry="logistics",Brand=1})); eq(d.Bank,2500)
end)
test("full company contract needs pickup, travel time and pays exactly once",function()
    local b,c,p,d=companyFixture(); b:found(p,{Industry="logistics",Brand=1}); assert(b:start(p)); assert(not b:start(p))
    b:deliver(p,"logistics"); eq(d.Company.Treasury,0)
    b:pickup(p,"logistics"); b:deliver(p,"logistics"); eq(d.Company.Treasury,0)
    now=now+23; b:deliver(p,"logistics"); eq(d.Company.Treasury,700); eq(b.Contracts[p],nil)
    b:deliver(p,"logistics"); eq(d.Company.Treasury,700); assert(not b:start(p)); now=now+36; assert(b:start(p))
end)
test("wrong industry, distance, death/role and deadlines cannot grant company income",function()
    local b,c,p,d,r=companyFixture(); b:found(p,{Industry="motors",Brand=1}); b:start(p)
    b:pickup(p,"logistics"); eq(b.Contracts[p].Stage,"Pickup")
    r[p].Position=vector(100,4,0); b:pickup(p,"motors"); eq(b.Contracts[p].Stage,"Pickup"); r[p].Position=vector(0,4,0)
    b:pickup(p,"motors"); now=now+Config.Company.Deadline+1; b:deliver(p,"motors"); b:step(); eq(b.Contracts[p],nil); eq(d.Company.Treasury,0)
    now=now+36; b:start(p); d.Wanted=1; b:step(); eq(b.Contracts[p],nil); eq(d.Company.Treasury,0)
end)
local function policeFixture()
    local s,c,p,q,data,roots,callbacks,setLos=fixture("src/server/PoliceService.lua")
    s.C=c; s.NPC={path=function() end,animate=function() end}; c.Roles[p]="Police"
    c.Prison={arrest=function(_,target,officer) if data[target].Wanted==0 then return false end; D.jail(data[target],now,Config); c.LastArrest={target,officer}; return true end}
    local model={Parent=true,SetAttribute=function() end,GetChildren=function() return {} end}
    local root={Position=vector(4,4,0),AssemblyLinearVelocity=vector(0,0,0)}
    model.PivotTo=function(_,pos) root.Position=pos end
    model.Destroy=function() model.Parent=nil end
    local suspect={Id="test:npc",Index=1,Status="Wanted",Spec={Name="Suspect",Crime="Test",Stars=2,Point=vector(4,4,0),Location="Garage"},Label={},Prompt={},Agent={Root=root,Model=model,Human={WalkSpeed=13,Health=100,MoveTo=function() end}}}
    s.Suspects[suspect.Id]=suspect
    return s,c,p,q,data,roots,suspect,setLos
end
test("police cannot cuff civilians, distant targets, occluded targets or malformed ids",function()
    local s,c,p,q,d,r,a,setLos=policeFixture()
    assert(not s:begin(p,q.UserId)); assert(not s:begin(p,{})); assert(not s:begin(p,"missing"))
    c.Roles[p]="Civilian"; assert(not s:begin(p,a.Id)); c.Roles[p]="Police"
    r[p].Position=vector(100,4,0); assert(not s:begin(p,a.Id)); r[p].Position=vector(0,4,0)
    setLos(false); assert(not s:begin(p,a.Id)); setLos(true); assert(s:begin(p,a.Id))
end)
test("one officer claims cuffs and continuous distance matters",function()
    local s,c,p,q,d,r,a=policeFixture(); c.Roles[q]="Police"
    assert(s:begin(p,a.Id)); assert(not s:begin(q,a.Id)); now=now+2; s:step(0.2); eq(a.Status,"Cuffing"); eq(d[p].Cash,1500)
    r[p].Position=vector(100,4,0); s:step(0.2); eq(s.Arrests[p],nil); eq(a.Status,"Wanted"); eq(d[p].Cash,1500)
end)
test("NPC arrest sends suspect into detention and pays once",function()
    local s,c,p,q,d,r,a=policeFixture(); assert(s:assign(p,a.Id)); assert(s:begin(p,a.Id)); now=now+3.1; s:step(0.2)
    eq(a.Status,"Detained"); eq(a.Prompt.Enabled,false); eq(d[p].Cash,1900); eq(d[p].Arrests,1); eq(s.Assigned[p],nil); eq(s.Arrests[p],nil)
    assert(not s:begin(p,a.Id)); s:complete(p,a.Id); eq(d[p].Cash,1900)
end)
test("wanted player arrest reaches prison only after the required time",function()
    local s,c,p,q,d,r,a=policeFixture(); d[q].Wanted=3
    assert(s:begin(p,q.UserId)); now=now+2; s:step(0.2); eq(c.LastArrest,nil)
    now=now+1.1; s:step(0.2); eq(c.LastArrest[1],q); eq(c.LastArrest[2],p); eq(d[q].Wanted,0); assert(d[q].JailUntil>now)
end)
test("officer death or role change cancels cuffs without a nil-root error",function()
    local s,c,p,q,d,r,a=policeFixture(); s:begin(p,a.Id); r[p]=nil; now=now+4; s:step(0.2); eq(s.Arrests[p],nil); eq(d[p].Cash,1500)
end)
test("prison work is capped and ventilation requires earned tool and travel",function()
    local prison,c,p,q,d,r,cb=fixture("src/server/PrisonService.lua"); prison:init(c); d[p].JailUntil=now+100
    cb.VentEnter(p); eq(prison.Vents[p],nil)
    cb.PrisonWorkshop(p); eq(d[p].JailUntil,now+92); assert(prison.Tools[p]); cb.PrisonWorkshop(p); eq(d[p].JailUntil,now+92)
    cb.VentEnter(p); assert(prison.Vents[p]); cb.VentExit(p); assert(d[p].JailUntil>0)
    now=now+9; cb.VentExit(p); eq(d[p].JailUntil,0); eq(d[p].Wanted,4); eq(prison.Vents[p],nil)
end)
test("prison gate needs police, closes on timer and release clears equipment",function()
    local prison,c,p,q,d,r,cb,setLos,m=fixture("src/server/PrisonService.lua"); prison:init(c)
    cb.PrisonGateConsole(p); eq(prison.GateUntil,0); c.Roles[p]="Police"; cb.PrisonGateConsole(p); eq(m.PrisonGate.CanCollide,false)
    now=now+9; prison:step(); eq(m.PrisonGate.CanCollide,true)
    prison.Keys[p]=true; prison.Tools[p]=true; d[p].JailUntil=now-1; prison:step(); eq(d[p].JailUntil,0); eq(prison.Keys[p],nil); eq(prison.Tools[p],nil); assert(p.Reloaded)
end)
print("EXPANSION TESTS: "..passed.." passed (mocked engine boundaries)")
