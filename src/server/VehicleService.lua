local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Domain = require(Shared.Domain)
local Util = require(script.Parent.Util)
local Guard = require(script.Parent.Guard)
local Vehicle = {Cars = {}, ByPlayer = {}}
local palette = {Color3.fromRGB(68,155,173), Color3.fromRGB(239,171,79), Color3.fromRGB(214,219,225), Color3.fromRGB(32,37,49), Color3.fromRGB(162,68,68), Color3.fromRGB(126,151,106)}
local function welded(parent, base, name, size, offset, color, shape)
    local p = Util.part(parent, name, size, base.CFrame * offset, color, false)
    if shape then p.Shape = shape end
    p.CanCollide = false; p.Massless = true
    local weld = Instance.new("WeldConstraint"); weld.Part0 = base; weld.Part1 = p; weld.Parent = p
    return p
end
function Vehicle:init(context)
    self.C = context
    self.Folder = Instance.new("Folder"); self.Folder.Name = "Vehicles"; self.Folder.Parent = workspace
    RunService.Heartbeat:Connect(function(dt) self:step(math.min(dt, 0.08)) end)
end
function Vehicle:spawn(player, id)
    local data = self.C.Data:get(player); local spec = Config.Vehicles[id]
    if not data or not spec or data.JailUntil > os.time() then return false, "Vůz teď nelze vyzvednout." end
    if data.Wanted > 0 then return false, "Garáž je při pátrání uzamčena." end
    if spec.Police then
        if self.C.Roles[player] ~= "Police" then return false, "Pouze pro policii." end
    elseif not data.Cars[id] then return false, "Tento vůz nevlastníš." end
    local pad = workspace.City.Markers:FindFirstChild(spec.Police and "PoliceCar" or "GarageCar")
    if not Util.near(player, pad.Position, 65) then return false, "Dojdi ke garáži nebo na policejní parkoviště." end
    local old = self.ByPlayer[player]
    if old and (old.Seat.Occupant or old.Base.AssemblyLinearVelocity.Magnitude > 3) then return false, "Nejdřív zastav a vystup z auta." end
    for _, car in pairs(self.Cars) do if car ~= old and (car.Base.Position - pad.Position).Magnitude < 15 then return false, "Výjezd je obsazený." end end
    if old then self:destroy(old) end
    local model = Instance.new("Model"); model.Name = spec.Name; model:SetAttribute("OwnerId", player.UserId)
    local bodyColor = palette[data.Colors[id] or 1]
    if spec.Police then bodyColor = Color3.fromRGB(29,42,60) end
    local width,length=spec.Width or 6.7,spec.Length or 12
    local sx,sz=width/6.7,length/12
    local base = Util.part(model, "Chassis", Vector3.new(width,1.5,length), CFrame.new(pad.Position + Vector3.new(0,1.8,0)), bodyColor, false)
    base.CustomPhysicalProperties = PhysicalProperties.new(1.1,0.25,0.05,1,1)
    model.PrimaryPart = base
    welded(model,base,"Hood",Vector3.new(width*0.97,0.8,length*0.32),CFrame.new(0,0.8,-length*0.31),bodyColor)
    welded(model,base,"Roof",Vector3.new(width*0.82,0.45,length*0.45),CFrame.new(0,3,length*0.04),bodyColor)
    local windshield = welded(model,base,"Windshield",Vector3.new(width*0.81,2.1,0.2),CFrame.new(0,1.9,-length*0.175)*CFrame.Angles(math.rad(-14),0,0),Color3.fromRGB(86,130,146))
    windshield.Material = Enum.Material.Glass; windshield.Transparency = 0.35
    for _, x in ipairs({-2.85,2.85}) do
        for _, z in ipairs({-length*0.175,length*0.25}) do welded(model,base,"Pillar",Vector3.new(0.25,2.5,0.3),CFrame.new(x,1.8,z),bodyColor) end
    end
    welded(model,base,"RearWindow",Vector3.new(width*0.79,1.8,0.25),CFrame.new(0,1.8,length*0.25),Color3.fromRGB(53,75,91))
    local wheels = {}
    for _, x in ipairs({-width*0.51,width*0.51}) do
        for _, z in ipairs({-length*0.31,length*0.31}) do
            local w = welded(model,base,"Wheel",Vector3.new(1.2,2.6,2.6),CFrame.new(x,-0.4,z),Color3.fromRGB(22,25,31),Enum.PartType.Cylinder)
            table.insert(wheels,w)
            welded(model,base,"Rim",Vector3.new(1.24,1.55,1.55),CFrame.new(x,-0.4,z),Color3.fromRGB(128,139,151),Enum.PartType.Cylinder)
        end
    end
    local seat = Instance.new("VehicleSeat"); seat.Name = "Driver"; seat.Size = Vector3.new(2.1,0.65,2)
    seat.CFrame = base.CFrame * CFrame.new(-width*0.2,1,length*0.02); seat.CanCollide = false; seat.Massless = true; seat.HeadsUpDisplay = false; seat.MaxSpeed = 0; seat.Parent = model
    local sw = Instance.new("WeldConstraint"); sw.Part0=base; sw.Part1=seat; sw.Parent=seat
    local attachment = Instance.new("Attachment"); attachment.Parent=base
    local velocity = Instance.new("LinearVelocity"); velocity.Attachment0=attachment
    velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Plane; velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    velocity.PrimaryTangentAxis=Vector3.xAxis; velocity.SecondaryTangentAxis=Vector3.zAxis
    velocity.ForceLimitsEnabled=true; velocity.ForceLimitMode=Enum.ForceLimitMode.Magnitude; velocity.MaxForce=80000; velocity.PlaneVelocity=Vector2.zero; velocity.Parent=base
    local align = Instance.new("AlignOrientation"); align.Attachment0=attachment; align.Mode=Enum.OrientationAlignmentMode.OneAttachment
    align.MaxTorque=150000; align.MaxAngularVelocity=3; align.Responsiveness=12; align.CFrame=base.CFrame.Rotation; align.Parent=base
    local spring=Instance.new("VectorForce"); spring.Attachment0=attachment; spring.RelativeTo=Enum.ActuatorRelativeTo.World; spring.ApplyAtCenterOfMass=true; spring.Parent=base
    local lights={}; local indicators={}
    for _, x in ipairs({-width*0.36,width*0.36}) do
        local lens=welded(model,base,"Headlamp",Vector3.new(1.5,0.5,0.2),CFrame.new(x,0.35,-length*0.5-0.05),Color3.fromRGB(238,231,199))
        lens.Material=Enum.Material.Neon
        local spot=Instance.new("SpotLight"); spot.Face=Enum.NormalId.Front; spot.Range=65; spot.Angle=75; spot.Brightness=2; spot.Enabled=false; spot.Parent=lens; table.insert(lights,spot)
        welded(model,base,"TailLight",Vector3.new(1.4,0.4,0.2),CFrame.new(x,0.4,length*0.5+0.05),Color3.fromRGB(151,47,48)).Material=Enum.Material.Neon
        table.insert(indicators,welded(model,base,"Indicator",Vector3.new(0.5,0.45,0.22),CFrame.new(x,0.8,-length*0.5-0.06),Color3.fromRGB(89,64,30)))
    end
    local bars={}
    if spec.Police then
        for i, x in ipairs({-1.4,1.4}) do
            local bar=welded(model,base,"Lightbar",Vector3.new(2.4,0.5,0.8),CFrame.new(x,3.5,0),i==1 and Color3.fromRGB(54,129,235) or Color3.fromRGB(229,65,65))
            table.insert(bars,bar)
        end
        welded(model,base,"PoliceStripe",Vector3.new(6.75,0.5,7),CFrame.new(0,0.1,0),Color3.fromRGB(215,222,231))
    end
    model.Parent=self.Folder; base:SetNetworkOwner(nil)
    local car={Model=model,Base=base,Seat=seat,Velocity=velocity,Align=align,Spring=spring,Spec=spec,Owner=player,Speed=0,Yaw=0,Throttle=0,Steer=0,LastInput=0,Health=100,Lights=lights,Indicators=indicators,Bars=bars,Id=id,LastHit=0}
    model:SetAttribute("Health",100); model:SetAttribute("VehicleId",id)
    self.Cars[model]=car; self.ByPlayer[player]=car
    local prompt=Util.prompt(seat,"Nastoupit",spec.Name,0)
    Guard:bindPrompt(prompt,function(p)
        local d=self.C.Data:get(p)
        return d and d.JailUntil<=os.time() and p==player and not seat.Occupant and Util.near(p,seat.Position,12)
    end,function(p) local _,hum=Util.root(p); if hum then seat:Sit(hum) end end)
    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local occupant=seat.Occupant
        if occupant then
            local driver=Players:GetPlayerFromCharacter(occupant.Parent)
            local d=driver and self.C.Data:get(driver)
            if driver~=player or not d or d.JailUntil>os.time() or (spec.Police and self.C.Roles[driver]~="Police") then occupant.Sit=false; return end
        end
        prompt.Enabled=not occupant; car.Throttle=0; car.Steer=0; base:SetNetworkOwner(nil)
    end)
    base.Touched:Connect(function(hit)
        if hit:IsDescendantOf(model) or not hit.CanCollide or os.clock()-car.LastHit<1.5 then return end
        -- Only a side/front impact at speed damages the car; road contact is excluded.
        local localPos=base.CFrame:PointToObjectSpace(hit.Position)
        if localPos.Y < -2 or math.abs(car.Speed)<38 then return end
        car.LastHit=os.clock(); car.Health=math.max(0,car.Health-math.floor(math.abs(car.Speed)/8)); model:SetAttribute("Health",car.Health)
    end)
    return true,"Auto čeká na výjezdu."
end
function Vehicle:input(player, throttle, steer, brake)
    if not Guard:allow(player,"drive",24,20) then return end
    if type(throttle)~="number" or throttle~=throttle or math.abs(throttle)>1 or type(steer)~="number" or steer~=steer or math.abs(steer)>1 or type(brake)~="boolean" then return end
    local car=self.ByPlayer[player]; local _,human=Util.root(player)
    if car and human and car.Seat.Occupant==human then car.Throttle=throttle; car.Steer=steer; car.Brake=brake; car.LastInput=os.clock() end
end
function Vehicle:action(player, action)
    local car=self.ByPlayer[player]; local _,human=Util.root(player)
    if not car or not human or car.Seat.Occupant~=human then return false,"Nejdřív nastup do vlastního auta." end
    if action=="lights" then for _,light in ipairs(car.Lights) do light.Enabled=not light.Enabled end
    elseif action=="signal" then car.Signal=not car.Signal
    elseif action=="siren" and car.Spec.Police then car.Siren=not car.Siren
    else return false,"Neplatná funkce vozu." end
    return true
end
function Vehicle:step(dt)
    for _, car in pairs(self.Cars) do
        if os.clock()-car.LastInput>0.5 or not car.Seat.Occupant then car.Throttle=0; car.Steer=0; car.Brake=true end
        local base=car.Base
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={car.Model,car.Owner.Character or car.Model}
        local hit=workspace:Raycast(base.Position,Vector3.new(0,-6,0),params)
        local grounded=hit and hit.Normal.Y>0.4
        local mass=base.AssemblyMass
        car.Spring.Force=grounded and Vector3.new(0,math.clamp(mass*(workspace.Gravity+(1.8-hit.Distance)*70-base.AssemblyLinearVelocity.Y*12),0,mass*workspace.Gravity*3),0) or Vector3.zero
        car.Velocity.Enabled=grounded~=nil and grounded~=false
        local target=car.Throttle*car.Spec.Speed*(car.Throttle<0 and 0.4 or 1); car.TrafficStop=false
        local horizontal=Vector3.new(base.AssemblyLinearVelocity.X,0,base.AssemblyLinearVelocity.Z)
        if math.abs(car.Speed)>3 and horizontal.Magnitude>1 then
            local direction=horizontal.Unit
            local axis=math.abs(direction.X)>math.abs(direction.Z) and 0 or 1
            local openAxis=workspace:GetAttribute("TrafficPhase") or 0
            if axis~=openAxis and not workspace:GetAttribute("TrafficAmber") then
                for _,x in ipairs({-180,0,180}) do for _,z in ipairs({-180,0,180}) do
                    local offset=Vector3.new(x-base.Position.X,0,z-base.Position.Z)
                    local ahead=offset:Dot(direction); local across=math.abs(offset.X*direction.Z-offset.Z*direction.X)
                    if ahead>0 and ahead<48 and across<15 then target=0; car.TrafficStop=true end
                end end
            end
        end
        if car.Health<=0 or car.Brake then target=0 end
        local acceleration=car.TrafficStop and 150 or (car.Brake or car.Throttle==0) and 65 or car.Spec.Acceleration
        car.Speed=car.Speed+math.clamp(target-car.Speed,-acceleration*dt,acceleration*dt)
        car.Yaw=car.Yaw-car.Steer*math.clamp(car.Speed/28,-1,1)*1.6*dt
        local forward=CFrame.Angles(0,car.Yaw,0).LookVector
        car.Velocity.PlaneVelocity=Vector2.new(forward.X*car.Speed,forward.Z*car.Speed)
        car.Align.CFrame=CFrame.Angles(0,car.Yaw,0)
        local flash=math.floor(os.clock()*3)%2==0
        for _,light in ipairs(car.Indicators) do light.Material=car.Signal and flash and Enum.Material.Neon or Enum.Material.SmoothPlastic end
        for i,bar in ipairs(car.Bars) do bar.Material=car.Siren and (flash==(i==1)) and Enum.Material.Neon or Enum.Material.SmoothPlastic end
        if base.Position.Y < -60 then self:destroy(car) end
    end
end
function Vehicle:repaint(car,index)
    local color=palette[index]; if not color then return end
    local names={Chassis=true,Hood=true,Roof=true,Pillar=true}
    for _,part in ipairs(car.Model:GetDescendants()) do if part:IsA("BasePart") and names[part.Name] then part.Color=color end end
end
function Vehicle:destroy(car)
    self.Cars[car.Model]=nil; if self.ByPlayer[car.Owner]==car then self.ByPlayer[car.Owner]=nil end
    car.Model:Destroy()
end
function Vehicle:remove(player) local car=self.ByPlayer[player]; if car then self:destroy(car) end end
return Vehicle
