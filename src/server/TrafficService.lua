-- Cosmetic, server-driven traffic. No collision damage or gameplay rewards.
local Util=require(script.Parent.Util)
local Traffic={Cars={}}
local function positionAlong(points,distance)
    local edge=math.floor(distance/344)%4+1
    local t=(distance%344)/344
    local from,to=points[edge],points[edge%4+1]
    return from:Lerp(to,t),(to-from).Unit,edge
end
function Traffic:init()
    self.Folder=Instance.new("Folder"); self.Folder.Name="AmbientTraffic"; self.Folder.Parent=workspace
    self.Points={Vector3.new(-172,2,-172),Vector3.new(172,2,-172),Vector3.new(172,2,172),Vector3.new(-172,2,172)}
    for i=1,5 do
        local model=Instance.new("Model"); model.Name="Traffic "..i; model.Parent=self.Folder
        local color=Color3.fromHSV(i/8,0.25,0.65)
        local base=Util.part(model,"Body",Vector3.new(6,1.6,11),CFrame.new(0,0,0),color); base.CanCollide=false
        local roof=Util.part(model,"Cabin",Vector3.new(5,2.1,5),CFrame.new(0,1.8,0),Color3.fromRGB(65,95,110)); roof.CanCollide=false
        for _,x in ipairs({-3.1,3.1}) do for _,z in ipairs({-3.3,3.3}) do
            local wheel=Util.part(model,"Wheel",Vector3.new(0.8,2.1,2.1),CFrame.new(x,-0.4,z),Color3.fromRGB(28,31,36)); wheel.Shape=Enum.PartType.Cylinder; wheel.CanCollide=false
        end end
        for _,x in ipairs({-2,2}) do
            local lens=Util.part(model,"Headlamp",Vector3.new(1.2,0.4,0.2),CFrame.new(x,0,-5.6),Color3.fromRGB(243,224,184)); lens.Material=Enum.Material.Neon; lens.CanCollide=false
        end
        model.PrimaryPart=base
        self.Cars[i]={Model=model,Distance=(i-1)*270,Speed=22+(i%2)*3}
    end
end
function Traffic:step(dt)
    local phase=workspace:GetAttribute("TrafficPhase") or 0
    for _,car in ipairs(self.Cars) do
        local pos,dir,edge=positionAlong(self.Points,car.Distance)
        local progress=car.Distance%344
        -- Stop before the central intersection and before each corner.
        local stop=(progress>142 and progress<151) or (progress>316 and progress<325)
        local wait=stop and (edge%2~=phase)
        for _,other in ipairs(self.Cars) do
            local gap=(other.Distance-car.Distance)%1376
            if other~=car and gap>0 and gap<22 then wait=true end
        end
        if not wait then car.Distance=(car.Distance+car.Speed*dt)%1376 end
        pos,dir=positionAlong(self.Points,car.Distance)
        car.Model:PivotTo(CFrame.lookAt(pos,pos+dir))
    end
end
return Traffic
