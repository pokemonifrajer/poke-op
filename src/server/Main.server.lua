local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local Teams=game:GetService("Teams")
local HttpService=game:GetService("HttpService")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Guard=require(script.Parent.Guard)
local Data=require(script.Parent.DataService)
local Vehicles=require(script.Parent.VehicleService)
local Prison=require(script.Parent.PrisonService)
local Heist=require(script.Parent.HeistService)
local NPC=require(script.Parent.NPCService)
local Traffic=require(script.Parent.TrafficService)
local city=workspace:WaitForChild("City",20)
assert(city,"City map is missing. Open dist/HarborCity.rbxlx, or run tools/build_place.py.")
local C={Data=Data,Vehicles=Vehicles,Prison=Prison,Heist=Heist,Roles={},Jobs={},Teams={},Remotes={},RespawnAt={},Movement={},PlayerArrests={},JoinAt={},HomeGuests={},HomeLocked={}}
local folder=Instance.new("Folder"); folder.Name="Network"; folder.Parent=ReplicatedStorage
for _,name in ipairs({"Action","Drive","State","Notify","Hack","OpenPanel"}) do local remote=Instance.new("RemoteEvent"); remote.Name=name; remote.Parent=folder; C.Remotes[name]=remote end
for _,name in ipairs({"Civilian","Police","Prisoner"}) do
    local team=Instance.new("Team"); team.Name=name; team.AutoAssignable=false
    team.TeamColor=BrickColor.new(name=="Police" and "Bright blue" or name=="Prisoner" and "Bright orange" or "Medium stone grey"); team.Parent=Teams; C.Teams[name]=team
end
function C:notify(p,text) if p.Parent then self.Remotes.Notify:FireClient(p,text) end end
function C:broadcast(text) self.Remotes.Notify:FireAllClients(text) end
function C:teleport(p,pos)
    self.Movement[p]={At=os.clock(),Position=pos,Grace=os.clock()+3}; Util.teleport(p,pos)
end
function C:valid(p)
    return Data:get(p)~=nil and Util.root(p)~=nil and not (self.Movement[p] and (self.Movement[p].BlockedUntil or 0)>os.clock())
end
function C:bind(marker,action,object,hold,callback)
    local part=city.Markers:FindFirstChild(marker); assert(part,"Missing marker: "..marker)
    local prompt=Util.prompt(part,action,object,hold)
    Guard:bindPrompt(prompt,function(p)
        return self:valid(p) and Util.near(p,part.Position,Config.InteractionDistance) and Util.los(Util.root(p).Position,part.Position,{p.Character,part})
    end,callback)
end
function C:push(p)
    local profile=Data.Profiles[p]; local d=Data:get(p); if not profile or not d or not p.Parent then return end
    local roster={}
    if self.Roles[p]=="Police" then
        for other,otherProfile in pairs(Data.Profiles) do
            if otherProfile.Ready and otherProfile.Data.Wanted>0 then table.insert(roster,{Id=other.UserId,Name=other.DisplayName,Wanted=otherProfile.Data.Wanted}) end
        end
    end
    self.Remotes.State:FireClient(p,{Cash=d.Cash,Bank=d.Bank,Cars=d.Cars,Colors=d.Colors,Home=d.Home,HomeLocked=self.HomeLocked[p]~=false,
        Wanted=d.Wanted,Jail=math.max(0,d.JailUntil-os.time()),Role=self.Roles[p] or "Civilian",Transactions=d.Transactions,
        SaveMode=profile.Mode,Version=Config.Version,Heist=Heist:snapshot(p),Key=Prison.Keys[p] or false,
        Job=self.Jobs[p] and {Name="Rozvoz zásilek",Target=self.Jobs[p].Target,Deadline=math.max(0,self.Jobs[p].Deadline-os.time())} or nil,
        Roster=roster,BankCooldown=math.max(0,Heist.CooldownUntil-os.time())})
end
local function civilian(p)
    local d=Data:get(p)
    return d and d.JailUntil<=os.time() and C.Roles[p]~="Police"
end
local function clean(p)
    local d=Data:get(p); return d and d.JailUntil<=os.time() and d.Wanted==0 and not Heist:snapshot(p)
end
function C:startJob(p)
    if not clean(p) then self:notify(p,"Práci lze zahájit jen bez hledanosti a aktivní loupeže."); return end
    if self.Jobs[p] then self:notify(p,"Už vezeš zásilku."); return end
    self.Jobs[p]={Id=HttpService:GenerateGUID(false),Started=os.clock(),Deadline=os.time()+180,Target="Docks"}
    self:notify(p,"Vyzvedl jsi zásilku. Doruč ji k modrému stanovišti v přístavu."); self:push(p)
end
Vehicles:init(C); Prison:init(C); Heist:init(C); NPC:init(C); Traffic:init()
C:bind("GarageDesk","Otevřít garáž","ASTER • autohaus",0,function(p) C.Remotes.OpenPanel:FireClient(p,"Garage") end)
C:bind("BankATM","Otevřít banku","Bankomat",0,function(p) if not Prison:jailed(p) then C.Remotes.OpenPanel:FireClient(p,"Bank") end end)
C:bind("PoliceDesk","Zvolit službu","Policejní stanice",0,function(p) C.Remotes.OpenPanel:FireClient(p,"Jobs") end)
C:bind("JobDepot","Vyzvednout zásilku","Harbor Express",1,function(p) C:startJob(p) end)
C:bind("DeliveryDrop","Doručit zásilku","Přístavní kancelář",2,function(p)
    local job=C.Jobs[p]; local d=Data:get(p)
    if not job or not d or d.JailUntil>os.time() then return end
    if os.clock()-job.Started<Config.DeliverySeconds or os.time()>job.Deadline then C:notify(p,"Dodávka nemá platný čas."); return end
    if Domain.reward(d,Config.DeliveryReward,job.Id,"Doručení zásilky",Config,os.time()) then C.Jobs[p]=nil; C:notify(p,"Zásilka doručena: +$"..Config.DeliveryReward); C:push(p) end
end)
C:bind("HomeDesk","Spravovat byt","Marina Residence",0,function(p) C.Remotes.OpenPanel:FireClient(p,"Home") end)
C:bind("HomeEnter","Vstoupit","Marina • vstup",0,function(p)
    local d=Data:get(p)
    if d and d.Home and clean(p) then C:teleport(p,city.Markers.HomeInside.Position+Vector3.new(0,3,0))
    else C:notify(p,"Vstup do bytu je pro vlastníka bez hledanosti.") end
end)
C:bind("HomeLeave","Odejít","Marina Residence",0,function(p) C:teleport(p,city.Markers.HomeDesk.Position+Vector3.new(0,3,8)) end)
C:bind("CarRepair","Opravit vůz • $250","Servis",2,function(p)
    local d=Data:get(p); local car=Vehicles.ByPlayer[p]
    if d and car and clean(p) and (car.Base.Position-city.Markers.CarRepair.Position).Magnitude<22 and car.Base.AssemblyLinearVelocity.Magnitude<3 then
        local ok,reason=Domain.spend(d,250,"Oprava vozu",os.time())
        if ok then car.Health=100; car.Model:SetAttribute("Health",100); C:notify(p,"Vůz opraven.") else C:notify(p,reason) end
        C:push(p)
    else C:notify(p,"Přistav svoje auto k servisu a zastav.") end
end)
local actions={}
actions.snapshot=function(p) C:push(p) end
actions.deposit=function(p,amount) return Domain.transfer(Data:get(p),"deposit",amount,Config,os.time()) end
actions.withdraw=function(p,amount) return Domain.transfer(Data:get(p),"withdraw",amount,Config,os.time()) end
actions.buyCar=function(p,id)
    if type(id)~="string" or #id>32 then return false end
    if not clean(p) or not Util.near(p,city.Markers.GarageDesk.Position,60) then return false,"Nákup je dostupný u prodejce bez hledanosti." end
    return Domain.buyCar(Data:get(p),id,Config,os.time())
end
actions.spawnCar=function(p,id) if type(id)=="string" and #id<32 then return Vehicles:spawn(p,id) end end
actions.color=function(p,index)
    if not Domain.integer(index,1,6) or not clean(p) or not Util.near(p,city.Markers.GarageDesk.Position,60) then return false,"Přelakování je dostupné v garáži." end
    local car=Vehicles.ByPlayer[p]
    if not car or car.Spec.Police or car.Seat.Occupant or car.Base.AssemblyLinearVelocity.Magnitude>3 then return false,"Nejdřív přistav vlastní vůz a vystup." end
    if (car.Base.Position-city.Markers.GarageDesk.Position).Magnitude>70 then return false,"Vůz musí být u garáže." end
    local data=Data:get(p); local ok,reason=Domain.spend(data,150,"Nový lak",os.time())
    if ok then data.Colors[car.Id]=index; Vehicles:repaint(car,index); return true,"Lak změněn." end
    return false,reason
end
actions.role=function(p,role)
    if role~="Police" and role~="Civilian" then return false end
    if not clean(p) or not Util.near(p,city.Markers.PoliceDesk.Position,35) then return false,"Změň práci u přepážky na policejní stanici, bez hledanosti." end
    if C.Roles[p]==role then return true end
    C.Jobs[p]=nil; Vehicles:remove(p); C.Roles[p]=role; p.Team=C.Teams[role]
    C.RespawnAt[p]="Police"; p:LoadCharacter()
    return true,role=="Police" and "Služba zahájena. Policejní vůz vyzvedni v garáži telefonu." or "Služba ukončena."
end
actions.job=function(p)
    if not Util.near(p,city.Markers.JobDepot.Position,20) then return false,"Dojdi do depa Harbor Express. V telefonu je mapa." end
    C:startJob(p); return true
end
actions.cancelJob=function(p) C.Jobs[p]=nil; return true,"Rozvoz zrušen." end
actions.homeBuy=function(p)
    local d=Data:get(p)
    if d.Home then return false,"Byt už vlastníš." end
    if not clean(p) or not Util.near(p,city.Markers.HomeDesk.Position,20) then return false,"Nákup je dostupný v Marina Residence." end
    local ok,reason=Domain.spend(d,18000,"Marina • byt",os.time()); if ok then d.Home=true end; return ok,reason
end
actions.homeLock=function(p)
    local d=Data:get(p); if not d.Home then return false,"Nevlastníš byt." end
    C.HomeLocked[p]=not (C.HomeLocked[p]~=false); return true,C.HomeLocked[p] and "Pozvánky do bytu uzamčeny." or "Můžeš pozvat hráče ze serveru."
end
actions.homeInvite=function(p,id)
    local d=Data:get(p); if not d.Home or C.HomeLocked[p]~=false or not Domain.integer(id,1,100000000000) then return false,"Nejdřív odemkni pozvánky." end
    if not Util.near(p,city.Markers.HomeInside.Position,45) or not clean(p) then return false,"Pozvánku lze poslat z vlastního bytu." end
    local guest=Players:GetPlayerByUserId(id)
    if not guest or guest==p or not clean(guest) then return false,"Hráč není dostupný." end
    C.HomeGuests[guest]={Owner=p,Until=os.clock()+30}; C:notify(guest,p.DisplayName.." tě zve do bytu. Pozvánku přijmi v telefonu → Byt.")
    return true,"Pozvánka odeslána."
end
actions.homeAccept=function(p)
    local invite=C.HomeGuests[p]
    if not invite or invite.Until<os.clock() or not invite.Owner.Parent or C.HomeLocked[invite.Owner]~=false or not clean(p) or not Util.near(invite.Owner,city.Markers.HomeInside.Position,45) then return false,"Žádná platná pozvánka." end
    C.HomeGuests[p]=nil; C:teleport(p,city.Markers.HomeInside.Position+Vector3.new(3,3,0)); return true
end
actions.lights=function(p) return Vehicles:action(p,"lights") end
actions.signal=function(p) return Vehicles:action(p,"signal") end
actions.siren=function(p) return Vehicles:action(p,"siren") end
actions.sprint=function(p,enabled)
    if type(enabled)~="boolean" then return false end
    local _,h=Util.root(p); if h then h.WalkSpeed=enabled and 22 or 16 end; return true
end
actions.arrest=function(p,id)
    if C.Roles[p]~="Police" or not Domain.integer(id,1,100000000000) then return false end
    local target=Players:GetPlayerByUserId(id); local d=target and Data:get(target); local root=target and Util.root(target)
    if not root or not d or d.Wanted==0 or not Util.near(p,root.Position,Config.ArrestDistance) or not Util.los(Util.root(p).Position,root.Position,{p.Character,target.Character}) then return false,"Hledaný hráč musí být blízko a v dohledu." end
    C.PlayerArrests[p]={Target=target,Started=os.clock()}; C:notify(target,"Policista tě poutá! Zatčení za 3 sekundy."); return true,"Zůstaň u podezřelého 3 sekundy."
end
C.Remotes.Action.OnServerEvent:Connect(function(p,action,value)
    if type(action)~="string" or #action>24 or not actions[action] or not Guard:allow(p,"action",8,4) or not C:valid(p) then return end
    if Prison:jailed(p) and action~="snapshot" and action~="sprint" then C:notify(p,"Tato funkce je ve vězení uzamčená."); return end
    local ok,success,message=pcall(actions[action],p,value)
    if not ok then warn("[Harbor City] Action failed:",action,success); C:notify(p,"Operace se nezdařila.")
    elseif message then C:notify(p,message) end
    C:push(p)
end)
C.Remotes.Drive.OnServerEvent:Connect(function(p,throttle,steer,brake) if C:valid(p) then Vehicles:input(p,throttle,steer,brake) end end)
C.Remotes.Hack.OnServerEvent:Connect(function(p,value) if C:valid(p) and Guard:allow(p,"hack",3,3) then Heist:input(p,value) end end)
local function onCharacter(p,character)
    local root=character:WaitForChild("HumanoidRootPart",10); local human=character:FindFirstChildOfClass("Humanoid")
    if not root or not human then return end
    local data=Data:get(p); if not data then return end
    Heist:remove(p); C.Jobs[p]=nil
    human.WalkSpeed=16
    if data.JailUntil>os.time() then
        p.Team=C.Teams.Prisoner; C:teleport(p,city.Markers.PrisonSpawn.Position+Vector3.new(0,3,0))
        task.delay(1,function() if p.Character==character then Prison:uniform(p) end end)
    else
        local location=C.RespawnAt[p] or (C.Roles[p]=="Police" and "Police" or "Spawn"); C.RespawnAt[p]=nil
        C:teleport(p,Util.vector(Config.Locations[location]))
        if C.Roles[p]=="Police" then
            local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            if torso then
                local vest=Util.part(character,"PoliceVest",torso.Size+Vector3.new(0.14,0.08,0.22),torso.CFrame,Color3.fromRGB(28,50,76),false)
                vest.CanCollide=false; vest.Massless=true; local weld=Instance.new("WeldConstraint"); weld.Part0=torso; weld.Part1=vest; weld.Parent=vest
            end
        end
    end
    human.Died:Connect(function() Heist:remove(p); C.Jobs[p]=nil end)
    C:push(p)
end
local function onPlayer(p)
    if not Data:load(p) then return end
    if not p.Parent then Data:save(p,true); return end
    C.Roles[p]="Civilian"; p.Team=C.Teams.Civilian; C.JoinAt[p]=os.time()
    p.CharacterAdded:Connect(function(c) onCharacter(p,c) end)
    if p.Character then task.spawn(onCharacter,p,p.Character) end
    C:push(p)
end
Players.PlayerAdded:Connect(onPlayer)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer,p) end
Players.PlayerRemoving:Connect(function(p)
    Heist:remove(p); Vehicles:remove(p); Prison:remove(p)
    C.Roles[p]=nil; C.Jobs[p]=nil; C.Movement[p]=nil; C.PlayerArrests[p]=nil; C.JoinAt[p]=nil; C.HomeGuests[p]=nil; C.HomeLocked[p]=nil; C.RespawnAt[p]=nil
    Data:save(p,true)
end)
Data:start()
local elapsed,npcClock,weatherClock,payClock=0,0,0,0
local weather="Clear"; workspace:SetAttribute("Weather",weather); workspace:SetAttribute("BankAlarm",false)
RunService.Heartbeat:Connect(function(dt)
    Lighting.ClockTime=(Lighting.ClockTime+dt/100)%24
    npcClock=npcClock+dt; elapsed=elapsed+dt; weatherClock=weatherClock+dt; payClock=payClock+dt
    if npcClock>=0.2 then NPC:step(npcClock); Traffic:step(npcClock); npcClock=0 end
    if weatherClock>150 then
        weatherClock=0; weather=({"Clear","Fog","Rain"})[math.random(1,3)]; workspace:SetAttribute("Weather",weather)
        local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then atmosphere.Density=weather=="Fog" and 0.48 or weather=="Rain" and 0.37 or 0.25; atmosphere.Haze=weather=="Clear" and 1 or 2.5 end
    end
    if elapsed>=1 then
        local tick=elapsed; elapsed=0
        Heist:step(); Prison:step()
        for p,profile in pairs(Data.Profiles) do
            local d=Data:get(p)
            if d then
                Domain.decay(d,os.time(),NPC.Seen[p] or Heist:snapshot(p)~=nil,Config.HeatDecaySeconds)
                local root,h=Util.root(p)
                if root then
                    local movement=C.Movement[p]; local now=os.clock()
                    if movement and now>(movement.Grace or 0) then
                        local delta=root.Position-movement.Position
                        local horizontal=Vector3.new(delta.X,0,delta.Z).Magnitude
                        local limit=(h.SeatPart and 150 or 34)*(now-movement.At)+12
                        if horizontal>limit then
                            Util.teleport(p,movement.Position); movement.BlockedUntil=now+3
                        end
                    end
                    C.Movement[p]={Position=root.Position,At=now,Grace=movement and movement.Grace or now+2,BlockedUntil=movement and movement.BlockedUntil or 0}
                    if root.Position.Y< -45 then C:teleport(p,Util.vector(Config.Locations.Spawn)) end
                end
                local job=C.Jobs[p]; if job and (os.time()>job.Deadline or d.Wanted>0) then C.Jobs[p]=nil; C:notify(p,"Rozvoz byl zrušen.") end
                C:push(p)
            end
        end
        for officer,arrest in pairs(C.PlayerArrests) do
            local root=Util.root(arrest.Target)
            if not Data:get(officer) or C.Roles[officer]~="Police" or not root or not Util.near(officer,root.Position,Config.ArrestDistance) or root.AssemblyLinearVelocity.Magnitude>9 or not Util.los(Util.root(officer).Position,root.Position,{officer.Character,arrest.Target.Character}) then C.PlayerArrests[officer]=nil
            elseif os.clock()-arrest.Started>=3 then Prison:arrest(arrest.Target,officer); C.PlayerArrests[officer]=nil end
        end
        local night=Lighting.ClockTime<6 or Lighting.ClockTime>18
        for _,light in ipairs(city.StreetLights:GetDescendants()) do if light:IsA("PointLight") then light.Enabled=night end end
        for _,lamp in ipairs(city.AlarmLights:GetChildren()) do lamp.Color=workspace:GetAttribute("BankAlarm") and Color3.fromRGB(245,70,70) or Color3.fromRGB(45,71,79) end
        local phase=math.floor(os.clock()/12)%2; workspace:SetAttribute("TrafficPhase",phase)
        for i,light in ipairs(city.TrafficLights:GetChildren()) do
            if light.Name=="Signal" then
                local axis=math.floor(i/2)%2
                light.Color=axis==phase and Color3.fromRGB(91,201,143) or Color3.fromRGB(231,88,84)
            end
        end
    end
    if payClock>=Config.PayInterval then
        payClock=0
        for p,role in pairs(C.Roles) do
            local d=Data:get(p)
            if d and role=="Police" and os.time()-(C.JoinAt[p] or os.time())>=Config.PayInterval then
                Domain.reward(d,Config.PolicePay,HttpService:GenerateGUID(false),"Policejní výplata",Config,os.time()); C:push(p)
            end
        end
    end
end)
workspace:SetAttribute("HarborReady",true)
print("[Harbor City] Alpha initialized. Studio persistence:",Config.StudioPersistence)
