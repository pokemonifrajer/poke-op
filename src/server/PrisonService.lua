local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Prison={Keys={},Dig={},Tunnels={}}
function Prison:init(context)
    self.C=context; self.Markers=workspace.City.Markers
    context:bind("PrisonLaundry","Prohledat prádlo","Prádelna • přístupová karta",8,function(p)
        if self:jailed(p) then self.Keys[p]=true; context:notify(p,"Našel jsi služební kartu. Využij servisní východ."); context:push(p) end
    end)
    context:bind("PrisonExit","Použít kartu","Servisní dveře",3,function(p)
        if self:jailed(p) and self.Keys[p] then self:escape(p,"card") else context:notify(p,"Potřebuješ přístupovou kartu z prádelny.") end
    end)
    context:bind("TunnelDig","Uvolnit mříž","Starý odtok • 3 kroky",6,function(p)
        if not self:jailed(p) then return end
        self.Dig[p]=(self.Dig[p] or 0)+1
        if self.Dig[p]>=3 then
            self.Dig[p]=0; self.Tunnels[p]=os.clock(); context:teleport(p,self.Markers.TunnelStart.Position+Vector3.new(0,3,0))
            context:notify(p,"Mříž povolila. Projdi podzemím k východu.")
        else context:notify(p,"Uvolnění mříže: "..self.Dig[p].." / 3.") end
    end)
    context:bind("TunnelExit","Vylézt ven","Odtok za vězením",2,function(p)
        if self:jailed(p) and self.Tunnels[p] and os.clock()-self.Tunnels[p]>8 then self:escape(p,"tunnel") end
    end)
end
function Prison:jailed(p) local d=self.C.Data:get(p); return d and d.JailUntil>os.time() end
function Prison:arrest(target, officer)
    local d=self.C.Data:get(target)
    if not d or d.Wanted==0 or d.JailUntil>os.time() then return false end
    Domain.jail(d,os.time(),Config)
    self.C.Heist:remove(target); self.C.Jobs[target]=nil; self.C.Vehicles:remove(target)
    self.Keys[target]=nil; self.Dig[target]=nil; self.Tunnels[target]=nil
    self.C.Roles[target]="Civilian"; target.Team=self.C.Teams.Prisoner
    self.C:teleport(target,self.Markers.PrisonSpawn.Position+Vector3.new(0,3,0)); self:uniform(target)
    self.C:notify(target,"Jsi zatčen. Trest: "..(d.JailUntil-os.time()).." sekund. Můžeš počkat nebo hledat cestu ven.")
    if officer then
        local data=self.C.Data:get(officer)
        if data then Domain.reward(data,250,"arrest:"..target.UserId..":"..d.JailUntil,"Zatčení",Config,os.time()); self.C:push(officer) end
    end
    self.C:push(target); return true
end
function Prison:uniform(p)
    local c=p.Character; if not c then return end
    for _, item in ipairs(c:GetChildren()) do
        if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then item:Destroy() end
        if item:IsA("BasePart") and (item.Name:find("Torso") or item.Name:find("Leg") or item.Name:find("Arm")) then item.Color=Color3.fromRGB(220,127,57) end
    end
end
function Prison:escape(p, route)
    local d=self.C.Data:get(p); if not d then return end
    d.JailUntil=0; Domain.crime(d,4,os.time())
    self.Keys[p]=nil; self.Tunnels[p]=nil; self.Dig[p]=nil
    p.Team=self.C.Teams.Civilian
    self.C:teleport(p,self.Markers.PrisonOutside.Position+Vector3.new(0,3,0))
    self.C:notify(p,route=="card" and "Karta zabrala! Po útěku po tobě pátrá policie." or "Tunel tě dostal ven. Setřes policejní hlídky."); self.C:push(p)
end
function Prison:release(p)
    local d=self.C.Data:get(p); if not d then return end
    d.JailUntil=0; self.Keys[p]=nil; self.Tunnels[p]=nil; self.Dig[p]=nil
    p.Team=self.C.Teams.Civilian; self.C.RespawnAt[p]="Release"; p:LoadCharacter()
    self.C:notify(p,"Trest skončil. Jsi volný."); self.C:push(p)
end
function Prison:step()
    for p,profile in pairs(self.C.Data.Profiles) do
        local d=profile.Data
        if profile.Ready and not profile.Closing and d.JailUntil>0 then
            if d.JailUntil<=os.time() then self:release(p)
            else
                local root=Util.root(p)
                if root then
                    local pos=root.Position
                    local yard=math.abs(pos.X)<103 and pos.Z>-437 and pos.Z<-282 and pos.Y>-4
                    local tunnel=self.Tunnels[p] and pos.X>-12 and pos.X<152 and pos.Z>-384 and pos.Z<-353 and pos.Y<0 and pos.Y>-22
                    if not yard and not tunnel then self.C:teleport(p,self.Markers.PrisonSpawn.Position+Vector3.new(0,3,0)) end
                end
            end
        end
    end
end
function Prison:remove(p) self.Keys[p]=nil; self.Tunnels[p]=nil; self.Dig[p]=nil end
return Prison
