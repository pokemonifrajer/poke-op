-- Deterministic service tests with explicitly mocked engine boundaries.
-- These do not emulate Roblox physics, networking, UI or PathfindingService.
local Config=dofile("src/shared/Config.lua")
local Domain=dofile("src/shared/Domain.lua")
local count=0
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function player(id) return {UserId=id,Parent=true,Kick=function(self,reason) self.Kicked=reason end} end
local time=1000
local function clock() return time end
local function dataModule(store,session,studio)
    local env=setmetatable({},{__index=_G})
    env.os={time=clock,clock=clock}; env.task={wait=function() end}; env.warn=function() end
    env.game={JobId=session,GetService=function(_,name)
        if name=="DataStoreService" then return {GetDataStore=function() return store end}
        elseif name=="RunService" then return {IsStudio=function() return studio end}
        elseif name=="HttpService" then return {GenerateGUID=function() return session end}
        elseif name=="ReplicatedStorage" then return {WaitForChild=function() return {Config="Config",Domain="Domain"} end} end
    end}
    env.require=function(which) return which=="Config" and Config or Domain end
    return assert(loadfile("src/server/DataService.lua","t",env))()
end
local function memoryStore()
    return {Value=nil,Calls=0,UpdateAsync=function(self,key,callback)
        self.Calls=self.Calls+1
        if self.Fail then error("storage unavailable") end
        -- Roblox may invoke the transform more than once. Discard the first result.
        callback(Domain.copy(self.Value))
        local value=callback(Domain.copy(self.Value))
        if value==nil then return nil end
        self.Value=Domain.copy(value); return Domain.copy(value)
    end}
end
test("Studio memory mode never opens datastore",function()
    local s=memoryStore(); local service=dataModule(s,"A",true); local p=player(1)
    assert(service:load(p)); eq(s.Calls,0); service:save(p,true); eq(s.Calls,0); eq(service.Profiles[p],nil)
end)
test("exclusive session lock prevents simultaneous profile load",function()
    local s=memoryStore(); local a,b=dataModule(s,"A",false),dataModule(s,"B",false)
    assert(a:load(player(1))); local p=player(1); assert(not b:load(p)); assert(p.Kicked); eq(s.Value.Lock.Owner,"A")
end)
test("release saves full snapshot and permits reconnect",function()
    local s=memoryStore(); local a=dataModule(s,"A",false); local p=player(1); assert(a:load(p)); a:get(p).Cash=4800
    assert(a:save(p,true)); eq(s.Value.Lock,nil)
    local b=dataModule(s,"B",false); local p2=player(1); assert(b:load(p2)); eq(b:get(p2).Cash,4800)
end)
test("stale server cannot overwrite a reclaimed session",function()
    local s=memoryStore(); local a=dataModule(s,"A",false); local p=player(1); assert(a:load(p))
    time=time+Config.SessionLease+1
    local b=dataModule(s,"B",false); local p2=player(1); assert(b:load(p2)); b:get(p2).Cash=9999; assert(b:save(p2,false))
    a.Profiles[p].Data.Cash=1; assert(not a:save(p,false)); eq(s.Value.Data.Cash,9999); eq(a:get(p),nil); assert(p.Kicked)
end)
test("load failure never creates or writes a fallback profile",function()
    local s=memoryStore(); s.Fail=true; local a=dataModule(s,"A",false); local p=player(1)
    assert(not a:load(p)); eq(a:get(p),nil); eq(s.Value,nil); eq(s.Calls,3)
end)
test("corrupt existing data is preserved",function()
    local s=memoryStore(); s.Value={Data={Cash="corrupt"}}; local a=dataModule(s,"A",false); local p=player(1)
    assert(not a:load(p)); eq(s.Value.Data.Cash,"corrupt")
end)
test("save failure freezes the session instead of allowing new spending",function()
    local s=memoryStore(); local a=dataModule(s,"A",false); local p=player(1); assert(a:load(p)); s.Fail=true
    assert(not a:save(p,false)); eq(a:get(p),nil); assert(p.Kicked)
end)
local function heistFixture()
    local p,q=player(1),player(2); local profiles={[p]=Domain.default(Config),[q]=Domain.default(Config)}
    local markers={BankTerminal={Position=0},VaultDoor={CanCollide=true,Transparency=0}}
    local env=setmetatable({},{__index=_G}); env.os={time=clock,clock=clock}
    env.script={Parent={Util="Util",Guard="Guard"}}
    env.workspace={City={Markers=markers},SetAttribute=function(self,key,val) self[key]=val end}
    env.game={GetService=function(_,name)
        if name=="ReplicatedStorage" then return {WaitForChild=function() return {Config="Config",Domain="Domain"} end} end
        if name=="HttpService" then return {GenerateGUID=function() return "heist-id" end} end
    end}
    local near=true
    env.require=function(which)
        if which=="Config" then return Config elseif which=="Domain" then return Domain
        elseif which=="Util" then return {near=function() return near end,root=function() return nil end} else return {} end
    end
    local h=assert(loadfile("src/server/HeistService.lua","t",env))()
    local c={Data={get=function(_,who) return profiles[who] end},Roles={},Remotes={Hack={FireClient=function() end}},bind=function() end,notify=function() end,push=function() end,broadcast=function() end}
    h:init(c)
    return h,p,q,profiles,markers,c,function(v) near=v end
end
local function unlock(h,p)
    time=time+Config.Heist.HackSeconds+1
    local seq=Domain.copy(h.Active.Sequence)
    for _,choice in ipairs(seq) do h:input(p,choice); time=time+0.3 end
end
test("bank refuses officers and jailed players",function()
    local h,p,q,d,m,c=heistFixture(); c.Roles[p]="Police"; h:start(p); eq(h.Active,nil)
    d[q].JailUntil=time+60; h:start(q); eq(h.Active,nil)
end)
test("bank rejects early client completion and wrong leader",function()
    local h,p,q=heistFixture(); h:start(p); local first=h.Active.Sequence[1]
    h:input(p,first); eq(h.Active.Index,1); time=time+11; h:input(q,first); eq(h.Active.Index,1)
end)
test("full bank mission pays once only after loot and extraction",function()
    local h,p,q,d,m=heistFixture(); h:start(p); h:start(q); unlock(h,p)
    eq(h.Active.Stage,"Loot"); eq(m.VaultDoor.CanCollide,false); eq(d[p].Wanted,3); eq(d[q].Wanted,3)
    h:extract(p); eq(d[p].Cash,1500)
    h:collect(p); h:extract(p); eq(d[p].Cash,1500)
    time=time+13; h:extract(p); eq(d[p].Cash,1500+Config.Heist.Reward)
    h:extract(p); eq(d[p].Cash,1500+Config.Heist.Reward)
    h:remove(q); eq(h.Active,nil); assert(h.CooldownUntil>time); eq(m.VaultDoor.CanCollide,true)
end)
test("three wrong sequences fail the mission without a reward",function()
    local h,p,q,d=heistFixture(); h:start(p); time=time+11
    local wrong=h.Active.Sequence[1]%4+1
    for i=1,3 do h:input(p,wrong); time=time+1 end
    eq(h.Active,nil); eq(d[p].Cash,1500)
end)
test("leader disconnect during hack closes the mission",function()
    local h,p,q=heistFixture(); h:start(p); h:start(q); h:remove(p); eq(h.Active,nil)
end)
test("timeout closes vault and pays nothing",function()
    local h,p,q,d,m=heistFixture(); h:start(p); unlock(h,p); h:collect(p)
    time=time+Config.Heist.Duration+1; h:step(); eq(h.Active,nil); eq(m.VaultDoor.CanCollide,true); eq(d[p].Cash,1500)
end)
test("leaving terminal breaks the hack",function()
    local h,p,q,d,m,c,setNear=heistFixture(); h:start(p); setNear(false); h:step(); eq(h.Active,nil)
end)
print("SERVICE TESTS: "..count.." passed (mocked engine boundaries)")
