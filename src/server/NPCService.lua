local Players=game:GetService("Players")
local PathfindingService=game:GetService("PathfindingService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Domain=require(Shared.Domain)
local Config=require(Shared.Config)
local Util=require(script.Parent.Util)
local NPC={Agents={},Seen={}}
local function joint(parent,name,p0,p1,c0,c1)
    local m=Instance.new("Motor6D"); m.Name=name; m.Part0=p0; m.Part1=p1; m.C0=c0; m.C1=c1; m.Parent=parent; return m
end
function NPC:rig(name,position,color)
    local model=Instance.new("Model"); model.Name=name
    local root=Util.part(model,"HumanoidRootPart",Vector3.new(2,2,1),CFrame.new(position),color,false); root.Transparency=1; root.CanCollide=false
    local torso=Util.part(model,"Torso",Vector3.new(2,2,1),CFrame.new(position),color,false)
    joint(root,"RootJoint",root,torso,CFrame.identity,CFrame.identity)
    local head=Util.part(model,"Head",Vector3.new(1.4,1.4,1.4),CFrame.new(position+Vector3.new(0,1.6,0)),Color3.fromRGB(205,170,141),false)
    head.CanCollide=false
    joint(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-0.6,0))
    local joints={}
    for _,side in ipairs({-1,1}) do
        local label=side==-1 and "Left" or "Right"
        local arm=Util.part(model,label.." Arm",Vector3.new(1,2,1),CFrame.new(position+Vector3.new(side*1.5,0,0)),color,false); arm.CanCollide=false
        local leg=Util.part(model,label.." Leg",Vector3.new(1,2,1),CFrame.new(position+Vector3.new(side*0.5,-2,0)),Color3.fromRGB(39,48,62),false)
        leg.CanCollide=false
        table.insert(joints,joint(torso,label.." Shoulder",torso,arm,CFrame.new(side*1.5,0.5,0),CFrame.new(0,0.5,0)))
        table.insert(joints,joint(torso,label.." Hip",torso,leg,CFrame.new(side*0.5,-1,0),CFrame.new(0,1,0)))
    end
    local human=Instance.new("Humanoid"); human.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None; human.WalkSpeed=12; human.Parent=model
    model.PrimaryPart=root; model.Parent=self.Folder; root:SetNetworkOwner(nil)
    return {Model=model,Root=root,Human=human,Joints=joints,NextPath=0,Patrol=math.random(1,#self.PatrolPoints),State="Patrol",Phase=math.random()*5}
end
function NPC:init(context)
    self.C=context; self.Folder=Instance.new("Folder"); self.Folder.Name="CityNPCs"; self.Folder.Parent=workspace
    self.PatrolPoints={Vector3.new(-25,4,-155),Vector3.new(-155,4,-25),Vector3.new(-155,4,155),Vector3.new(155,4,155),Vector3.new(155,4,-25),Vector3.new(25,4,-155)}
    for i=1,4 do
        local a=self:rig("Hlídka "..i,self.PatrolPoints[i],Color3.fromRGB(42,65,90)); a.Police=true; table.insert(self.Agents,a)
    end
    for i=1,6 do table.insert(self.Agents,self:rig("Obyvatel",self.PatrolPoints[i]+Vector3.new(7,0,7),Color3.fromHSV(i/8,0.25,0.65))) end
end
function NPC:path(agent, goal)
    if agent.Computing or os.clock()<agent.NextPath then return end
    agent.Computing=true; agent.NextPath=os.clock()+2.2
    task.spawn(function()
        local path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=7})
        local ok=pcall(function() path:ComputeAsync(agent.Root.Position,goal) end)
        if ok and path.Status==Enum.PathStatus.Success then agent.Waypoints=path:GetWaypoints(); agent.Waypoint=2
        else agent.Waypoints=nil; agent.Human:MoveTo(goal) end
        agent.Computing=false
    end)
end
function NPC:step(dt)
    local now=os.clock(); self.Seen={}
    local assignments={}
    for _,agent in ipairs(self.Agents) do
        if agent.Root.Position.Y < -30 or agent.Human.Health<=0 then
            agent.Model:PivotTo(CFrame.new(self.PatrolPoints[agent.Patrol])); agent.Human.Health=100
        end
        local target, nearest=nil,math.huge
        if agent.Police then
            for _,player in ipairs(Players:GetPlayers()) do
                local d=self.C.Data:get(player); local root=Util.root(player)
                if d and d.Wanted>0 and d.JailUntil<=os.time() and root then
                    local distance=(root.Position-agent.Root.Position).Magnitude
                    if distance < 65+d.Wanted*22 and distance<nearest and (assignments[player] or 0)<math.min(4,d.Wanted+1) and Util.los(agent.Root.Position+Vector3.new(0,1,0),root.Position,{agent.Model,player.Character}) then
                        target=player; nearest=distance
                    end
                end
            end
        end
        local goal
        if target then
            assignments[target]=(assignments[target] or 0)+1; self.Seen[target]=true
            local root=Util.root(target); agent.LastSeen=root.Position; agent.SeenAt=now; agent.State="Chase"; agent.Human.WalkSpeed=21; goal=root.Position
            if nearest<8 and root.AssemblyLinearVelocity.Magnitude<9 then
                if agent.ArrestTarget~=target then agent.ArrestTarget=target; agent.ArrestAt=now; self.C:notify(target,"Policie tě poutá! Vzdal se, nebo uteč.") end
                if now-agent.ArrestAt>=3 then self.C.Prison:arrest(target); agent.ArrestTarget=nil end
            else agent.ArrestTarget=nil end
        else
            agent.ArrestTarget=nil; agent.Human.WalkSpeed=agent.Police and 14 or 10
            if agent.LastSeen and now-(agent.SeenAt or 0)<12 then agent.State="Investigate"; goal=agent.LastSeen
            else
                agent.State="Patrol"; goal=self.PatrolPoints[agent.Patrol]
                if (agent.Root.Position-goal).Magnitude<9 then agent.Patrol=agent.Patrol%#self.PatrolPoints+1; goal=self.PatrolPoints[agent.Patrol] end
            end
        end
        self:path(agent,goal)
        local points=agent.Waypoints; local wp=points and points[agent.Waypoint]
        if wp then
            if (agent.Root.Position-wp.Position).Magnitude<4 then agent.Waypoint=agent.Waypoint+1; wp=points[agent.Waypoint] end
            if wp then if wp.Action==Enum.PathWaypointAction.Jump then agent.Human.Jump=true end; agent.Human:MoveTo(wp.Position) end
        end
        local moving=agent.Root.AssemblyLinearVelocity.Magnitude>1
        agent.Phase=agent.Phase+dt*8
        for i,j in ipairs(agent.Joints) do
            j.C0=(i==1 and CFrame.new(-1.5,0.5,0) or i==2 and CFrame.new(-0.5,-1,0) or i==3 and CFrame.new(1.5,0.5,0) or CFrame.new(0.5,-1,0))*CFrame.Angles(moving and math.sin(agent.Phase+(i<=2 and 0 or math.pi))*(i%2==0 and -0.55 or 0.45) or 0,0,0)
        end
    end
end
return NPC
