local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__GameIntelCleanup) == "function" then
        pcall(Global.__GameIntelCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[GameIntel] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local running = true
local connections = {}

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnect(connection)
        if connection then
                pcall(function()
                        connection:Disconnect()
                end)
        end
end

local function sanitizeName(name, maxLen)
        local cleaned = tostring(name or ""):gsub("[^%w%-_]+", "_")
        cleaned = cleaned:gsub("^_+", "")
        cleaned = cleaned:gsub("_+$", "")

        if #cleaned == 0 then
                cleaned = "unnamed"
        end

        return cleaned:sub(1, maxLen or 60)
end

local function jsonEscape(text)
        local value = tostring(text)
        value = value:gsub("\\", "\\\\")
        value = value:gsub('"', '\\"')
        value = value:gsub("\n", "\\n")
        value = value:gsub("\r", "\\r")
        value = value:gsub("\t", "\\t")
        return value
end

local function jsonEncode(value, depth)
        local kind = type(value)

        if kind == "string" then
                return '"' .. jsonEscape(value) .. '"'
        elseif kind == "number" then
                if value ~= value or value == math.huge or value == -math.huge then
                        return '"' .. tostring(value) .. '"'
                end

                return string.format("%.14g", value)
        elseif kind == "boolean" then
                return value and "true" or "false"
        elseif kind ~= "table" then
                return "null"
        end

        local pad = string.rep("  ", depth)
        local innerPad = string.rep("  ", depth + 1)
        local count = #value

        if count > 0 then
                local items = {}

                for i = 1, count do
                        items[i] = innerPad .. jsonEncode(value[i], depth + 1)
                end

                return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
        end

        local fields = {}

        for key, item in pairs(value) do
                fields[#fields + 1] = innerPad
                        .. '"'
                        .. jsonEscape(key)
                        .. '": '
                        .. jsonEncode(item, depth + 1)
        end

        if #fields == 0 then
                return "{}"
        end

        return "{\n" .. table.concat(fields, ",\n") .. "\n" .. pad .. "}"
end

local function topEntries(countTable, limit)
        local list = {}

        for name, count in pairs(countTable) do
                list[#list + 1] = { name = name, count = count }
        end

        table.sort(list, function(a, b)
                if a.count == b.count then
                        return a.name < b.name
                end

                return a.count > b.count
        end)

        local result = {}

        for i = 1, math.min(limit, #list) do
                result[i] = { name = list[i].name, count = list[i].count }
        end

        return result
end

local statusLabel = nil

local function setStatus(text)
        if statusLabel then
                pcall(function()
                        statusLabel:Set(tostring(text))
                end)
        end
end

local ASSET_PROPS = {
        Sound = { "SoundId" },
        Animation = { "AnimationId" },
        MeshPart = { "MeshId", "TextureID" },
        SpecialMesh = { "MeshId", "TextureId" },
        Decal = { "Texture" },
        Texture = { "Texture" },
        Shirt = { "ShirtTemplate" },
        Pants = { "PantsTemplate" },
        ParticleEmitter = { "Texture" },
        Beam = { "Texture" },
        Trail = { "Texture" },
        Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
}

local REMOTE_CLASSES = {
        RemoteEvent = true,
        UnreliableRemoteEvent = true,
        RemoteFunction = true,
        BindableEvent = true,
        BindableFunction = true
}

local extracting = false
local cancelRequested = false
local lastFolderPath = nil

local function runExtract()
        if extracting then
                setStatus("Already extracting - watch this line for progress")
                return
        end

        if type(writefile) ~= "function"
                or type(makefolder) ~= "function"
                or type(isfolder) ~= "function" then
                setStatus("This executor cannot write files (writefile/makefolder missing) - extraction needs file access")
                return
        end

        cancelRequested = false

        extracting = true

        task.spawn(function()
                local ok, err = pcall(function()
                        local function abortNow()
                                return (not running) or cancelRequested
                        end

                        setStatus("Resolving game info...")

                        local placeName = game.Name
                        local infoOk, info = pcall(function()
                                return MarketplaceService:GetProductInfo(game.PlaceId)
                        end)

                        if infoOk and type(info) == "table" and type(info.Name) == "string" then
                                placeName = info.Name
                        end

                        local root = "GameIntel/" .. tostring(game.PlaceId) .. "_" .. sanitizeName(placeName, 40)
                        local scriptsDir = root .. "/scripts"

                        if not isfolder("GameIntel") then
                                makefolder("GameIntel")
                        end

                        if not isfolder(root) then
                                makefolder(root)
                        end

                        if not isfolder(scriptsDir) then
                                makefolder(scriptsDir)
                        end

                        lastFolderPath = root

                        local function writeFile(path, content)
                                local writeOk, writeErr = pcall(writefile, path, content)

                                if not writeOk then
                                        error("write failed: " .. path .. " - " .. tostring(writeErr))
                                end
                        end

                        setStatus("Walking instance tree...")

                        local descendants = game:GetDescendants()
                        local total = #descendants

                        local treeLines = {}
                        local remotesLines = {}
                        local assetsLines = {}
                        local scriptEntries = {}

                        local classCounts = {}
                        local materialCounts = {}
                        local partCount = 0
                        local anchoredCount = 0
                        local collideOffCount = 0
                        local serverScriptCount = 0
                        local boundsMin = nil
                        local boundsMax = nil

                        for i, instance in ipairs(descendants) do
                                local className = instance.ClassName

                                classCounts[className] = (classCounts[className] or 0) + 1
                                treeLines[#treeLines + 1] = className .. "  " .. instance:GetFullName()

                                local assetProps = ASSET_PROPS[className]

                                if assetProps then
                                        for _, propName in ipairs(assetProps) do
                                                local readOk, value = pcall(function()
                                                        return instance[propName]
                                                end)

                                                if readOk
                                                        and type(value) == "string"
                                                        and #value > 0
                                                        and value ~= "rbxasset://" then
                                                        assetsLines[#assetsLines + 1] = className
                                                                .. "."
                                                                .. propName
                                                                .. "  "
                                                                .. value
                                                                .. "  "
                                                                .. instance:GetFullName()
                                                end
                                        end
                                end

                                if REMOTE_CLASSES[className] then
                                        remotesLines[#remotesLines + 1] = className .. "  " .. instance:GetFullName()
                                end

                                if className == "LocalScript" or className == "ModuleScript" then
                                        scriptEntries[#scriptEntries + 1] = {
                                                instance = instance,
                                                className = className,
                                                name = instance.Name,
                                                path = instance:GetFullName()
                                        }
                                elseif className == "Script" then
                                        local contextOk, runContext = pcall(function()
                                                return instance.RunContext
                                        end)

                                        if contextOk and runContext == Enum.RunContext.Client then
                                                scriptEntries[#scriptEntries + 1] = {
                                                        instance = instance,
                                                        className = className,
                                                        name = instance.Name,
                                                        path = instance:GetFullName()
                                                }
                                        else
                                                serverScriptCount = serverScriptCount + 1
                                        end
                                end

                                if instance:IsA("BasePart") then
                                        partCount = partCount + 1

                                        if instance.Anchored then
                                                anchoredCount = anchoredCount + 1
                                        end

                                        if not instance.CanCollide then
                                                collideOffCount = collideOffCount + 1
                                        end

                                        local materialName = tostring(instance.Material):gsub("^Enum%.Material%.", "")
                                        materialCounts[materialName] = (materialCounts[materialName] or 0) + 1

                                        if instance:IsDescendantOf(Workspace) then
                                                local position = instance.Position

                                                if boundsMin then
                                                        boundsMin = Vector3.new(
                                                                math.min(boundsMin.X, position.X),
                                                                math.min(boundsMin.Y, position.Y),
                                                                math.min(boundsMin.Z, position.Z)
                                                        )
                                                        boundsMax = Vector3.new(
                                                                math.max(boundsMax.X, position.X),
                                                                math.max(boundsMax.Y, position.Y),
                                                                math.max(boundsMax.Z, position.Z)
                                                        )
                                                else
                                                        boundsMin = position
                                                        boundsMax = position
                                                end
                                        end
                                end

                                if i % 2000 == 0 then
                                        setStatus("Walking tree... " .. i .. " / " .. total .. " instances")
                                        task.wait()

                                        if abortNow() then
                                                return
                                        end
                                end
                        end

                        if abortNow() then
                                return
                        end

                        local generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
                        local header = "Game: "
                                .. placeName
                                .. " ("
                                .. tostring(game.PlaceId)
                                .. ")\nGenerated: "
                                .. generatedAt
                                .. "\n\n"

                        setStatus("Writing tree (" .. #treeLines .. " lines)...")

                        if #treeLines > 0 then
                                writeFile(root .. "/tree.txt", header .. table.concat(treeLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/tree.txt", header .. "no instances found\n")
                        end

                        setStatus("Writing remotes (" .. #remotesLines .. ")...")

                        if #remotesLines > 0 then
                                writeFile(root .. "/remotes.txt", header .. table.concat(remotesLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/remotes.txt", header .. "no remote events or functions visible to the client\n")
                        end

                        setStatus("Writing assets (" .. #assetsLines .. ")...")

                        if #assetsLines > 0 then
                                writeFile(root .. "/assets.txt", header .. table.concat(assetsLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/assets.txt", header .. "no asset ids found\n")
                        end

                        local decompiledCount = 0
                        local failedCount = 0
                        local manifestLines = {
                                "Game: " .. placeName .. " (" .. tostring(game.PlaceId) .. ")",
                                "Generated: " .. generatedAt,
                                ""
                        }

                        if #scriptEntries == 0 then
                                manifestLines[#manifestLines + 1] = "no client-visible scripts found in this game"
                        elseif type(decompile) ~= "function" then
                                manifestLines[#manifestLines + 1] = "executor has no decompile() - "
                                        .. #scriptEntries
                                        .. " scripts skipped"
                        else
                                for i, entry in ipairs(scriptEntries) do
                                        setStatus("Decompiling " .. i .. " / " .. #scriptEntries .. ": " .. entry.name)
                                        task.wait()

                                        if abortNow() then
                                                return
                                        end

                                        local decompileOk, source = pcall(decompile, entry.instance)

                                        if decompileOk and type(source) == "string" and #source > 0 then
                                                local fileName = string.format("%03d_%s.lua", i, sanitizeName(entry.name, 50))
                                                local writeOk, writeErr = pcall(writefile, scriptsDir .. "/" .. fileName, source)

                                                if writeOk then
                                                        decompiledCount = decompiledCount + 1
                                                        manifestLines[#manifestLines + 1] = "OK        "
                                                                .. fileName
                                                                .. "  <-  "
                                                                .. entry.className
                                                                .. "  "
                                                                .. entry.path
                                                else
                                                        failedCount = failedCount + 1
                                                        manifestLines[#manifestLines + 1] = "WRITEFAIL  "
                                                                .. entry.className
                                                                .. "  "
                                                                .. entry.path
                                                                .. "  - "
                                                                .. tostring(writeErr)
                                                end
                                        else
                                                failedCount = failedCount + 1

                                                local reason = decompileOk and "empty result" or tostring(source):sub(1, 80)

                                                manifestLines[#manifestLines + 1] = "FAIL      "
                                                        .. entry.className
                                                        .. "  "
                                                        .. entry.path
                                                        .. "  - "
                                                        .. reason
                                        end
                                end
                        end

                        manifestLines[#manifestLines + 1] = ""
                        manifestLines[#manifestLines + 1] = "decompiled: "
                                .. decompiledCount
                                .. " / "
                                .. #scriptEntries
                                .. ", failed: "
                                .. failedCount

                        writeFile(scriptsDir .. "/manifest.txt", table.concat(manifestLines, "\n") .. "\n")

                        if abortNow() then
                                return
                        end

                        setStatus("Writing overview.json...")

                        local lightingInfo = {}
                        pcall(function()
                                lightingInfo = {
                                        clockTime = Lighting.ClockTime,
                                        brightness = Lighting.Brightness,
                                        globalShadows = Lighting.GlobalShadows,
                                        fogEnd = Lighting.FogEnd,
                                        ambient = tostring(Lighting.Ambient)
                                }
                        end)

                        local bounds = nil

                        if boundsMin and boundsMax then
                                local size = boundsMax - boundsMin
                                bounds = {
                                        min = { boundsMin.X, boundsMin.Y, boundsMin.Z },
                                        max = { boundsMax.X, boundsMax.Y, boundsMax.Z },
                                        sizeStuds = {
                                                math.floor(size.X + 0.5),
                                                math.floor(size.Y + 0.5),
                                                math.floor(size.Z + 0.5)
                                        }
                                }
                        end

                        local creatorName = nil

                        if infoOk and type(info) == "table" and type(info.Creator) == "table" then
                                creatorName = info.Creator.Name
                        end

                        local overview = {
                                generatedAt = generatedAt,
                                game = {
                                        name = placeName,
                                        placeId = game.PlaceId,
                                        jobId = game.JobId,
                                        creatorId = game.CreatorId,
                                        creatorType = tostring(game.CreatorType),
                                        creatorName = creatorName,
                                        playerCount = #Players:GetPlayers(),
                                        maxPlayers = Players.MaxPlayers,
                                        privateServerId = game.PrivateServerId ~= "" and game.PrivateServerId or nil
                                },
                                workspace = {
                                        streamingEnabled = Workspace.StreamingEnabled,
                                        partCount = partCount,
                                        anchoredCount = anchoredCount,
                                        unanchoredCount = partCount - anchoredCount,
                                        collideOffCount = collideOffCount,
                                        hasTerrain = Workspace:FindFirstChildOfClass("Terrain") ~= nil,
                                        bounds = bounds,
                                        lighting = lightingInfo
                                },
                                instances = {
                                        total = total,
                                        topClasses = topEntries(classCounts, 25),
                                        topMaterials = topEntries(materialCounts, 15)
                                },
                                extraction = {
                                        remotesFound = #remotesLines,
                                        assetIdsFound = #assetsLines,
                                        clientScripts = #scriptEntries,
                                        scriptsDecompiled = decompiledCount,
                                        scriptsFailed = failedCount,
                                        decompilerAvailable = type(decompile) == "function",
                                        serverScriptsVisibleButNotReadable = serverScriptCount
                                }
                        }

                        writeFile(root .. "/overview.json", jsonEncode(overview, 0) .. "\n")

                        setStatus("Done: "
                                .. total
                                .. " instances, "
                                .. partCount
                                .. " parts, "
                                .. decompiledCount
                                .. "/"
                                .. #scriptEntries
                                .. " scripts, "
                                .. #remotesLines
                                .. " remotes, "
                                .. #assetsLines
                                .. " assets -> "
                                .. root
                                .. "/ (Copy Folder Path copies this)")
                end)

                local wasCancelled = cancelRequested

                extracting = false
                cancelRequested = false

                if not ok then
                        setStatus("Extract failed: " .. tostring(err):sub(1, 140))
                elseif wasCancelled then
                        if lastFolderPath then
                                setStatus("Cancelled - partial files kept in " .. lastFolderPath .. "/ (in your executor's workspace folder)")
                        else
                                setStatus("Cancelled - nothing was written")
                        end
                end
        end)
end

local Window = Reborn:CreateWindow({
        Title = "GameIntel",
        Size = Vector2.new(520, 320)
})

local ExtractTab = Window:Tab("Extract", "search")
local ExtractSection = ExtractTab:Section("Game Extract")

statusLabel = ExtractSection:Paragraph({
        Text = "Idle. One click dumps everything this game shows your client into a folder in your executor's workspace directory."
})

ExtractSection:Button({
        Text = "Extract Game Intel",
        Primary = true,
        Callback = function()
                runExtract()
        end
})

ExtractSection:Button({
        Text = "Cancel",
        Callback = function()
                if not extracting then
                        setStatus("Nothing is being extracted right now.")
                        return
                end

                if cancelRequested then
                        setStatus("Already cancelling - stopping after the current batch...")
                        return
                end

                cancelRequested = true
                setStatus("Cancelling - stopping after the current batch...")
        end
})

ExtractSection:Button({
        Text = "Copy Folder Path",
        Callback = function()
                if extracting then
                        setStatus("Still extracting - the folder path will be copyable when it finishes.")
                        return
                end

                if not lastFolderPath then
                        setStatus("Nothing to copy yet - press Extract first.")
                        return
                end

                local clip = nil

                if type(setclipboard) == "function" then
                        clip = setclipboard
                elseif type(toclipboard) == "function" then
                        clip = toclipboard
                elseif type(set_clipboard) == "function" then
                        clip = set_clipboard
                end

                if not clip then
                        setStatus("This executor has no clipboard function - folder: " .. lastFolderPath)
                        return
                end

                local copyOk = pcall(clip, lastFolderPath)

                if copyOk then
                        setStatus("Copied: " .. lastFolderPath .. " (relative to your executor's workspace folder)")
                else
                        setStatus("Clipboard copy failed - folder: " .. lastFolderPath)
                end
        end
})

ExtractSection:Paragraph({
        Text = "Writes overview.json (game + map census), tree.txt (every instance), remotes.txt (Remote/Bindable events), assets.txt (sound/mesh/animation ids) and scripts/ (decompiled LocalScripts + ModuleScripts with a manifest)."
})

local function cleanup()
        if not running then
                return
        end

        running = false

        for _, connection in ipairs(connections) do
                disconnect(connection)
        end

        table.clear(connections)
end

Global.__GameIntelCleanup = cleanup

track(Window.Gui.Destroying:Connect(cleanup))
