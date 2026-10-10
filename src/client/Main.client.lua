local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local player=Players.LocalPlayer
local Config=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local network=ReplicatedStorage:WaitForChild("Network")
local Action=network:WaitForChild("Action")
local palette={Bg=Color3.fromRGB(14,22,32),Panel=Color3.fromRGB(22,33,46),Card=Color3.fromRGB(32,46,60),Text=Color3.fromRGB(233,236,233),Muted=Color3.fromRGB(152,170,181),Teal=Color3.fromRGB(100,207,188),Gold=Color3.fromRGB(238,184,104),Red=Color3.fromRGB(233,114,106)}
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
    local f=create("Frame",parent,{Position=pos,Size=size,BackgroundColor3=color or palette.Panel,BorderSizePixel=0}); corner(f); return f
end
local function text(parent,value,pos,size,opts)
    opts=opts or {}
    return create("TextLabel",parent,{Text=value,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=opts.Color or palette.Text,TextSize=opts.Size or 16,Font=opts.Bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=opts.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=opts.Wrap or false})
end
local function button(parent,label,pos,size,callback,color)
    local b=create("TextButton",parent,{Text=label,Position=pos,Size=size,BackgroundColor3=color or palette.Card,BorderSizePixel=0,TextColor3=palette.Text,TextSize=15,Font=Enum.Font.GothamMedium,AutoButtonColor=true})
    corner(b,8); b.Activated:Connect(callback); return b
end
local function input(parent,placeholder,pos,size)
    local t=create("TextBox",parent,{PlaceholderText=placeholder,Text="",Position=pos,Size=size,BackgroundColor3=palette.Card,BorderSizePixel=0,TextColor3=palette.Text,PlaceholderColor3=palette.Muted,TextSize=16,Font=Enum.Font.Gotham,ClearTextOnFocus=false}); corner(t,8); return t
end
local function cash(n) return "$"..tostring(math.floor(n or 0)) end
local top=frame(gui,UDim2.new(0,20,0,14),UDim2.new(1,-40,0,66))
text(top,"HARBOR\nCITY",UDim2.fromOffset(18,8),UDim2.fromOffset(125,50),{Size=19,Bold=true})
local money=text(top,"Načítání profilu…",UDim2.fromOffset(156,10),UDim2.fromOffset(295,25),{Size=18,Bold=true})
local role=text(top,"",UDim2.fromOffset(156,34),UDim2.fromOffset(345,21),{Size=12,Color=palette.Muted})
local stars=text(top,"",UDim2.new(1,-295,0,9),UDim2.fromOffset(170,29),{Size=24,Bold=true,Color=palette.Gold})
local health=text(top,"",UDim2.new(1,-295,0,38),UDim2.fromOffset(180,19),{Size=12,Color=palette.Muted})
local objective=frame(gui,UDim2.fromOffset(20,93),UDim2.fromOffset(345,92))
text(objective,"AKTUÁLNÍ CÍL",UDim2.fromOffset(15,9),UDim2.fromOffset(315,17),{Size=11,Bold=true,Color=palette.Teal})
local objectiveText=text(objective,"Prozkoumej město. V telefonu najdeš mapu a garáž.",UDim2.fromOffset(15,28),UDim2.fromOffset(315,54),{Size=14,Wrap=true})
local toast=frame(gui,UDim2.new(0.5,-255,0,92),UDim2.fromOffset(510,58)); toast.Visible=false; toast.ZIndex=20
local toastText=text(toast,"",UDim2.fromOffset(16,5),UDim2.new(1,-32,1,-10),{Size=15,Center=true,Wrap=true})
toastText.ZIndex=20
local toastSerial=0
local function notify(message)
    toastSerial=toastSerial+1; local serial=toastSerial; toastText.Text=message; toast.Visible=true
    task.delay(5,function() if toastSerial==serial then toast.Visible=false end end)
end
network.Notify.OnClientEvent:Connect(notify)
local mapInstances={}; local waypoint=nil; local waypointPart=nil
local function mapPosition(x,z) return (x-Config.Map.MinX)/(Config.Map.MaxX-Config.Map.MinX),(z-Config.Map.MinZ)/(Config.Map.MaxZ-Config.Map.MinZ) end
local names={Spawn="Náměstí",Police="Policie",Garage="Garáž",Bank="Banka",Prison="Vězení",Docks="Přístav",Apartment="Byt",Depot="Depo"}
local function setWaypoint(key)
    waypoint=key
    if waypointPart then waypointPart:Destroy(); waypointPart=nil end
    local loc=Config.Locations[key]
    if not loc then return end
    local p=create("Part",workspace,{Name="LocalWaypoint",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Transparency=1,Size=Vector3.one,Position=Vector3.new(loc[1],loc[2]+12,loc[3])})
    local billboard=create("BillboardGui",p,{Size=UDim2.fromOffset(150,46),AlwaysOnTop=true,MaxDistance=1500})
    text(billboard,names[key] or key,UDim2.fromScale(0,0),UDim2.fromScale(1,1),{Size=18,Bold=true,Center=true,Color=palette.Teal})
    waypointPart=p; notify("Navigace: "..(names[key] or key))
end
local function makeMap(parent,pos,size,full)
    local f=frame(parent,pos,size,Color3.fromRGB(35,52,62)); f.ClipsDescendants=true
    local function rectangle(x,z,w,d,color)
        local mx,mz=mapPosition(x-w/2,z-d/2)
        create("Frame",f,{Position=UDim2.fromScale(mx,mz),Size=UDim2.fromScale(w/860,d/865),BorderSizePixel=0,BackgroundColor3=color})
    end
    rectangle(378,0,102,800,Color3.fromRGB(48,88,108))
    for _,v in ipairs({-180,0,180}) do rectangle(v,40,36,720,Color3.fromRGB(97,115,120)); rectangle(0,v,640,36,Color3.fromRGB(97,115,120)) end
    rectangle(0,-359,204,150,Color3.fromRGB(86,96,104))
    for key,loc in pairs(Config.Locations) do
        if names[key] then
            local x,z=mapPosition(loc[1],loc[3])
            local mark=button(f,full and names[key] or "•",UDim2.fromScale(x,z),full and UDim2.fromOffset(75,24) or UDim2.fromOffset(15,15),function() setWaypoint(key) end,palette.Panel)
            mark.AnchorPoint=Vector2.new(0.5,0.5); mark.TextSize=full and 10 or 17; mark.TextColor3=key=="Prison" and palette.Gold or palette.Teal
        end
    end
    local dot=create("Frame",f,{Size=UDim2.fromOffset(9,9),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=palette.Text,BorderSizePixel=0,ZIndex=5}); corner(dot,9)
    table.insert(mapInstances,{Frame=f,Dot=dot}); return f
end
local mini=makeMap(gui,UDim2.new(0,20,1,-207),UDim2.fromOffset(185,185),false)
local navigation=text(gui,"",UDim2.new(0,219,1,-65),UDim2.fromOffset(305,36),{Size=13,Wrap=true,Color=palette.Teal})
local speed=text(gui,"",UDim2.new(1,-320,1,-235),UDim2.fromOffset(296,45),{Size=30,Bold=true})
local carHealth=text(gui,"",UDim2.new(1,-320,1,-193),UDim2.fromOffset(296,23),{Size=13,Color=palette.Muted})
local panel=frame(gui,UDim2.new(0.5,-330,0.5,-258),UDim2.fromOffset(660,516)); panel.Visible=false
local panelTitle=text(panel,"CITY / OS",UDim2.fromOffset(24,13),UDim2.fromOffset(540,36),{Size=22,Bold=true})
local content=frame(panel,UDim2.fromOffset(20,138),UDim2.fromOffset(620,356),palette.Bg)
local currentPanel=nil; local panelRefresh=nil
button(panel,"×",UDim2.fromOffset(603,16),UDim2.fromOffset(36,34),function() panel.Visible=false end)
local openPanel
local function clearContent()
    for _,child in ipairs(content:GetChildren()) do if not child:IsA("UICorner") then child:Destroy() end end
    panelRefresh=nil
end
local function description(value,y) return text(content,value,UDim2.fromOffset(16,y),UDim2.fromOffset(586,42),{Size=14,Color=palette.Muted,Wrap=true}) end
local function send(action,value) Action:FireServer(action,value) end
openPanel=function(name)
    currentPanel=name; panel.Visible=true; clearContent(); panelTitle.Text="CITY / OS    ·    "..({Map="MAPA",Garage="GARÁŽ",Bank="BANKA",Jobs="PRÁCE",Police="DISPEČINK",Home="BYT",Settings="NASTAVENÍ"})[name]
    if name=="Map" then
        makeMap(content,UDim2.fromOffset(12,12),UDim2.fromOffset(596,306),true)
        text(content,"Klikni na místo a zapni navigaci.",UDim2.fromOffset(16,319),UDim2.fromOffset(586,26),{Size=13,Color=palette.Muted})
    elseif name=="Garage" then
        description("Vůz vyzvedneš u ASTER Autohaus. Policejní auto čeká u stanice.",4)
        local info={}
        for i,id in ipairs({"commuter","sport","patrol"}) do
            local spec=Config.Vehicles[id]; local row=frame(content,UDim2.fromOffset(12,52+(i-1)*68),UDim2.fromOffset(596,59),palette.Card)
            text(row,spec.Name,UDim2.fromOffset(12,7),UDim2.fromOffset(220,24),{Bold=true,Size=16})
            info[id]=text(row,"",UDim2.fromOffset(12,31),UDim2.fromOffset(330,20),{Size=12,Color=palette.Muted})
            button(row,"Koupit",UDim2.fromOffset(364,10),UDim2.fromOffset(95,38),function() send("buyCar",id) end)
            button(row,"Vyzvednout",UDim2.fromOffset(469,10),UDim2.fromOffset(115,38),function() send("spawnCar",id) end)
        end
        text(content,"LAK / $150 · vystup z auta u garáže",UDim2.fromOffset(16,264),UDim2.fromOffset(550,24),{Size=13,Color=palette.Muted})
        local colors={Color3.fromRGB(68,155,173),Color3.fromRGB(239,171,79),Color3.fromRGB(214,219,225),Color3.fromRGB(32,37,49),Color3.fromRGB(162,68,68),Color3.fromRGB(126,151,106)}
        for i,col in ipairs(colors) do button(content,tostring(i),UDim2.fromOffset(16+(i-1)*58,299),UDim2.fromOffset(48,37),function() send("color",i) end,col) end
        panelRefresh=function()
            for id,label in pairs(info) do local spec=Config.Vehicles[id]; label.Text=spec.Police and "Služební vozidlo · pouze policie" or state.Cars[id] and "Ve tvé garáži" or "Cena "..cash(spec.Price) end
        end
    elseif name=="Bank" then
        local balance=text(content,"",UDim2.fromOffset(16,10),UDim2.fromOffset(586,35),{Size=22,Bold=true})
        local amount=input(content,"Částka",UDim2.fromOffset(16,59),UDim2.fromOffset(242,40))
        button(content,"Vložit",UDim2.fromOffset(274,59),UDim2.fromOffset(150,40),function() send("deposit",tonumber(amount.Text)) end)
        button(content,"Vybrat",UDim2.fromOffset(438,59),UDim2.fromOffset(166,40),function() send("withdraw",tonumber(amount.Text)) end)
        local history=text(content,"",UDim2.fromOffset(16,116),UDim2.fromOffset(586,225),{Size=14,Wrap=true}); history.TextYAlignment=Enum.TextYAlignment.Top
        panelRefresh=function()
            balance.Text="ÚČET "..cash(state.Bank).."    /    HOTOVOST "..cash(state.Cash)
            local lines={"POSLEDNÍ TRANSAKCE"}
            for i,t in ipairs(state.Transactions) do if i>8 then break end; table.insert(lines,t.Label.."     "..(t.Amount>0 and "+" or "")..cash(t.Amount)) end
            history.Text=table.concat(lines,"\n\n")
        end
    elseif name=="Jobs" then
        description("ROZVOZ: vyzvedni zásilku v depu a doruč ji do přístavu. Odměna $450.",8)
        button(content,"Navigace do depa",UDim2.fromOffset(16,64),UDim2.fromOffset(250,40),function() setWaypoint("Depot") end)
        button(content,"Vyzvednout / u depa",UDim2.fromOffset(281,64),UDim2.fromOffset(322,40),function() send("job") end)
        button(content,"Zrušit rozvoz",UDim2.fromOffset(16,116),UDim2.fromOffset(250,36),function() send("cancelJob") end)
        description("POLICIE: práci změníš u přepážky na stanici. Zatýkej hledané hráče; služba přináší pravidelnou výplatu.",171)
        button(content,"Navigace na stanici",UDim2.fromOffset(16,231),UDim2.fromOffset(270,40),function() setWaypoint("Police") end)
        button(content,"Nastoupit službu",UDim2.fromOffset(302,231),UDim2.fromOffset(301,40),function() send("role","Police") end)
        button(content,"Zpět na civilistu",UDim2.fromOffset(302,285),UDim2.fromOffset(301,40),function() send("role","Civilian") end)
    elseif name=="Police" then
        description("Pouta fungují do 11 studů: musíš zůstat u hledaného hráče 3 sekundy. Databázi vidí jen policie.",5)
        local rosterFrame=create("ScrollingFrame",content,{Position=UDim2.fromOffset(12,59),Size=UDim2.fromOffset(596,280),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0)})
        local previous=""
        panelRefresh=function()
            local signature=state.Role
            for _,record in ipairs(state.Roster) do signature=signature..record.Id..":"..record.Wanted end
            if signature==previous then return end; previous=signature
            for _,child in ipairs(rosterFrame:GetChildren()) do child:Destroy() end
            if state.Role~="Police" then text(rosterFrame,"Přístup pouze pro policisty ve službě.",UDim2.fromOffset(8,8),UDim2.fromOffset(575,50),{Wrap=true}); return end
            if #state.Roster==0 then text(rosterFrame,"Momentálně není nikdo hledaný.",UDim2.fromOffset(8,8),UDim2.fromOffset(575,50),{Wrap=true}) end
            for i,record in ipairs(state.Roster) do
                text(rosterFrame,record.Name.."  ·  "..record.Wanted.." ★",UDim2.fromOffset(8,(i-1)*52),UDim2.fromOffset(397,44),{Size=16})
                button(rosterFrame,"Zatknout",UDim2.fromOffset(435,(i-1)*52+4),UDim2.fromOffset(146,37),function() send("arrest",record.Id) end)
            end
            rosterFrame.CanvasSize=UDim2.fromOffset(0,#state.Roster*52)
        end
    elseif name=="Home" then
        description("Marina Residence • $18 000. V alfě je interiér společný; vlastnictví a pozvánky spravuje server.",7)
        local ownership=text(content,"",UDim2.fromOffset(16,52),UDim2.fromOffset(586,26),{Bold=true})
        button(content,"Koupit u recepce",UDim2.fromOffset(16,91),UDim2.fromOffset(278,39),function() send("homeBuy") end)
        button(content,"Navigace",UDim2.fromOffset(309,91),UDim2.fromOffset(295,39),function() setWaypoint("Apartment") end)
        button(content,"Povolit / zamknout pozvánky",UDim2.fromOffset(16,145),UDim2.fromOffset(588,38),function() send("homeLock") end)
        local guest=input(content,"Přesné uživatelské jméno hráče",UDim2.fromOffset(16,199),UDim2.fromOffset(395,40))
        button(content,"Pozvat",UDim2.fromOffset(424,199),UDim2.fromOffset(180,40),function()
            for _,other in ipairs(Players:GetPlayers()) do if string.lower(other.Name)==string.lower(guest.Text) then send("homeInvite",other.UserId); return end end
            notify("Tento hráč na serveru není.")
        end)
        button(content,"Přijmout pozvánku",UDim2.fromOffset(16,256),UDim2.fromOffset(588,40),function() send("homeAccept") end)
        panelRefresh=function() ownership.Text=state.Home and ("BYT VLASTNÍŠ · "..(state.HomeLocked and "pozvánky zamčené" or "pozvánky povolené")) or "Zatím nevlastníš byt." end
    elseif name=="Settings" then
        description("ALFA "..Config.Version.." · engine testy v Roblox Studiu zatím nepotvrzené.",4)
        local mode=text(content,"",UDim2.fromOffset(16,55),UDim2.fromOffset(586,38),{Size=15,Wrap=true,Color=palette.Gold})
        button(content,"Omezit stíny / výkon",UDim2.fromOffset(16,115),UDim2.fromOffset(588,42),function() Lighting.GlobalShadows=not Lighting.GlobalShadows; notify(Lighting.GlobalShadows and "Stíny zapnuté." or "Stíny vypnuté.") end)
        button(content,"Vypnout navigaci",UDim2.fromOffset(16,172),UDim2.fromOffset(588,42),function() waypoint=nil; if waypointPart then waypointPart:Destroy(); waypointPart=nil end end)
        description("WASD pohyb / jízda · E interakce · Shift běh · P telefon · M mapa · L světla · Q blinkry · B policejní majáky · mezerník vystoupit",232)
        panelRefresh=function() mode.Text="DATA: "..(state.SaveMode or "načítání") end
    end
    if panelRefresh then panelRefresh() end
end
for i,entry in ipairs({{"Map","Mapa"},{"Garage","Garáž"},{"Bank","Banka"},{"Jobs","Práce"},{"Police","Policie"},{"Home","Byt"},{"Settings","Nastavení"}}) do
    local col=(i-1)%4; local row=math.floor((i-1)/4)
    button(panel,entry[2],UDim2.fromOffset(20+col*156,61+row*34),UDim2.fromOffset(149,29),function() openPanel(entry[1]) end)
end
button(top,"TELEFON",UDim2.new(1,-112,0,16),UDim2.fromOffset(98,34),function() if panel.Visible then panel.Visible=false else openPanel("Map") end end)
network.OpenPanel.OnClientEvent:Connect(openPanel)
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
text(hack,"CIVIC / SECURITY",UDim2.fromOffset(22,15),UDim2.fromOffset(396,32),{Size=21,Bold=true})
local hackHint=text(hack,"",UDim2.fromOffset(22,58),UDim2.fromOffset(396,88),{Size=20,Center=true,Wrap=true,Color=palette.Teal})
local hackStatus=text(hack,"",UDim2.fromOffset(22,246),UDim2.fromOffset(396,26),{Size=13,Center=true,Color=palette.Muted})
local symbols={"▲","●","■","◆"}; local hackReady=false; local hackVersion=0
for i,symbol in ipairs(symbols) do button(hack,symbol,UDim2.fromOffset(22+(i-1)*102,161),UDim2.fromOffset(90,67),function() if hackReady then network.Hack:FireServer(i) end end) end
network.Hack.OnClientEvent:Connect(function(message)
    if message.Close then hackVersion=hackVersion+1; hack.Visible=false; hackReady=false; return end
    if message.Sequence then
        hackVersion=hackVersion+1; local version=hackVersion; hack.Visible=true; panel.Visible=false; hackReady=false
        local shown={}; for _,v in ipairs(message.Sequence) do table.insert(shown,symbols[v]) end
        hackHint.Text=table.concat(shown,"    "); hackStatus.Text="Zapamatuj si pořadí. Tlačítka se odemknou za "..message.Duration.." s."
        task.delay(message.Duration,function() if version==hackVersion then hackReady=true; hackHint.Text="Zopakuj pořadí"; hackStatus.Text="Klikni na 4 symboly ve správném pořadí." end end)
    elseif message.Reset then hackStatus.Text="Chyba "..message.Attempts.." / 3. Začni znovu."
    elseif message.Progress then hackStatus.Text="Správně: "..message.Progress.." / 4" end
end)
network.State.OnClientEvent:Connect(function(new)
    state=new; money.Text="Účet "..cash(state.Bank).."   /   "..cash(state.Cash)
    role.Text=(state.Role=="Police" and "POLICIE" or state.Jail>0 and "VĚZEŇ" or "CIVILISTA").."  ·  "..(state.SaveMode or "")
    stars.Text=string.rep("★",state.Wanted)..string.rep("☆",5-state.Wanted)
    if state.Jail>0 then objectiveText.Text="Trest: "..state.Jail.." s. "..(state.Key and "Máš kartu — najdi servisní dveře." or "Prádelna ukrývá kartu. Odtok je další možnost.")
    elseif state.Heist then
        objectiveText.Text=state.Heist.Bag and "Dovez tašku do přístavu. Zbývá "..state.Heist.Seconds.." s." or state.Heist.Stage=="Hack" and "Odemkni bankovní terminál." or "Vezmi tašku z otevřeného trezoru."
    elseif state.Job then objectiveText.Text="Doruč zásilku do přístavu. Zbývá "..state.Job.Deadline.." s."
    elseif state.Wanted>0 then objectiveText.Text="Setřes policii. Hvězdičky klesají mimo dohled hlídek."
    else objectiveText.Text="Vyzvedni si auto v garáži. Vydělávej rozvozem nebo se vydej do banky." end
    if panelRefresh and panel.Visible then panelRefresh() end
end)
UIS.InputBegan:Connect(function(i,processed)
    if processed then return end
    if i.KeyCode==Enum.KeyCode.P then if panel.Visible then panel.Visible=false else openPanel("Map") end
    elseif i.KeyCode==Enum.KeyCode.M then openPanel("Map")
    elseif i.KeyCode==Enum.KeyCode.L then send("lights")
    elseif i.KeyCode==Enum.KeyCode.Q then send("signal")
    elseif i.KeyCode==Enum.KeyCode.B then send("siren")
    elseif i.KeyCode==Enum.KeyCode.LeftShift then send("sprint",true) end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.LeftShift then send("sprint",false) end end)
local intro=frame(gui,UDim2.new(0.5,-265,0.5,-193),UDim2.fromOffset(530,386))
text(intro,"HARBOR CITY",UDim2.fromOffset(30,26),UDim2.fromOffset(470,52),{Size=35,Bold=true})
text(intro,"MĚSTO. VOLBA. NÁSLEDKY.",UDim2.fromOffset(31,80),UDim2.fromOffset(468,24),{Size=12,Color=palette.Teal,Bold=true})
text(intro,"První čtvrť je otevřená. Vyzvedni si Aster Compact, doruč zásilku nebo zkus bankovní loupež. Policie tě může poslat do Northgate — kde existují dvě cesty ven.",UDim2.fromOffset(30,120),UDim2.fromOffset(470,107),{Size=17,Wrap=true})
text(intro,"VÝVOJOVÁ ALFA · neověřeno v Roblox enginu\nVe Studiu se postup záměrně neukládá.",UDim2.fromOffset(30,243),UDim2.fromOffset(470,49),{Size=13,Color=palette.Gold,Wrap=true})
button(intro,"VSTOUPIT DO MĚSTA",UDim2.fromOffset(30,311),UDim2.fromOffset(470,47),function() intro.Visible=false; setWaypoint("Garage") end,palette.Card)
-- Local weather: no third-party asset dependency. Roof ray prevents indoor rain.
local rainPart=create("Part",workspace,{Name="LocalRain",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1,Size=Vector3.new(50,1,50)})
local rain=create("ParticleEmitter",rainPart,{Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Speed=NumberRange.new(65,75),Lifetime=NumberRange.new(0.45,0.6),EmissionDirection=Enum.NormalId.Bottom,SpreadAngle=Vector2.new(3,3),Size=NumberSequence.new(0.08),Transparency=NumberSequence.new(0.4),Color=ColorSequence.new(Color3.fromRGB(167,190,207)),LightInfluence=0.5})
local driveClock,rainClock=0,0
RunService.RenderStepped:Connect(function(dt)
    driveClock=driveClock+dt; rainClock=rainClock+dt
    local character=player.Character; local rootPart=character and character:FindFirstChild("HumanoidRootPart"); local human=character and character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not human then return end
    health.Text="Zdraví "..math.floor(human.Health).." / "..math.floor(human.MaxHealth)
    local mx,mz=mapPosition(rootPart.Position.X,rootPart.Position.Z)
    for i=#mapInstances,1,-1 do local m=mapInstances[i]; if not m.Frame.Parent then table.remove(mapInstances,i) else m.Dot.Position=UDim2.fromScale(math.clamp(mx,0,1),math.clamp(mz,0,1)) end end
    if waypoint then local loc=Config.Locations[waypoint]; local distance=(rootPart.Position-Vector3.new(loc[1],loc[2],loc[3])).Magnitude; navigation.Text=(names[waypoint] or waypoint).." · "..math.floor(distance).." studů" else navigation.Text="" end
    local seat=human.SeatPart; local driving=seat and seat:IsA("VehicleSeat") and seat.Parent:GetAttribute("OwnerId")==player.UserId
    controlFrame.Visible=driving or false
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
        rainClock=0; resize(); rainPart.Position=rootPart.Position+Vector3.new(0,28,0)
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character,rainPart}
        local covered=workspace:Raycast(rootPart.Position,Vector3.new(0,45,0),params)
        rain.Rate=workspace:GetAttribute("Weather")=="Rain" and not covered and (UIS.TouchEnabled and 65 or 130) or 0
    end
end)
task.spawn(function() for _=1,8 do send("snapshot"); task.wait(1) end end)
