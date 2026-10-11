local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Prison={Keys={},Dig={},Tunnels={},Tools={},Vents={},WorkNext={},WorkCount={},GateUntil=0}
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
    context:bind("PrisonWorkshop","Pracovat v dílně","Práce • zkrácení trestu o 8 s",5,function(p)
        if not self:jailed(p) then return end
        if (self.WorkNext[p] or 0)>os.clock() or (self.WorkCount[p] or 0)>=2 then context:notify(p,"Dnešní pracovní směna skončila. Další možnost: útěk, nebo počkat na propuštění."); return end
        local d=context.Data:get(p); d.JailUntil=math.max(os.time()+1,d.JailUntil-8)
        self.WorkNext[p]=os.clock()+18; self.WorkCount[p]=(self.WorkCount[p] or 0)+1; self.Tools[p]=true
        context:notify(p,"Odpracováno: trest −8 s. Našel jsi také nástroj na ventilační mříž."); context:push(p)
    end)
    context:bind("PrisonMeal","Vzít jídlo","Vězeňská jídelna",2,function(p)
        if self:jailed(p) then local _,h=Util.root(p); if h then h.Health=math.min(h.MaxHealth,h.Health+25); context:notify(p,"Najedl ses. +25 zdraví.") end end
    end)
    context:bind("VentEnter","Odšroubovat mříž","Ventilace • potřebuješ nástroj z dílny",5,function(p)
        if not self:jailed(p) or not self.Tools[p] then context:notify(p,"Nejdřív pracuj v dílně. Potřebuješ nástroj."); return end
        self.Tools[p]=nil; self.Vents[p]=os.clock(); context:teleport(p,self.Markers.VentStart.Position+Vector3.new(0,3,0)); context:notify(p,"Jsi ve ventilační chodbě. Najdi výstup na jejím konci.")
    end)
    context:bind("VentExit","Otevřít výstup","Výstup za perimetrem",3,function(p)
        if self:jailed(p) and self.Vents[p] and os.clock()-self.Vents[p]>=8 then self:escape(p,"vent") end
    end)
    context:bind("PrisonGateConsole","Otevřít bránu","Northgate • služební vstup",1,function(p)
        if context.Roles[p]~="Police" then context:notify(p,"Bránu může otevřít pouze policista."); return end
        self.GateUntil=os.clock()+8; self.Markers.PrisonGate.CanCollide=false; self.Markers.PrisonGate.Transparency=0.8
    end)
    context:bind("PrisonIntake","Vězeňský přehled","Northgate • evidence",0,function(p) context.Remotes.OpenPanel:FireClient(p,"Prison") end)

end
function Prison:jailed(p) local d=self.C.Data:get(p); return d and d.JailUntil>os.time() end
function Prison:arrest(target, officer)
    local d=self.C.Data:get(target)
    if not d or d.Wanted==0 or d.JailUntil>os.time() then return false end
    Domain.jail(d,os.time(),Config)
    self.C.Heist:remove(target); self.C.Jobs[target]=nil; self.C.Vehicles:remove(target)
    self:remove(target)
    if self.C.Business then self.C.Business:cancel(target) end
    if self.C.Police then self.C.Police:remove(target) end
    self.C.Roles[target]="Civilian"; target.Team=self.C.Teams.Prisoner
    self.C:teleport(target,self.Markers.PrisonSpawn.Position+Vector3.new(0,3,0)); self:uniform(target)
    self.C:notify(target,"Jsi zatčen. Trest: "..(d.JailUntil-os.time()).." sekund. Můžeš počkat nebo hledat cestu ven.")
    if officer then
        local data=self.C.Data:get(officer)
        if data and Domain.reward(data,250,"arrest:"..target.UserId..":"..d.JailUntil,"Zatčení hráče",Config,os.time()) then data.Arrests=math.min(100000000,(data.Arrests or 0)+1); self.C:notify(officer,"Hráč byl poslán do Northgate. +$250"); self.C:push(officer) end
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
    self:remove(p)
    p.Team=self.C.Teams.Civilian
    self.C:teleport(p,self.Markers.PrisonOutside.Position+Vector3.new(0,3,0))
    self.C:notify(p,route=="card" and "Karta zabrala! Po útěku po tobě pátrá policie." or route=="vent" and "Ventilace tě dostala ven. Policie vyhlásila pátrání." or "Dostal ses ven. Setřes policejní hlídky."); self.C:push(p)
end
function Prison:release(p)
    local d=self.C.Data:get(p); if not d then return end
    d.JailUntil=0; self:remove(p)
    p.Team=self.C.Teams.Civilian; self.C.RespawnAt[p]="Release"; p:LoadCharacter()
    self.C:notify(p,"Trest skončil. Jsi volný."); self.C:push(p)
end
function Prison:step()
    local open=os.clock()<self.GateUntil
    self.Markers.PrisonGate.CanCollide=not open; self.Markers.PrisonGate.Transparency=open and 0.8 or 0
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
                    local vent=self.Vents[p] and pos.X> -55 and pos.X<154 and pos.Z> -418 and pos.Z< -404 and pos.Y>13 and pos.Y<28
                    if open and math.abs(pos.X)<8 and pos.Z> -284 and pos.Z< -267 then self:escape(p,"gate")
                    elseif not yard and not tunnel and not vent then self.C:teleport(p,self.Markers.PrisonSpawn.Position+Vector3.new(0,3,0)) end
                end
            end
        end
    end
end
function Prison:remove(p) self.Keys[p]=nil; self.Tunnels[p]=nil; self.Dig[p]=nil; self.Tools[p]=nil; self.Vents[p]=nil; self.WorkNext[p]=nil; self.WorkCount[p]=nil end
return Prison
