local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PLACE_ID = 155615604
local GIVER_WAIT = 4
local DETONATE_DELAY = 0.55
local EXPLODED_WAIT = 3
local RETREAT_DISTANCE = 60
local DOOR_DELAY = 0.35
local C4_TOOL_NAME = "C4 Explosive"

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__PrisonLifeCleanup) == "function" then
        pcall(Global.__PrisonLifeCleanup)
end

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

local Window = Reborn:CreateWindow({
        Title = "Prison Life",
        Size = Vector2.new(500, 360),
})

local function registerEarlyExit()
        Global.__PrisonLifeCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__PrisonLifeCleanup = nil
        end
end

if game.PlaceId ~= PLACE_ID then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Prison Life")
        section:Paragraph({Text = "Wrong game."})
        registerEarlyExit()
        return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local GiverPressed = Remotes and Remotes:WaitForChild("GiverPressed", 5)
local C4Folder = Remotes and Remotes:WaitForChild("C4", 5)
local ActivateC4 = C4Folder and C4Folder:WaitForChild("ActivateC4", 5)
local PrisonItems = workspace:WaitForChild("Prison_ITEMS", 10)
local GiverFolder = PrisonItems and PrisonItems:FindFirstChild("giver")
local C4Giver = GiverFolder and GiverFolder:FindFirstChild(C4_TOOL_NAME)

if not (GiverPressed and GiverPressed:IsA("RemoteEvent"))
        or not (ActivateC4 and ActivateC4:IsA("RemoteFunction"))
        or not (C4Giver and C4Giver:IsA("Model")) then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Prison Life")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local running = false
local statusToken = 0
local lastResult = "Idle"
local stats = {blown = 0, failed = 0}

local function getRoot()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then
                return character, humanoid, root
        end
        return nil
end

local function waitCharacter(timeout)
        local deadline = os.clock() + timeout
        while os.clock() < deadline do
                local character, humanoid, root = getRoot()
                if character then
                        return character, humanoid, root
                end
                task.wait(0.1)
        end
        return nil
end

local function findC4()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
                local tool = backpack:FindFirstChild(C4_TOOL_NAME)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        local character = LocalPlayer.Character
        if character then
                local tool = character:FindFirstChild(C4_TOOL_NAME)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        return nil
end

local function requestC4()
        local tool = findC4()
        if tool then
                return tool
        end

        local character, humanoid, root = waitCharacter(6)
        if not character then
                return nil
        end

        root.CFrame = CFrame.new(C4Giver:GetPivot().Position + Vector3.new(0, 4, 0))
        task.wait(0.2)
        GiverPressed:FireServer(C4Giver)

        local deadline = os.clock() + GIVER_WAIT
        while os.clock() < deadline do
                tool = findC4()
                if tool then
                        return tool
                end
                task.wait(0.1)
        end
        return nil
end

local function isTargetDoor(door)
        return door:FindFirstChild("block") ~= nil
                and door:FindFirstChild("scn") ~= nil
end

local function getDoors()
        local list = {}
        local _, _, root = getRoot()
        local origin = root and root.Position or Vector3.zero
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
                if isTargetDoor(door) and not door:GetAttribute("Exploded") then
                        local block = door:FindFirstChild("block")
                        local distance = (block:GetPivot().Position - origin).Magnitude
                        table.insert(list, {door = door, block = block, distance = distance})
                end
        end
        table.sort(list, function(a, b)
                return a.distance < b.distance
        end)
        return list
end

local function countBlown()
        local total = 0
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
                if isTargetDoor(door) and door:GetAttribute("Exploded") then
                        total = total + 1
                end
        end
        return total
end

local function approachDirection(pivot, rootPos)
        local flat = (rootPos - pivot) * Vector3.new(1, 0, 1)
        if flat.Magnitude < 0.5 then
                return Vector3.xAxis
        end
        return flat.Unit
end

local function destroyDoor(entry)
        local character, humanoid, root = waitCharacter(6)
        if not character then
                lastResult = "No character"
                return false
        end

        local tool = requestC4()
        if not tool then
                lastResult = "C4 giver refused"
                return false
        end

        character, humanoid, root = getRoot()
        if not character then
                lastResult = "No character"
                return false
        end

        if tool.Parent ~= character then
                pcall(function()
                        humanoid:EquipTool(tool)
                end)
                task.wait(0.15)
        end

        tool:SetAttribute("Local_Mode", "Placement")

        local pivot = entry.block:GetPivot().Position
        local approach = approachDirection(pivot, root.Position)
        root.CFrame = CFrame.lookAt(
                pivot + Vector3.new(0, 2, 0) + approach * 5,
                pivot + Vector3.new(0, 2, 0)
        )
        task.wait(0.2)

        tool:SetAttribute("Local_PlacedAt", os.clock())
        tool:SetAttribute("Local_Mode", "Detonate")

        local placed = false
        pcall(function()
                placed = ActivateC4:InvokeServer(root.Position, pivot) and true or false
        end)

        if not placed then
                lastResult = "Placement rejected"
                return false
        end

        root.CFrame = CFrame.new(pivot + approach * RETREAT_DISTANCE + Vector3.new(0, 10, 0))
        task.wait(DETONATE_DELAY)

        pcall(function()
                ActivateC4:InvokeServer()
        end)

        local deadline = os.clock() + EXPLODED_WAIT
        while os.clock() < deadline and running do
                if entry.door:GetAttribute("Exploded") then
                        return true
                end
                task.wait(0.1)
        end

        if entry.door:GetAttribute("Exploded") then
                return true
        end

        lastResult = "No detonation"
        return false
end

local function destroyAll()
        if running then
                return
        end
        running = true
        lastResult = "Running"

        local doors = getDoors()
        local total = #doors
        local index = 1
        local giverRefuses = 0

        while index <= total and running do
                local entry = doors[index]
                index = index + 1

                if entry.door.Parent and isTargetDoor(entry.door) and not entry.door:GetAttribute("Exploded") then
                        if not waitCharacter(8) then
                                lastResult = "No character"
                                break
                        end

                        local blown = destroyDoor(entry)
                        if blown then
                                stats.blown = stats.blown + 1
                                giverRefuses = 0
                                lastResult = "Door destroyed"
                        elseif lastResult == "C4 giver refused" then
                                stats.failed = stats.failed + 1
                                giverRefuses = giverRefuses + 1
                                if giverRefuses >= 2 then
                                        break
                                end
                        else
                                stats.failed = stats.failed + 1
                                giverRefuses = 0
                        end

                        task.wait(DOOR_DELAY)
                end
        end

        running = false
        lastResult = "Done"
        Window:Notify({
                Title = "Prison Life",
                Description = string.format(
                        "Blown %d · Failed %d · Left %d",
                        countBlown(),
                        stats.failed,
                        #getDoors()
                ),
                Duration = 8,
        })
end

local tab = Window:Tab("Main", "zap")

local c4Section = tab:Section("C4")
c4Section:Button({
        Text = "Get C4",
        Primary = true,
        Callback = function()
                task.spawn(function()
                        if requestC4() then
                                lastResult = "C4 ready"
                                Window:Notify({
                                        Title = "Prison Life",
                                        Description = "C4 ready.",
                                        Duration = 5,
                                })
                        else
                                lastResult = "C4 giver refused"
                                Window:Notify({
                                        Title = "Prison Life",
                                        Description = "C4 giver refused.",
                                        Duration = 5,
                                })
                        end
                end)
        end,
})

local doorsSection = tab:Section("Doors")
doorsSection:Button({
        Text = "Destroy All Doors",
        Primary = true,
        Callback = function()
                task.spawn(destroyAll)
        end,
})
doorsSection:Button({
        Text = "Stop",
        Callback = function()
                running = false
        end,
})

local statusSection = tab:Section("Status")
local statusLabel = statusSection:Paragraph({Text = "Team None · Left 0 · Blown 0 · Failed 0 · Idle"})

statusSection:Button({
        Text = "Unload",
        Callback = function()
                if type(Global.__PrisonLifeCleanup) == "function" then
                        pcall(Global.__PrisonLifeCleanup)
                end
        end,
})

local function refreshStatus()
        local team = LocalPlayer.Team and LocalPlayer.Team.Name or "None"
        statusLabel:Set(string.format(
                "Team %s · Left %d · Blown %d · Failed %d · %s",
                team,
                #getDoors(),
                countBlown(),
                stats.failed,
                lastResult
        ))
end

Global.__PrisonLifeCleanup = function()
        statusToken = statusToken + 1
        running = false
        pcall(function()
                Window:Destroy()
        end)
        Global.__PrisonLifeCleanup = nil
end

statusToken = statusToken + 1
local token = statusToken
task.spawn(function()
        while token == statusToken do
                local ok = pcall(refreshStatus)
                if not ok then
                        break
                end
                task.wait(1)
        end
end)

refreshStatus()
