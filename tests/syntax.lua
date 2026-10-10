local paths = {
"src/shared/Config.lua","src/shared/Domain.lua","src/server/Util.lua","src/server/DataService.lua","src/server/Guard.lua","src/server/VehicleService.lua","src/server/HeistService.lua","src/server/PrisonService.lua","src/server/NPCService.lua","src/server/Main.server.lua","src/server/TrafficService.lua","src/client/Main.client.lua"
}
for _,path in ipairs(paths) do local fn,err=loadfile(path); assert(fn,path..": "..tostring(err)); print("SYNTAX OK "..path) end
