if myHero.charName ~= "Fiora" then return end

-- [ update ]
do
    
    local Version = 1
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "Fiora.lua",
            Url = "https://raw.githubusercontent.com/miragessee/GoSFiora/master/Fiora.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "miragesfiora.version",
            Url = "https://raw.githubusercontent.com/miragessee/GoSFiora/master/miragesfiora.version"
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print(Files.Version.Name .. ": Updated to " .. tostring(NewVersion) .. ". Please Reload with 2x F6")
        else
            print(Files.Version.Name .. ": No Updates Found")
        end
    
    end
    
    AutoUpdate()

end

local _atan = math.atan2
local _min = math.min
local _abs = math.abs
local _sqrt = math.sqrt
local _floor = math.floor
local _max = math.max
local _pow = math.pow
local _huge = math.huge
local _pi = math.pi
local _insert = table.insert
local _contains = table.contains
local _sort = table.sort
local _pairs = pairs
local _find = string.find
local _sub = string.sub
local _len = string.len

local LocalDrawLine = Draw.Line;
local LocalDrawColor = Draw.Color;
local LocalDrawCircle = Draw.Circle;
local LocalDrawCircleMinimap = Draw.CircleMinimap;
local LocalDrawText = Draw.Text;
local LocalControlIsKeyDown = Control.IsKeyDown;
local LocalControlMouseEvent = Control.mouse_event;
local LocalControlSetCursorPos = Control.SetCursorPos;
local LocalControlCastSpell = Control.CastSpell;
local LocalControlKeyUp = Control.KeyUp;
local LocalControlKeyDown = Control.KeyDown;
local LocalControlMove = Control.Move;
local LocalGetTickCount = GetTickCount;
local LocalGamecursorPos = Game.cursorPos;
local LocalGameCanUseSpell = Game.CanUseSpell;
local LocalGameLatency = Game.Latency;
local LocalGameTimer = Game.Timer;
local LocalGameHeroCount = Game.HeroCount;
local LocalGameHero = Game.Hero;
local LocalGameMinionCount = Game.MinionCount;
local LocalGameMinion = Game.Minion;
local LocalGameTurretCount = Game.TurretCount;
local LocalGameTurret = Game.Turret;
local LocalGameWardCount = Game.WardCount;
local LocalGameWard = Game.Ward;
local LocalGameObjectCount = Game.ObjectCount;
local LocalGameObject = Game.Object;
local LocalGameMissileCount = Game.MissileCount;
local LocalGameMissile = Game.Missile;
local LocalGameParticleCount = Game.ParticleCount;
local LocalGameParticle = Game.Particle;
local LocalGameIsChatOpen = Game.IsChatOpen;
local LocalGameIsOnTop = Game.IsOnTop;

function GetMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function IsReady(spell)
    return Game.CanUseSpell(spell) == 0
end

function ValidTarget(target, range)
    range = range and range or math.huge
    return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
end

function GetDistance(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2) + _pow((p2.z - p1.z), 2))
end

function GetDistance2D(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2))
end

local _OnWaypoint = {}
function OnWaypoint(unit)
    if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()} end
    if _OnWaypoint[unit.networkID].pos ~= unit.posTo then
        _OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()}
        DelayAction(function()
            local time = (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos, _OnWaypoint[unit.networkID].pos) > 200 then
                _OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            end
        end, 0.05)
    end
    return _OnWaypoint[unit.networkID]
end

function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function GetMinionCollision(StartPos, EndPos, Width, Target)
    local Count = 0
    for i = 1, LocalGameMinionCount() do
        local m = LocalGameMinion(i)
        if m and not m.isAlly then
            local w = Width + m.boundingRadius
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
            if isOnSegment and GetDistanceSqr(pointSegment, m.pos) < w ^ 2 and GetDistanceSqr(StartPos, EndPos) > GetDistanceSqr(StartPos, m.pos) then
                Count = Count + 1
            end
        end
    end
    return Count
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx ^ 2 + dz ^ 2
end

function GetEnemyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

--[[ str = "This is some text containing the word tiger."
if str:match("tiger") then
print ("The word tiger was found.")
else
print ("The word tiger was not found.")
end
]]
function IsUnderTurret(unit)
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i);
        if turret and turret.isEnemy and turret.valid and turret.health > 0 then
            if GetDistance(unit, turret.pos) <= 850 then
                return true
            end
        end
    end
    return false
end

function GetDashPos(unit)
    return myHero.pos + (unit.pos - myHero.pos):Normalized() * 500
end

function GetSpellEName()
    return myHero:GetSpellData(_E).name
end

function GetSpellRName()
    return myHero:GetSpellData(_R).name
end

function QDmg()
    if myHero:GetSpellData(_Q).level == 0 then
        local Dmg1 = (({70, 80, 90, 100, 110})[1])
        local bonusDmg = (({0.95, 1.00, 1.05, 1.10, 1.15})[1] * myHero.bonusDamage)
        return Dmg1 + bonusDmg
    else
        local Dmg1 = (({70, 80, 90, 100, 110})[myHero:GetSpellData(_Q).level])
        local bonusDmg = (({0.95, 1.00, 1.05, 1.10, 1.15})[myHero:GetSpellData(_Q).level] * myHero.bonusDamage)
        return Dmg1 + bonusDmg
    end
end

function WDmg()
    if myHero:GetSpellData(_W).level == 0 then
        local Dmg1 = (({90, 130, 170, 210, 250})[1] * myHero.ap)
        return Dmg1
    else
        local Dmg1 = (({90, 130, 170, 210, 250})[myHero:GetSpellData(_W).level] * myHero.ap)
        return Dmg1
    end
end

function EDmg()
    if myHero:GetSpellData(_E).level == 0 then
        local Dmg1 = (({60, 100, 140, 180, 220})[1] + 0.50 * myHero.totalDamage)
        return Dmg1
    else
        local Dmg1 = (({60, 100, 140, 180, 220})[myHero:GetSpellData(_E).level] + 0.50 * myHero.totalDamage)
        return Dmg1
    end
end

function RDmg()
    if myHero:GetSpellData(_R).level == 0 then
        local Dmg1 = (({50, 175, 300})[1] + 0.5 * myHero.totalDamage)
        return Dmg1
    else
        local Dmg1 = (({50, 175, 300})[myHero:GetSpellData(_R).level] + 0.5 * myHero.totalDamage)
        return Dmg1
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff.count
        end
    end
    return 0
end

function IsRecalling()
    for K, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

function SetMovement(bool)
    if _G.EOWLoaded then
        EOW:SetMovements(bool)
        EOW:SetAttacks(bool)
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    else
        GOS.BlockMovement = not bool
        GOS.BlockAttack = not bool
    end
end

function EnableMovement()
    SetMovement(true)
end

function ReturnCursor(pos)
    Control.SetCursorPos(pos)
    DelayAction(EnableMovement, 0.1)
end

function RightClick(pos)
    Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
    Control.mouse_event(MOUSEEVENTF_RIGHTUP)
    DelayAction(ReturnCursor, 0.05, {pos})
end

function IsImmune(unit)
    if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got " .. type(unit) .. ")") end
    for i, buff in pairs(GetBuffs(unit)) do
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then
            return true
        end
    end
    return false
end

function TestBuff(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name:match("fiora") then
            print(buff.name)
            print(buff.pos)
        --print(buff.x)
        --print(buff.y)
        --print(buff.z)
        end
    end
    print("No buff")
end

class "Fiora"

function Fiora:GetGameObjects()
    for i = 1, Game.ObjectCount() do
        local GameObject = Game.Object(i)
        
        if GameObject.name:lower():find("fiora") then
            print(GameObject.name)
            print(GameObject.pos)
            self.ObjectPos = GameObject.pos
        end
    end
end

function Fiora:GetGameObjectsParticle()
    for i = 1, Game.ParticleCount() do
        local GameObject = Game.Particle(i)
        
        if GameObject.name:lower():find("fiora") then
            print(GameObject.name)
            print(GameObject.pos)
            self.ObjectPos = GameObject.pos
        end
    end
end

local HeroIcon = "https://www.mobafire.com/images/champion/square/fiora.png"
local IgniteIcon = "http://pm1.narvii.com/5792/0ce6cda7883a814a1a1e93efa05184543982a1e4_hq.jpg"
local QIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/79/Lunge.png"
local WIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/de/Riposte.png"
local EIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/05/Bladework.png"
local RIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4e/Grand_Challenge.png"
local BCIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Bilgewater_Cutlass_item.png/revision/latest"
local HGIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/64/Hextech_Gunblade_item.png"
local TiamatIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e3/Tiamat_item.png"
local THydraIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/22/Titanic_Hydra_item.png"
local RHydraIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e8/Ravenous_Hydra_item.png"
local IS = {}

function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function GunbladeDMG()--3146
    local level = myHero.levelData.lvl
    local damage = ({175, 180, 184, 189, 193, 198, 203, 207, 212, 216, 221, 225, 230, 235, 239, 244, 248, 253})[level] + 0.30 * myHero.ap
    return damage
end

function TiamatDMG()--3077
    return 100
end

function THydraDMG()--3748
    return 200
end

local Version, Author, LVersion = "v1", "miragessee", "8.23"

function Fiora:LoadMenu()
    
    self.previousMinHealtEnemy = nil
    
    self.Collision = nil
    
    self.CollisionSpellName = nil
    
    self.ObjectPos = nil
    
    self.FioraMenu = MenuElement({type = MENU, id = "Fiora", name = "Mirage's Fiora", leftIcon = HeroIcon})
    
    self.FioraMenu:MenuElement({type = MENU, id = "Extra", name = "Extra"})
    self.FioraMenu.Extra:MenuElement({id = "UseWBA", name = "Use W if enemy basic attack", value = true, leftIcon = WIcon})
    
    self.FioraMenu:MenuElement({id = "Escape", name = "Escape", type = MENU})
    self.FioraMenu.Escape:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    
    self.FioraMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
    self.FioraMenu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true, leftIcon = BCIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.FioraMenu.Harass:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    
    self.FioraMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
    self.FioraMenu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseR", name = "Use R", value = true, leftIcon = RIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true, leftIcon = BCIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.FioraMenu.Combo:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    
    self.FioraMenu:MenuElement({id = "KillSteal", name = "KillSteal", type = MENU})
    self.FioraMenu.KillSteal:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true, leftIcon = IgniteIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.FioraMenu.KillSteal:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    
    self.FioraMenu:MenuElement({id = "AutoLevel", name = "AutoLevel", type = MENU})
    self.FioraMenu.AutoLevel:MenuElement({id = "AutoLevel", name = "Only Q->E->W", value = true})
    
    self.FioraMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
    self.FioraMenu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawAA", name = "Draw Killable AAs", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawKS", name = "Draw Killable Skills", value = true})
    self.FioraMenu.Drawings:MenuElement({id = "DrawJng", name = "Draw Jungler Info", value = true})
    
    self.FioraMenu:MenuElement({id = "blank", type = SPACE, name = ""})
    self.FioraMenu:MenuElement({id = "blank", type = SPACE, name = "Script Ver: " .. Version .. " - LoL Ver: " .. LVersion .. ""})
    self.FioraMenu:MenuElement({id = "blank", type = SPACE, name = "by " .. Author .. ""})
end

function Fiora:LoadSpells()
    FioraQ = {range = 550}
    FioraW = {range = 750, speed=3200, radius=70,delay=0.75}
    --["FioraW"]={charName="Fiora",slot=_W,type="linear",speed=3200,range=750,delay=0.75,radius=70,hitbox=true,aoe=true,cc=true,collision=false},
    FioraE = {range = 150}
    FioraR = {range = 500}
end

function Fiora:__init()
    self.Spells = {
        ["AatroxQ"] = {charName = "Aatrox", slot = _Q, type = "linear", speed = math.huge, range = 650, delay = 0.6, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxQ2"] = {charName = "Aatrox", slot = _Q, type = "linear", speed = math.huge, range = 525, delay = 0.6, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxQ3"] = {charName = "Aatrox", slot = _Q, type = "circular", speed = math.huge, range = 200, delay = 0.6, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxW"] = {charName = "Aatrox", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["AhriOrbofDeception"] = {charName = "Ahri", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["AhriOrbReturn"] = {charName = "Ahri", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["AhriSeduce"] = {charName = "Ahri", slot = _E, type = "linear", speed = 1550, range = 975, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["AkaliQ"] = {charName = "Akali", slot = _Q, type = "conic", speed = math.huge, range = 550, delay = 0.25, angle = 45, hitbox = true, aoe = true, cc = true, collision = false},
        ["AkaliW"] = {charName = "Akali", slot = _W, type = "circular", speed = math.huge, range = 300, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = false, collision = false},
        ["AkaliE"] = {charName = "Akali", slot = _E, type = "linear", speed = 1650, range = 825, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["AkaliR"] = {charName = "Akali", slot = _R, type = "linear", speed = 1650, range = 575, delay = 0, radius = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["AkaliRb"] = {charName = "Akali", slot = _R, type = "linear", speed = 3300, range = 575, delay = 0, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["Pulverize"] = {charName = "Alistar", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 365, hitbox = true, aoe = true, cc = true, collision = false},
        ["BandageToss"] = {charName = "Amumu", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["AuraofDespair"] = {charName = "Amumu", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.307, radius = 300, hitbox = false, aoe = true, cc = false, collision = false},
        ["Tantrum"] = {charName = "Amumu", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["CurseoftheSadMummy"] = {charName = "Amumu", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = true, collision = false},
        ["FlashFrost"] = {charName = "Anivia", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0.25, radius = 110, hitbox = true, aoe = true, cc = true, collision = false},
        ["Crystallize"] = {charName = "Anivia", slot = _W, type = "rectangle", speed = math.huge, range = 1000, delay = 0.25, radius1 = 250, radius2 = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["GlacialStorm"] = {charName = "Anivia", slot = _R, type = "circular", speed = math.huge, range = 750, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["Incinerate"] = {charName = "Annie", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = false, collision = false},
        ["InfernalGuardian"] = {charName = "Annie", slot = _R, type = "circular", speed = math.huge, range = 600, delay = 0.25, radius = 290, hitbox = true, aoe = true, cc = false, collision = false},
        ["Volley"] = {charName = "Ashe", slot = _W, type = "conic", speed = 1500, range = 1200, delay = 0.25, radius = 20, angle = 57.5, hitbox = true, aoe = true, cc = true, collision = true},
        ["EnchantedCrystalArrow"] = {charName = "Ashe", slot = _R, type = "linear", speed = 1600, range = 25000, delay = 0.25, radius = 130, hitbox = true, aoe = false, cc = true, collision = false},
        ["AurelionSolQ"] = {charName = "AurelionSol", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0.25, radius = 210, hitbox = true, aoe = true, cc = true, collision = false},
        ["AurelionSolR"] = {charName = "AurelionSol", slot = _R, type = "linear", speed = 4500, range = 1500, delay = 0.35, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["BardQ"] = {charName = "Bard", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = true},
        ["BardW"] = {charName = "Bard", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["BardR"] = {charName = "Bard", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, hitbox = true, aoe = true, cc = true, collision = false},
        ["RocketGrab"] = {charName = "Blitzcrank", slot = _Q, type = "linear", speed = 1800, range = 925, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["StaticField"] = {charName = "Blitzcrank", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 600, hitbox = false, aoe = true, cc = true, collision = false},
        ["BrandQ"] = {charName = "Brand", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["BrandW"] = {charName = "Brand", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["BraumQ"] = {charName = "Braum", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = true},
        ["BraumRWrapper"] = {charName = "Braum", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, hitbox = true, aoe = true, cc = true, collision = false},
        ["CaitlynPiltoverPeacemaker"] = {charName = "Caitlyn", slot = _Q, type = "linear", speed = 2200, range = 1250, delay = 0.625, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["CaitlynYordleTrap"] = {charName = "Caitlyn", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.25, radius = 75, hitbox = true, aoe = false, cc = true, collision = false},
        ["CaitlynEntrapmentMissile"] = {charName = "Caitlyn", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["CamilleW"] = {charName = "Camille", slot = _W, type = "conic", speed = math.huge, range = 610, delay = 0.75, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["CamilleE"] = {charName = "Camille", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, hitbox = true, aoe = false, cc = true, collision = false},
        ["CassiopeiaQ"] = {charName = "Cassiopeia", slot = _Q, type = "circular", speed = math.huge, range = 850, delay = 0.4, radius = 150, hitbox = true, aoe = true, cc = false, collision = false},
        ["CassiopeiaW"] = {charName = "Cassiopeia", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.25, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["CassiopeiaR"] = {charName = "Cassiopeia", slot = _R, type = "conic", speed = math.huge, range = 825, delay = 0.5, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["Rupture"] = {charName = "Chogath", slot = _Q, type = "circular", speed = math.huge, range = 950, delay = 0.5, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["FeralScream"] = {charName = "Chogath", slot = _W, type = "conic", speed = math.huge, range = 650, delay = 0.5, angle = 60, hitbox = false, aoe = true, cc = true, collision = false},
        ["PhosphorusBomb"] = {charName = "Corki", slot = _Q, type = "circular", speed = 1000, range = 825, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["CarpetBomb"] = {charName = "Corki", slot = _W, type = "linear", speed = 650, range = 600, delay = 0, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["CarpetBombMega"] = {charName = "Corki", slot = _W, type = "linear", speed = 1500, range = 1800, delay = 0, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GGun"] = {charName = "Corki", slot = _E, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 35, hitbox = false, aoe = true, cc = false, collision = false},
        ["MissileBarrageMissile"] = {charName = "Corki", slot = _R, type = "linear", speed = 2000, range = 1225, delay = 0.175, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["MissileBarrageMissile2"] = {charName = "Corki", slot = _R, type = "linear", speed = 2000, range = 1225, delay = 0.175, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["DariusCleave"] = {charName = "Darius", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.75, radius = 425, hitbox = false, aoe = true, cc = false, collision = false},
        ["DariusAxeGrabCone"] = {charName = "Darius", slot = _E, type = "conic", speed = math.huge, range = 535, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = true, collision = false},
        ["DianaArc"] = {charName = "Diana", slot = _Q, type = "arc", speed = 1400, range = 900, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["InfectedCleaverMissileCast"] = {charName = "DrMundo", slot = _Q, type = "linear", speed = 2000, range = 975, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["DravenDoubleShot"] = {charName = "Draven", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.25, radius = 130, hitbox = true, aoe = true, cc = true, collision = false},
        ["DravenRCast"] = {charName = "Draven", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 0.5, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["DravenRDoublecast"] = {charName = "Draven", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 0.5, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["EkkoQ"] = {charName = "Ekko", slot = _Q, type = "linear", speed = 1650, range = 1075, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["EkkoW"] = {charName = "Ekko", slot = _W, type = "circular", speed = 1650, range = 1600, delay = 3.75, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["EkkoR"] = {charName = "Ekko", slot = _R, type = "circular", speed = 1650, range = 1600, delay = 0.25, radius = 375, hitbox = false, aoe = true, cc = false, collision = false},
        ["EliseHumanE"] = {charName = "Elise", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["EvelynnQ"] = {charName = "Evelynn", slot = _Q, type = "linear", speed = 2200, range = 800, delay = 0.25, radius = 35, hitbox = true, aoe = false, cc = false, collision = true},
        ["EvelynnR"] = {charName = "Evelynn", slot = _R, type = "conic", speed = math.huge, range = 450, delay = 0.35, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["EzrealMysticShot"] = {charName = "Ezreal", slot = _Q, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["EzrealEssenceFlux"] = {charName = "Ezreal", slot = _W, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["EzrealTrueshotBarrage"] = {charName = "Ezreal", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 1, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["FioraW"] = {charName = "Fiora", slot = _W, type = "linear", speed = 3200, range = 750, delay = 0.75, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["FizzR"] = {charName = "Fizz", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["GalioQ"] = {charName = "Galio", slot = _Q, type = "arc", speed = 1150, range = 825, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["GalioE"] = {charName = "Galio", slot = _E, type = "linear", speed = 1800, range = 650, delay = 0.45, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["GalioR"] = {charName = "Galio", slot = _R, type = "circular", speed = math.huge, range = 5500, delay = 2.75, radius = 650, hitbox = true, aoe = true, cc = true, collision = false},
        ["GangplankE"] = {charName = "Gangplank", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["GangplankR"] = {charName = "Gangplank", slot = _R, type = "circular", speed = math.huge, range = 25000, delay = 0.25, radius = 600, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarQ"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 2500, range = 1100, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarQReturn"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 1700, range = 3000, delay = 0.25, radius = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarE"] = {charName = "Gnar", slot = _E, type = "circular", speed = 900, range = 475, delay = 0.25, radius = 160, hitbox = true, aoe = false, cc = true, collision = false},
        ["GnarBigQ"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 2100, range = 1100, delay = 0.5, radius = 90, hitbox = true, aoe = true, cc = true, collision = true},
        ["GnarBigW"] = {charName = "Gnar", slot = _W, type = "linear", speed = math.huge, range = 550, delay = 0.6, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarBigE"] = {charName = "Gnar", slot = _E, type = "circular", speed = 800, range = 600, delay = 0.25, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarR"] = {charName = "Gnar", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 475, hitbox = true, aoe = true, cc = true, collision = false},
        ["GragasQ"] = {charName = "Gragas", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["GragasE"] = {charName = "Gragas", slot = _E, type = "linear", speed = 900, range = 600, delay = 0.25, radius = 170, hitbox = true, aoe = true, cc = true, collision = true},
        ["GragasR"] = {charName = "Gragas", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["GravesQLineSpell"] = {charName = "Graves", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 20, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesQLineMis"] = {charName = "Graves", slot = _Q, type = "rectangle", speed = math.huge, range = 925, delay = 0.25, radius1 = 250, radius2 = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesQReturn"] = {charName = "Graves", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesSmokeGrenade"] = {charName = "Graves", slot = _W, type = "circular", speed = 1450, range = 950, delay = 0.15, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["GravesChargeShot"] = {charName = "Graves", slot = _R, type = "linear", speed = 2100, range = 1000, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesChargeShotFxMissile"] = {charName = "Graves", slot = _R, type = "conic", speed = 2000, range = 800, delay = 0.3, radius = 20, angle = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["HecarimRapidSlash"] = {charName = "Hecarim", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["HecarimUlt"] = {charName = "Hecarim", slot = _R, type = "linear", speed = 1100, range = 1000, delay = 0.01, radius = 230, hitbox = true, aoe = true, cc = true, collision = false},
        ["HeimerdingerQ"] = {charName = "Heimerdinger", slot = _Q, type = "circular", speed = math.huge, range = 450, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = false, collision = false},
        ["HeimerdingerW"] = {charName = "Heimerdinger", slot = _W, type = "linear", speed = 2050, range = 1325, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = true},
        ["HeimerdingerE"] = {charName = "Heimerdinger", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["HeimerdingerEUlt"] = {charName = "Heimerdinger", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["IllaoiQ"] = {charName = "Illaoi", slot = _Q, type = "linear", speed = math.huge, range = 850, delay = 0.75, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["IllaoiE"] = {charName = "Illaoi", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["IllaoiR"] = {charName = "Illaoi", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 450, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaW2"] = {charName = "Irelia", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 275, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaW2"] = {charName = "Irelia", slot = _W, type = "linear", speed = math.huge, range = 825, delay = 0.25, radius = 90, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaE"] = {charName = "Irelia", slot = _E, type = "circular", speed = 2000, range = 850, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["IreliaE2"] = {charName = "Irelia", slot = _E, type = "circular", speed = 2000, range = 850, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["IreliaR"] = {charName = "Irelia", slot = _R, type = "linear", speed = 2000, range = 1000, delay = 0.4, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["IvernQ"] = {charName = "Ivern", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["IvernW"] = {charName = "Ivern", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 150, hitbox = true, aoe = true, cc = false, collision = false},
        ["HowlingGale"] = {charName = "Janna", slot = _Q, type = "linear", speed = 667, range = 1750, delay = 0, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["ReapTheWhirlwind"] = {charName = "Janna", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.001, radius = 725, hitbox = false, aoe = true, cc = true, collision = false},
        ["JarvanIVDragonStrike"] = {charName = "JarvanIV", slot = _Q, type = "linear", speed = math.huge, range = 770, delay = 0.4, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["JarvanIVGoldenAegis"] = {charName = "JarvanIV", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.125, radius = 625, hitbox = false, aoe = true, cc = true, collision = false},
        ["JarvanIVDemacianStandard"] = {charName = "JarvanIV", slot = _E, type = "circular", speed = 3440, range = 860, delay = 0, radius = 175, hitbox = true, aoe = true, cc = false, collision = false},
        ["JaxCounterStrike"] = {charName = "Jax", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 1.4, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["JayceShockBlast"] = {charName = "Jayce", slot = _Q, type = "linear", speed = 1450, range = 1175, delay = 0.214, radius = 70, hitbox = true, aoe = true, cc = false, collision = true},
        ["JayceShockBlastWallMis"] = {charName = "Jayce", slot = _Q, type = "linear", speed = 2350, range = 1900, delay = 0.214, radius = 115, hitbox = true, aoe = true, cc = false, collision = true},
        ["JayceStaticField"] = {charName = "Jayce", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 285, hitbox = false, aoe = true, cc = false, collision = false},
        ["JhinW"] = {charName = "Jhin", slot = _W, type = "linear", speed = 5000, range = 3000, delay = 0.75, radius = 40, hitbox = true, aoe = false, cc = true, collision = false},
        ["JhinE"] = {charName = "Jhin", slot = _E, type = "circular", speed = 1600, range = 750, delay = 0.25, radius = 120, hitbox = true, aoe = false, cc = true, collision = false},
        ["JhinRShot"] = {charName = "Jhin", slot = _R, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = false},
        ["JinxW"] = {charName = "Jinx", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["JinxE"] = {charName = "Jinx", slot = _E, type = "circular", speed = 1100, range = 900, delay = 1.5, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["JinxR"] = {charName = "Jinx", slot = _R, type = "linear", speed = 1700, range = 25000, delay = 0.6, radius = 140, hitbox = true, aoe = true, cc = false, collision = false},
        ["KaisaW"] = {charName = "Kaisa", slot = _W, type = "linear", speed = 1750, range = 3000, delay = 0.4, radius = 100, hitbox = true, aoe = false, cc = false, collision = true},
        ["KalistaMysticShot"] = {charName = "Kalista", slot = _Q, type = "linear", speed = 2400, range = 1150, delay = 0.35, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["KalistaW"] = {charName = "Kalista", slot = _W, type = "circular", speed = math.huge, range = 5000, delay = 0.5, radius = 45, hitbox = true, aoe = false, cc = false, collision = false},
        ["KarmaQ"] = {charName = "Karma", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["KarmaQMantra"] = {charName = "Karma", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["KarthusLayWasteA1"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusLayWasteA2"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusLayWasteA3"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusWallOfPain"] = {charName = "Karthus", slot = _W, type = "rectangle", speed = math.huge, range = 1000, delay = 0.25, radius1 = 470, radius2 = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["ForcePulse"] = {charName = "Kassadin", slot = _E, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["Riftwalk"] = {charName = "Kassadin", slot = _R, type = "circular", speed = math.huge, range = 500, delay = 0.25, radius = 300, hitbox = true, aoe = true, cc = false, collision = false},
        ["KatarinaW"] = {charName = "Katarina", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 1.25, radius = 340, hitbox = false, aoe = true, cc = false, collision = false},
        ["KatarinaE"] = {charName = "Katarina", slot = _E, type = "circular", speed = math.huge, range = 725, delay = 0.15, radius = 150, hitbox = true, aoe = false, cc = false, collision = false},
        ["KatarinaR"] = {charName = "Katarina", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["KaynQ"] = {charName = "Kayn", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.15, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["KaynW"] = {charName = "Kayn", slot = _W, type = "linear", speed = math.huge, range = 700, delay = 0.55, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["KennenShurikenHurlMissile1"] = {charName = "Kennen", slot = _Q, type = "linear", speed = 1700, range = 1050, delay = 0.175, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["KennenShurikenStorm"] = {charName = "Kennen", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["KhazixW"] = {charName = "Khazix", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["KhazixWLong"] = {charName = "Khazix", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = true},
        ["KhazixE"] = {charName = "Khazix", slot = _E, type = "circular", speed = 1000, range = 700, delay = 0.25, radius = 320, hitbox = true, aoe = true, cc = false, collision = false},
        ["KhazixELong"] = {charName = "Khazix", slot = _E, type = "circular", speed = 1000, range = 900, delay = 0.25, radius = 320, hitbox = true, aoe = true, cc = false, collision = false},
        ["KindredR"] = {charName = "Kindred", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 500, hitbox = false, aoe = true, cc = false, collision = false},
        ["KledQ"] = {charName = "Kled", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, hitbox = true, aoe = false, cc = true, collision = true},
        ["KledEDash"] = {charName = "Kled", slot = _E, type = "linear", speed = 1100, range = 550, delay = 0, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["KledRiderQ"] = {charName = "Kled", slot = _Q, type = "conic", speed = 3000, range = 700, delay = 0.25, angle = 25, hitbox = false, aoe = true, cc = false, collision = false},
        ["KogMawQ"] = {charName = "KogMaw", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["KogMawVoidOoze"] = {charName = "KogMaw", slot = _E, type = "linear", speed = 1400, range = 1280, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["KogMawLivingArtillery"] = {charName = "KogMaw", slot = _R, type = "circular", speed = math.huge, range = 1800, delay = 0.85, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancW"] = {charName = "Leblanc", slot = _W, type = "circular", speed = 1450, range = 600, delay = 0.25, radius = 260, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancE"] = {charName = "Leblanc", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["LeblancRW"] = {charName = "Leblanc", slot = _W, type = "circular", speed = 1450, range = 600, delay = 0.25, radius = 260, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancRE"] = {charName = "Leblanc", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["BlindMonkQOne"] = {charName = "LeeSin", slot = _Q, type = "linear", speed = 1800, range = 1200, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["BlindMonkEOne"] = {charName = "LeeSin", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["LeonaZenithBlade"] = {charName = "Leona", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = false},
        ["LeonaSolarFlare"] = {charName = "Leona", slot = _R, type = "circular", speed = math.huge, range = 1200, delay = 0.625, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["LissandraQ"] = {charName = "Lissandra", slot = _Q, type = "linear", speed = 2200, range = 825, delay = 0.251, radius = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["LissandraW"] = {charName = "Lissandra", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 450, hitbox = false, aoe = true, cc = true, collision = false},
        ["LissandraE"] = {charName = "Lissandra", slot = _E, type = "linear", speed = 850, range = 1050, delay = 0.25, radius = 125, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianQ"] = {charName = "Lucian", slot = _Q, type = "linear", speed = math.huge, range = 900, delay = 0.5, radius = 65, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianW"] = {charName = "Lucian", slot = _W, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianR"] = {charName = "Lucian", slot = _R, type = "linear", speed = 2800, range = 1200, delay = 0.01, radius = 110, hitbox = true, aoe = false, cc = false, collision = true},
        ["LuluQ"] = {charName = "Lulu", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["LuxLightBinding"] = {charName = "Lux", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 50, hitbox = true, aoe = true, cc = true, collision = true},
        ["LuxPrismaticWave"] = {charName = "Lux", slot = _W, type = "linear", speed = 1400, range = 1075, delay = 0.25, radius = 110, hitbox = true, aoe = true, cc = false, collision = false},
        ["LuxLightStrikeKugel"] = {charName = "Lux", slot = _E, type = "circular", speed = 1200, range = 1000, delay = 0.25, radius = 310, hitbox = true, aoe = true, cc = true, collision = false},
        ["LuxMaliceCannon"] = {charName = "Lux", slot = _R, type = "linear", speed = math.huge, range = 3340, delay = 1, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["Landslide"] = {charName = "Malphite", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.242, radius = 200, hitbox = false, aoe = true, cc = true, collision = false},
        ["UFSlash"] = {charName = "Malphite", slot = _R, type = "circular", speed = 1835, range = 1000, delay = 0, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["MalzaharQ"] = {charName = "Malzahar", slot = _Q, type = "rectangle", speed = math.huge, range = 900, delay = 0.25, radius1 = 400, radius2 = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["MaokaiQ"] = {charName = "Maokai", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, hitbox = true, aoe = true, cc = true, collision = false},
        ["MaokaiR"] = {charName = "Maokai", slot = _R, type = "linear", speed = 150, range = 3000, delay = 0.25, radius = 650, hitbox = true, aoe = true, cc = true, collision = false},
        ["MissFortuneScattershot"] = {charName = "MissFortune", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.5, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["MissFortuneBulletTime"] = {charName = "MissFortune", slot = _R, type = "conic", speed = math.huge, range = 1400, delay = 0.001, angle = 40, hitbox = false, aoe = true, cc = false, collision = false},
        ["MordekaiserSiphonOfDestruction"] = {charName = "Mordekaiser", slot = _E, type = "conic", speed = math.huge, range = 675, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = false, collision = false},
        ["DarkBindingMissile"] = {charName = "Morgana", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["TormentedSoil"] = {charName = "Morgana", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.25, radius = 325, hitbox = true, aoe = true, cc = false, collision = false},
        ["NamiQ"] = {charName = "Nami", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.95, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["NamiR"] = {charName = "Nami", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["NasusE"] = {charName = "Nasus", slot = _E, type = "circular", speed = math.huge, range = 650, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = false, collision = false},
        ["NautilusAnchorDrag"] = {charName = "Nautilus", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 90, hitbox = true, aoe = false, cc = true, collision = true},
        ["NautilusSplashZone"] = {charName = "Nautilus", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 600, hitbox = false, aoe = true, cc = true, collision = false},
        ["JavelinToss"] = {charName = "Nidalee", slot = _Q, type = "linear", speed = 1300, range = 1500, delay = 0.25, radius = 40, hitbox = true, aoe = true, cc = false, collision = true},
        ["Bushwhack"] = {charName = "Nidalee", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.25, radius = 85, hitbox = true, aoe = false, cc = false, collision = true},
        ["Pounce"] = {charName = "Nidalee", slot = _W, type = "circular", speed = 1750, range = 750, delay = 0.25, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["Swipe"] = {charName = "Nidalee", slot = _E, type = "conic", speed = math.huge, range = 300, delay = 0.25, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["NocturneDuskbringer"] = {charName = "Nocturne", slot = _Q, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["AbsoluteZero"] = {charName = "Nunu", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 3.01, radius = 650, hitbox = false, aoe = true, cc = true, collision = false},
        ["OlafAxeThrowCast"] = {charName = "Olaf", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrianaIzunaCommand"] = {charName = "Orianna", slot = _Q, type = "linear", speed = 1400, range = 825, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["OrianaDissonanceCommand"] = {charName = "Orianna", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 250, hitbox = false, aoe = true, cc = true, collision = false},
        ["OrianaRedactCommand"] = {charName = "Orianna", slot = _E, type = "linear", speed = 1400, range = 1100, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["OrianaDetonateCommand"] = {charName = "Orianna", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 325, hitbox = false, aoe = true, cc = true, collision = false},
        ["OrnnQ"] = {charName = "Ornn", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrnnE"] = {charName = "Ornn", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.35, radius = 150, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrnnR"] = {charName = "Ornn", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["PantheonE"] = {charName = "Pantheon", slot = _E, type = "conic", speed = math.huge, range = 0, delay = 0.389, angle = 80, hitbox = false, aoe = true, cc = false, collision = false},
        ["PantheonRFall"] = {charName = "Pantheon", slot = _R, type = "circular", speed = math.huge, range = 5500, delay = 2.5, radius = 700, hitbox = true, aoe = true, cc = true, collision = false},
        ["PoppyQSpell"] = {charName = "Poppy", slot = _Q, type = "linear", speed = math.huge, range = 430, delay = 1.32, radius = 85, hitbox = true, aoe = true, cc = true, collision = false},
        ["PoppyW"] = {charName = "Poppy", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 400, hitbox = false, aoe = true, cc = false, collision = false},
        ["PoppyRSpell"] = {charName = "Poppy", slot = _R, type = "linear", speed = 2000, range = 1900, delay = 0.333, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["PykeQMelee"] = {charName = "Pyke", slot = _Q, type = "linear", speed = math.huge, range = 400, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["PykeQRange"] = {charName = "Pyke", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["PykeR"] = {charName = "Pyke", slot = _R, type = "cross", speed = math.huge, range = 750, delay = 0.5, radius1 = 300, radius2 = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["QuinnQ"] = {charName = "Quinn", slot = _Q, type = "linear", speed = 1550, range = 1025, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["RakanQ"] = {charName = "Rakan", slot = _Q, type = "linear", speed = 1850, range = 900, delay = 0.25, radius = 65, hitbox = true, aoe = false, cc = false, collision = true},
        ["RakanW"] = {charName = "Rakan", slot = _W, type = "circular", speed = 2050, range = 600, delay = 0, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["RakanWCast"] = {charName = "Rakan", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 250, hitbox = false, aoe = true, cc = true, collision = false},
        ["Tremors2"] = {charName = "Rammus", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["RekSaiQBurrowed"] = {charName = "RekSai", slot = _Q, type = "linear", speed = 1950, range = 1650, delay = 0.125, radius = 65, hitbox = true, aoe = false, cc = false, collision = true},
        ["RenektonCleave"] = {charName = "Renekton", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 325, hitbox = false, aoe = true, cc = false, collision = false},
        ["RenektonSliceAndDice"] = {charName = "Renekton", slot = _E, type = "linear", speed = 1125, range = 450, delay = 0.25, radius = 45, hitbox = true, aoe = true, cc = false, collision = false},
        ["RengarW"] = {charName = "Rengar", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 450, hitbox = false, aoe = true, cc = false, collision = false},
        ["RengarE"] = {charName = "Rengar", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["RivenMartyr"] = {charName = "Riven", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.267, radius = 135, hitbox = false, aoe = true, cc = true, collision = false},
        ["RivenIzunaBlade"] = {charName = "Riven", slot = _R, type = "conic", speed = 1600, range = 900, delay = 0.25, angle = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["RumbleGrenade"] = {charName = "Rumble", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["RumbleCarpetBombDummy"] = {charName = "Rumble", slot = _R, type = "rectangle", speed = 1600, range = 1700, delay = 0.583, radius1 = 600, radius2 = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["RyzeQ"] = {charName = "Ryze", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = false, collision = true},
        ["SejuaniW"] = {charName = "Sejuani", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 75, hitbox = false, aoe = true, cc = true, collision = false},
        ["SejuaniWDummy"] = {charName = "Sejuani", slot = _W, type = "linear", speed = math.huge, range = 600, delay = 1, radius = 65, hitbox = true, aoe = false, cc = true, collision = false},
        ["SejuaniR"] = {charName = "Sejuani", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShenE"] = {charName = "Shen", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShyvanaFireball"] = {charName = "Shyvana", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["ShyvanaTransformLeap"] = {charName = "Shyvana", slot = _R, type = "linear", speed = 1130, range = 850, delay = 0.25, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShyvanaFireballDragon2"] = {charName = "Shyvana", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.333, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["MegaAdhesive"] = {charName = "Singed", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 265, hitbox = true, aoe = true, cc = true, collision = false},
        ["SionQ"] = {charName = "Sion", slot = _Q, type = "linear", speed = math.huge, range = 600, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["SionE"] = {charName = "Sion", slot = _E, type = "linear", speed = 1800, range = 725, delay = 0.25, radius = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["SivirQ"] = {charName = "Sivir", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0.25, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["SivirQReturn"] = {charName = "Sivir", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["SkarnerVirulentSlash"] = {charName = "Skarner", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["SkarnerFracture"] = {charName = "Skarner", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["SonaR"] = {charName = "Sona", slot = _R, type = "linear", speed = 2400, range = 900, delay = 0.25, radius = 140, hitbox = true, aoe = true, cc = true, collision = false},
        ["SorakaQ"] = {charName = "Soraka", slot = _Q, type = "circular", speed = 1150, range = 800, delay = 0.25, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["SorakaE"] = {charName = "Soraka", slot = _E, type = "circular", speed = math.huge, range = 925, delay = 1.5, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["SwainQ"] = {charName = "Swain", slot = _Q, type = "conic", speed = math.huge, range = 725, delay = 0.25, angle = 45, hitbox = false, aoe = true, cc = false, collision = false},
        ["SwainW"] = {charName = "Swain", slot = _W, type = "circular", speed = math.huge, range = 3500, delay = 1.5, radius = 325, hitbox = false, aoe = true, cc = false, collision = false},
        ["SwainE"] = {charName = "Swain", slot = _E, type = "linear", speed = 935, range = 850, delay = 0.25, radius = 85, hitbox = true, aoe = true, cc = true, collision = false},
        ["SwainR"] = {charName = "Swain", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 650, hitbox = false, aoe = true, cc = true, collision = false},
        ["SyndraQ"] = {charName = "Syndra", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["SyndraWCast"] = {charName = "Syndra", slot = _W, type = "circular", speed = 1450, range = 950, delay = 0.25, radius = 225, hitbox = true, aoe = true, cc = true, collision = false},
        ["SyndraE"] = {charName = "Syndra", slot = _E, type = "conic", speed = 2500, range = 700, delay = 0.25, angle = 40, hitbox = false, aoe = true, cc = true, collision = false},
        ["SyndraEMissile"] = {charName = "Syndra", slot = _E, type = "linear", speed = 1600, range = 1250, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["TahmKenchQ"] = {charName = "TahmKench", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["TaliyahQ"] = {charName = "Taliyah", slot = _Q, type = "linear", speed = 3600, range = 1000, delay = 0.25, radius = 100, hitbox = true, aoe = false, cc = false, collision = true},
        ["TaliyahWVC"] = {charName = "Taliyah", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.6, radius = 150, hitbox = true, aoe = true, cc = true, collision = false},
        ["TaliyahE"] = {charName = "Taliyah", slot = _E, type = "conic", speed = 2000, range = 800, delay = 0.25, angle = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["TaliyahR"] = {charName = "Taliyah", slot = _R, type = "linear", speed = 1700, range = 6000, delay = 1, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["TalonW"] = {charName = "Talon", slot = _W, type = "conic", speed = 1850, range = 650, delay = 0.25, angle = 35, hitbox = true, aoe = true, cc = true, collision = false},
        ["TalonR"] = {charName = "Talon", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["TaricE"] = {charName = "Taric", slot = _E, type = "linear", speed = math.huge, range = 575, delay = 1, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["TeemoRCast"] = {charName = "Teemo", slot = _R, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["ThreshQ"] = {charName = "Thresh", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["ThreshE"] = {charName = "Thresh", slot = _E, type = "linear", speed = math.huge, range = 400, delay = 0.389, radius = 110, hitbox = false, aoe = true, cc = true, collision = false},
        ["ThreshRPenta"] = {charName = "Thresh", slot = _R, type = "pentagon", speed = math.huge, range = 0, delay = 0.45, radius = 450, hitbox = false, aoe = true, cc = true, collision = false},
        ["TristanaW"] = {charName = "Tristana", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["trundledesecrate"] = {charName = "Trundle", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 1000, hitbox = false, aoe = false, cc = false, collision = false},
        ["TrundleCircle"] = {charName = "Trundle", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["TryndamereE"] = {charName = "Tryndamere", slot = _E, type = "linear", speed = 1300, range = 660, delay = 0, radius = 225, hitbox = true, aoe = true, cc = false, collision = false},
        ["WildCards"] = {charName = "TwistedFate", slot = _Q, type = "linear", speed = 1000, range = 1450, delay = 0.25, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["TwitchVenomCask"] = {charName = "Twitch", slot = _W, type = "circular", speed = 1400, range = 950, delay = 0.25, radius = 340, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotQ"] = {charName = "Urgot", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.6, radius = 215, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotE"] = {charName = "Urgot", slot = _E, type = "linear", speed = 1050, range = 475, delay = 0.45, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotR"] = {charName = "Urgot", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.4, radius = 80, hitbox = true, aoe = false, cc = true, collision = false},
        ["VarusQ"] = {charName = "Varus", slot = _Q, type = "linear", speed = 1900, range = 1625, delay = 0, radius = 70, hitbox = true, aoe = true, cc = false, collision = false},
        ["VarusE"] = {charName = "Varus", slot = _E, type = "circular", speed = 1500, range = 925, delay = 0.242, radius = 280, hitbox = true, aoe = true, cc = true, collision = false},
        ["VarusR"] = {charName = "Varus", slot = _R, type = "linear", speed = 1950, range = 1075, delay = 0.242, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["VeigarBalefulStrike"] = {charName = "Veigar", slot = _Q, type = "linear", speed = 2200, range = 950, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = false, collision = true},
        ["VeigarDarkMatter"] = {charName = "Veigar", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 225, hitbox = true, aoe = true, cc = false, collision = false},
        ["VeigarEventHorizon"] = {charName = "Veigar", slot = _E, type = "circular", speed = math.huge, range = 700, delay = 0.75, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["VelKozQ"] = {charName = "VelKoz", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.251, radius = 50, hitbox = true, aoe = false, cc = true, collision = true},
        ["VelkozQMissileSplit"] = {charName = "VelKoz", slot = _Q, type = "linear", speed = 2100, range = 1050, delay = 0.251, radius = 45, hitbox = true, aoe = false, cc = true, collision = true},
        ["VelKozW"] = {charName = "VelKoz", slot = _W, type = "linear", speed = 1700, range = 1050, delay = 0.25, radius = 87.5, hitbox = true, aoe = true, cc = false, collision = false},
        ["VelKozE"] = {charName = "VelKoz", slot = _E, type = "circular", speed = math.huge, range = 850, delay = 0.75, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViQ"] = {charName = "Vi", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViktorGravitonField"] = {charName = "Viktor", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 1.333, radius = 290, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViktorDeathRay"] = {charName = "Viktor", slot = _E, type = "linear", speed = 1050, range = 1025, delay = 0, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["ViktorChaosStorm"] = {charName = "Viktor", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 0.25, radius = 290, hitbox = true, aoe = true, cc = false, collision = false},
        ["VladimirSanguinePool"] = {charName = "Vladimir", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["VladimirE"] = {charName = "Vladimir", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 600, hitbox = false, aoe = true, cc = true, collision = true},
        ["VladimirHemoplague"] = {charName = "Vladimir", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 0.389, radius = 350, hitbox = true, aoe = true, cc = false, collision = true},
        ["WarwickR"] = {charName = "Warwick", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 45, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahQ"] = {charName = "Xayah", slot = _Q, type = "linear", speed = 2075, range = 1100, delay = 0.5, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahE"] = {charName = "Xayah", slot = _E, type = "linear", speed = 4000, range = 2000, delay = 0, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahR"] = {charName = "Xayah", slot = _R, type = "conic", speed = 4000, range = 1100, delay = 1.5, radius = 20, angle = 40, hitbox = false, aoe = true, cc = false, collision = false},
        ["XerathArcanopulse2"] = {charName = "Xerath", slot = _Q, type = "linear", speed = math.huge, range = 1400, delay = 0.5, radius = 90, hitbox = false, aoe = true, cc = false, collision = false},
        ["XerathArcaneBarrage2"] = {charName = "Xerath", slot = _W, type = "circular", speed = math.huge, range = 1100, delay = 0.5, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["XerathMageSpear"] = {charName = "Xerath", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["XerathRMissileWrapper"] = {charName = "Xerath", slot = _R, type = "circular", speed = math.huge, range = 6160, delay = 0.6, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["XinZhaoW"] = {charName = "XinZhao", slot = _W, type = "conic", speed = math.huge, range = 125, delay = 0, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["XinZhaoW"] = {charName = "XinZhao", slot = _W, type = "linear", speed = math.huge, range = 900, delay = 0.5, radius = 45, hitbox = true, aoe = true, cc = true, collision = false},
        ["XinZhaoR"] = {charName = "XinZhao", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.325, radius = 550, hitbox = false, aoe = true, cc = true, collision = false},
        ["YasuoQW"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = math.huge, range = 475, delay = 0.339, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["YasuoQ2W"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = math.huge, range = 475, delay = 0.339, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["YasuoQ3W"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = 1200, range = 1000, delay = 0.339, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["YorickW"] = {charName = "Yorick", slot = _W, type = "circular", speed = math.huge, range = 600, delay = 0.25, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["YorickE"] = {charName = "Yorick", slot = _E, type = "conic", speed = 2100, range = 700, delay = 0.33, angle = 25, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZacQ"] = {charName = "Zac", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 80, hitbox = true, aoe = true, cc = true, collision = true},
        ["ZacW"] = {charName = "Zac", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["ZacE"] = {charName = "Zac", slot = _E, type = "circular", speed = 1330, range = 1800, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZacR"] = {charName = "Zac", slot = _R, type = "circular", speed = math.huge, range = 1000, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZedQ"] = {charName = "Zed", slot = _Q, type = "linear", speed = 1700, range = 900, delay = 0.25, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZedW"] = {charName = "Zed", slot = _W, type = "linear", speed = 1750, range = 650, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZedE"] = {charName = "Zed", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 290, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZiggsQ"] = {charName = "Ziggs", slot = _Q, type = "circular", speed = 1700, range = 1400, delay = 0.25, radius = 130, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZiggsW"] = {charName = "Ziggs", slot = _W, type = "circular", speed = 2000, range = 1000, delay = 0.25, radius = 280, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZiggsE"] = {charName = "Ziggs", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZiggsR"] = {charName = "Ziggs", slot = _R, type = "circular", speed = 1600, range = 5300, delay = 0.375, radius = 550, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZileanQ"] = {charName = "Zilean", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 180, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZileanQAttachAudio"] = {charName = "Zilean", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 180, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZoeQ"] = {charName = "Zoe", slot = _Q, type = "linear", speed = 1200, range = 800, delay = 0.25, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["ZoeQRecast"] = {charName = "Zoe", slot = _Q, type = "linear", speed = 2500, range = 1600, delay = 0, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["ZoeE"] = {charName = "Zoe", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, hitbox = true, aoe = false, cc = true, collision = true},
        ["ZyraQ"] = {charName = "Zyra", slot = _Q, type = "rectangle", speed = math.huge, range = 800, delay = 0.625, radius1 = 400, radius2 = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZyraW"] = {charName = "Zyra", slot = _W, type = "circular", speed = math.huge, range = 850, delay = 0.243, radius = 50, hitbox = true, aoe = false, cc = false, collision = false},
        ["ZyraE"] = {charName = "Zyra", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZyraR"] = {charName = "Zyra", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 1.775, radius = 575, hitbox = true, aoe = true, cc = true, collision = false},
    }
    self.Detected = {}
    Item_HK = {}
    self:LoadMenu()
    self:LoadSpells()
    Callback.Add("Tick", function()self:Tick() end)
    Callback.Add("Draw", function()self:Draw() end)
end

function Fiora:Tick()
    if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or ExtLibEvade and ExtLibEvade.Evading == true then return end
    
    if self.Detected[1] == nil then
        self.Collision = false
        self.CollisionSpellName = nil
    end

    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7

    self:Action()
    self:ProcessSpell(GetEnemyHeroes())

    self:Escape()

    if self.FioraMenu.AutoLevel.AutoLevel:Value() then
        local mylevel = myHero.levelData.lvl
        local mylevelpts = myHero.levelData.lvlPts
        
        if mylevelpts > 0 then
            if mylevel == 6 or mylevel == 11 or mylevel == 16 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_R)
                LocalControlKeyUp(HK_R)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 1 or mylevel == 4 or mylevel == 5 or mylevel == 7 or mylevel == 9 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_Q)
                LocalControlKeyUp(HK_Q)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 3 or mylevel == 14 or mylevel == 15 or mylevel == 17 or mylevel == 18 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_W)
                LocalControlKeyUp(HK_W)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 2 or mylevel == 8 or mylevel == 10 or mylevel == 12 or mylevel == 13 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_E)
                LocalControlKeyUp(HK_E)
                LocalControlKeyUp(HK_LUS)
            end
        end
    end
    
    self:KillSteal()

    self:Extra()

    if GetMode() == "Harass" then
        self:Harass()
        
    end
    if GetMode() == "Combo" then
        self:Combo()
    end
end

function Fiora:CollisionX(myHeroPos, dangerousPos, unitPos, radius)
    local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(Vector(myHeroPos), Vector(unitPos), Vector(dangerousPos))
    if isOnSegment and GetDistanceSqr(pointSegment, Vector(dangerousPos)) < (myHero.boundingRadius * 2 + radius) ^ 2 then
        return true
    else
        return false
    end
end

function Fiora:Action()
    for _, spell in pairs(self.Detected) do
        local delay = self.SpellsE[spell.name].delay
        local radius = self.SpellsE[spell.name].radius
        if spell.startTime + delay > Game.Timer() then
            if GetDistance(myHero.pos, spell.endPos) < (radius + myHero.boundingRadius) or GetDistance(spell.source, spell.endPos) < (radius + 100) or self:CollisionX(myHero.pos, spell.endPos, spell.source, radius) then
                --print("Yes")
                self.Collision = true
                self.CollisionSpellName = spell.name
            else
                --print("No")
                self.Collision = false
            end
        else
            table.remove(self.Detected, _)
        end
    end
--print("No")
--self.Collision = false
end

function Fiora:CalculateEndPos(startPos, placementPos, unitPos, range)
    if range > 0 then
        if GetDistance(unitPos, placementPos) > range then
            local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
            return endPos
        else
            local endPos = placementPos
            return endPos
        end
    else
        local endPos = unitPos
        return endPos
    end
end

function Fiora:ProcessSpell(units)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit.activeSpell and unit.activeSpell.isChanneling then
            --print(unit.activeSpell.name)
            if self.SpellsE and self.SpellsE[unit.activeSpell.name] then
                local startPos = Vector(unit.activeSpell.startPos)
                local placementPos = Vector(unit.activeSpell.placementPos)
                local unitPos = Vector(unit.pos)
                local sRange = self.SpellsE[unit.activeSpell.name].range
                local endPos = self:CalculateEndPos(startPos, placementPos, unitPos, sRange)
                spell = {source = unitPos, startPos = startPos, endPos = endPos, name = unit.activeSpell.name, startTime = Game.Timer()}
                table.insert(self.Detected, spell)
            end
        end
    end
end

function Fiora:Escape()
    for i = 1, Game.HeroCount() do
        local h = Game.Hero(i);
        if h.isEnemy then
            if h.activeSpell.valid and h.activeSpell.range > 0 then
                local t = self.Spells[h.activeSpell.name]
                if t then
                    if IS[h.networkID] == nil then
                        IS[h.networkID] = {
                            sPos = h.activeSpell.startPos,
                            ePos = h.activeSpell.startPos + Vector(h.activeSpell.startPos, h.activeSpell.placementPos):Normalized() * h.activeSpell.range,
                            radius = self.Spells[h.activeSpell.name].radius,
                            speed = self.Spells[h.activeSpell.name].speed,
                            startTime = h.activeSpell.startTime,
                            name = h.activeSpell.name,
                            delay = self.Spells[h.activeSpell.name].delay
                        }
                    end
                end
            end
        end
    end
    for key, v in pairs(IS) do
        local SpellHit = v.sPos + Vector(v.sPos, v.ePos):Normalized() * GetDistance(myHero.pos, v.sPos)
        local SpellPosition = v.sPos + Vector(v.sPos, v.ePos):Normalized() * (v.speed * (Game.Timer() - v.startTime) * 3)
        local dodge = SpellPosition + Vector(v.sPos, v.ePos):Normalized() * (v.speed * 0.1)
        if GetDistanceSqr(SpellHit, SpellPosition) <= GetDistanceSqr(dodge, SpellPosition) and GetDistance(SpellHit, v.sPos) - v.radius - myHero.boundingRadius <= GetDistance(v.sPos, v.ePos) then
            if GetDistanceSqr(myHero.pos, SpellHit) < (v.radius + myHero.boundingRadius) ^ 2 then
                if self.FioraMenu.Escape.UseW:Value() then
                    if IsReady(_W) then
                        LocalControlCastSpell(HK_W)
                    end
                end
            end
        end
        if (GetDistanceSqr(SpellPosition, v.sPos) >= GetDistanceSqr(v.sPos, v.ePos)) then
            IS[key] = nil
        end
    end
end

function Fiora:Extra()
    if self.FioraMenu.Extra.UseWBA:Value() then
        if self.CollisionSpellName == "YasuoWMovingWall" then
            
            else
            if IsReady(_W) then
                if unit and unit.team ~= myHero.team and unit.activeSpell.target == myHero and GetDistance(myHero.pos, unit.pos) < FioraW.range then
                    if unit.activeSpell.name:lower():find("attack") then
                        --print(unit.activeSpell.name)
                        LocalControlCastSpell(HK_W, unit)
                    end
                end
            end
        end
    end
end

function Fiora:Harass()
    
    local targetBC = GOS:GetTarget(550, "AP")
    
    if self.FioraMenu.Harass.UseBC:Value() then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AP")
    
    if self.FioraMenu.Harass.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
            end
        end
    end
    
    --TestBuff(targetHG)
    --self:GetGameObjects()
    --self:GetGameObjectsParticle()

    local targetTiamat = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Harass.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 and ValidTarget(targetTiamat, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], targetTiamat)
            end
        end
    end
    
    local targetTHydra = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Harass.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 and ValidTarget(targetTHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], targetTHydra)
            end
        end
    end

    local targetRHydra = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Harass.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 and ValidTarget(targetRHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], targetRHydra)
            end
        end
    end

    local targetQ = GOS:GetTarget(FioraQ.range, "AD")
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.FioraMenu.Harass.UseQ:Value() then
                if IsReady(_Q) and self.Collision == false then
                    if ValidTarget(targetQ, FioraQ.range) then
                        LocalControlCastSpell(HK_Q, targetQ)
                    end
                end
            end
        end
    end
    
    local targetW = GOS:GetTarget(FioraW.range, "AD")

    if targetW then
        if not IsImmune(targetW) then
            if self.FioraMenu.Harass.UseW:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_W) then
                        if ValidTarget(targetW, FioraW.range) then
                            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetW, FioraW.range, FioraW.delay, FioraW.speed, FioraW.radius, false)
                            if hitChance and hitChance >= 2 then
                                self:CastW(targetW, aimPosition)
                            end
                        end
                    end
                end
            end
        end
    end

    local targetE = GOS:GetTarget(FioraE.range, "AD")
    
    if targetE then
        if not IsImmune(targetE) then
            if self.FioraMenu.Harass.UseE:Value() then
                if IsReady(_E) and self.Collision == false then
                    if ValidTarget(targetE, FioraE.range) then
                        LocalControlCastSpell(HK_E, targetE)
                    end
                end
            end
        end
    end
end

function Fiora:CastW(target, EcastPos)
    if LocalGameTimer() - OnWaypoint(target).time > 0.05 and (LocalGameTimer() - OnWaypoint(target).time < 0.125 or LocalGameTimer() - OnWaypoint(target).time > 1.25) then
        if GetDistance(myHero.pos, EcastPos) <= FioraW.range then
            LocalControlCastSpell(HK_W, EcastPos)
        end
    end
end

function Fiora:Combo()
    
    local targetBC = GOS:GetTarget(550, "AP")
    
    if self.FioraMenu.Combo.UseBC:Value() then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AP")
    
    if self.FioraMenu.Combo.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
            end
        end
    end
    
    --TestBuff(targetHG)
    --self:GetGameObjects()
    --self:GetGameObjectsParticle()

    local targetTiamat = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Combo.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 and ValidTarget(targetTiamat, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], targetTiamat)
            end
        end
    end
    
    local targetTHydra = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Combo.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 and ValidTarget(targetTHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], targetTHydra)
            end
        end
    end

    local targetRHydra = GOS:GetTarget(380, "AD")
    
    if self.FioraMenu.Combo.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 and ValidTarget(targetRHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], targetRHydra)
            end
        end
    end

    local targetQ = GOS:GetTarget(FioraQ.range, "AD")
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.FioraMenu.Combo.UseQ:Value() then
                if IsReady(_Q) and self.Collision == false then
                    if ValidTarget(targetQ, FioraQ.range) then
                        LocalControlCastSpell(HK_Q, targetQ)
                    end
                end
            end
        end
    end
    
    local targetW = GOS:GetTarget(FioraW.range, "AD")

    if targetW then
        if not IsImmune(targetW) then
            if self.FioraMenu.Combo.UseW:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_W) then
                        if ValidTarget(targetW, FioraW.range) then
                            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetW, FioraW.range, FioraW.delay, FioraW.speed, FioraW.radius, false)
                            if hitChance and hitChance >= 2 then
                                self:CastW(targetW, aimPosition)
                            end
                        end
                    end
                end
            end
        end
    end

    local targetE = GOS:GetTarget(FioraE.range, "AD")
    
    if targetE then
        if not IsImmune(targetE) then
            if self.FioraMenu.Combo.UseE:Value() then
                if IsReady(_E) and self.Collision == false then
                    if ValidTarget(targetE, FioraE.range) then
                        LocalControlCastSpell(HK_E, targetE)
                    end
                end
            end
        end
    end

    local targetR = GOS:GetTarget(FioraR.range, "AD")
    
    if targetR then
        if not IsImmune(targetR) then
            if self.FioraMenu.Combo.UseR:Value() then
                if IsReady(_R) and self.Collision == false then
                    if ValidTarget(targetR, FioraR.range) then
                        LocalControlCastSpell(HK_R, targetR)
                    end
                end
            end
        end
    end
end

function Fiora:KillSteal()
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.FioraMenu.KillSteal.UseIgnite:Value() then
            local IgniteDmg = (55 + 25 * myHero.levelData.lvl)
            if ValidTarget(enemy, 600) and enemy.health + enemy.hpRegen < IgniteDmg then
                if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
                    Control.CastSpell(HK_SUMMONER_1, enemy)
                elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
                    Control.CastSpell(HK_SUMMONER_2, enemy)
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseQ:Value() then
        if IsReady(_Q) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, FioraQ.range) and enemy.health < QDmg() then
                    LocalControlCastSpell(HK_Q, enemy)
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseW:Value() then
        if IsReady(_W) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, FioraW.range) and enemy.health < WDmg() then
                    LocalControlCastSpell(HK_W, enemy)
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 700) and enemy.health + enemy.shieldAP < GunbladeDMG() then
                    if not IsImmune(enemy) then
                        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], enemy)
                        end
                    end
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < TiamatDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], enemy)
                    end
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < TiamatDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], enemy)
                    end
                end
            end
        end
    end
    if self.FioraMenu.KillSteal.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < THydraDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], enemy)
                    end
                end
            end
        end
    end
end

function Fiora:Draw()
    if self.ObjectPos then
        Draw.Circle(self.ObjectPos, 50, 1, Draw.Color(192, 255, 255, 255))
        Draw.Line(myHero.pos:To2D(), self.ObjectPos:To2D(), 0.1, Draw.Color(192, 255, 255, 255))
    end

    if myHero.dead then return end
    if self.FioraMenu.Drawings.DrawQ:Value() then Draw.Circle(myHero.pos, FioraQ.range, 1, Draw.Color(255, 0, 191, 255)) end
    if self.FioraMenu.Drawings.DrawW:Value() then Draw.Circle(myHero.pos, FioraW.range, 1, Draw.Color(255, 65, 105, 225)) end
    if self.FioraMenu.Drawings.DrawE:Value() then Draw.Circle(myHero.pos, FioraE.range, 1, Draw.Color(255, 30, 144, 255)) end
    if self.FioraMenu.Drawings.DrawR:Value() then Draw.Circle(myHero.pos, FioraR.range, 1, Draw.Color(255, 0, 0, 255)) end
    
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.FioraMenu.Drawings.DrawJng:Value() then
            if enemy:GetSpellData(SUMMONER_1).name == "SummonerSmite" or enemy:GetSpellData(SUMMONER_2).name == "SummonerSmite" then
                Smite = true
            else
                Smite = false
            end
            if Smite then
                if enemy.alive then
                    if ValidTarget(enemy) then
                        if GetDistance(myHero.pos, enemy.pos) > 3000 then
                            Draw.Text("Jungler: Visible", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                        else
                            Draw.Text("Jungler: Near", 17, myHero.pos2D.x - 43, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                        end
                    else
                        Draw.Text("Jungler: Invisible", 17, myHero.pos2D.x - 55, myHero.pos2D.y + 10, Draw.Color(0xFFFFD700))
                    end
                else
                    Draw.Text("Jungler: Dead", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                end
            end
        end
        if self.FioraMenu.Drawings.DrawAA:Value() then
            if ValidTarget(enemy) then
                AALeft = enemy.health / myHero.totalDamage
                Draw.Text("AA Left: " .. tostring(math.ceil(AALeft)), 17, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFF00BFFF))
            end
        end
        if self.FioraMenu.Drawings.DrawKS:Value() then
            if ValidTarget(enemy) then
                if enemy.health < (QDmg()) then
                    Draw.Text("Killable Skills (Q): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (QDmg() + WDmg()) then
                    Draw.Text("Killable Skills (Q+W): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                end
            end
        end
    end
end

function OnLoad()
    Fiora()
end

class "HPred"

local _tickFrequency = .2
local _nextTick = LocalGameTimer()
local _reviveLookupTable =
    {
        ["LifeAura.troy"] = 4,
        ["ZileanBase_R_Buf.troy"] = 3,
        ["Aatrox_Base_Passive_Death_Activate"] = 3
    }

local _blinkSpellLookupTable =
    {
        ["EzrealArcaneShift"] = 475,
        ["RiftWalk"] = 500,
        ["EkkoEAttack"] = 0,
        ["AlphaStrike"] = 0,
        ["KatarinaE"] = -255,
        ["KatarinaEDagger"] = {"Katarina_Base_Dagger_Ground_Indicator", "Katarina_Skin01_Dagger_Ground_Indicator", "Katarina_Skin02_Dagger_Ground_Indicator", "Katarina_Skin03_Dagger_Ground_Indicator", "Katarina_Skin04_Dagger_Ground_Indicator", "Katarina_Skin05_Dagger_Ground_Indicator", "Katarina_Skin06_Dagger_Ground_Indicator", "Katarina_Skin07_Dagger_Ground_Indicator", "Katarina_Skin08_Dagger_Ground_Indicator", "Katarina_Skin09_Dagger_Ground_Indicator"},
    }

local _blinkLookupTable =
    {
        "global_ss_flash_02.troy",
        "Lissandra_Base_E_Arrival.troy",
        "LeBlanc_Base_W_return_activation.troy"
    }

local _cachedBlinks = {}
local _cachedRevives = {}
local _cachedTeleports = {}
local _cachedMissiles = {}
local _incomingDamage = {}
local _windwall
local _windwallStartPos
local _windwallWidth

local _OnVision = {}
function HPred:OnVision(unit)
    if unit == nil or type(unit) ~= "userdata" then return end
    if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {visible = unit.visible, tick = LocalGetTickCount(), pos = unit.pos} end
    if _OnVision[unit.networkID].visible == true and not unit.visible then _OnVision[unit.networkID].visible = false _OnVision[unit.networkID].tick = LocalGetTickCount() end
    if _OnVision[unit.networkID].visible == false and unit.visible then _OnVision[unit.networkID].visible = true _OnVision[unit.networkID].tick = LocalGetTickCount()_OnVision[unit.networkID].pos = unit.pos end
    return _OnVision[unit.networkID]
end

function HPred:Tick()
    if _nextTick > LocalGameTimer() then return end
    _nextTick = LocalGameTimer() + _tickFrequency
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            if t.isEnemy then
                HPred:OnVision(t)
            end
        end
    end
    if true then return end
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport and LocalGameTimer() > teleport.expireTime + .5 then
            _cachedTeleports[_] = nil
        end
    end
    HPred:CacheTeleports()
    HPred:CacheParticles()
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and not _cachedRevives[particle.networkID] and _reviveLookupTable[particle.name] then
            _cachedRevives[particle.networkID] = {}
            _cachedRevives[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedRevives[particle.networkID]["target"] = target
                _cachedRevives[particle.networkID]["pos"] = target.pos
                _cachedRevives[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
        if particle and not _cachedBlinks[particle.networkID] and _blinkLookupTable[particle.name] then
            _cachedBlinks[particle.networkID] = {}
            _cachedBlinks[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedBlinks[particle.networkID]["target"] = target
                _cachedBlinks[particle.networkID]["pos"] = target.pos
                _cachedBlinks[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
    end

end

function HPred:GetEnemyNexusPosition()
    if myHero.team == 100 then return Vector(14340, 171.977722167969, 14390); else return Vector(396, 182.132507324219, 462); end
end


function HPred:GetGuarenteedTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end


function HPred:GetReliableTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetDashingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius, midDash)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end

function HPred:GetLineTargetCount(source, aimPos, delay, speed, width, targetAllies)
    local targetCount = 0
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTargetALL(t) and (targetAllies or t.isEnemy) then
            local predictedPos = self:PredictUnitPosition(t, delay + self:GetDistance(source, t.pos) / speed)
            local proj1, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(source, aimPos, predictedPos)
            if proj1 and isOnSegment and (self:GetDistanceSqr(predictedPos, proj1) <= (t.boundingRadius + width) * (t.boundingRadius + width)) then
                targetCount = targetCount + 1
            end
        end
    end
    return targetCount
end

function HPred:GetUnreliableTarget(source, range, delay, speed, radius, checkCollision, minimumHitChance, whitelist, isLine)
    local _validTargets = {}
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t, true) and (not whitelist or whitelist[t.charName]) then
            local hitChance, aimPosition = self:GetHitchance(source, t, range, delay, speed, radius, checkCollision, isLine)
            if hitChance >= minimumHitChance then
                _insert(_validTargets, {aimPosition, hitChance, hitChance * 100 + self:CalculateMagicDamage(t, 400)})
            end
        end
    end
    _sort(_validTargets, function(a, b) return a[3] > b[3] end)
    if #_validTargets > 0 then
        return _validTargets[1][2], _validTargets[1][1]
    end
end

function HPred:GetHitchance(source, target, range, delay, speed, radius, checkCollision, isLine)
    if isLine == nil and checkCollision then
        isLine = true
    end
    local hitChance = 1
    local aimPosition = self:PredictUnitPosition(target, delay + self:GetDistance(source, target.pos) / speed)
    local interceptTime = self:GetSpellInterceptTime(source, aimPosition, delay, speed)
    local reactionTime = self:PredictReactionTime(target, .1, isLine)
    if isLine then
        local pathVector = aimPosition - target.pos
        local castVector = (aimPosition - myHero.pos):Normalized()
        if pathVector.x + pathVector.z ~= 0 then
            pathVector = pathVector:Normalized()
            if pathVector:DotProduct(castVector) < -.85 or pathVector:DotProduct(castVector) > .85 then
                if speed > 3000 then
                    reactionTime = reactionTime + .25
                else
                    reactionTime = reactionTime + .15
                end
            end
        end
    end
    Waypoints = self:GetCurrentWayPoints(target)
    if (#Waypoints == 1) then
        HitChance = 2
    end
    if self:isSlowed(target, delay, speed, source) then
        HitChance = 2
    end
    if self:GetDistance(source, target.pos) < 350 then
        HitChance = 2
    end
    local angletemp = Vector(source):AngleBetween(Vector(target.pos), Vector(aimPosition))
    if angletemp > 60 then
        HitChance = 1
    elseif angletemp < 10 then
        HitChance = 2
    end
    if not target.pathing or not target.pathing.hasMovePath then
        hitChancevisionData = 2
        hitChance = 2
    end
    local origin, movementRadius = self:UnitMovementBounds(target, interceptTime, reactionTime)
    if movementRadius - target.boundingRadius <= radius / 2 then
        origin, movementRadius = self:UnitMovementBounds(target, interceptTime, 0)
        if movementRadius - target.boundingRadius <= radius / 2 then
            hitChance = 4
        else
            hitChance = 3
        end
    end
    if target.activeSpell and target.activeSpell.valid then
        if target.activeSpell.startTime + target.activeSpell.windup - LocalGameTimer() >= delay then
            hitChance = 5
        else
            hitChance = 3
        end
    end
    local visionData = HPred:OnVision(target)
    if visionData and visionData.visible == false then
        local hiddenTime = visionData.tick - LocalGetTickCount()
        if hiddenTime < -1000 then
            hitChance = -1
        else
            local targetSpeed = self:GetTargetMS(target)
            local unitPos = target.pos + Vector(target.pos, target.posTo):Normalized() * ((LocalGetTickCount() - visionData.tick) / 1000 * targetSpeed)
            local aimPosition = unitPos + Vector(target.pos, target.posTo):Normalized() * (targetSpeed * (delay + (self:GetDistance(myHero.pos, unitPos) / speed)))
            if self:GetDistance(target.pos, aimPosition) > self:GetDistance(target.pos, target.posTo) then aimPosition = target.posTo end
            hitChance = _min(hitChance, 2)
        end
    end
    if not self:IsInRange(source, aimPosition, range) then
        hitChance = -1
    end
    if hitChance > 0 and checkCollision then
        if self:IsWindwallBlocking(source, aimPosition) then
            hitChance = -1
        elseif self:CheckMinionCollision(source, aimPosition, delay, speed, radius) then
            hitChance = -1
        end
    end
    
    return hitChance, aimPosition
end

function HPred:PredictReactionTime(unit, minimumReactionTime)
    local reactionTime = minimumReactionTime
    if unit.activeSpell and unit.activeSpell.valid then
        local windupRemaining = unit.activeSpell.startTime + unit.activeSpell.windup - LocalGameTimer()
        if windupRemaining > 0 then
            reactionTime = windupRemaining
        end
    end
    return reactionTime
end

function HPred:GetCurrentWayPoints(object)
    local result = {}
    if object.pathing.hasMovePath then
        _insert(result, Vector(object.pos.x, object.pos.y, object.pos.z))
        for i = object.pathing.pathIndex, object.pathing.pathCount do
            path = object:GetPath(i)
            _insert(result, Vector(path.x, path.y, path.z))
        end
    else
        _insert(result, object and Vector(object.pos.x, object.pos.y, object.pos.z) or Vector(object.pos.x, object.pos.y, object.pos.z))
    end
    return result
end

function HPred:GetDashingTarget(source, range, delay, speed, dashThreshold, checkCollision, radius, midDash)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.pathing.hasMovePath and t.pathing.isDashing and t.pathing.dashSpeed > 500 then
            local dashEndPosition = t:GetPath(1)
            if self:IsInRange(source, dashEndPosition, range) then
                local dashTimeRemaining = self:GetDistance(t.pos, dashEndPosition) / t.pathing.dashSpeed
                local skillInterceptTime = self:GetSpellInterceptTime(source, dashEndPosition, delay, speed)
                local deltaInterceptTime = skillInterceptTime - dashTimeRemaining
                if deltaInterceptTime > 0 and deltaInterceptTime < dashThreshold and (not checkCollision or not self:CheckMinionCollision(source, dashEndPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = dashEndPosition
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy then
            local success, timeRemaining = self:HasBuff(t, "zhonyasringshield")
            if success then
                local spellInterceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
                local deltaInterceptTime = spellInterceptTime - timeRemaining
                if spellInterceptTime > timeRemaining and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = t.pos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, revive in _pairs(_cachedRevives) do
        if revive.isEnemy then
            local interceptTime = self:GetSpellInterceptTime(source, revive.pos, delay, speed)
            if interceptTime > revive.expireTime - LocalGameTimer() and interceptTime - revive.expireTime - LocalGameTimer() < timingAccuracy then
                target = revive.target
                aimPosition = revive.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.activeSpell and t.activeSpell.valid and _blinkSpellLookupTable[t.activeSpell.name] then
            local windupRemaining = t.activeSpell.startTime + t.activeSpell.windup - LocalGameTimer()
            if windupRemaining > 0 then
                local endPos
                local blinkRange = _blinkSpellLookupTable[t.activeSpell.name]
                if type(blinkRange) == "table" then
                    elseif blinkRange > 0 then
                    endPos = Vector(t.activeSpell.placementPos.x, t.activeSpell.placementPos.y, t.activeSpell.placementPos.z)
                    endPos = t.activeSpell.startPos + (endPos - t.activeSpell.startPos):Normalized() * _min(self:GetDistance(t.activeSpell.startPos, endPos), range)
                    else
                        local blinkTarget = self:GetObjectByHandle(t.activeSpell.target)
                        if blinkTarget then
                            local offsetDirection
                            if blinkRange == 0 then
                                if t.activeSpell.name == "AlphaStrike" then
                                    windupRemaining = windupRemaining + .75
                                end
                                offsetDirection = (blinkTarget.pos - t.pos):Normalized()
                            elseif blinkRange == -1 then
                                offsetDirection = (t.pos - blinkTarget.pos):Normalized()
                            elseif blinkRange == -255 then
                                if radius > 250 then
                                    endPos = blinkTarget.pos
                                end
                            end
                            if offsetDirection then
                                endPos = blinkTarget.pos - offsetDirection * blinkTarget.boundingRadius
                            end
                        end
                end
                local interceptTime = self:GetSpellInterceptTime(source, endPos, delay, speed)
                local deltaInterceptTime = interceptTime - windupRemaining
                if self:IsInRange(source, endPos, range) and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, endPos, delay, speed, radius)) then
                    target = t
                    aimPosition = endPos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    local target
    local aimPosition
    for _, particle in _pairs(_cachedBlinks) do
        if particle and self:IsInRange(source, particle.pos, range) then
            local t = particle.target
            local pPos = particle.pos
            if t and t.isEnemy and (not checkCollision or not self:CheckMinionCollision(source, pPos, delay, speed, radius)) then
                target = t
                aimPosition = pPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetChannelingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if self:CanTarget(t) and self:IsInRange(source, t.pos, range) and self:IsChannelling(t, interceptTime) and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t) and self:IsInRange(source, t.pos, range) then
            local immobileTime = self:GetImmobileTime(t)
            
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if immobileTime - interceptTime > timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:CacheTeleports()
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i);
        if turret and turret.isEnemy and not _cachedTeleports[turret.networkID] then
            local hasBuff, expiresAt = self:HasBuff(turret, "teleport_target")
            if hasBuff then
                self:RecordTeleport(turret, self:GetTeleportOffset(turret.pos, 223.31), expiresAt)
            end
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.isEnemy and not _cachedTeleports[ward.networkID] then
            local hasBuff, expiresAt = self:HasBuff(ward, "teleport_target")
            if hasBuff then
                self:RecordTeleport(ward, self:GetTeleportOffset(ward.pos, 100.01), expiresAt)
            end
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i);
        if minion and minion.isEnemy and not _cachedTeleports[minion.networkID] then
            local hasBuff, expiresAt = self:HasBuff(minion, "teleport_target")
            if hasBuff then
                self:RecordTeleport(minion, self:GetTeleportOffset(minion.pos, 143.25), expiresAt)
            end
        end
    end
end

function HPred:RecordTeleport(target, aimPos, endTime)
    _cachedTeleports[target.networkID] = {}
    _cachedTeleports[target.networkID]["target"] = target
    _cachedTeleports[target.networkID]["aimPos"] = aimPos
    _cachedTeleports[target.networkID]["expireTime"] = endTime + LocalGameTimer()
end


function HPred:CalculateIncomingDamage()
    _incomingDamage = {}
    local currentTime = LocalGameTimer()
    for _, missile in _pairs(_cachedMissiles) do
        if missile then
            local dist = self:GetDistance(missile.data.pos, missile.target.pos)
            if missile.name == "" or currentTime >= missile.timeout or dist < missile.target.boundingRadius then
                _cachedMissiles[_] = nil
            else
                if not _incomingDamage[missile.target.networkID] then
                    _incomingDamage[missile.target.networkID] = missile.damage
                else
                    _incomingDamage[missile.target.networkID] = _incomingDamage[missile.target.networkID] + missile.damage
                end
            end
        end
    end
end

function HPred:GetIncomingDamage(target)
    local damage = 0
    if _incomingDamage[target.networkID] then
        damage = _incomingDamage[target.networkID]
    end
    return damage
end

local _maxCacheRange = 3000
function HPred:CacheParticles()
    if _windwall and _windwall.name == "" then
        _windwall = nil
    end
    
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and self:IsInRange(particle.pos, myHero.pos, _maxCacheRange) then
            if _find(particle.name, "W_windwall%d") and not _windwall then
                local owner = self:GetObjectByHandle(particle.handle)
                if owner and owner.isEnemy then
                    _windwall = particle
                    _windwallStartPos = Vector(particle.pos.x, particle.pos.y, particle.pos.z)
                    local index = _len(particle.name) - 5
                    local spellLevel = _sub(particle.name, index, index) - 1
                    if type(spellLevel) ~= "number" then
                        spellLevel = 1
                    end
                    _windwallWidth = 150 + spellLevel * 25
                end
            end
        end
    end
end

function HPred:CacheMissiles()
    local currentTime = LocalGameTimer()
    for i = 1, LocalGameMissileCount() do
        local missile = LocalGameMissile(i)
        if missile and not _cachedMissiles[missile.networkID] and missile.missileData then
            if missile.missileData.target and missile.missileData.owner then
                local missileName = missile.missileData.name
                local owner = self:GetObjectByHandle(missile.missileData.owner)
                local target = self:GetObjectByHandle(missile.missileData.target)
                if owner and target and _find(target.type, "Hero") then
                    if (_find(missileName, "BasicAttack") or _find(missileName, "CritAttack")) then
                        _cachedMissiles[missile.networkID] = {}
                        _cachedMissiles[missile.networkID].target = target
                        _cachedMissiles[missile.networkID].data = missile
                        _cachedMissiles[missile.networkID].danger = 1
                        _cachedMissiles[missile.networkID].timeout = currentTime + 1.5
                        local damage = owner.totalDamage
                        if _find(missileName, "CritAttack") then
                            damage = damage * 1.5
                        end
                        _cachedMissiles[missile.networkID].damage = self:CalculatePhysicalDamage(target, damage)
                    end
                end
            end
        end
    end
end

function HPred:CalculatePhysicalDamage(target, damage)
    local targetArmor = target.armor * myHero.armorPenPercent - myHero.armorPen
    local damageReduction = 100 / (100 + targetArmor)
    if targetArmor < 0 then
        damageReduction = 2 - (100 / (100 - targetArmor))
    end
    damage = damage * damageReduction
    return damage
end

function HPred:CalculateMagicDamage(target, damage)
    local targetMR = target.magicResist * myHero.magicPenPercent - myHero.magicPen
    local damageReduction = 100 / (100 + targetMR)
    if targetMR < 0 then
        damageReduction = 2 - (100 / (100 - targetMR))
    end
    damage = damage * damageReduction
    return damage
end


function HPred:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport.expireTime > LocalGameTimer() and self:IsInRange(source, teleport.aimPos, range) then
            local spellInterceptTime = self:GetSpellInterceptTime(source, teleport.aimPos, delay, speed)
            local teleportRemaining = teleport.expireTime - LocalGameTimer()
            if spellInterceptTime > teleportRemaining and spellInterceptTime - teleportRemaining <= timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, teleport.aimPos, delay, speed, radius)) then
                target = teleport.target
                aimPosition = teleport.aimPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetTargetMS(target)
    local ms = target.pathing.isDashing and target.pathing.dashSpeed or target.ms
    return ms
end

function HPred:Angle(A, B)
    local deltaPos = A - B
    local angle = _atan(deltaPos.x, deltaPos.z) * 180 / _pi
    if angle < 0 then angle = angle + 360 end
    return angle
end

function HPred:PredictUnitPosition(unit, delay)
    local predictedPosition = unit.pos
    local timeRemaining = delay
    local pathNodes = self:GetPathNodes(unit)
    for i = 1, #pathNodes - 1 do
        local nodeDistance = self:GetDistance(pathNodes[i], pathNodes[i + 1])
        local nodeTraversalTime = nodeDistance / self:GetTargetMS(unit)
        if timeRemaining > nodeTraversalTime then
            timeRemaining = timeRemaining - nodeTraversalTime
            predictedPosition = pathNodes[i + 1]
        else
            local directionVector = (pathNodes[i + 1] - pathNodes[i]):Normalized()
            predictedPosition = pathNodes[i] + directionVector * self:GetTargetMS(unit) * timeRemaining
            break;
        end
    end
    return predictedPosition
end

function HPred:IsChannelling(target, interceptTime)
    if target.activeSpell and target.activeSpell.valid and target.activeSpell.isChanneling then
        return true
    end
end

function HPred:HasBuff(target, buffName, minimumDuration)
    local duration = minimumDuration
    if not minimumDuration then
        duration = 0
    end
    local durationRemaining
    for i = 1, target.buffCount do
        local buff = target:GetBuff(i)
        if buff.duration > duration and buff.name == buffName then
            durationRemaining = buff.duration
            return true, durationRemaining
        end
    end
end

function HPred:GetTeleportOffset(origin, magnitude)
    local teleportOffset = origin + (self:GetEnemyNexusPosition() - origin):Normalized() * magnitude
    return teleportOffset
end

function HPred:GetSpellInterceptTime(startPos, endPos, delay, speed)
    local interceptTime = Game.Latency() / 2000 + delay + self:GetDistance(startPos, endPos) / speed
    return interceptTime
end

function HPred:CanTarget(target, allowInvisible)
    return target.isEnemy and target.alive and target.health > 0 and (allowInvisible or target.visible) and target.isTargetable
end

function HPred:CanTargetALL(target)
    return target.alive and target.health > 0 and target.visible and target.isTargetable
end

function HPred:UnitMovementBounds(unit, delay, reactionTime)
    local startPosition = self:PredictUnitPosition(unit, delay)
    local radius = 0
    local deltaDelay = delay - reactionTime - self:GetImmobileTime(unit)
    if (deltaDelay > 0) then
        radius = self:GetTargetMS(unit) * deltaDelay
    end
    return startPosition, radius
end

function HPred:GetImmobileTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and (buff.type == 5 or buff.type == 8 or buff.type == 21 or buff.type == 22 or buff.type == 24 or buff.type == 11 or buff.type == 29 or buff.type == 30 or buff.type == 39) then
            duration = buff.duration
        end
    end
    return duration
end

function HPred:isSlowed(unit, delay, speed, from)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if from and unit and buff.count > 0 and buff.duration >= (delay + GetDistance(unit.pos, from) / speed) then
            if (buff.type == 10) then
                return true
            end
        end
    end
    return false
end

function HPred:GetSlowedTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and buff.type == 10 then
            duration = buff.duration
            return duration
        end
    end
    return duration
end

function HPred:GetPathNodes(unit)
    local nodes = {}
    _insert(nodes, unit.pos)
    if unit.pathing.hasMovePath then
        for i = unit.pathing.pathIndex, unit.pathing.pathCount do
            path = unit:GetPath(i)
            _insert(nodes, path)
        end
    end
    return nodes
end

function HPred:GetObjectByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and minion.handle == handle then
            target = minion
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.handle == handle then
            target = ward
            return target
        end
    end
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i)
        if turret and turret.handle == handle then
            target = turret
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and particle.handle == handle then
            target = particle
            return target
        end
    end
end

function HPred:GetHeroByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetObjectByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local enemy = LocalGameMinion(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local enemy = LocalGameWard(i);
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local enemy = LocalGameParticle(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetEnemyHeroByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
end

function HPred:GetNearestParticleByNames(origin, names)
    local target
    local distance = 999999
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle then
            local d = self:GetDistance(origin, particle.pos)
            if d < distance then
                distance = d
                target = particle
            end
        end
    end
    return target, distance
end

function HPred:GetPathLength(nodes)
    local result = 0
    for i = 1, #nodes - 1 do
        result = result + self:GetDistance(nodes[i], nodes[i + 1])
    end
    return result
end

function HPred:CheckMinionCollision(origin, endPos, delay, speed, radius, frequency)
    if not frequency then
        frequency = radius
    end
    local directionVector = (endPos - origin):Normalized()
    local checkCount = self:GetDistance(origin, endPos) / frequency
    for i = 1, checkCount do
        local checkPosition = origin + directionVector * i * frequency
        local checkDelay = delay + self:GetDistance(origin, checkPosition) / speed
        if self:IsMinionIntersection(checkPosition, radius, checkDelay, radius * 3) then
            return true
        end
    end
    return false
end

function HPred:IsMinionIntersection(location, radius, delay, maxDistance)
    if not maxDistance then
        maxDistance = 500
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and self:CanTarget(minion) and self:IsInRange(minion.pos, location, maxDistance) then
            local predictedPosition = self:PredictUnitPosition(minion, delay)
            if self:IsInRange(location, predictedPosition, radius + minion.boundingRadius) then
                return true
            end
        end
    end
    return false
end

function HPred:VectorPointProjectionOnLineSegment(v1, v2, v)
    assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)")
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function HPred:IsWindwallBlocking(source, target)
    if _windwall then
        local windwallFacing = (_windwallStartPos - _windwall.pos):Normalized()
        return self:DoLineSegmentsIntersect(source, target, _windwall.pos + windwallFacing:Perpendicular() * _windwallWidth, _windwall.pos + windwallFacing:Perpendicular2() * _windwallWidth)
    end
    return false
end

function HPred:DoLineSegmentsIntersect(A, B, C, D)
    local o1 = self:GetOrientation(A, B, C)
    local o2 = self:GetOrientation(A, B, D)
    local o3 = self:GetOrientation(C, D, A)
    local o4 = self:GetOrientation(C, D, B)
    if o1 ~= o2 and o3 ~= o4 then
        return true
    end
    if o1 == 0 and self:IsOnSegment(A, C, B) then return true end
    if o2 == 0 and self:IsOnSegment(A, D, B) then return true end
    if o3 == 0 and self:IsOnSegment(C, A, D) then return true end
    if o4 == 0 and self:IsOnSegment(C, B, D) then return true end
    
    return false
end

function HPred:GetOrientation(A, B, C)
    local val = (B.z - A.z) * (C.x - B.x) -
        (B.x - A.x) * (C.z - B.z)
    if val == 0 then
        return 0
    elseif val > 0 then
        return 1
    else
        return 2
    end

end

function HPred:IsOnSegment(A, B, C)
    return B.x <= _max(A.x, C.x) and
        B.x >= _min(A.x, C.x) and
        B.z <= _max(A.z, C.z) and
        B.z >= _min(A.z, C.z)
end

function HPred:GetSlope(A, B)
    return (B.z - A.z) / (B.x - A.x)
end

function HPred:GetEnemyByName(name)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.isEnemy and enemy.charName == name then
            target = enemy
            return target
        end
    end
end

function HPred:IsPointInArc(source, origin, target, angle, range)
    local deltaAngle = _abs(HPred:Angle(origin, target) - HPred:Angle(source, origin))
    if deltaAngle < angle and self:IsInRange(origin, target, range) then
        return true
    end
end

function HPred:GetDistanceSqr(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined GetDistanceSqr target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y))
end

function HPred:IsInRange(p1, p2, range)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined IsInRange target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return false
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y)) < range * range
end

function HPred:GetDistance(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        _print("Undefined GetDistance target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return _sqrt(self:GetDistanceSqr(p1, p2))
end

