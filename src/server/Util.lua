local Util = {}
function Util.root(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if root and human and human.Health > 0 then return root, human end
    return nil
end
function Util.near(player, position, radius)
    local root = Util.root(player)
    return root ~= nil and (root.Position - position).Magnitude <= radius
end
function Util.los(from, to, exclusions)
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclusions or {}
    local hit = workspace:Raycast(from, to - from, params)
    return not hit or (hit.Position - to).Magnitude < 2
end
function Util.part(parent, name, size, cf, color, anchored)
    local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf
    p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = anchored ~= false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent; return p
end
function Util.prompt(part, action, object, duration)
    local p = Instance.new("ProximityPrompt"); p.ActionText = action; p.ObjectText = object
    p.HoldDuration = duration or 0; p.MaxActivationDistance = 11; p.RequiresLineOfSight = true; p.Parent = part; return p
end
function Util.vector(array) return Vector3.new(array[1], array[2], array[3]) end
function Util.teleport(player, position)
    local root, human = Util.root(player)
    if root then
        human.Sit = false
        local weld = human.SeatPart and human.SeatPart:FindFirstChild("SeatWeld")
        if weld then weld:Destroy() end
        root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
        player.Character:PivotTo(CFrame.new(position))
    end
end
return Util
