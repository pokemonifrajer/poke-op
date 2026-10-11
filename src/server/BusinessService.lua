local Http=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config)
local Domain=require(Shared.Domain)
local Util=require(script.Parent.Util)
local Business={Contracts={},Next={}}
function Business:init(context)
    self.C=context; self.Markers=workspace.City.Markers
    context:bind("CompanyDesk","Založit / spravovat firmu","HARBOR • obchodní centrum",0,function(p) context.Remotes.OpenPanel:FireClient(p,"Business") end)
    for id,spec in pairs(Config.Company.Industries) do
        context:bind(spec.Pickup,"Převzít náklad",spec.Label.." • firemní zakázka",3,function(p) self:pickup(p,id) end)
        context:bind(spec.Drop,"Dokončit zakázku",spec.Label.." • předání",3,function(p) self:deliver(p,id) end)
    end
end
function Business:eligible(p)
    local d=self.C.Data:get(p)
    return d and d.JailUntil<=os.time() and d.Wanted==0 and self.C.Roles[p]~="Police" and not self.C.Heist:snapshot(p)
end
function Business:found(p,request)
    if not self:eligible(p) or not Util.near(p,self.Markers.CompanyDesk.Position,20) then return false,"Založ firmu u přepážky obchodního centra jako civilista bez hledanosti." end
    if type(request)~="table" then return false end
    local ok,reason=Domain.foundCompany(self.C.Data:get(p),request.Industry,request.Brand,Config,os.time())
    return ok,ok and "Firma založena. Přijmi první zakázku v telefonu → Firmy." or reason
end
function Business:start(p)
    local d=self.C.Data:get(p)
    if not self:eligible(p) or not d.Company then return false,"Nejdřív založ firmu. Zakázky může vozit civilista bez hledanosti." end
    if self.Contracts[p] or self.C.Jobs[p] then return false,"Nejdřív dokonči aktivní rozvoz." end
    if (self.Next[p] or 0)>os.clock() then return false,"Další nabídka bude za chvíli." end
    local spec=Config.Company.Industries[d.Company.Industry]
    self.Contracts[p]={Id=Http:GenerateGUID(false),Industry=d.Company.Industry,Stage="Pickup",Started=os.clock(),Deadline=os.time()+Config.Company.Deadline}
    return true,"Zakázka přijata. Vyzvedni materiál: "..(d.Company.Industry=="logistics" and "depo Harbor Express." or "přístavní sklad.")
end
function Business:pickup(p,industry)
    local job=self.Contracts[p]; local spec=Config.Company.Industries[industry]
    if not self:eligible(p) or not job or job.Industry~=industry or job.Stage~="Pickup" or not Util.near(p,self.Markers[spec.Pickup].Position,16) then return end
    job.Stage="Deliver"; job.PickedAt=os.clock()
    self.C:notify(p,"Náklad převzat. Doruč jej: "..(industry=="logistics" and "přístav." or "autoservis Aster.")); self.C:push(p)
end
function Business:deliver(p,industry)
    local job=self.Contracts[p]; local spec=Config.Company.Industries[industry]
    if not self:eligible(p) or not job or job.Industry~=industry or job.Stage~="Deliver" or not Util.near(p,self.Markers[spec.Drop].Position,16) then return end
    if os.time()>job.Deadline or os.clock()-job.PickedAt<Config.Company.MinSeconds then self.C:notify(p,"Dodávka nemá platný čas. Dokonči trasu."); return end
    local ok,amount=Domain.companyReward(self.C.Data:get(p),job.Id,Config,os.time())
    if ok then
        self.Contracts[p]=nil; self.Next[p]=os.clock()+Config.Company.Cooldown
        self.C:notify(p,"Zakázka dokončena. +$"..amount.." do firemní pokladny."); self.C:push(p)
    end
end
function Business:upgrade(p)
    if not self:eligible(p) or self.Contracts[p] then return false,"Rozšíření je dostupné bez aktivní zakázky a hledanosti." end
    return Domain.upgradeCompany(self.C.Data:get(p),Config,os.time())
end
function Business:withdraw(p)
    if not self:eligible(p) then return false,"Výběr je dostupný bez hledanosti." end
    return Domain.withdrawCompany(self.C.Data:get(p),Config,os.time())
end
function Business:cancel(p)
    if self.Contracts[p] then self.Contracts[p]=nil; self.Next[p]=os.clock()+Config.Company.Cooldown end
end
function Business:snapshot(p)
    local d=self.C.Data:get(p); local c=d and d.Company
    if not c then return nil end
    local result=Domain.copy(c); result.Name=Domain.companyName(c,Config)
    result.Cooldown=math.max(0,math.ceil((self.Next[p] or 0)-os.clock()))
    local job=self.Contracts[p]
    if job then
        local spec=Config.Company.Industries[job.Industry]
        result.Contract={Stage=job.Stage,Seconds=math.max(0,job.Deadline-os.time()),Target=job.Stage=="Pickup" and (job.Industry=="logistics" and "Depot" or "Docks") or spec.Destination}
    end
    return result
end
function Business:step()
    for p,job in pairs(self.Contracts) do
        if not self:eligible(p) or os.time()>job.Deadline then self:cancel(p); self.C:notify(p,"Firemní zakázka byla zrušena.") end
    end
end
function Business:remove(p) self.Contracts[p]=nil; self.Next[p]=nil end
return Business
