local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Guard=require(script.Parent.Guard)
local Police={Suspects={},Arrests={},Assigned={},Serial=0}
local cases={
    {Name="Alex Mercer",Crime="Krádež zásilky",Location="Depot",Point=Vector3.new(-240,4,143),Stars=1},
    {Name="Robin Vale",Crime="Vloupání do obchodu",Location="Jewelry",Point=Vector3.new(285,4,313),Stars=2},
    {Name="Sam Cross",Crime="Krádež vozidla",Location="Garage",Point=Vector3.new(-123,4,138),Stars=2},
}
function Police:init(context,npc)
    self.C=context; self.NPC=npc
    for index,spec in ipairs(cases) do self:spawn(index,spec) end
end
function Police:spawn(index,spec)
    self.Serial=self.Serial+1
    local agent=self.NPC:rig(spec.Name,spec.Point,Color3.fromRGB(116+index*20,71,74))
    local record={Id="npc:"..Http:GenerateGUID(false),Index=index,Spec=spec,Agent=agent,Status="Wanted",Born=os.clock()}
    self.Suspects[record.Id]=record
    agent.Model:SetAttribute("SuspectId",record.Id); agent.Model:SetAttribute("Wanted",spec.Stars)
    local tag=Instance.new("BillboardGui"); tag.Name="SuspectTag"; tag.Size=UDim2.fromOffset(160,40); tag.StudsOffset=Vector3.new(0,3.5,0); tag.MaxDistance=45; tag.Parent=agent.Root
    local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Size=UDim2.fromScale(1,1); label.Text=spec.Name.."\n"..string.rep("★",spec.Stars); label.Font=Enum.Font.GothamBold; label.TextSize=13; label.TextColor3=Color3.fromRGB(245,184,91); label.Parent=tag
    record.Label=label
    local prompt=Util.prompt(agent.Root,"Nasadit pouta",spec.Name,0)
    Guard:bindPrompt(prompt,function(p) return self:onDuty(p) and Util.near(p,agent.Root.Position,Config.ArrestDistance) end,function(p)
        local _,message=self:begin(p,record.Id); if message then self.C:notify(p,message) end
    end)
    record.Prompt=prompt
end
function Police:onDuty(p)
    local d=self.C.Data:get(p)
    return d and self.C:valid(p) and self.C.Roles[p]=="Police" and d.JailUntil<=os.time() and d.Wanted==0
end
function Police:target(id)
    if type(id)=="string" then
        local suspect=self.Suspects[id]
        if suspect and (suspect.Status=="Wanted" or suspect.Status=="Cuffing") then return suspect.Agent.Root,suspect.Agent.Model,suspect end
    elseif Domain.integer(id,1,100000000000) then
        local p=Players:GetPlayerByUserId(id); local d=p and self.C.Data:get(p); local root=p and Util.root(p)
        if d and root and d.Wanted>0 and d.JailUntil<=os.time() then return root,p.Character,nil,p end
    end
    return nil
end
function Police:nearTarget(p,id)
    local root,model,record,target=self:target(id); local officerRoot=Util.root(p)
    if not root or not officerRoot or not Util.near(p,root.Position,Config.ArrestDistance) or not Util.los(officerRoot.Position,root.Position,{p.Character,model}) then return nil end
    return root,record,target
end
function Police:begin(p,id)
    if not self:onDuty(p) then return false,"Pouta může použít policista ve službě." end
    if not Guard:allow(p,"cuffs",3,1) then return false end
    if self.Arrests[p] then return false,"Poutání už probíhá." end
    local root,record=self:nearTarget(p,id)
    if not root then return false,"Přibliž se k hledanému na 11 studů a měj ho v dohledu." end
    for officer,arrest in pairs(self.Arrests) do if officer~=p and arrest.Id==id then return false,"Podezřelého už poutá kolega." end end
    self.Arrests[p]={Id=id,Started=os.clock()}
    if record then record.Status="Cuffing"; record.Agent.Human.WalkSpeed=5
    else local _,_,_,target=self:target(id); if target then self.C:notify(target,"Policista tě poutá! Zůstaň stát nebo uteč z jeho dosahu.") end end
    return true,"Drž se u podezřelého 3 sekundy."
end
function Police:nearest(p)
    if not self:onDuty(p) then return false,"Nejdřív nastup do služby na stanici." end
    local officerRoot=Util.root(p); local best,distance=nil,Config.ArrestDistance+0.1
    local function inspect(id)
        local root=self:target(id)
        if root then local d=(root.Position-officerRoot.Position).Magnitude; if d<distance then distance=d; best=id end end
    end
    for id in pairs(self.Suspects) do inspect(id) end
    for _,other in ipairs(Players:GetPlayers()) do if other~=p then inspect(other.UserId) end end
    if best then return self:begin(p,best) end
    return false,"V dosahu není žádné hledané NPC ani hráč."
end
function Police:assign(p,id)
    if not self:onDuty(p) or type(id)~="string" then return false end
    local r=self.Suspects[id]
    if not r or r.Status~="Wanted" then return false,"Výjezd již není dostupný." end
    self.Assigned[p]=id; return true,"Výjezd přijat: "..r.Spec.Crime..". Poloha je v policejním tabletu."
end
function Police:cancel(p)
    local arrest=self.Arrests[p]
    local record=arrest and self.Suspects[arrest.Id]
    if record and record.Status=="Cuffing" then record.Status="Wanted" end
    self.Arrests[p]=nil
end
function Police:complete(p,id)
    local root,model,record,target=self:target(id)
    if not root then return false end
    if target then return self.C.Prison:arrest(target,p) end
    record.Status="Detained"; record.DetainedAt=os.clock(); record.Prompt.Enabled=false
    record.Agent.Human.WalkSpeed=0; record.Agent.Waypoints=nil
    record.Agent.Model:SetAttribute("Wanted",0); record.Label.Text=record.Spec.Name.."\nVE VAZBĚ"
    record.Agent.Model:PivotTo(CFrame.new(-79+(record.Index-1)*20,4,-410))
    record.Agent.Human:MoveTo(record.Agent.Root.Position)
    for _,part in ipairs(record.Agent.Model:GetChildren()) do
        if part:IsA("BasePart") and part.Name~="Head" and part.Name~="HumanoidRootPart" then part.Color=Color3.fromRGB(221,124,55) end
    end
    local data=self.C.Data:get(p)
    if data and Domain.reward(data,Config.Police.NPCReward,id,"Zadržení NPC",Config,os.time()) then
        data.Arrests=math.min(100000000,(data.Arrests or 0)+1)
        self.C:notify(p,"Podezřelý je ve vazbě v Northgate. +$"..Config.Police.NPCReward); self.C:push(p)
    end
    for officer,assigned in pairs(self.Assigned) do if assigned==id then self.Assigned[officer]=nil end end
    return true
end
function Police:roster(p)
    if not self:onDuty(p) then return {} end
    local result={}
    for id,r in pairs(self.Suspects) do
        if r.Status~="Detained" and r.Status~="Cooldown" then
            local pos=r.Agent.Root.Position
            table.insert(result,{Id=id,Name=r.Spec.Name,Crime=r.Spec.Crime,Wanted=r.Spec.Stars,Kind="NPC",Status=r.Status,Position={pos.X,pos.Y,pos.Z},Location=r.Spec.Location,Assigned=self.Assigned[p]==id})
        end
    end
    for _,other in ipairs(Players:GetPlayers()) do
        local data=self.C.Data:get(other); local root=Util.root(other)
        if data and root and data.Wanted>0 then table.insert(result,{Id=other.UserId,Name=other.DisplayName,Crime="Hledaný hráč",Wanted=data.Wanted,Kind="PLAYER",Position={root.Position.X,root.Position.Y,root.Position.Z}}) end
    end
    table.sort(result,function(a,b) return tostring(a.Id)<tostring(b.Id) end)
    return result
end
function Police:progress(p)
    local a=self.Arrests[p]
    return a and math.clamp((os.clock()-a.Started)/Config.Police.CuffSeconds,0,1) or nil
end
function Police:step(dt)
    local now=os.clock()
    for p,a in pairs(self.Arrests) do
        local root,record=self:nearTarget(p,a.Id)
        if not self:onDuty(p) or not root or (not record and root.AssemblyLinearVelocity.Magnitude>9) then
            self:cancel(p); self.C:notify(p,"Poutání přerušeno. Podezřelý unikl z dosahu.")
        elseif now-a.Started>=Config.Police.CuffSeconds then self:complete(p,a.Id); self:cancel(p) end
    end
    local respawns={}
    for id,r in pairs(self.Suspects) do
        local agent=r.Agent
        if r.Status=="Detained" then
            if now-r.DetainedAt>Config.Police.DetentionSeconds then agent.Model:Destroy(); r.Status="Cooldown" end
        elseif r.Status=="Cooldown" then
            if now-r.DetainedAt>Config.Police.RespawnSeconds then table.insert(respawns,r); self.Suspects[id]=nil end
        else
            if agent.Root.Position.Y< -20 then agent.Model:PivotTo(CFrame.new(r.Spec.Point)) end
            local closest,dist=nil,45
            for _,p in ipairs(Players:GetPlayers()) do
                local root=Util.root(p)
                if self.C.Roles[p]=="Police" and root then local d=(root.Position-agent.Root.Position).Magnitude; if d<dist then closest=root; dist=d end end
            end
            local goal=r.Spec.Point
            if closest then
                local away=agent.Root.Position-closest.Position; local flat=Vector3.new(away.X,0,away.Z)
                if flat.Magnitude>0.1 then goal=agent.Root.Position+flat.Unit*28 end
                -- Keep callouts in their walkable district instead of running out of the world.
                goal=Vector3.new(math.clamp(goal.X,r.Spec.Point.X-32,r.Spec.Point.X+32),4,math.clamp(goal.Z,r.Spec.Point.Z-17,r.Spec.Point.Z+17))
                agent.Human.WalkSpeed=r.Status=="Cuffing" and 5 or 13
            else agent.Human.WalkSpeed=7 end
            self.NPC:path(agent,goal)
            local wp=agent.Waypoints and agent.Waypoints[agent.Waypoint]
            if wp then
                if (agent.Root.Position-wp.Position).Magnitude<4 then agent.Waypoint=agent.Waypoint+1 end
                agent.Human:MoveTo(wp.Position); if wp.Action==Enum.PathWaypointAction.Jump then agent.Human.Jump=true end
            end
            self.NPC:animate(agent,dt)
        end
    end
    for _,r in ipairs(respawns) do self:spawn(r.Index,r.Spec) end
end
function Police:remove(p) self:cancel(p); self.Assigned[p]=nil end
return Police
