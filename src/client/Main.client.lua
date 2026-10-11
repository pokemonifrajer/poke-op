local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
local CAS=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local Config=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local VehicleDesign=require(ReplicatedStorage.Shared.VehicleDesign)
local network=ReplicatedStorage:WaitForChild("Network")
local Action=network:WaitForChild("Action")
local palette={Bg=Color3.fromRGB(9,13,20),Panel=Color3.fromRGB(16,22,31),Card=Color3.fromRGB(28,36,47),Text=Color3.fromRGB(239,242,247),Muted=Color3.fromRGB(147,160,180),Teal=Color3.fromRGB(117,179,250),Gold=Color3.fromRGB(239,190,110),Red=Color3.fromRGB(226,62,79),Green=Color3.fromRGB(106,218,153)}
local menuOpen=true; local profileReady=false
local state={Cash=0,Bank=0,Wanted=0,Jail=0,Cars={},Transactions={},Role="Civilian",Roster={}}
local screen=Instance.new("ScreenGui"); screen.Name="HarborHUD"; screen.ResetOnSpawn=false; screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; screen.Parent=player:WaitForChild("PlayerGui")
local gui=Instance.new("Frame"); gui.Name="Surface"; gui.BackgroundTransparency=1; gui.Size=UDim2.fromScale(1,1); gui.Parent=screen
local scale=Instance.new("UIScale"); scale.Parent=gui
local function resize()
    local camera=workspace.CurrentCamera
    if camera then scale.Scale=math.clamp(math.min(camera.ViewportSize.X/1050,camera.ViewportSize.Y/650),0.5,1); gui.Size=UDim2.fromScale(1/scale.Scale,1/scale.Scale) end
end
resize(); workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resize)
local function create(class,parent,props)
    local object=Instance.new(class)
    for k,v in pairs(props or {}) do object[k]=v end
    object.Parent=parent; return object
end
local function corner(o,r) create("UICorner",o,{CornerRadius=UDim.new(0,r or 12)}) end
local function frame(parent,pos,size,color)
    local f=create("Frame",parent,{Position=pos,Size=size,BackgroundColor3=color or palette.Panel,BorderSizePixel=0}); corner(f,10); return f
end
local function text(parent,value,pos,size,opts)
    opts=opts or {}
    return create("TextLabel",parent,{Text=value,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=opts.Color or palette.Text,TextSize=opts.Size or 16,Font=opts.Bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=opts.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=opts.Wrap or false})
end
local function button(parent,label,pos,size,callback,color)
    local b=create("TextButton",parent,{Text=label,Position=pos,Size=size,BackgroundColor3=color or palette.Card,BorderSizePixel=0,TextColor3=palette.Text,TextSize=15,Font=Enum.Font.GothamMedium,AutoButtonColor=true})
    corner(b,8); b.Activated:Connect(callback)
    local original=color or palette.Card
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.16),{BackgroundColor3=original:Lerp(palette.Text,0.12)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.16),{BackgroundColor3=original}):Play() end)
    return b
end
local function input(parent,placeholder,pos,size)
    local t=create("TextBox",parent,{PlaceholderText=placeholder,Text="",Position=pos,Size=size,BackgroundColor3=palette.Card,BorderSizePixel=0,TextColor3=palette.Text,PlaceholderColor3=palette.Muted,TextSize=16,Font=Enum.Font.Gotham,ClearTextOnFocus=false}); corner(t,8); return t
end
local function cash(n)
    local digits=tostring(math.floor(n or 0)); local count
    repeat digits,count=digits:gsub("^(%-?%d+)(%d%d%d)","%1 %2") until count==0
    return "$"..digits
end
local top=frame(gui,UDim2.new(0,20,0,14),UDim2.new(1,-40,0,66))
text(top,"HARBOR\nCITY / 03",UDim2.fromOffset(18,8),UDim2.fromOffset(125,50),{Size=19,Bold=true})
local money=text(top,"Načítání profilu…",UDim2.fromOffset(156,10),UDim2.fromOffset(295,25),{Size=18,Bold=true})
local role=text(top,"",UDim2.fromOffset(156,34),UDim2.fromOffset(345,21),{Size=12,Color=palette.Muted})
local stars=text(top,"",UDim2.new(1,-295,0,9),UDim2.fromOffset(170,29),{Size=24,Bold=true,Color=palette.Gold})
local health=text(top,"",UDim2.new(1,-295,0,38),UDim2.fromOffset(180,19),{Size=12,Color=palette.Muted})
local objective=frame(gui,UDim2.fromOffset(20,93),UDim2.fromOffset(345,92))
text(objective,"AKTUÁLNÍ CÍL",UDim2.fromOffset(15,9),UDim2.fromOffset(315,17),{Size=11,Bold=true,Color=palette.Teal})
local objectiveText=text(objective,"Prozkoumej město. V telefonu najdeš mapu a garáž.",UDim2.fromOffset(15,28),UDim2.fromOffset(315,54),{Size=14,Wrap=true})
local toast=frame(gui,UDim2.new(0.5,-255,0,92),UDim2.fromOffset(510,58)); toast.Visible=false; toast.ZIndex=60
local toastText=text(toast,"",UDim2.fromOffset(16,5),UDim2.new(1,-32,1,-10),{Size=15,Center=true,Wrap=true})
toastText.ZIndex=60
local toastSerial=0
local function notify(message)
    toastSerial=toastSerial+1; local serial=toastSerial; toastText.Text=message; toast.Visible=true
    task.delay(5,function() if toastSerial==serial then toast.Visible=false end end)
end
network.Notify.OnClientEvent:Connect(notify)
local mapInstances={}; local waypoint=nil; local waypointPart=nil; local trackedId=nil
local function mapPosition(x,z) return (x-Config.Map.MinX)/(Config.Map.MaxX-Config.Map.MinX),(z-Config.Map.MinZ)/(Config.Map.MaxZ-Config.Map.MinZ) end
local names={Spawn="Náměstí",Police="Policie",Garage="Garáž",Bank="Banka",Prison="Vězení",Docks="Přístav",Apartment="Marina",Depot="Depo",Jewelry="Klenotnictví",School="Škola",Industrial="Průmysl",Airport="Letiště",WestwoodHome="Westwood",NorthHillHome="North Hill",Company="Firma"}
local function setWaypoint(key)
    waypoint=key; trackedId=nil
    if waypointPart then waypointPart:Destroy(); waypointPart=nil end
    local loc=Config.Locations[key]
    if not loc then return end
    local p=create("Part",workspace,{Name="LocalWaypoint",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Transparency=1,Size=Vector3.one,Position=Vector3.new(loc[1],loc[2]+12,loc[3])})
    local billboard=create("BillboardGui",p,{Size=UDim2.fromOffset(150,46),AlwaysOnTop=true,MaxDistance=1500})
    text(billboard,names[key] or key,UDim2.fromScale(0,0),UDim2.fromScale(1,1),{Size=18,Bold=true,Center=true,Color=palette.Teal})
    waypointPart=p; notify("Navigace: "..(names[key] or key))
end
local function makeMap(parent,pos,size,full)
    local f=frame(parent,pos,size,Color3.fromRGB(22,36,42)); f.ClipsDescendants=true
    local spanX=Config.Map.MaxX-Config.Map.MinX; local spanZ=Config.Map.MaxZ-Config.Map.MinZ
    local function rectangle(x,z,w,d,color)
        local mx,mz=mapPosition(x-w/2,z-d/2)
        create("Frame",f,{Position=UDim2.fromScale(mx,mz),Size=UDim2.fromScale(w/spanX,d/spanZ),BorderSizePixel=0,BackgroundColor3=color})
    end
    rectangle(477,0,66,995,Color3.fromRGB(18,46,67))
    for _,block in ipairs({{-84,-84,88,72},{84,-88,86,64},{-85,86,87,65},{-266,-87,67,85},{267,-85,63,78},{-90,268,94,63},{-266,268,65,61},{266,-261,58,64},{-270,-258,66,62},{267,270,78,67},{-267,82,65,64},{-84,-244,60,44},{270,390,96,78},{320,-340,58,48},{-350,255,56,44}}) do rectangle(block[1],block[2],block[3],block[4],Color3.fromRGB(45,56,61)) end
    rectangle(85,80,124,122,Color3.fromRGB(38,57,50))
    rectangle(0,320,800,30,Color3.fromRGB(64,76,86))
    rectangle(-405,-12,30,415,Color3.fromRGB(64,76,86)); rectangle(340,131,30,622,Color3.fromRGB(64,76,86))
    for _,v in ipairs({-180,0,180}) do rectangle(v,40,36,720,Color3.fromRGB(64,76,86)); rectangle(0,v,640,36,Color3.fromRGB(64,76,86)) end
    rectangle(0,-359,204,150,Color3.fromRGB(86,96,104))
    rectangle(395,170,42,260,Color3.fromRGB(56,62,69))
    if full then
        for _,district in ipairs({{"WESTWOOD",-340,245},{"DOWNTOWN",0,35},{"INDUSTRIAL",-430,115},{"NORTH HILLS",320,-390},{"PORT",270,80},{"AIRPORT",393,350},{"SOUTH COAST",40,370}}) do
            local x,z=mapPosition(district[2],district[3])
            local tag=text(f,district[1],UDim2.fromScale(x-0.08,z-0.025),UDim2.fromScale(0.16,0.05),{Size=10,Bold=true,Center=true,Color=palette.Text})
            tag.TextTransparency=0.12
        end
    end
    for key,loc in pairs(Config.Locations) do
        if names[key] then
            local x,z=mapPosition(loc[1],loc[3])
            local mark=button(f,full and names[key] or "•",UDim2.fromScale(x,z),full and UDim2.fromOffset(47,19) or UDim2.fromOffset(15,15),function() setWaypoint(key) end,palette.Panel)
            mark.AnchorPoint=Vector2.new(0.5,0.5); mark.TextSize=full and 10 or 17; mark.TextColor3=key=="Prison" and palette.Gold or palette.Teal
        end
    end
    local dot=create("Frame",f,{Size=UDim2.fromOffset(9,9),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=palette.Text,BorderSizePixel=0,ZIndex=5}); corner(dot,9)
    local targetDot=create("Frame",f,{Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=palette.Red,BorderSizePixel=0,ZIndex=5,Visible=false}); corner(targetDot,12)
    table.insert(mapInstances,{Frame=f,Dot=dot,Target=targetDot}); return f
end
local mini=makeMap(gui,UDim2.new(0,20,1,-207),UDim2.fromOffset(185,185),false)
local navigation=text(gui,"",UDim2.new(0,219,1,-65),UDim2.fromOffset(305,36),{Size=13,Wrap=true,Color=palette.Teal})
local speed=text(gui,"",UDim2.new(1,-320,1,-235),UDim2.fromOffset(296,45),{Size=30,Bold=true})
local carHealth=text(gui,"",UDim2.new(1,-320,1,-193),UDim2.fromOffset(296,23),{Size=13,Color=palette.Muted})
local panel=frame(gui,UDim2.new(1,-16,0.5,0),UDim2.fromOffset(368,620),Color3.fromRGB(6,10,16)); panel.AnchorPoint=Vector2.new(1,0.5); panel.Visible=false; panel.ZIndex=30; corner(panel,38)
create("UIStroke",panel,{Thickness=2,Color=Color3.fromRGB(94,112,126),Transparency=0.18})
local phone=frame(panel,UDim2.fromOffset(8,8),UDim2.fromOffset(352,604),palette.Bg); corner(phone,32)
local phoneTime=text(phone,"",UDim2.fromOffset(18,9),UDim2.fromOffset(100,18),{Size=11,Bold=true,Color=palette.Muted})
corner(create("Frame",phone,{Position=UDim2.new(0.5,-48,0,7),Size=UDim2.fromOffset(96,19),BackgroundColor3=Color3.fromRGB(5,8,12),BorderSizePixel=0}),10)
text(phone,"••• ▮",UDim2.new(1,-66,0,7),UDim2.fromOffset(50,20),{Size=10,Bold=true,Center=true,Color=palette.Teal})
local panelTitle=text(phone,"HARBOR MOBILE",UDim2.fromOffset(17,31),UDim2.fromOffset(260,32),{Size=19,Bold=true})
local content=frame(phone,UDim2.fromOffset(14,145),UDim2.fromOffset(324,438),palette.Panel); corner(content,20)
local panelRefresh=nil; local previewUpdate=nil
button(phone,"×",UDim2.fromOffset(309,34),UDim2.fromOffset(27,27),function() panel.Visible=false end)
local openPanel
local showTablet
local closeTablet
local tabletRefresh=nil
local function clearContent()
    for _,child in ipairs(content:GetChildren()) do if not child:IsA("UICorner") then child:Destroy() end end
    panelRefresh=nil; previewUpdate=nil
end
local function description(value,y,height)
    return text(content,value,UDim2.fromOffset(13,y),UDim2.fromOffset(294,height or 43),{Size=13,Color=palette.Muted,Wrap=true})
end
local function send(action,value) Action:FireServer(action,value) end
local labels={Home="DOMŮ",Map="MAPA",Garage="AUTA",Jobs="PRÁCE",Bank="BANKA",Police="POLICIE",HomeApp="NEMOVITOSTI",Business="PODNIKÁNÍ",Settings="NASTAVENÍ",Prison="NORTHGATE",Franchises="FRANŠÍZY"}
openPanel=function(name)
    if (name=="Police" or name=="Map") and showTablet then showTablet(name); return end
    if closeTablet then closeTablet() end
    panel.Visible=true; clearContent(); panelTitle.Text=name=="Home" and "HARBOR MOBILE" or (labels[name] or "APLIKACE")
    if name=="Map" then
        makeMap(content,UDim2.fromOffset(8,12),UDim2.fromOffset(308,355),true)
        description("Kliknutím na značku nastavíš navigaci. M • domů",374,40)
    elseif name=="Garage" then
        local catalog={"commuter","sport","suv","muscle","van","patrol"}; local selection=1
        local nameLabel=text(content,"",UDim2.fromOffset(13,10),UDim2.fromOffset(295,25),{Bold=true,Size=19})
        local viewport=create("ViewportFrame",content,{Position=UDim2.fromOffset(8,44),Size=UDim2.fromOffset(308,187),BackgroundColor3=Color3.fromRGB(21,29,42),BorderSizePixel=0,Ambient=Color3.fromRGB(170,180,195),LightColor=Color3.fromRGB(255,221,183),LightDirection=Vector3.new(-1,-1,-1)})
        corner(viewport,10)
        local camera=create("Camera",viewport,{FieldOfView=38}); viewport.CurrentCamera=camera
        local world=create("WorldModel",viewport,{}); local angle=0
        local price=text(content,"",UDim2.fromOffset(13,239),UDim2.fromOffset(295,26),{Size=16,Bold=true,Color=palette.Green})
        local stats=text(content,"",UDim2.fromOffset(13,269),UDim2.fromOffset(295,23),{Size=12,Color=palette.Muted})
        local function render()
            world:ClearAllChildren(); local spec=Config.Vehicles[catalog[selection]]
            nameLabel.Text=spec.Name
            local model=create("Model",world,{Name=spec.Name}); local color=Color3.fromRGB(table.unpack(spec.Color))
            local base=create("Part",model,{Name="Chassis",Anchored=true,Size=Vector3.new(spec.Width or 6.7,1.5,spec.Length or 12),Color=color,CFrame=CFrame.identity})
            local function add(name,size,offset,tint,shape)
                local part=create("Part",model,{Name=name,Size=size,CFrame=offset,Color=tint,Anchored=true,Material=Enum.Material.SmoothPlastic})
                if shape then part.Shape=shape end; return part
            end
            VehicleDesign.build(spec,base,add,color)
            for _,x in ipairs({-2.3,2.3}) do
                add("Headlamp",Vector3.new(1.5,0.5,0.2),CFrame.new(x,0.35,-base.Size.Z/2-0.05),Color3.fromRGB(240,230,200)).Material=Enum.Material.Neon
                add("TailLamp",Vector3.new(1.5,0.4,0.2),CFrame.new(x,0.35,base.Size.Z/2+0.05),palette.Red).Material=Enum.Material.Neon
            end
            if spec.Police then for i,x in ipairs({-1.4,1.4}) do add("Lightbar",Vector3.new(2.4,0.5,0.8),CFrame.new(x,3.5,0),i==1 and palette.Teal or palette.Red).Material=Enum.Material.Neon end end
            add("Podium",Vector3.new(21,0.25,23),CFrame.new(0,-1.9,0),Color3.fromRGB(36,43,54))
            angle=0; stats.Text="RYCHLOST "..spec.Speed.."    /    ZRYCHLENÍ "..spec.Acceleration
        end
        local prevCar=button(content,"‹",UDim2.fromOffset(14,190),UDim2.fromOffset(43,31),function() selection=(selection-2)%#catalog+1; render() end)
        local nextCar=button(content,"›",UDim2.fromOffset(267,190),UDim2.fromOffset(43,31),function() selection=selection%#catalog+1; render() end)
        prevCar.ZIndex=2; nextCar.ZIndex=2
        button(content,"KOUPIT",UDim2.fromOffset(13,304),UDim2.fromOffset(141,39),function() send("buyCar",catalog[selection]) end)
        button(content,"VYZVEDNOUT",UDim2.fromOffset(165,304),UDim2.fromOffset(146,39),function() send("spawnCar",catalog[selection]) end,palette.Red)
        button(content,"Navigace k výdeji",UDim2.fromOffset(13,351),UDim2.fromOffset(298,32),function() setWaypoint(catalog[selection]=="patrol" and "Police" or "Garage") end)
        for i,tint in ipairs({Color3.fromRGB(68,155,173),palette.Gold,Color3.fromRGB(214,219,225),Color3.fromRGB(32,37,49),palette.Red,Color3.fromRGB(126,151,106)}) do button(content,"",UDim2.fromOffset(14+(i-1)*50,396),UDim2.fromOffset(42,23),function() send("color",i) end,tint) end
        panelRefresh=function() local id=catalog[selection]; price.Text=Config.Vehicles[id].Police and "SLUŽEBNÍ VŮZ" or state.Cars[id] and "VE TVÉ GARÁŽI" or cash(Config.Vehicles[id].Price) end
        previewUpdate=function(dt) if not viewport.Parent then return end; angle=angle+dt*0.18; camera.CFrame=CFrame.lookAt(Vector3.new(math.cos(angle)*20,10,math.sin(angle)*20-16),Vector3.new(0,0.7,0)) end
        render(); previewUpdate(0)
    elseif name=="Bank" then
        local balance=text(content,"",UDim2.fromOffset(12,9),UDim2.fromOffset(293,41),{Size=16,Bold=true,Wrap=true})
        local amount=input(content,"Částka",UDim2.fromOffset(12,56),UDim2.fromOffset(122,38))
        button(content,"Vložit",UDim2.fromOffset(142,56),UDim2.fromOffset(75,38),function() send("deposit",tonumber(amount.Text)) end)
        button(content,"Vybrat",UDim2.fromOffset(223,56),UDim2.fromOffset(88,38),function() send("withdraw",tonumber(amount.Text)) end)
        local history=text(content,"",UDim2.fromOffset(12,112),UDim2.fromOffset(294,296),{Size=12,Wrap=true}); history.TextYAlignment=Enum.TextYAlignment.Top
        panelRefresh=function()
            balance.Text="ÚČET  "..cash(state.Bank).."\nHOTOVOST  "..cash(state.Cash)
            local lines={"POSLEDNÍ TRANSAKCE"}
            for i,t in ipairs(state.Transactions) do if i>9 then break end; table.insert(lines,t.Label.."     "..(t.Amount>0 and "+" or "")..cash(t.Amount)) end
            history.Text=table.concat(lines,"\n\n")
        end
    elseif name=="Jobs" then
        description("ROZVOZ · odměna $450",5,25)
        button(content,"Najít depo",UDim2.fromOffset(12,36),UDim2.fromOffset(144,39),function() setWaypoint("Depot") end)
        button(content,"Vyzvednout",UDim2.fromOffset(169,36),UDim2.fromOffset(142,39),function() send("job") end)
        button(content,"Zrušit rozvoz",UDim2.fromOffset(12,82),UDim2.fromOffset(299,35),function() send("cancelJob") end)
        description("BANKA · až 4 hráči · $3 800",128,30)
        button(content,"Najít banku",UDim2.fromOffset(12,160),UDim2.fromOffset(144,38),function() setWaypoint("Bank") end)
        button(content,"Začít loupež",UDim2.fromOffset(169,160),UDim2.fromOffset(142,38),function() send("startHeist","bank") end)
        description("KLENOTNICTVÍ · $2 900",209,28)
        button(content,"Najít obchod",UDim2.fromOffset(12,239),UDim2.fromOffset(144,38),function() setWaypoint("Jewelry") end)
        button(content,"Začít loupež",UDim2.fromOffset(169,239),UDim2.fromOffset(142,38),function() send("startHeist","jewelry") end)
        description("PANCÉŘOVÁ DODÁVKA · $2 300",288,34)
        button(content,"Najít sklady",UDim2.fromOffset(12,324),UDim2.fromOffset(144,38),function() setWaypoint("Industrial") end)
        button(content,"Začít loupež",UDim2.fromOffset(169,324),UDim2.fromOffset(142,38),function() send("startHeist","convoy") end)
    elseif name=="Police" then
        description("POLICEJNÍ PRÁCE",8,25)
        button(content,"Najít stanici",UDim2.fromOffset(12,42),UDim2.fromOffset(144,38),function() setWaypoint("Police") end)
        button(content,"Nastoupit službu",UDim2.fromOffset(169,42),UDim2.fromOffset(142,38),function() send("role","Police") end)
        button(content,"Zpět na civilistu",UDim2.fromOffset(12,87),UDim2.fromOffset(299,38),function() send("role","Civilian") end)
        description("Pouta: 11 studů. Zůstaň u hledaného hráče 3 sekundy. Databázi vidí pouze policie.",136,52)
        local rosterFrame=create("ScrollingFrame",content,{Position=UDim2.fromOffset(10,194),Size=UDim2.fromOffset(304,219),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0)})
        local previous=""
        panelRefresh=function()
            local signature=state.Role
            for _,record in ipairs(state.Roster) do signature=signature..record.Id..":"..record.Wanted end
            if signature==previous then return end; previous=signature
            for _,child in ipairs(rosterFrame:GetChildren()) do child:Destroy() end
            if state.Role~="Police" then text(rosterFrame,"Přístup pro policisty ve službě.",UDim2.fromOffset(8,8),UDim2.fromOffset(285,50),{Wrap=true}); return end
            if #state.Roster==0 then text(rosterFrame,"Nikdo není hledaný.",UDim2.fromOffset(8,8),UDim2.fromOffset(285,42),{Wrap=true}) end
            for i,record in ipairs(state.Roster) do
                text(rosterFrame,record.Name.." · "..record.Wanted.." ★",UDim2.fromOffset(5,(i-1)*45),UDim2.fromOffset(161,40),{Size=13})
                button(rosterFrame,"Zatknout",UDim2.fromOffset(172,(i-1)*45+4),UDim2.fromOffset(121,34),function() send("arrest",record.Id) end)
            end
            rosterFrame.CanvasSize=UDim2.fromOffset(0,#state.Roster*45)
        end
    elseif name=="HomeApp" then
        description("Tři skutečné domy s vlastními vchody a interiéry. Nákup potvrď u jejich recepce.",8,42)
        local ownership=text(content,"",UDim2.fromOffset(12,52),UDim2.fromOffset(295,22),{Bold=true,Size=12})
        local rows={}
        for i,id in ipairs({"marina","westwood","northhill"}) do
            local spec=Config.Properties[id]; local row=frame(content,UDim2.fromOffset(8,77+(i-1)*55),UDim2.fromOffset(308,49),palette.Card)
            text(row,spec.Name,UDim2.fromOffset(8,3),UDim2.fromOffset(146,19),{Bold=true,Size=12})
            rows[id]=text(row,"",UDim2.fromOffset(8,24),UDim2.fromOffset(144,17),{Size=11,Color=palette.Muted})
            button(row,"Mapa",UDim2.fromOffset(173,7),UDim2.fromOffset(56,34),function() setWaypoint(spec.MapLocation) end)
            button(row,"Koupit",UDim2.fromOffset(235,7),UDim2.fromOffset(64,34),function() send("homeBuy",id) end)
        end
        button(content,"Povolit / zamknout pozvánky",UDim2.fromOffset(12,247),UDim2.fromOffset(299,34),function() send("homeLock") end)
        local guest=input(content,"Uživatelské jméno hráče",UDim2.fromOffset(12,288),UDim2.fromOffset(189,35))
        button(content,"Pozvat",UDim2.fromOffset(207,288),UDim2.fromOffset(104,35),function()
            for _,other in ipairs(Players:GetPlayers()) do if string.lower(other.Name)==string.lower(guest.Text) then send("homeInvite",other.UserId); return end end
            notify("Tento hráč není na serveru.")
        end)
        button(content,"Přijmout domácí pozvánku",UDim2.fromOffset(12,330),UDim2.fromOffset(299,36),function() send("homeAccept") end)
        panelRefresh=function()
            local count=0
            for id,label in pairs(rows) do local owned=(state.Homes and state.Homes[id]) or (id=="marina" and state.Home); label.Text=owned and "Ve vlastnictví" or cash(Config.Properties[id].Price); if owned then count=count+1 end end
            ownership.Text=count>0 and (count.." / 3 nemovitostí · "..(state.HomeLocked and "zamčené" or "otevřené pozvánky")) or "Zatím nemáš vlastní dům."
        end
    elseif name=="Business" then
        local c=state.Company
        if not c then
            text(content,"VYBUDUJ VLASTNÍ FIRMU",UDim2.fromOffset(13,12),UDim2.fromOffset(294,24),{Bold=true,Size=15})
            description("Zvol značku a obor. Registraci dokončíš u přepážky Harbor Commerce.",44,52)
            local brand=1; local industry="logistics"
            local brandText=text(content,Config.Company.Brands[brand],UDim2.fromOffset(13,108),UDim2.fromOffset(216,30),{Bold=true,Size=22})
            button(content,"›",UDim2.fromOffset(246,105),UDim2.fromOffset(65,35),function() brand=brand%#Config.Company.Brands+1; brandText.Text=Config.Company.Brands[brand] end)
            local kind=text(content,"",UDim2.fromOffset(13,152),UDim2.fromOffset(294,54),{Size=14,Wrap=true,Color=palette.Green})
            local function choose(id) industry=id; local spec=Config.Company.Industries[id]; kind.Text=spec.Label.." / Registrace "..cash(spec.Price).."\nZakázka od "..cash(spec.Reward) end
            button(content,"DOPRAVA",UDim2.fromOffset(13,218),UDim2.fromOffset(141,38),function() choose("logistics") end)
            button(content,"AUTOSERVIS",UDim2.fromOffset(165,218),UDim2.fromOffset(146,38),function() choose("motors") end)
            button(content,"ZALOŽIT FIRMU",UDim2.fromOffset(13,272),UDim2.fromOffset(298,44),function() send("foundCompany",{Industry=industry,Brand=brand}) end,palette.Red)
            button(content,"Navigace k registraci",UDim2.fromOffset(13,325),UDim2.fromOffset(298,36),function() setWaypoint("Company") end)
            button(content,"FRANŠÍZY / DALŠÍ INVESTICE",UDim2.fromOffset(13,378),UDim2.fromOffset(298,33),function() openPanel("Franchises") end); choose(industry)
            panelRefresh=function() if state.Company then task.defer(function() if panel.Visible then openPanel("Business") end end) end end
        else
            local title=text(content,c.Name,UDim2.fromOffset(13,9),UDim2.fromOffset(294,32),{Bold=true,Size=20})
            local stats=text(content,"",UDim2.fromOffset(13,49),UDim2.fromOffset(294,68),{Size=14,Wrap=true,Color=palette.Green})
            local jobText=description("",124,64)
            button(content,"Přijmout zakázku",UDim2.fromOffset(13,200),UDim2.fromOffset(298,39),function() send("companyContract") end,palette.Red)
            button(content,"Navigace k zakázce",UDim2.fromOffset(13,247),UDim2.fromOffset(298,35),function() local job=state.Company and state.Company.Contract; if job then setWaypoint(job.Target) else notify("Nejdřív přijmi zakázku.") end end)
            button(content,"Vybrat zisk",UDim2.fromOffset(13,290),UDim2.fromOffset(141,36),function() send("companyWithdraw") end)
            button(content,"Zrušit zakázku",UDim2.fromOffset(165,290),UDim2.fromOffset(146,36),function() send("companyCancel") end)
            local upgrade=button(content,"",UDim2.fromOffset(13,338),UDim2.fromOffset(298,37),function() send("companyUpgrade") end)
            button(content,"FRANŠÍZY / DALŠÍ INVESTICE",UDim2.fromOffset(13,383),UDim2.fromOffset(298,33),function() openPanel("Franchises") end)
            panelRefresh=function()
                local firm=state.Company; if not firm then return end
                title.Text=firm.Name; stats.Text="ÚROVEŇ "..firm.Level.." / 3     •     ZAKÁZEK "..firm.Completed.."\nFIREMNÍ POKLADNA  "..cash(firm.Treasury)
                jobText.Text=firm.Contract and ((firm.Contract.Stage=="Pickup" and "Vyzvedni materiál" or "Předej náklad").." • "..(names[firm.Contract.Target] or firm.Contract.Target).."\nZbývá "..firm.Contract.Seconds.." s") or firm.Cooldown>0 and "Nová nabídka za "..firm.Cooldown.." s." or "Žádná aktivní zakázka. Přijmi nabídku a vyjeď do města."
                upgrade.Text=firm.Level<3 and ("Rozšířit firmu • "..cash(Config.Company.UpgradePrices[firm.Level])) or "Maximální úroveň dosažena"
            end
        end
    elseif name=="Franchises" then
        description("Kup firmu na její pobočce. Každé 3 minuty přidá zisk na bankovní účet.",8,48)
        local rows={}
        for i,id in ipairs({"courier","autohaus"}) do
            local spec=Config.Businesses[id]; local y=68+(i-1)*82
            local row=frame(content,UDim2.fromOffset(8,y),UDim2.fromOffset(308,72),palette.Card)
            text(row,spec.Name,UDim2.fromOffset(10,4),UDim2.fromOffset(284,22),{Bold=true,Size=12})
            rows[id]=text(row,"",UDim2.fromOffset(10,28),UDim2.fromOffset(284,17),{Size=11,Color=palette.Muted})
            button(row,"Najít místo",UDim2.fromOffset(10,49),UDim2.fromOffset(132,18),function() setWaypoint(id=="courier" and "Depot" or "Garage") end)
            button(row,"Koupit firmu",UDim2.fromOffset(151,49),UDim2.fromOffset(146,18),function() send("buyBusiness",id) end)
        end
        description("Výnosy se ukládají do banky i do historie transakcí.",244,45)
        panelRefresh=function() for id,label in pairs(rows) do local spec=Config.Businesses[id]; label.Text=state.Businesses and state.Businesses[id] and ("VLASTNÍŠ · +"..cash(spec.Income).." / 3 min") or ("Investice "..cash(spec.Price).." · "..cash(spec.Income).." každé 3 min") end end
    elseif name=="Prison" then
        text(content,"NORTHGATE",UDim2.fromOffset(13,14),UDim2.fromOffset(295,35),{Bold=true,Size=26})
        local sentence=text(content,"",UDim2.fromOffset(13,58),UDim2.fromOffset(295,70),{Size=26,Bold=true,Color=palette.Gold,Wrap=true})
        description("DÍLNA\nPrací si zkrátíš trest a získáš nástroj.\n\nJÍDELNA\nJídlo obnovuje zdraví.\n\nÚTĚK\nKarta z prádelny, podzemní odtok nebo ventilace. Po útěku začne pátrání.",137,219)
        button(content,"Najít věznici",UDim2.fromOffset(13,370),UDim2.fromOffset(298,38),function() setWaypoint("Prison") end)
        panelRefresh=function() sentence.Text=state.Jail>0 and string.format("%02d:%02d\nDO PROPUŠTĚNÍ",math.floor(state.Jail/60),state.Jail%60) or "ŽÁDNÝ AKTIVNÍ TREST" end
    elseif name=="Settings" then
        description("ALFA "..Config.Version.." · ukládání ve Studiu je vypnuté.",10,49)
        local mode=text(content,"",UDim2.fromOffset(12,61),UDim2.fromOffset(296,46),{Size=12,Wrap=true,Color=palette.Gold})
        button(content,"Přepnout stíny",UDim2.fromOffset(12,120),UDim2.fromOffset(299,39),function() Lighting.GlobalShadows=not Lighting.GlobalShadows; notify(Lighting.GlobalShadows and "Stíny zapnuté." or "Stíny vypnuté.") end)
        button(content,"Vypnout navigaci",UDim2.fromOffset(12,165),UDim2.fromOffset(299,39),function() waypoint=nil; if waypointPart then waypointPart:Destroy(); waypointPart=nil end end)
        description("WASD · E interakce · Shift běh · F pouta · L světla · Q blinkry · B majáky · mezerník vystoupit",225,95)
        panelRefresh=function() mode.Text="DATA: "..(state.SaveMode or "načítání") end
    else
        local hello=text(content,"",UDim2.fromOffset(14,14),UDim2.fromOffset(293,61),{Size=18,Bold=true,Wrap=true})
        local balance=text(content,"",UDim2.fromOffset(14,82),UDim2.fromOffset(293,45),{Size=14,Color=palette.Teal,Wrap=true})
        description("VYBER APLIKACI",144,23)
        for i,entry in ipairs({{"Map","MAPA"},{"Garage","AUTA"},{"Jobs","PRÁCE"},{"Bank","BANKA"},{"Police","POLICIE"},{"HomeApp","DOMY"},{"Business","FIRMY"},{"Prison","VĚZENÍ"},{"Settings","VOLBY"}}) do
            local col=(i-1)%3; local row=math.floor((i-1)/3)
            local app=button(content,entry[2],UDim2.fromOffset(13+col*99,174+row*84),UDim2.fromOffset(91,70),function() openPanel(entry[1]) end,({palette.Card,Color3.fromRGB(42,65,113),Color3.fromRGB(142,90,45),Color3.fromRGB(39,86,73),Color3.fromRGB(41,76,110),Color3.fromRGB(84,62,106),Color3.fromRGB(112,54,69),Color3.fromRGB(131,84,51),palette.Card})[i])
            app.TextSize=13; app.Font=Enum.Font.GothamBold
        end
        panelRefresh=function() hello.Text="Ahoj, "..player.DisplayName; balance.Text="ÚČET  "..cash(state.Bank).."   ·   HOTOVOST  "..cash(state.Cash) end
    end
    if panelRefresh then panelRefresh() end
end
for i,entry in ipairs({{"Map","MAPA"},{"Garage","AUTA"},{"Jobs","PRÁCE"},{"Bank","BANKA"},{"Police","POLICIE"},{"HomeApp","DOMY"},{"Business","FIRMY"},{"Settings","NAST."}}) do
    local col=(i-1)%4; local row=math.floor((i-1)/4)
    local tab=button(phone,entry[2],UDim2.fromOffset(13+col*81,74+row*32),UDim2.fromOffset(77,27),function() openPanel(entry[1]) end,palette.Card)
    tab.TextSize=10
end
button(top,"TELEFON",UDim2.new(1,-112,0,16),UDim2.fromOffset(98,34),function() if panel.Visible then panel.Visible=false else openPanel("Home") end end)
network.OpenPanel.OnClientEvent:Connect(function(name) openPanel(name=="Home" and "HomeApp" or name) end)
local phoneScale=create("UIScale",panel,{Scale=1})
local function resizePhone()
    local camera=workspace.CurrentCamera
    if camera then phoneScale.Scale=math.clamp(math.min((camera.ViewportSize.X-24)/384,(camera.ViewportSize.Y-30)/636),0.58,1) end
end
resizePhone(); workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resizePhone)
local controlFrame=frame(gui,UDim2.new(1,-312,1,-162),UDim2.fromOffset(292,140)); controlFrame.Visible=false
button(controlFrame,"Světla / L",UDim2.fromOffset(10,10),UDim2.fromOffset(132,33),function() send("lights") end)
button(controlFrame,"Blinkry / Q",UDim2.fromOffset(150,10),UDim2.fromOffset(132,33),function() send("signal") end)
button(controlFrame,"Majáky / B",UDim2.fromOffset(10,51),UDim2.fromOffset(132,33),function() send("siren") end)
button(controlFrame,"Vystoupit",UDim2.fromOffset(150,51),UDim2.fromOffset(132,33),function() local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if h then h.Sit=false; h.Jump=true end end)
local brakeHeld=false
local brakeButton=button(controlFrame,"BRZDA",UDim2.fromOffset(10,93),UDim2.fromOffset(272,35),function() end)
brakeButton.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then brakeHeld=true end end)
brakeButton.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then brakeHeld=false end end)
local sprint=false
button(gui,"BĚH",UDim2.new(1,-118,1,-218),UDim2.fromOffset(98,36),function() sprint=not sprint; send("sprint",sprint) end).Visible=UIS.TouchEnabled
-- Heist minigame: the server creates the sequence and enforces timing and step order.
local hack=frame(gui,UDim2.new(0.5,-220,0.5,-145),UDim2.fromOffset(440,290)); hack.Visible=false
local hackScale=create("UIScale",hack,{Scale=1})
local hackTitle=text(hack,"CIVIC / SECURITY",UDim2.fromOffset(22,15),UDim2.fromOffset(396,32),{Size=21,Bold=true})
local hackHint=text(hack,"",UDim2.fromOffset(22,58),UDim2.fromOffset(396,88),{Size=20,Center=true,Wrap=true,Color=palette.Teal})
local hackStatus=text(hack,"",UDim2.fromOffset(22,246),UDim2.fromOffset(396,26),{Size=13,Center=true,Color=palette.Muted})
local symbols={"▲","●","■","◆"}; local hackReady=false; local hackVersion=0
for i,symbol in ipairs(symbols) do button(hack,symbol,UDim2.fromOffset(22+(i-1)*102,161),UDim2.fromOffset(90,67),function() if hackReady then network.Hack:FireServer(i) end end) end
network.Hack.OnClientEvent:Connect(function(message)
    if message.Close then hackVersion=hackVersion+1; hack.Visible=false; hackReady=false; return end
    if message.Sequence then
        hackVersion=hackVersion+1; hackScale.Scale=math.clamp(math.min((workspace.CurrentCamera.ViewportSize.X-24)/464,(workspace.CurrentCamera.ViewportSize.Y-24)/314),0.58,1); local version=hackVersion; hack.Visible=true; panel.Visible=false; hackReady=false
        local shown={}; for _,v in ipairs(message.Sequence) do table.insert(shown,symbols[v]) end
        hackTitle.Text=(message.Name or "LOUPEŽ"):upper(); hackHint.Text=table.concat(shown,"    "); hackStatus.Text="Zapamatuj si pořadí. Tlačítka se odemknou za "..message.Duration.." s."
        task.delay(message.Duration,function() if version==hackVersion then hackReady=true; hackHint.Text="Zopakuj pořadí"; hackStatus.Text="Klikni na symboly ve správném pořadí." end end)
    elseif message.Reset then hackStatus.Text="Chyba "..message.Attempts.." / 3. Začni znovu."
    elseif message.Progress then hackStatus.Text="Správně: "..message.Progress.." / 4" end
end)
network.State.OnClientEvent:Connect(function(new)
    state=new; profileReady=true; money.Text="Účet "..cash(state.Bank).."   /   "..cash(state.Cash)
    role.Text=(state.Role=="Police" and "POLICIE" or state.Jail>0 and "VĚZEŇ" or "CIVILISTA").."  ·  "..(state.SaveMode or "")
    stars.Text=string.rep("★",state.Wanted)..string.rep("☆",5-state.Wanted)
    if state.Jail>0 then objectiveText.Text="Trest: "..state.Jail.." s. "..(state.Key and "Máš kartu — najdi servisní dveře." or "Prádelna ukrývá kartu. Odtok je další možnost.")
    elseif state.Heist then
        objectiveText.Text=state.Heist.Bag and "Dovez kořist z mise „"..(state.Heist.Name or "loupež").."“ do přístavu. Zbývá "..state.Heist.Seconds.." s." or state.Heist.Stage=="Hack" and "Dokonči bezpečnostní minihru: "..(state.Heist.Name or "loupež").."." or "Vezmi kořist z otevřeného cíle."
    elseif state.Company and state.Company.Contract then objectiveText.Text="FIRMA / "..(state.Company.Contract.Stage=="Pickup" and "Vyzvedni materiál" or "Doruč náklad").." • "..(names[state.Company.Contract.Target] or "")..". Zbývá "..state.Company.Contract.Seconds.." s."
    elseif state.Job then objectiveText.Text="Doruč zásilku do přístavu. Zbývá "..state.Job.Deadline.." s."
    elseif state.Wanted>0 then objectiveText.Text="Setřes policii. Hvězdičky klesají mimo dohled hlídek."
    elseif state.Role=="Police" then objectiveText.Text=state.ArrestProgress and ("POUTÁNÍ / "..math.floor(state.ArrestProgress*100).." %. Drž se u podezřelého.") or "Otevři policejní tablet. Výjezdy obsahují hledaná NPC i hráče. F / pouta v dosahu."
    else objectiveText.Text="Vyzvedni si auto v garáži. Vydělávej rozvozem nebo se vydej do banky." end
    if panelRefresh and panel.Visible then panelRefresh() end
    if tabletRefresh then tabletRefresh() end
end)
UIS.InputBegan:Connect(function(i,processed)
    if processed or menuOpen then return end
    if i.KeyCode==Enum.KeyCode.P then if panel.Visible then panel.Visible=false else openPanel("Home") end
    elseif i.KeyCode==Enum.KeyCode.M then openPanel("Map")
    elseif i.KeyCode==Enum.KeyCode.F then send("arrestNearest")
    elseif i.KeyCode==Enum.KeyCode.L then send("lights")
    elseif i.KeyCode==Enum.KeyCode.Q then send("signal")
    elseif i.KeyCode==Enum.KeyCode.B then send("siren")
    elseif i.KeyCode==Enum.KeyCode.LeftShift then send("sprint",true) end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.LeftShift then send("sprint",false) end end)
-- Live title sequence uses the actual map, not a mockup or screenshot.
local intro=frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1),palette.Bg); intro.ZIndex=25; intro.BackgroundTransparency=0.12
create("UIGradient",intro,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.44,0.14),NumberSequenceKeypoint.new(1,0.95)})})
text(intro,"HARBOR",UDim2.fromOffset(56,94),UDim2.fromOffset(410,68),{Size=53,Bold=true})
text(intro,"CITY",UDim2.fromOffset(57,153),UDim2.fromOffset(410,72),{Size=67,Bold=true,Color=palette.Red})
text(intro,"TVŮJ PŘÍBĚH ZAČÍNÁ TADY.",UDim2.fromOffset(59,233),UDim2.fromOffset(430,26),{Size=12,Bold=true,Color=palette.Muted})
local welcome=frame(intro,UDim2.new(1,-330,0,28),UDim2.fromOffset(298,63),palette.Panel)
text(welcome,"VÍTEJ VE MĚSTĚ",UDim2.fromOffset(18,8),UDim2.fromOffset(262,18),{Size=10,Color=palette.Muted,Bold=true})
text(welcome,player.DisplayName,UDim2.fromOffset(18,29),UDim2.fromOffset(262,23),{Size=18,Bold=true})
local function enterCity(destination)
    if not profileReady then notify("Počkej na načtení profilu."); return end
    menuOpen=false; intro.Visible=false; top.Visible=true; objective.Visible=true; mini.Visible=true
    CAS:UnbindAction("HarborMenuLock")
    local camera=workspace.CurrentCamera; camera.CameraType=Enum.CameraType.Custom
    local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if h then camera.CameraSubject=h end
    if destination then openPanel(destination) end
end
button(intro,"▶   VSTOUPIT DO MĚSTA",UDim2.fromOffset(58,298),UDim2.fromOffset(330,58),function() enterCity() end,palette.Red)
button(intro,"◈   MAPA MĚSTA",UDim2.fromOffset(58,368),UDim2.fromOffset(330,48),function() enterCity("Map") end)
button(intro,"▣   NASTAVENÍ",UDim2.fromOffset(58,428),UDim2.fromOffset(330,48),function() enterCity("Settings") end)
text(intro,"JEDNO MĚSTO. VLASTNÍ CESTA.",UDim2.new(0,59,1,-73),UDim2.fromOffset(440,22),{Size=14,Bold=true})
text(intro,"HARBOR CITY  /  "..Config.Version,UDim2.new(0,59,1,-45),UDim2.fromOffset(440,20),{Size=10,Color=palette.Muted})
top.Visible=false; objective.Visible=false; mini.Visible=false
CAS:BindActionAtPriority("HarborMenuLock",function() return Enum.ContextActionResult.Sink end,false,3000,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
local cuffs=button(gui,"POUTA / F",UDim2.new(0.5,-90,1,-68),UDim2.fromOffset(180,42),function() send("arrestNearest") end,palette.Red); cuffs.Visible=false
local jailBanner=frame(gui,UDim2.new(0.5,-172,0,195),UDim2.fromOffset(344,70)); jailBanner.Visible=false
text(jailBanner,"NORTHGATE / DO PROPUŠTĚNÍ",UDim2.fromOffset(16,7),UDim2.fromOffset(312,19),{Size=10,Bold=true,Color=palette.Muted})
local jailClock=text(jailBanner,"",UDim2.fromOffset(16,26),UDim2.fromOffset(190,36),{Size=27,Bold=true,Color=palette.Gold})
button(jailBanner,"VĚZENÍ",UDim2.fromOffset(227,25),UDim2.fromOffset(100,33),function() openPanel("Prison") end)
-- A wide map / police tablet complements the compact smartphone.
local tablet=frame(gui,UDim2.fromScale(0.5,0.5),UDim2.fromOffset(960,568)); tablet.AnchorPoint=Vector2.new(0.5,0.5); tablet.Visible=false; tablet.ZIndex=35
create("UIStroke",tablet,{Color=Color3.fromRGB(69,84,105),Thickness=1})
local tabletTitle=text(tablet,"",UDim2.fromOffset(24,16),UDim2.fromOffset(780,29),{Size=23,Bold=true})
local tabletSub=text(tablet,"",UDim2.fromOffset(24,49),UDim2.fromOffset(870,20),{Size=12,Color=palette.Muted})
closeTablet=function() tablet.Visible=false; tabletRefresh=nil end
local tabletScale=create("UIScale",tablet,{Scale=1})
local tabletBody=frame(tablet,UDim2.fromOffset(18,83),UDim2.fromOffset(924,467),palette.Bg)
button(tablet,"×",UDim2.fromOffset(895,17),UDim2.fromOffset(44,39),function() tablet.Visible=false; tabletRefresh=nil end)
local function track(record)
    if waypointPart then waypointPart:Destroy(); waypointPart=nil end
    waypoint=nil; trackedId=record.Id; notify("Sleduješ: "..record.Name..". Poloha se aktualizuje na mapě.")
end
showTablet=function(mode)
    panel.Visible=false; tablet.Visible=true
    for _,child in ipairs(tabletBody:GetChildren()) do if not child:IsA("UICorner") then child:Destroy() end end
    tabletTitle.Text=mode=="Police" and "HCPD / POLICEJNÍ TABLET" or "HARBOR CITY / MAPA"
    tabletSub.Text=mode=="Police" and "DISPEČINK   /   VÝJEZDY   /   DATABÁZE HLEDANÝCH" or "DOWNTOWN  •  WESTWOOD  •  NORTH HILLS  •  PORT  •  AIRPORT"
    if mode=="Map" then
        makeMap(tabletBody,UDim2.fromOffset(228,10),UDim2.fromOffset(685,448),true)
        text(tabletBody,"KAM SE VYDÁŠ?",UDim2.fromOffset(14,13),UDim2.fromOffset(199,25),{Size=13,Bold=true})
        for i,key in ipairs({"Police","Garage","Company","Bank","Prison","Depot","Jewelry","Apartment","Airport"}) do
            button(tabletBody,names[key],UDim2.fromOffset(12,50+(i-1)*44),UDim2.fromOffset(201,36),function() setWaypoint(key) end)
        end
        tabletRefresh=nil; return
    end
    local stats=text(tabletBody,"",UDim2.fromOffset(16,10),UDim2.fromOffset(878,25),{Size=14,Bold=true,Color=palette.Teal})
    button(tabletBody,"NASTOUPIT SLUŽBU",UDim2.fromOffset(14,46),UDim2.fromOffset(207,39),function() send("role","Police") end)
    button(tabletBody,"UKONČIT SLUŽBU",UDim2.fromOffset(229,46),UDim2.fromOffset(195,39),function() send("role","Civilian") end)
    button(tabletBody,"NAVIGACE KE STANICI",UDim2.fromOffset(432,46),UDim2.fromOffset(241,39),function() setWaypoint("Police") end)
    button(tabletBody,"POUTA / F",UDim2.fromOffset(681,46),UDim2.fromOffset(228,39),function() send("arrestNearest") end,palette.Red)
    makeMap(tabletBody,UDim2.fromOffset(14,100),UDim2.fromOffset(410,350),true)
    local list=create("ScrollingFrame",tabletBody,{Position=UDim2.fromOffset(438,100),Size=UDim2.fromOffset(471,350),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0)})
    local previous=""
    tabletRefresh=function()
        if not tablet.Visible then return end
        stats.Text=(state.Role=="Police" and "VE SLUŽBĚ" or "MIMO SLUŽBU").."     /     ZADRŽENÍ: "..(state.Arrests or 0).."     /     AKTIVNÍ PŘÍPADY: "..#state.Roster
        local signature=state.Role
        for _,r in ipairs(state.Roster) do signature=signature..tostring(r.Id)..(r.Status or "") end
        if signature==previous then return end; previous=signature
        for _,child in ipairs(list:GetChildren()) do child:Destroy() end
        if state.Role~="Police" then text(list,"Nastup do služby u přepážky na stanici. Dostaneš uniformu, pouta a přístup k policejnímu autu.",UDim2.fromOffset(16,16),UDim2.fromOffset(430,100),{Size=16,Wrap=true}); return end
        if #state.Roster==0 then text(list,"Město je právě klidné. Nový výjezd se brzy objeví.",UDim2.fromOffset(16,16),UDim2.fromOffset(430,100),{Wrap=true}) end
        for i,r in ipairs(state.Roster) do
            local row=frame(list,UDim2.fromOffset(0,(i-1)*118),UDim2.fromOffset(458,108),palette.Card)
            text(row,(r.Kind=="NPC" and "NPC  /  " or "HRÁČ  /  ")..r.Name,UDim2.fromOffset(12,8),UDim2.fromOffset(338,23),{Size=14,Bold=true})
            text(row,string.rep("★",r.Wanted),UDim2.fromOffset(351,8),UDim2.fromOffset(95,22),{Size=17,Color=palette.Gold})
            text(row,r.Crime,UDim2.fromOffset(12,33),UDim2.fromOffset(424,23),{Size=12,Color=palette.Muted})
            button(row,r.Kind=="NPC" and "PŘIJMOUT VÝJEZD" or "SLEDOVAT",UDim2.fromOffset(12,63),UDim2.fromOffset(262,33),function() if r.Kind=="NPC" then send("assignCase",r.Id) end; track(r) end)
            button(row,"ZATKNOUT",UDim2.fromOffset(283,63),UDim2.fromOffset(161,33),function() send("arrest",r.Id) end,palette.Red)
        end
        list.CanvasSize=UDim2.fromOffset(0,#state.Roster*118)
    end
    tabletRefresh()
end
-- Local weather: no third-party asset dependency. Roof ray prevents indoor rain.
local rainPart=create("Part",workspace,{Name="LocalRain",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1,Size=Vector3.new(50,1,50)})
local rain=create("ParticleEmitter",rainPart,{Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Speed=NumberRange.new(65,75),Lifetime=NumberRange.new(0.45,0.6),EmissionDirection=Enum.NormalId.Bottom,SpreadAngle=Vector2.new(3,3),Size=NumberSequence.new(0.08),Transparency=NumberSequence.new(0.4),Color=ColorSequence.new(Color3.fromRGB(167,190,207)),LightInfluence=0.5})
local driveClock,rainClock=0,0
RunService.RenderStepped:Connect(function(dt)
    driveClock=driveClock+dt; rainClock=rainClock+dt
    if previewUpdate and panel.Visible then previewUpdate(dt) end
    local vp=workspace.CurrentCamera.ViewportSize; tabletScale.Scale=math.min(1,(vp.X/scale.Scale-30)/960,(vp.Y/scale.Scale-30)/568)
    if menuOpen then
        local camera=workspace.CurrentCamera; camera.CameraType=Enum.CameraType.Scriptable
        camera.CFrame=CFrame.lookAt(Vector3.new(130+math.sin(os.clock()*0.06)*8,30,128),Vector3.new(-26,35,-90))
    end
    cuffs.Visible=not menuOpen and state.Role=="Police" and not tablet.Visible and not panel.Visible
    jailBanner.Visible=not menuOpen and state.Jail>0
    jailClock.Text=string.format("%02d:%02d",math.floor(state.Jail/60),state.Jail%60)
    local tracked=nil
    if trackedId then for _,r in ipairs(state.Roster) do if r.Id==trackedId then tracked=r end end; if not tracked then trackedId=nil end end
    local character=player.Character; local rootPart=character and character:FindFirstChild("HumanoidRootPart"); local human=character and character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not human then return end
    health.Text="Zdraví "..math.floor(human.Health).." / "..math.floor(human.MaxHealth)
    local mx,mz=mapPosition(rootPart.Position.X,rootPart.Position.Z)
    for i=#mapInstances,1,-1 do local m=mapInstances[i]; if not m.Frame.Parent then table.remove(mapInstances,i) else m.Dot.Position=UDim2.fromScale(math.clamp(mx,0,1),math.clamp(mz,0,1)); m.Target.Visible=tracked~=nil; if tracked then local x,z=mapPosition(tracked.Position[1],tracked.Position[3]); m.Target.Position=UDim2.fromScale(x,z) end end end
    if waypoint then local loc=Config.Locations[waypoint]; local distance=(rootPart.Position-Vector3.new(loc[1],loc[2],loc[3])).Magnitude; navigation.Text=(names[waypoint] or waypoint).." · "..math.floor(distance).." studů" elseif tracked then navigation.Text=tracked.Name.." • "..math.floor((rootPart.Position-Vector3.new(table.unpack(tracked.Position))).Magnitude).." studů" else navigation.Text="" end
    if panel.Visible then phoneTime.Text=string.format("%02d:%02d",math.floor(Lighting.ClockTime)%24,math.floor((Lighting.ClockTime%1)*60)); speed.Visible=false; carHealth.Visible=false else speed.Visible=true; carHealth.Visible=true end
    local seat=human.SeatPart; local driving=seat and seat:IsA("VehicleSeat") and seat.Parent:GetAttribute("OwnerId")==player.UserId
    controlFrame.Visible=(driving and not menuOpen and not tablet.Visible and not panel.Visible) or false
    speed.Text=driving and (math.floor(seat.AssemblyLinearVelocity.Magnitude*1.008).." km/h") or ""
    carHealth.Text=driving and ("STAV VOZU "..tostring(seat.Parent:GetAttribute("Health") or 100).." %") or ""
    if driving and driveClock>=0.07 then
        driveClock=0
        local throttle,steer=seat.ThrottleFloat,seat.SteerFloat
        if UIS.KeyboardEnabled and not UIS:GetFocusedTextBox() then
            throttle=(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
            steer=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
        end
        network.Drive:FireServer(throttle,steer,brakeHeld or UIS:IsKeyDown(Enum.KeyCode.LeftControl))
    end
    if rainClock>0.5 then
        rainClock=0; resize(); resizePhone(); rainPart.Position=rootPart.Position+Vector3.new(0,28,0)
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character,rainPart}
        local covered=workspace:Raycast(rootPart.Position,Vector3.new(0,45,0),params)
        rain.Rate=workspace:GetAttribute("Weather")=="Rain" and not covered and (UIS.TouchEnabled and 65 or 130) or 0
    end
end)
task.spawn(function() for _=1,8 do send("snapshot"); task.wait(1) end end)
