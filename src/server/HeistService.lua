local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Guard=require(script.Parent.Guard)
local HttpService=game:GetService("HttpService")
local Heist={Active=nil,Cooldowns={}}
function Heist:init(context)
    self.C=context; self.Markers=workspace.City.Markers
    for mode,spec in pairs(Config.Heists) do
        context:bind(spec.StartMarker,"Začít / připojit loupež",spec.Name,1,function(player) self:start(player,mode) end)
        context:bind(spec.LootMarker,"Vyzvednout kořist",spec.Name,spec.CollectSeconds,function(player) self:collect(player) end)
    end
    context:bind("Dropoff","Odevzdat kořist","Úkryt v přístavu",2,function(player) self:extract(player) end)
end
function Heist:eligible(player)
    local data=self.C.Data:get(player)
    return data and data.JailUntil<=os.time() and self.C.Roles[player]~="Police"
end
function Heist:start(player,mode)
    mode=mode or "bank"
    local rules=Config.Heists[mode]
    if not rules then return false,"Neznámá mise." end
    if not self:eligible(player) then self.C:notify(player,"Loupež je dostupná pouze civilistům na svobodě."); return false end
    local origin=self.Markers[rules.StartMarker]
    if not Util.near(player,origin.Position,18) then self.C:notify(player,"Dojdi na místo zahájení mise."); return false end
    local active=self.Active
    if active then
        if active.Stage~="Hack" or active.Mode~=mode or active.Members[player] then self.C:notify(player,"V jiné loupeži už probíhá příprava."); return false end
        local count=0; for _ in pairs(active.Members) do count=count+1 end
        if count>=Config.Heist.MaxCrew then self.C:notify(player,"Posádka je plná."); return false end
        active.Members[player]={Bag=false}; self.C:notify(player,"Připojil ses k posádce. Počkej na otevření kořisti."); self.C:push(player); return true
    end
    local readyAt=self.Cooldowns[mode] or 0
    if os.time()<readyAt then self.C:notify(player,rules.Name.." je uzavřený ještě "..(readyAt-os.time()).." s."); return false end
    local sequence={}; for i=1,rules.Steps do sequence[i]=math.random(1,4) end
    active={Id=HttpService:GenerateGUID(false),Mode=mode,Rules=rules,Leader=player,Members={[player]={Bag=false}},Stage="Hack",Started=os.clock(),Deadline=os.time()+Config.Heist.Duration,Sequence=sequence,Index=1,LastStep=0,Attempts=0}
    self.Active=active
    self.C.Remotes.Hack:FireClient(player,{Sequence=sequence,Duration=rules.HackSeconds,Name=rules.Name})
    self.C:notify(player,"Zapamatuj si pořadí symbolů. Pak ho zopakuj."); self.C:push(player); return true
end
function Heist:input(player,choice)
    local a=self.Active
    if not a or a.Leader~=player or a.Stage~="Hack" or not Domain.integer(choice,1,4) then return end
    if not self:eligible(player) or not Util.near(player,self.Markers[a.Rules.StartMarker].Position,18) then self:finish("Posádka opustila místo loupeže."); return end
    local now=os.clock()
    if now-a.Started<a.Rules.HackSeconds or now-a.LastStep<0.25 then return end
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
        if a.Rules.DoorMarker then local door=self.Markers[a.Rules.DoorMarker]; door.CanCollide=false; door.Transparency=0.82 end
        if a.Rules.LootMarker=="ConvoyLoot" then self.Markers.ConvoyCrate.CanCollide=false; self.Markers.ConvoyCrate.Transparency=0.82 end
        workspace:SetAttribute("BankAlarm",true)
        for member in pairs(a.Members) do
            local data=self.C.Data:get(member)
            if data then
                Domain.crime(data,a.Rules.Stars,os.time())
                self.C:notify(member,"ALARM! Vezmi kořist a uteč na označené místo."); self.C:push(member)
            end
        end
        self.C:broadcast("Dispečink: alarm — "..a.Rules.Name..". Hlídky jsou na cestě.")
    else self.C.Remotes.Hack:FireClient(player,{Progress=a.Index-1}) end
end
function Heist:collect(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member or a.Stage~="Loot" or member.Bag or not self:eligible(player) then self.C:notify(player,"Nemůžeš vyzvednout kořist z této mise."); return end
    if not Util.near(player,self.Markers[a.Rules.LootMarker].Position,14) then return end
    member.Bag=true; member.Collected=os.clock()
    local root=Util.root(player)
    if root then
        local bag=Util.part(player.Character,"HeistBag",Vector3.new(2,2.4,1),root.CFrame*CFrame.new(0,0,1),Color3.fromRGB(58,75,68),false)
        bag.CanCollide=false; bag.Massless=true
        local weld=Instance.new("WeldConstraint"); weld.Part0=root; weld.Part1=bag; weld.Parent=bag
    end
    self.C:notify(player,"Kořist zajištěna. Doprav ji do přístavu."); self.C:push(player)
end
function Heist:extract(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member or not member.Bag or not self:eligible(player) then self.C:notify(player,"Nemáš kořist z aktivní loupeže."); return end
    if not Util.near(player,self.Markers.Dropoff.Position,18) then return end
    if os.clock()-member.Collected<a.Rules.MinEscapeSeconds then self.C:notify(player,"Od loupeže uplynulo příliš málo času."); return end
    local data=self.C.Data:get(player)
    if Domain.reward(data,a.Rules.Reward,a.Id..":"..player.UserId,a.Rules.Name,Config,os.time()) then
        self.C:notify(player,a.Rules.Name.." dokončen: +$"..a.Rules.Reward..". Hledanost stále platí.")
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
    self.Active=nil; self.Cooldowns[a.Mode]=os.time()+a.Rules.Cooldown
    if a.Rules.DoorMarker then local door=self.Markers[a.Rules.DoorMarker]; door.CanCollide=true; door.Transparency=0 end
    if a.Rules.LootMarker=="ConvoyLoot" then self.Markers.ConvoyCrate.CanCollide=true; self.Markers.ConvoyCrate.Transparency=0 end
    workspace:SetAttribute("BankAlarm",false)
    for player in pairs(a.Members) do
        local bag=player.Character and player.Character:FindFirstChild("HeistBag"); if bag then bag:Destroy() end
        if player.Parent then self.C.Remotes.Hack:FireClient(player,{Close=true}); self.C:notify(player,reason); self.C:push(player) end
    end
end
function Heist:step()
    local a=self.Active; if not a then return end
    if os.time()>a.Deadline then self:finish("Čas loupeže vypršel."); return end
    if a.Stage=="Hack" and not Util.near(a.Leader,self.Markers[a.Rules.StartMarker].Position,18) then self:finish("Spojení s místem loupeže přerušeno.") end
end
function Heist:snapshot(player)
    local a=self.Active; local member=a and a.Members[player]
    if not member then return nil end
    return {Stage=a.Stage,Mode=a.Mode,Name=a.Rules.Name,Bag=member.Bag,Seconds=math.max(0,a.Deadline-os.time()),Target=member.Bag and "Docks" or a.Mode}
end
return Heist
