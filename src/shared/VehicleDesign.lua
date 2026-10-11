-- One visual builder for the drivable vehicle and its showroom preview.
local Design={}
function Design.build(spec,base,add,color)
    local width,length=base.Size.X,base.Size.Z
    local sport=spec.Speed>=110; local utility=spec.Length and spec.Length>14
    local roofY=utility and 3.6 or sport and 2.35 or 3
    local glass=Color3.fromRGB(43,67,86); local ink=Color3.fromRGB(19,23,30)
    add("Hood",Vector3.new(width*0.95,0.65,length*0.32),CFrame.new(0,0.85,-length*0.31),color)
    add("Roof",Vector3.new(width*0.76,0.3,length*(utility and 0.62 or 0.39)),CFrame.new(0,roofY,length*0.055),color)
    local wind=add("Windshield",Vector3.new(width*0.75,roofY-0.8,0.22),CFrame.new(0,(roofY+0.75)/2,-length*0.165)*CFrame.Angles(math.rad(-21),0,0),glass)
    wind.Material=Enum.Material.Glass; wind.Transparency=0.18
    add("RearWindow",Vector3.new(width*0.74,roofY-0.9,0.2),CFrame.new(0,(roofY+0.75)/2,length*0.255)*CFrame.Angles(math.rad(18),0,0),glass)
    for _,side in ipairs({-1,1}) do
        add("SideGlass",Vector3.new(0.2,roofY-1,length*0.38),CFrame.new(side*width*0.395,(roofY+0.8)/2,length*0.04),glass)
        for _,z in ipairs({-length*0.18,length*0.25}) do add("Pillar",Vector3.new(0.28,roofY-0.65,0.3),CFrame.new(side*width*0.4,(roofY+0.65)/2,z),color) end
        add("DoorSeam",Vector3.new(0.05,1.1,0.04),CFrame.new(side*(width/2+0.02),0.1,length*0.05),ink)
        add("DoorHandle",Vector3.new(0.13,0.15,0.85),CFrame.new(side*(width/2+0.05),0.45,length*0.1),Color3.fromRGB(170,177,185))
        add("SideSkirt",Vector3.new(0.35,0.4,length*0.72),CFrame.new(side*width*0.48,-0.64,0),ink)
        add("Mirror",Vector3.new(0.65,0.36,1.2),CFrame.new(side*width*0.57,1.12,-length*0.11),color)
        for _,z in ipairs({-length*0.31,length*0.31}) do
            add("Wheel",Vector3.new(1.15,2.65,2.65),CFrame.new(side*width*0.51,-0.45,z),ink,Enum.PartType.Cylinder)
            add("Rim",Vector3.new(1.2,1.65,1.65),CFrame.new(side*width*0.51,-0.45,z),Color3.fromRGB(127,137,151),Enum.PartType.Cylinder)
            add("Hub",Vector3.new(1.25,0.68,0.68),CFrame.new(side*width*0.51,-0.45,z),ink,Enum.PartType.Cylinder)
        end
    end
    add("Grille",Vector3.new(width*0.58,0.55,0.15),CFrame.new(0,-0.1,-length/2-0.06),ink)
    add("FrontLip",Vector3.new(width*0.98,0.25,0.6),CFrame.new(0,-0.7,-length/2),ink)
    add("RearBumper",Vector3.new(width*0.98,0.36,0.4),CFrame.new(0,-0.55,length/2),ink)
    if sport then
        add("RearSpoiler",Vector3.new(width*0.91,0.18,1.2),CFrame.new(0,1.35,length*0.42),ink)
        for _,x in ipairs({-width*0.3,width*0.3}) do add("SpoilerSupport",Vector3.new(0.18,0.6,0.3),CFrame.new(x,1.07,length*0.42),ink) end
    elseif utility then
        add("CargoBody",Vector3.new(width*0.92,2.7,length*0.43),CFrame.new(0,2,length*0.2),color)
        add("CargoSeam",Vector3.new(0.05,2.5,0.05),CFrame.new(0,2,length*0.416),ink)
    end
end
return Design
