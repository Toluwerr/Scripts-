-- Prison Life autofarm (place 155615604)
-- Roles: Prisoner / Police / Criminal - arrest farming, kill farming,
-- auto escape, weapon fetching, kill aura, anti-arrest.
-- UI: Reborn (https://github.com/Toluwer/Reborn)

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__PrisonLifeCleanup) == "function" then
        pcall(Global.__PrisonLifeCleanup)
end

local running = true
local connections = {}

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnectAll()
        for _, connection in ipairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end
        connections = {}
end

local FS = {
        write = (type(writefile) == "function") and writefile or nil,
        read = (type(readfile) == "function") and readfile or nil,
        isFile = (type(isfile) == "function") and isfile or nil,
        isFolder = (type(isfolder) == "function") and isfolder or nil,
        makeFolder = (type(makefolder) == "function") and makefolder or nil,
}

-- ============================================================
-- Reborn UI
-- ============================================================

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[PrisonLife] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

-- ============================================================
-- Game bindings
-- ============================================================

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunRemotes = ReplicatedStorage:WaitForChild("GunRemotes")
local ArrestPlayer = Remotes:WaitForChild("ArrestPlayer")
local RequestTeamChange = Remotes:WaitForChild("RequestTeamChange")
local InteractWithItem = Remotes:WaitForChild("InteractWithItem")
local GiverPressed = Remotes:WaitForChild("GiverPressed")
local ClientArrested = Remotes:WaitForChild("ClientArrested")
local MeleeEvent = ReplicatedStorage:WaitForChild("meleeEvent")
local ShootEvent = GunRemotes:WaitForChild("ShootEvent")
local FuncReload = GunRemotes:WaitForChild("FuncReload")
local ToolProperties = ReplicatedStorage:FindFirstChild("SharedModules")
        and ReplicatedStorage.SharedModules:FindFirstChild("ToolProperties")

local GUN_SET = {
        ["AK-47"] = true,
        ["M4A1"] = true,
        ["FAL"] = true,
        ["MP5"] = true,
        ["Remington 870"] = true,
        ["Revolver"] = true,
        ["M700"] = true,
        ["M9"] = true,
        ["Taser"] = true,
}

local MELEE_SET = {
        ["Crude Knife"] = true,
        ["Hammer"] = true,
        ["Stop Sign"] = true,
}

local WEAPON_OPTIONS = {
        "AK-47", "M4A1", "FAL", "MP5", "Remington 870", "Revolver", "M700",
        "Crude Knife", "Hammer", "Stop Sign",
}

local DEFAULT_GUN_PROPS = {
        Damage = 15,
        MaxAmmo = 30,
        FireRate = 0.1,
        ReloadTime = 2,
        ProjectileCount = 1,
}

-- ============================================================
-- Config
-- ============================================================

local CONFIG_FOLDER = "prisonlife"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"

local cfg = {
        Role = "Police",
        FarmEnabled = false,
        AutoEscape = true,
        AutoArrest = true,
        AutoKill = true,
        AutoGun = true,
        FarmDelay = 0.35,
        KillAura = false,
        AuraRadius = 12,
        TargetPart = "Head",
        Priority = "Nearest",
        MaxRange = 250,
        AntiArrest = false,
        Weapon = "AK-47",
        WalkSpeed = 16,
        InfJump = false,
}

local saveQueued = false

local function queueSave()
        if not FS.write then
                return
        end
        if saveQueued then
                return
        end
        saveQueued = true
        task.delay(1, function()
                saveQueued = false
                if not running then
                        return
                end
                local ok, json = pcall(function()
                        return HttpService:JSONEncode(cfg)
                end)
                if not ok or type(json) ~= "string" then
                        return
                end
                pcall(function()
                        if FS.isFolder and FS.makeFolder then
                                if not FS.isFolder(CONFIG_FOLDER) then
                                        FS.makeFolder(CONFIG_FOLDER)
                                end
                        end
                        FS.write(CONFIG_FILE, json)
                end)
        end)
end

local function loadConfig()
        if not FS.read or not FS.isFile then
                return
        end
        local ok, body = pcall(function()
                if FS.isFile(CONFIG_FILE) then
                        return FS.read(CONFIG_FILE)
                end
                return nil
        end)
        if not ok or type(body) ~= "string" or #body < 2 then
                return
        end
        local okData, data = pcall(function()
                return HttpService:JSONDecode(body)
        end)
        if not okData or type(data) ~= "table" then
                return
        end
        for key, value in pairs(cfg) do
                local incoming = data[key]
                if incoming ~= nil then
                        if type(value) == "string" and type(incoming) == "string" then
                                cfg[key] = incoming
                        elseif type(value) == "boolean" then
                                cfg[key] = incoming and true or false
                        elseif type(value) == "number" and type(incoming) == "number" then
                                cfg[key] = incoming
                        end
                end
        end
end

loadConfig()

-- ============================================================
-- Runtime state
-- ============================================================

local state = {
        action = "Idle",
        arrested = false,
        arrestedAt = 0,
        farmBusy = false,
        arrests = 0,
        kills = 0,
        escapes = 0,
        blacklist = {},
        lastNotify = {},
        lastSwitchAt = 0,
        aaCooldownUntil = 0,
        auraWarned = false,
}

local ui = {}

local Window = Reborn:CreateWindow({
        Title = "Prison Life",
        Size = Vector2.new(520, 470),
})

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 3.2,
                })
        end)
end

local function notifyT(key, title, description, cooldown)
        local now = os.clock()
        cooldown = cooldown or 5
        if state.lastNotify[key] and now - state.lastNotify[key] < cooldown then
                return
        end
        state.lastNotify[key] = now
        notify(title, description)
end

local function setAction(text)
        state.action = text
end

-- ============================================================
-- Character helpers
-- ============================================================

local function myCharacter()
        return LocalPlayer.Character
end

local function myHumanoid()
        local character = myCharacter()
        return character and character:FindFirstChildOfClass("Humanoid")
end

local function myRoot()
        local character = myCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
end

local function rootPos()
        local root = myRoot()
        return root and root.Position or nil
end

local function isAlive()
        local humanoid = myHumanoid()
        return humanoid ~= nil and humanoid.Health > 0
end

local function teamName()
        local team = LocalPlayer.Team
        return team and team.Name or ""
end

local function teleport(cframe)
        local root = myRoot()
        if root then
                root.CFrame = cframe
        end
end

local function groundCFrame(pos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local character = myCharacter()
        if character then
                params.FilterDescendantsInstances = { character }
        end
        local origin = pos + Vector3.new(0, 60, 0)
        local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
        local base = result and result.Position or pos
        return CFrame.new(base.X, base.Y + 3.5, base.Z)
end

local function modelPos(model)
        local ok, pivot = pcall(function()
                return model:GetPivot()
        end)
        if ok and pivot then
                return pivot.Position
        end
        local part = model:FindFirstChildWhichIsA("BasePart", true)
        if part then
                return part.Position
        end
        return nil
end

local function firstBasePart(model)
        return model:FindFirstChildWhichIsA("BasePart", true)
end

local function criminalSpawnPos()
        local container = workspace:FindFirstChild("Criminals Spawn")
        if not container then
                return nil
        end
        local spawnLocation = container:FindFirstChildOfClass("SpawnLocation", true)
        if spawnLocation then
                return spawnLocation.Position
        end
        return modelPos(container)
end

-- ============================================================
-- Weapon system
-- ============================================================

local function gunProps(toolName)
        if ToolProperties then
                local module = ToolProperties:FindFirstChild(toolName)
                if module then
                        local ok, props = pcall(function()
                                return require(module)
                        end)
                        if ok and type(props) == "table" then
                                return {
                                        Damage = tonumber(props.Damage) or DEFAULT_GUN_PROPS.Damage,
                                        MaxAmmo = tonumber(props.MaxAmmo) or DEFAULT_GUN_PROPS.MaxAmmo,
                                        FireRate = tonumber(props.FireRate) or DEFAULT_GUN_PROPS.FireRate,
                                        ReloadTime = tonumber(props.ReloadTime) or DEFAULT_GUN_PROPS.ReloadTime,
                                        ProjectileCount = tonumber(props.ProjectileCount) or DEFAULT_GUN_PROPS.ProjectileCount,
                                }
                        end
                end
        end
        return {
                Damage = DEFAULT_GUN_PROPS.Damage,
                MaxAmmo = DEFAULT_GUN_PROPS.MaxAmmo,
                FireRate = DEFAULT_GUN_PROPS.FireRate,
                ReloadTime = DEFAULT_GUN_PROPS.ReloadTime,
                ProjectileCount = DEFAULT_GUN_PROPS.ProjectileCount,
        }
end

local function hasToolNamed(name)
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack and backpack:FindFirstChild(name) then
                return true
        end
        local character = myCharacter()
        if character then
                local tool = character:FindFirstChild(name)
                if tool and tool:IsA("Tool") then
                        return true
                end
        end
        return false
end

local function findToolNamed(name)
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
                local tool = backpack:FindFirstChild(name)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        local character = myCharacter()
        if character then
                local tool = character:FindFirstChild(name)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        return nil
end

local function findAnyTool(nameSet)
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
                for _, child in ipairs(backpack:GetChildren()) do
                        if child:IsA("Tool") and nameSet[child.Name] then
                                return child
                        end
                end
        end
        local character = myCharacter()
        if character then
                for _, child in ipairs(character:GetChildren()) do
                        if child:IsA("Tool") and nameSet[child.Name] then
                                return child
                        end
                end
        end
        return nil
end

local function hasGunTool()
        return findAnyTool(GUN_SET) ~= nil
end

local function hasMeleeTool()
        return findAnyTool(MELEE_SET) ~= nil
end

local function equippedTool()
        local character = myCharacter()
        return character and character:FindFirstChildOfClass("Tool") or nil
end

local function ensureUnequip()
        local humanoid = myHumanoid()
        if humanoid then
                pcall(function()
                        humanoid:UnequipTools()
                end)
        end
end

local function gunChoice()
        if GUN_SET[cfg.Weapon] then
                return cfg.Weapon
        end
        return "AK-47"
end

local function equipBestGun()
        local humanoid = myHumanoid()
        if not humanoid or not isAlive() then
                return false
        end
        local current = equippedTool()
        if current and GUN_SET[current.Name] then
                return true
        end
        local preferred = GUN_SET[cfg.Weapon] and findToolNamed(cfg.Weapon) or nil
        if preferred then
                pcall(function()
                        humanoid:EquipTool(preferred)
                end)
                return true
        end
        local anyGun = findAnyTool(GUN_SET)
        if anyGun then
                pcall(function()
                        humanoid:EquipTool(anyGun)
                end)
                return true
        end
        return false
end

local function giverCandidates(weaponName)
        local candidates = {}
        local seen = {}
        local itemsFolder = workspace:FindFirstChild("Prison_ITEMS")
        local giverFolder = itemsFolder and itemsFolder:FindFirstChild("giver")
        if giverFolder then
                for _, model in ipairs(giverFolder:GetChildren()) do
                        if model.Name == weaponName and not seen[model] then
                                seen[model] = true
                                table.insert(candidates, model)
                        end
                end
        end
        local okTagged, tagged = pcall(function()
                return CollectionService:GetTagged("Giver")
        end)
        if okTagged and type(tagged) == "table" then
                for _, model in ipairs(tagged) do
                        if model.Name == weaponName and not seen[model] then
                                seen[model] = true
                                table.insert(candidates, model)
                        end
                end
        end
        local myPos = rootPos()
        if myPos then
                table.sort(candidates, function(a, b)
                        local pa, pb = modelPos(a), modelPos(b)
                        local da = pa and (pa - myPos).Magnitude or math.huge
                        local db = pb and (pb - myPos).Magnitude or math.huge
                        return da < db
                end)
        end
        return candidates
end

local function getGun(weaponName)
        if not isAlive() then
                return false
        end
        local myRootPart = myRoot()
        if not myRootPart then
                return false
        end
        local originCF = myRootPart.CFrame
        local candidates = giverCandidates(weaponName)
        if #candidates == 0 then
                notifyT("nogiver" .. weaponName, "No giver found", "There is no " .. weaponName .. " giver on this map.", 12)
                return false
        end
        ensureUnequip()
        local tries = math.min(#candidates, 5)
        for i = 1, tries do
                if not running then
                        break
                end
                local model = candidates[i]
                local pos = modelPos(model)
                if pos then
                        teleport(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
                        task.wait(0.25)
                        local part = firstBasePart(model)
                        if part then
                                pcall(function()
                                        InteractWithItem:InvokeServer(part)
                                end)
                                task.wait(0.55)
                        end
                        if hasToolNamed(weaponName) then
                                teleport(originCF)
                                notifyT("got" .. weaponName, "Got " .. weaponName)
                                return true
                        end
                        pcall(function()
                                GiverPressed:FireServer(model)
                        end)
                        task.wait(0.55)
                        if hasToolNamed(weaponName) then
                                teleport(originCF)
                                notifyT("got" .. weaponName, "Got " .. weaponName)
                                return true
                        end
                end
        end
        teleport(originCF)
        notifyT("gunfail" .. weaponName, "Could not get " .. weaponName, "Every giver refused (wrong team or area).", 10)
        return false
end

local function getMelee(weaponName)
        if not isAlive() then
                return false
        end
        local myRootPart = myRoot()
        if not myRootPart then
                return false
        end
        local originCF = myRootPart.CFrame
        local myPos = rootPos()
        local best, bestDist = nil, math.huge
        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == weaponName then
                        local pos = modelPos(model)
                        if pos and myPos then
                                local dist = (pos - myPos).Magnitude
                                if dist < bestDist then
                                        best, bestDist = model, dist
                                end
                        end
                end
        end
        if not best then
                notifyT("nomelee" .. weaponName, "Not available", "No " .. weaponName .. " found on the map.", 12)
                return false
        end
        ensureUnequip()
        local pos = modelPos(best)
        if pos then
                teleport(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
                task.wait(0.8)
                if not hasToolNamed(weaponName) then
                        local root = myRoot()
                        local part = firstBasePart(best)
                        if root and part and type(firetouchinterest) == "function" then
                                pcall(function()
                                        firetouchinterest(root, part, 0)
                                        firetouchinterest(root, part, 1)
                                end)
                                task.wait(0.4)
                        end
                end
                if not hasToolNamed(weaponName) then
                        local part = firstBasePart(best)
                        if part then
                                pcall(function()
                                        InteractWithItem:InvokeServer(part)
                                end)
                                task.wait(0.4)
                        end
                end
        end
        local got = hasToolNamed(weaponName)
        teleport(originCF)
        if got then
                notifyT("got" .. weaponName, "Got " .. weaponName)
        else
                notifyT("meleefail" .. weaponName, "Could not pick up " .. weaponName, 10)
        end
        return got
end

local function getWeapon(weaponName)
        if MELEE_SET[weaponName] then
                return getMelee(weaponName)
        end
        return getGun(weaponName)
end

-- ============================================================
-- Targeting
-- ============================================================

local function isBlacklisted(player)
        local until_ = state.blacklist[player]
        if until_ and os.clock() < until_ then
                return true
        end
        state.blacklist[player] = nil
        return false
end

local function blacklist(player, seconds)
        state.blacklist[player] = os.clock() + seconds
end

local function validTargetCharacter(player)
        local character = player.Character
        if not character then
                return nil, nil, nil
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not root then
                return nil, nil, nil
        end
        if character:FindFirstChildOfClass("ForceField") then
                return nil, nil, nil
        end
        return character, humanoid, root
end

local function getEnemies()
        local out = {}
        local mine = teamName()
        if mine == "" then
                return out
        end
        local guardSide = mine == "Guards"
        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team then
                        local other = player.Team.Name
                        if guardSide then
                                if other == "Criminals" then
                                        table.insert(out, player)
                                end
                        else
                                if other == "Guards" then
                                        table.insert(out, player)
                                end
                        end
                end
        end
        return out
end

local function resolvePart(character, preference)
        if preference == "Head" then
                local head = character:FindFirstChild("Head")
                if head then
                        return head
                end
        end
        return character:FindFirstChild("Torso")
                or character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("HumanoidRootPart")
end

local function pickKillTarget()
        local myPos = rootPos()
        if not myPos then
                return nil
        end
        local best, bestScore = nil, nil
        for _, player in ipairs(getEnemies()) do
                if not isBlacklisted(player) then
                        local character, humanoid, root = validTargetCharacter(player)
                        if character then
                                local dist = (root.Position - myPos).Magnitude
                                if dist <= cfg.MaxRange then
                                        local score
                                        if cfg.Priority == "Lowest HP" then
                                                score = humanoid.Health
                                        elseif cfg.Priority == "Farthest" then
                                                score = -dist
                                        else
                                                score = dist
                                        end
                                        if not bestScore or score < bestScore then
                                                best, bestScore = player, score
                                        end
                                end
                        end
                end
        end
        return best
end

-- Mirrors the exact arrest rules the Handcuffs client uses.
local function arrestEligible(player)
        local character, humanoid, root = validTargetCharacter(player)
        if not character then
                return false
        end
        local team = player.Team
        if not team then
                return false
        end
        if team.Name == "Criminals" then
                return true
        end
        if team.Name == "Inmates" then
                local attributes = character:GetAttributes()
                if not attributes.Hostile then
                        if attributes.Trespassing then
                                return true
                        end
                elseif attributes.Tased then
                        return true
                end
        end
        return false
end

local function pickArrestTarget()
        local myPos = rootPos()
        if not myPos then
                return nil
        end
        local best, bestDist = nil, math.huge
        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and not isBlacklisted(player) and arrestEligible(player) then
                        local character, humanoid, root = validTargetCharacter(player)
                        if character then
                                local dist = (root.Position - myPos).Magnitude
                                if dist < bestDist and dist <= 1000 then
                                        best, bestDist = player, dist
                                end
                        end
                end
        end
        return best
end

-- ============================================================
-- Combat
-- ============================================================

local function shootAt(target)
        local character = myCharacter()
        local humanoid = myHumanoid()
        if not character or not humanoid or humanoid.Health <= 0 then
                return
        end
        local tool = equippedTool()
        if not tool or not GUN_SET[tool.Name] then
                return
        end
        local props = gunProps(tool.Name)
        local ammo = tonumber(tool:GetAttribute("Local_CurrentAmmo"))
        if not ammo or ammo < 0 then
                ammo = props.MaxAmmo
                pcall(function()
                        tool:SetAttribute("Local_CurrentAmmo", ammo)
                end)
        end
        local startedAt = os.clock()
        local fired = 0
        while running and cfg.AutoKill and cfg.FarmEnabled do
                local tCharacter = target.Character
                local tHumanoid = tCharacter and tCharacter:FindFirstChildOfClass("Humanoid")
                if not tCharacter or not tHumanoid or tHumanoid.Health <= 0 then
                        if tHumanoid and tHumanoid.Health <= 0 then
                                state.kills = state.kills + 1
                                notifyT("kill", "Killed " .. target.Name)
                        end
                        break
                end
                local tTeam = target.Team
                local mine = teamName()
                if mine == "Guards" then
                        if not tTeam or tTeam.Name ~= "Criminals" then
                                break
                        end
                else
                        if not tTeam or tTeam.Name ~= "Guards" then
                                break
                        end
                end
                if os.clock() - startedAt > 14 or fired > 90 then
                        blacklist(target, 18)
                        break
                end
                local me = myCharacter()
                local myHum = me and me:FindFirstChildOfClass("Humanoid")
                if not me or not myHum or myHum.Health <= 0 then
                        return
                end
                local currentTool = me:FindFirstChildOfClass("Tool")
                if currentTool ~= tool then
                        return
                end
                if ammo <= 0 then
                        task.spawn(function()
                                pcall(function()
                                        FuncReload:InvokeServer()
                                end)
                        end)
                        task.wait(props.ReloadTime + 0.25)
                        ammo = props.MaxAmmo
                        pcall(function()
                                tool:SetAttribute("Local_CurrentAmmo", ammo)
                        end)
                end
                local head = me:FindFirstChild("Head") or me:FindFirstChild("HumanoidRootPart")
                local part = resolvePart(tCharacter, cfg.TargetPart)
                if not head or not part then
                        return
                end
                local bullets = {}
                local count = props.ProjectileCount or 1
                for _ = 1, count do
                        table.insert(bullets, { head.Position, part.Position, part })
                end
                pcall(function()
                        ShootEvent:FireServer(bullets)
                end)
                ammo = ammo - 1
                fired = fired + 1
                pcall(function()
                        tool:SetAttribute("Local_CurrentAmmo", ammo)
                end)
                task.wait(props.FireRate + 0.01 + math.random() * 0.04)
        end
end

local function auraTick()
        if state.farmBusy or not isAlive() then
                return
        end
        local root = myRoot()
        if not root then
                return
        end
        local meleeTool = findAnyTool(MELEE_SET)
        if not meleeTool then
                if not state.auraWarned then
                        state.auraWarned = true
                        notifyT("auramelee", "Kill Aura", "No melee weapon - grab a Crude Knife from Misc.", 20)
                end
                return
        end
        local humanoid = myHumanoid()
        local current = equippedTool()
        if not (current and MELEE_SET[current.Name]) then
                if humanoid then
                        pcall(function()
                                humanoid:EquipTool(meleeTool)
                        end)
                end
                return
        end
        for _, player in ipairs(getEnemies()) do
                local character, humanoid2, root2 = validTargetCharacter(player)
                if character and (root2.Position - root.Position).Magnitude <= cfg.AuraRadius then
                        pcall(function()
                                MeleeEvent:FireServer(player, nil, 1)
                        end)
                end
        end
end

-- ============================================================
-- Arrest / escape / anti-arrest / team switch
-- ============================================================

local function arrestTarget(target)
        if not isAlive() then
                return
        end
        local root = myRoot()
        local tCharacter = target.Character
        local tRoot = tCharacter and tCharacter:FindFirstChild("HumanoidRootPart")
        if not root or not tRoot then
                return
        end
        local originCF = root.CFrame
        local handcuffs = findToolNamed("Handcuffs")
        local humanoid = myHumanoid()
        if handcuffs and humanoid then
                pcall(function()
                        humanoid:EquipTool(handcuffs)
                end)
                task.wait(0.1)
        end
        setAction("Arresting " .. target.Name)
        teleport(tRoot.CFrame * CFrame.new(0, 0, 4))
        task.wait(0.15)
        local ok, result = pcall(function()
                return ArrestPlayer:InvokeServer(target, 1)
        end)
        if not ok or not result then
                teleport(tRoot.CFrame * CFrame.new(0, 0, 2))
                task.wait(0.15)
                ok, result = pcall(function()
                        return ArrestPlayer:InvokeServer(target, 1)
                end)
        end
        if ok and result then
                state.arrests = state.arrests + 1
                notifyT("arrest", "Arrested " .. target.Name)
        else
                blacklist(target, 10)
        end
        task.wait(0.35)
        teleport(originCF)
end

local function escape()
        if teamName() ~= "Inmates" then
                return true
        end
        local criminals = Teams:FindFirstChild("Criminals")
        if criminals then
                pcall(function()
                        RequestTeamChange:InvokeServer(criminals, 1)
                end)
                task.wait(0.4)
                if teamName() ~= "Inmates" then
                        state.escapes = state.escapes + 1
                        notify("Escaped", "You are now a Criminal.")
                        return true
                end
        end
        local base = criminalSpawnPos()
        if not base then
                notifyT("nobase", "Escape failed", "Could not find the criminal base on this server.", 15)
                return false
        end
        local offsets = {
                Vector3.new(0, 0, 0),
                Vector3.new(14, 0, 0),
                Vector3.new(-14, 0, 0),
                Vector3.new(0, 0, 14),
                Vector3.new(0, 0, -14),
        }
        for _, offset in ipairs(offsets) do
                if not running then
                        return false
                end
                teleport(groundCFrame(base + offset + Vector3.new(0, 6, 0)))
                for _ = 1, 8 do
                        task.wait(0.3)
                        if teamName() ~= "Inmates" then
                                state.escapes = state.escapes + 1
                                notify("Escaped", "You are now a Criminal.")
                                return true
                        end
                end
        end
        notifyT("escapefail", "Could not auto-escape", "Teleporting to the base did not flip your team - escape manually once.", 20)
        return false
end

local function antiArrestTick()
        local mine = teamName()
        if mine == "Guards" or state.arrested then
                return
        end
        local root = myRoot()
        if not root then
                return
        end
        local now = os.clock()
        if now < state.aaCooldownUntil then
                return
        end
        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team and player.Team.Name == "Guards" then
                        local character = player.Character
                        if character and character:FindFirstChild("Handcuffs") then
                                local theirRoot = character:FindFirstChild("HumanoidRootPart")
                                if theirRoot and (theirRoot.Position - root.Position).Magnitude < 14 then
                                        state.aaCooldownUntil = now + 5
                                        local base = criminalSpawnPos()
                                        if base then
                                                local offset = Vector3.new(
                                                        math.random(-60, 60),
                                                        0,
                                                        math.random(-60, 60)
                                                )
                                                teleport(groundCFrame(base + offset + Vector3.new(0, 8, 0)))
                                                notifyT("antiarrest", "Anti-Arrest", "Evaded " .. player.Name .. ".")
                                        end
                                        return
                                end
                        end
                end
        end
end

local function tryTeamSwitch(name)
        local now = os.clock()
        if now - state.lastSwitchAt < 8 then
                return
        end
        state.lastSwitchAt = now
        local team = Teams:FindFirstChild(name)
        if not team then
                return
        end
        setAction("Switching to " .. name)
        local ok = pcall(function()
                RequestTeamChange:InvokeServer(team, 1)
        end)
        if not ok then
                return
        end
        task.delay(1.5, function()
                if teamName() ~= name then
                        notifyT("switchfail", "Team switch refused", "Could not switch to " .. name .. " right now.", 12)
                        state.lastSwitchAt = os.clock() + 22
                else
                        notifyT("switchok", "Switched to " .. name)
                end
        end)
end

-- ============================================================
-- Farm brain
-- ============================================================

local function farmTick()
        if not isAlive() then
                setAction("Waiting for respawn")
                return
        end
        if state.arrested then
                setAction("Arrested - waiting for release")
                return
        end
        local mine = teamName()

        if cfg.Role == "Police" then
                if mine ~= "Guards" then
                        tryTeamSwitch("Guards")
                        return
                end
                if cfg.AutoGun and not hasGunTool() then
                        setAction("Getting " .. gunChoice())
                        getWeapon(gunChoice())
                        return
                end
                if cfg.AutoArrest then
                        local target = pickArrestTarget()
                        if target then
                                arrestTarget(target)
                                return
                        end
                end
                if cfg.AutoKill then
                        local target = pickKillTarget()
                        if target then
                                if hasGunTool() and equipBestGun() then
                                        setAction("Shooting " .. target.Name)
                                        shootAt(target)
                                        return
                                end
                                setAction("No gun - turn on Auto Gun")
                                return
                        end
                        setAction("Idle - no criminals around")
                        return
                end
                setAction("Idle")
                return
        end

        -- Prisoner / Criminal roles
        if mine == "Inmates" then
                if cfg.AutoEscape then
                        setAction("Escaping prison")
                        escape()
                        return
                end
                if cfg.AutoGun and not hasMeleeTool() then
                        setAction("Getting a Crude Knife")
                        getWeapon("Crude Knife")
                        return
                end
                setAction("In prison (Auto Escape is off)")
                return
        elseif mine == "Criminals" then
                if cfg.AutoGun and not hasGunTool() then
                        setAction("Getting " .. gunChoice())
                        getWeapon(gunChoice())
                        return
                end
                if cfg.AutoKill then
                        local target = pickKillTarget()
                        if target then
                                if hasGunTool() and equipBestGun() then
                                        setAction("Shooting " .. target.Name)
                                        shootAt(target)
                                        return
                                end
                                setAction("No gun - turn on Auto Gun")
                                return
                        end
                        setAction("Idle - no guards in range")
                        return
                end
                setAction("Idle")
                return
        elseif mine == "Guards" then
                tryTeamSwitch("Inmates")
                return
        end
        setAction("Waiting for team")
end

-- ============================================================
-- Config sanitising (after load)
-- ============================================================

local function validOption(value, options, fallback)
        for _, option in ipairs(options) do
                if option == value then
                        return value
                end
        end
        return fallback
end

cfg.Role = validOption(cfg.Role, { "Police", "Prisoner", "Criminal" }, "Police")
cfg.Weapon = validOption(cfg.Weapon, WEAPON_OPTIONS, "AK-47")
cfg.TargetPart = validOption(cfg.TargetPart, { "Head", "Torso" }, "Head")
cfg.Priority = validOption(cfg.Priority, { "Nearest", "Farthest", "Lowest HP" }, "Nearest")
cfg.FarmDelay = math.clamp(cfg.FarmDelay, 0.1, 1.5)
cfg.AuraRadius = math.clamp(cfg.AuraRadius, 4, 20)
cfg.MaxRange = math.clamp(cfg.MaxRange, 50, 600)
cfg.WalkSpeed = math.clamp(cfg.WalkSpeed, 16, 200)

-- ============================================================
-- Status + arrested tracking
-- ============================================================

local function updateStatus()
        if state.arrested then
                local humanoid = myHumanoid()
                local elapsed = os.clock() - state.arrestedAt
                if elapsed > 90 or (humanoid and humanoid.WalkSpeed > 0 and elapsed > 5) then
                        state.arrested = false
                end
        end
        local team = teamName()
        local tool = equippedTool()
        local lines = {
                "Team: " .. (team ~= "" and team or "None") .. "   |   Held: " .. (tool and tool.Name or "Nothing"),
                "Arrests: " .. state.arrests .. "   |   Kills: " .. state.kills .. "   |   Escapes: " .. state.escapes,
                (state.farmBusy and "> " or "") .. state.action,
        }
        if ui.status then
                pcall(function()
                        ui.status:Set(table.concat(lines, "\n"))
                end)
        end
end

local function applyWalkSpeed()
        local humanoid = myHumanoid()
        if humanoid and not state.arrested and cfg.WalkSpeed > 16 then
                humanoid.WalkSpeed = cfg.WalkSpeed
        end
end

-- ============================================================
-- UI
-- ============================================================

local function applyRolePreset(role)
        if role == "Police" then
                cfg.AutoArrest = true
                cfg.AutoEscape = false
        else
                cfg.AutoArrest = false
                cfg.AutoEscape = true
        end
        cfg.AutoKill = true
        cfg.AutoGun = true
        if ui.autoArrest then
                pcall(function() ui.autoArrest:Set(cfg.AutoArrest, false) end)
        end
        if ui.autoEscape then
                pcall(function() ui.autoEscape:Set(cfg.AutoEscape, false) end)
        end
        if ui.autoKill then
                pcall(function() ui.autoKill:Set(cfg.AutoKill, false) end)
        end
        if ui.autoGun then
                pcall(function() ui.autoGun:Set(cfg.AutoGun, false) end)
        end
        queueSave()
end

local FarmTab = Window:Tab("Farm", "zap")
local CombatTab = Window:Tab("Combat", "crosshair")
local MiscTab = Window:Tab("Misc", "compass")

local AutoSection = FarmTab:Section("Autofarm")

ui.role = AutoSection:Dropdown({
        Text = "Role",
        Options = { "Police", "Prisoner", "Criminal" },
        Value = cfg.Role,
        Callback = function(value)
                cfg.Role = value
                applyRolePreset(value)
                queueSave()
        end,
})

ui.enabled = AutoSection:Toggle({
        Text = "Enabled",
        Value = cfg.FarmEnabled,
        Callback = function(value)
                cfg.FarmEnabled = value
                if value then
                        notify("Autofarm running", "Role: " .. cfg.Role)
                else
                        notify("Autofarm stopped")
                end
                queueSave()
        end,
})

ui.autoEscape = AutoSection:Toggle({
        Text = "Auto Escape",
        Value = cfg.AutoEscape,
        Callback = function(value)
                cfg.AutoEscape = value
                queueSave()
        end,
})

ui.autoArrest = AutoSection:Toggle({
        Text = "Auto Arrest",
        Value = cfg.AutoArrest,
        Callback = function(value)
                cfg.AutoArrest = value
                queueSave()
        end,
})

ui.autoKill = AutoSection:Toggle({
        Text = "Auto Kill",
        Value = cfg.AutoKill,
        Callback = function(value)
                cfg.AutoKill = value
                queueSave()
        end,
})

ui.autoGun = AutoSection:Toggle({
        Text = "Auto Gun",
        Value = cfg.AutoGun,
        Callback = function(value)
                cfg.AutoGun = value
                queueSave()
        end,
})

ui.delay = AutoSection:Slider({
        Text = "Action Delay",
        Min = 0.1,
        Max = 1.5,
        Step = 0.05,
        Value = cfg.FarmDelay,
        Suffix = "s",
        Callback = function(value)
                cfg.FarmDelay = value
                queueSave()
        end,
})

local StatusSection = FarmTab:Section("Status")
ui.status = StatusSection:Paragraph({
        Text = "Team: -   |   Held: Nothing\nArrests: 0   |   Kills: 0   |   Escapes: 0\nIdle",
})

local CombatSection = CombatTab:Section("Combat")

ui.killAura = CombatSection:Toggle({
        Text = "Kill Aura",
        Value = cfg.KillAura,
        Callback = function(value)
                cfg.KillAura = value
                state.auraWarned = false
                queueSave()
        end,
})

ui.auraRadius = CombatSection:Slider({
        Text = "Aura Radius",
        Min = 4,
        Max = 20,
        Step = 1,
        Value = cfg.AuraRadius,
        Suffix = "m",
        Callback = function(value)
                cfg.AuraRadius = value
                queueSave()
        end,
})

ui.targetPart = CombatSection:Dropdown({
        Text = "Target Part",
        Options = { "Head", "Torso" },
        Value = cfg.TargetPart,
        Callback = function(value)
                cfg.TargetPart = value
                queueSave()
        end,
})

ui.priority = CombatSection:Dropdown({
        Text = "Priority",
        Options = { "Nearest", "Farthest", "Lowest HP" },
        Value = cfg.Priority,
        Callback = function(value)
                cfg.Priority = value
                queueSave()
        end,
})

ui.maxRange = CombatSection:Slider({
        Text = "Max Range",
        Min = 50,
        Max = 600,
        Step = 10,
        Value = cfg.MaxRange,
        Suffix = "m",
        Callback = function(value)
                cfg.MaxRange = value
                queueSave()
        end,
})

local DefenseSection = CombatTab:Section("Defense")

ui.antiArrest = DefenseSection:Toggle({
        Text = "Anti-Arrest",
        Value = cfg.AntiArrest,
        Callback = function(value)
                cfg.AntiArrest = value
                queueSave()
        end,
})

local WeaponSection = MiscTab:Section("Weapons")

ui.weapon = WeaponSection:Dropdown({
        Text = "Weapon",
        Options = WEAPON_OPTIONS,
        Value = cfg.Weapon,
        Callback = function(value)
                cfg.Weapon = value
                queueSave()
        end,
})

local weaponRow = WeaponSection:Row()

weaponRow:Button({
        Text = "Get Weapon",
        Callback = function()
                task.spawn(function()
                        setAction("Getting " .. cfg.Weapon)
                        pcall(function()
                                getWeapon(cfg.Weapon)
                        end)
                end)
        end,
})

weaponRow:Button({
        Text = "Reload",
        Callback = function()
                task.spawn(function()
                        local tool = equippedTool()
                        pcall(function()
                                FuncReload:InvokeServer()
                        end)
                        if tool and GUN_SET[tool.Name] then
                                local props = gunProps(tool.Name)
                                task.wait(props.ReloadTime + 0.2)
                                pcall(function()
                                        tool:SetAttribute("Local_CurrentAmmo", props.MaxAmmo)
                                end)
                        end
                end)
        end,
})

local TeleportSection = MiscTab:Section("Teleport")

local function teleportTo(pos, hover)
        if pos and isAlive() then
                if hover then
                        teleport(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
                else
                        teleport(groundCFrame(pos + Vector3.new(0, 6, 0)))
                end
        end
end

local function gunRoomPos()
        local items = workspace:FindFirstChild("Prison_ITEMS")
        local folder = items and items:FindFirstChild("giver")
        if folder then
                local best, bestDist = nil, math.huge
                local myPos = rootPos()
                for _, model in ipairs(folder:GetChildren()) do
                        local pos = modelPos(model)
                        if pos and myPos then
                                local dist = (pos - myPos).Magnitude
                                if dist < bestDist then
                                        best, bestDist = pos, dist
                                end
                        end
                end
                if best then
                        return best
                end
                if #folder:GetChildren() > 0 then
                        return modelPos(folder:GetChildren()[1])
                end
        end
        return nil
end

local function yardPos()
        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Crude Knife" then
                        local pos = modelPos(model)
                        if pos then
                                return pos
                        end
                end
        end
        return nil
end

local tpRow = TeleportSection:Row()

tpRow:Button({
        Text = "Criminal Base",
        Callback = function()
                teleportTo(criminalSpawnPos(), false)
        end,
})

tpRow:Button({
        Text = "Gun Room",
        Callback = function()
                teleportTo(gunRoomPos(), false)
        end,
})

tpRow:Button({
        Text = "Yard",
        Callback = function()
                teleportTo(yardPos(), false)
        end,
})

local TeamSection = MiscTab:Section("Team")

local teamRow = TeamSection:Row()

teamRow:Button({
        Text = "Guards",
        Callback = function()
                state.lastSwitchAt = 0
                tryTeamSwitch("Guards")
        end,
})

teamRow:Button({
        Text = "Inmates",
        Callback = function()
                state.lastSwitchAt = 0
                tryTeamSwitch("Inmates")
        end,
})

teamRow:Button({
        Text = "Escape",
        Callback = function()
                task.spawn(function()
                        setAction("Escaping prison")
                        pcall(escape)
                end)
        end,
})

local MovementSection = MiscTab:Section("Movement")

ui.walkSpeed = MovementSection:Slider({
        Text = "Walk Speed",
        Min = 16,
        Max = 200,
        Step = 1,
        Value = cfg.WalkSpeed,
        Callback = function(value)
                cfg.WalkSpeed = value
                applyWalkSpeed()
                queueSave()
        end,
})

ui.infJump = MovementSection:Toggle({
        Text = "Infinite Jump",
        Value = cfg.InfJump,
        Callback = function(value)
                cfg.InfJump = value
                queueSave()
        end,
})

-- ============================================================
-- Events + loops
-- ============================================================

pcall(function()
        track(ClientArrested.OnClientEvent:Connect(function()
                state.arrested = true
                state.arrestedAt = os.clock()
                notify("Arrested", "Autofarm paused while you serve time.")
        end))
end)

pcall(function()
        track(LocalPlayer:GetAttributeChangedSignal("BackpackEnabled"):Connect(function()
                if LocalPlayer:GetAttribute("BackpackEnabled") == true then
                        state.arrested = false
                end
        end))
end)

track(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.6)
        applyWalkSpeed()
end))

track(UserInputService.JumpRequest:Connect(function()
        if cfg.InfJump and not state.arrested then
                local humanoid = myHumanoid()
                if humanoid then
                        humanoid.Jump = true
                end
        end
end))

task.spawn(function()
        while running do
                task.wait(0.4)
                if running then
                        pcall(updateStatus)
                end
        end
end)

task.spawn(function()
        while running do
                task.wait(0.35)
                if running and cfg.KillAura and not state.arrested then
                        pcall(auraTick)
                end
        end
end)

task.spawn(function()
        while running do
                task.wait(0.3)
                if running and cfg.AntiArrest then
                        pcall(antiArrestTick)
                end
        end
end)

task.spawn(function()
        while running do
                local base = math.max(0.1, cfg.FarmDelay)
                task.wait(base * (0.85 + math.random() * 0.3))
                if not running then
                        break
                end
                if cfg.FarmEnabled and not state.farmBusy then
                        state.farmBusy = true
                        pcall(farmTick)
                        state.farmBusy = false
                end
        end
end)

-- ============================================================
-- Cleanup
-- ============================================================

local function cleanup()
        running = false
        disconnectAll()
        pcall(function()
                Window:Destroy()
        end)
        Global.__PrisonLifeCleanup = nil
end

Global.__PrisonLifeCleanup = cleanup

notify("Prison Life loaded", "Pick a role in the Farm tab and hit Enabled.")
