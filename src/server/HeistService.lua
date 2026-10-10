local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Guard=require(script.Parent.Guard)
local HttpService=game:GetService("HttpService")
local Heist={Active=nil,CooldownUntil=0}
function Heist:init(context)
    self.C=context; self.Markers=workspace.City.Markers
    context:bind("BankTerminal","Spustit / přidat se","Civic Bank",1,function(player) self:start(player) end)
    context:bind("BankLoot","Vzít tašku","Trezor",Config.Heist.CollectSeconds,function(player) self:collect(player) end)
    context:bind("Dropoff","Odevzdat tašku","Úkryt v přístavu",2,function(player) self:extract(player) end)
end
function Heist:eligible(player)
    local data=self.C.Data:get(player)
    return data and data.JailUntil<=os.time() and self.C.Roles[player]~="Police"
end
function Heist:start(player)
    if not self:eligible(player) then self.C:notify(player,"Loupež je dostupná pouze civilistům na svobodě."); return end
    if os.time()<self.CooldownUntil then self.C:notify(player,"Banka je uzavřená ještě "..(self.CooldownUntil-os.time()).." s."); return end
    local active=self.Active
    if active then
        if active.Stage~="Hack" or active.Members[player] then self.C:notify(player,"Loupež právě probíhá."); return end
        local count=0; for _ in pairs(active.Members) do count=count+1 end
        if count>=Config.Heist.MaxCrew then self.C:notify(player,"Posádka je plná."); return end
        active.Members[player]={Bag=false}; self.C:notify(player,"Připojil ses k posádce. Počkej na otevření trezoru."); self.C:push(player); return
    end
    local sequence={}; for i=1,4 do sequence[i]=math.random(1,4) end
    active={Id=HttpService:GenerateGUID(false),Leader=player,Members={[player]={Bag=false}},Stage="Hack",Started=os.clock(),Deadline=os.time()+Config.Heist.Duration,Sequence=sequence,Index=1,LastStep=0,Attempts=0}
    self.Active=active
    self.C.Remotes.Hack:FireClient(player,{Sequence=sequence,Duration=Config.Heist.HackSeconds})
    self.C:notify(player,"Zapamatuj si pořadí symbolů. Pak ho zopakuj."); self.C:push(player)
end
function Heist:input(player, choice)
    local a=self.Active
    if not a or a.Leader~=player or a.Stage~="Hack" or not Domain.integer(choice,1,4) then return end
    if not self:eligible(player) or not Util.near(player,self.Markers.BankTerminal.Position,14) then self:finish("Posádka opustila terminál."); return end
    local now=os.clock()
    if now-a.Started<Config.Heist.HackSeconds or now-a.LastStep<0.25 then return end
    a.LastStep=now
    if choice~=a.Sequence[a.Index] then
        a.Attempts=a.Attempts+1; a.Index=1
        if a.Attempts>=3 then self:finish("Tři chybné pokusy. Loupež selhala.")
        else self.C.Remotes.Hack:FireClient(player,{Reset=true,Attempts=a.Attempts}); self.C:notify(player,"Chyba. Zopakuj celé pořadí.") end
        return
    end
    a.Index=a.Index+1
    if a.Index>#a.Sequence then
        a.Stage="Loot"; self.C.Remotes.Hack:FireClient(player,{Close=true})
        self.Markers.VaultDoor.CanCollide=false; self.Markers.VaultDoor.Transparency=0.82
        workspace:SetAttribute("BankAlarm",true)
        for member in pairs(a.Members) do
            local data=self.C.Data:get(member)
            if data then Domain.crime(data,3,os.time()); self.C:notify(member,"ALARM! Vezmi tašku z trezoru a dostaň se do přístavu."); self.C:push(member) end
        end
        self.C:broadcast("Dispečink: alarm v Civic Bank. Hlídky míří na místo.")
    else self.C.Remotes.Hack:FireClient(player,{Progress=a.Index-1}) end
end
function Heist:collect(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member or a.Stage~="Loot" or member.Bag or not self:eligible(player) then self.C:notify(player,"Nejdřív dokonči terminál banky."); return end
    member.Bag=true; member.Collected=os.clock()
    local root=Util.root(player)
    if root then
        local bag=Util.part(player.Character,"HeistBag",Vector3.new(2,2.4,1),root.CFrame*CFrame.new(0,0,1),Color3.fromRGB(58,75,68),false)
        bag.CanCollide=false; bag.Massless=true
        local weld=Instance.new("WeldConstraint"); weld.Part0=root; weld.Part1=bag; weld.Parent=bag
    end
    self.C:notify(player,"Taška získána. Označený úkryt je v přístavu."); self.C:push(player)
end
function Heist:extract(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member or not member.Bag or not self:eligible(player) then self.C:notify(player,"Nemáš tašku z aktivní loupeže."); return end
    if os.clock()-member.Collected<12 then self.C:notify(player,"Od loupeže uplynulo příliš málo času."); return end
    local data=self.C.Data:get(player)
    if Domain.reward(data,Config.Heist.Reward,a.Id..":"..player.UserId,"Bankovní loupež",Config,os.time()) then
        self.C:notify(player,"Loupež dokončena: +$"..Config.Heist.Reward..". Hledanost stále platí.")
    end
    self:remove(player)
end
function Heist:remove(player)
    local a=self.Active; if not a or not a.Members[player] then return end
    a.Members[player]=nil
    local bag=player.Character and player.Character:FindFirstChild("HeistBag"); if bag then bag:Destroy() end
    self.C.Remotes.Hack:FireClient(player,{Close=true}); self.C:push(player)
    if not next(a.Members) or (a.Stage=="Hack" and a.Leader==player) then self:finish("Loupež ukončena.") end
end
function Heist:finish(reason)
    local a=self.Active; if not a then return end
    self.Active=nil; self.CooldownUntil=os.time()+Config.Heist.Cooldown
    self.Markers.VaultDoor.CanCollide=true; self.Markers.VaultDoor.Transparency=0
    workspace:SetAttribute("BankAlarm",false)
    for player in pairs(a.Members) do
        local bag=player.Character and player.Character:FindFirstChild("HeistBag"); if bag then bag:Destroy() end
        if player.Parent then self.C.Remotes.Hack:FireClient(player,{Close=true}); self.C:notify(player,reason); self.C:push(player) end
    end
end
function Heist:step()
    local a=self.Active; if not a then return end
    if os.time()>a.Deadline then self:finish("Čas loupeže vypršel."); return end
    if a.Stage=="Hack" and not Util.near(a.Leader,self.Markers.BankTerminal.Position,18) then self:finish("Spojení s terminálem přerušeno.") end
end
function Heist:snapshot(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member then return nil end
    return {Stage=a.Stage,Bag=member.Bag,Seconds=math.max(0,a.Deadline-os.time()),Target=member.Bag and "Docks" or "Bank"}
end
return Heist
