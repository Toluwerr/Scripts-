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

local workspaceBase = nil

do
        local candidates = {
                "getworkspacepath",
                "getworkspacefolder",
                "getworkspacedirectory",
                "getexecutorpath",
                "getexecutordirectory",
                "getexecutorfolder"
        }

        for _, candidateName in ipairs(candidates) do
                local candidate = rawget(Global, candidateName) or rawget(_G, candidateName)

                if type(candidate) == "function" then
                        local ok, result = pcall(candidate)

                        if ok and type(result) == "string" then
                                result = result:gsub("[/\\]+$", "")

                                if #result > 0 then
                                        if result:lower():find("%.exe$") then
                                                result = result:gsub("[^/\\]+$", ""):gsub("[/\\]+$", "")
                                                local sep = result:find("\\", 1, true) and "\\" or "/"
                                                result = result .. sep .. "workspace"
                                        end

                                        workspaceBase = result
                                        break
                                end
                        end
                end
        end
end

local function toFullPath(relativePath)
        if not workspaceBase or not relativePath then
                return tostring(relativePath or "")
        end

        local sep = workspaceBase:find("\\", 1, true) and "\\" or "/"
        return workspaceBase .. sep .. (tostring(relativePath):gsub("/", sep))
end

local CRC_TABLE = nil

local function buildCrcTable()
        if CRC_TABLE then
                return CRC_TABLE
        end

        CRC_TABLE = {}

        for i = 0, 255 do
                local c = i

                for _ = 1, 8 do
                        if c % 2 == 1 then
                                c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1))
                        else
                                c = bit32.rshift(c, 1)
                        end
                end

                CRC_TABLE[i] = c
        end

        return CRC_TABLE
end

local function crc32Of(data)
        local crcTable = buildCrcTable()
        local crc = 0xFFFFFFFF

        for i = 1, #data do
                crc = bit32.bxor(crcTable[bit32.band(bit32.bxor(crc, string.byte(data, i)), 0xFF)], bit32.rshift(crc, 8))
        end

        return bit32.bxor(crc, 0xFFFFFFFF)
end

local function packU16(value)
        return string.char(bit32.band(value, 0xFF), bit32.band(bit32.rshift(value, 8), 0xFF))
end

local function packU32(value)
        return string.char(
                bit32.band(value, 0xFF),
                bit32.band(bit32.rshift(value, 8), 0xFF),
                bit32.band(bit32.rshift(value, 16), 0xFF),
                bit32.band(bit32.rshift(value, 24), 0xFF)
        )
end

local SIG_LOCAL = "PK" .. string.char(3, 4)
local SIG_CENTRAL = "PK" .. string.char(1, 2)
local SIG_EOCD = "PK" .. string.char(5, 6)

local function buildZip(entries)
        buildCrcTable()

        local timeInfo = os.date("*t")
        local dosTime = bit32.bor(
                bit32.lshift(timeInfo.hour % 32, 11),
                bit32.bor(bit32.lshift(timeInfo.min, 5), math.floor(timeInfo.sec / 2))
        )
        local dosDate = bit32.bor(
                bit32.lshift((timeInfo.year - 1980) % 128, 9),
                bit32.bor(bit32.lshift(timeInfo.month, 5), timeInfo.day)
        )

        local localParts = {}
        local centralParts = {}
        local offset = 0

        for _, entry in ipairs(entries) do
                local name = entry.path
                local data = entry.content
                local crc = crc32Of(data)

                local header = SIG_LOCAL
                        .. packU16(20)
                        .. packU16(0)
                        .. packU16(0)
                        .. packU16(dosTime)
                        .. packU16(dosDate)
                        .. packU32(crc)
                        .. packU32(#data)
                        .. packU32(#data)
                        .. packU16(#name)
                        .. packU16(0)
                        .. name

                localParts[#localParts + 1] = header
                localParts[#localParts + 1] = data

                centralParts[#centralParts + 1] = SIG_CENTRAL
                        .. packU16(20)
                        .. packU16(20)
                        .. packU16(0)
                        .. packU16(0)
                        .. packU16(dosTime)
                        .. packU16(dosDate)
                        .. packU32(crc)
                        .. packU32(#data)
                        .. packU32(#data)
                        .. packU16(#name)
                        .. packU16(0)
                        .. packU16(0)
                        .. packU16(0)
                        .. packU16(0)
                        .. packU32(0)
                        .. packU32(offset)
                        .. name

                offset = offset + #header + #data
        end

        local centralData = table.concat(centralParts)

        return table.concat(localParts)
                .. centralData
                .. SIG_EOCD
                .. packU16(0)
                .. packU16(0)
                .. packU16(#entries)
                .. packU16(#entries)
                .. packU32(#centralData)
                .. packU32(offset)
                .. packU16(0)
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
local outputAsZip = false
local lastOutputPath = nil

local function runExtract()
        if extracting then
                setStatus("Already extracting")
                return
        end

        if type(writefile) ~= "function" then
                setStatus("This executor cannot write files")
                return
        end

        if not outputAsZip
                and (type(makefolder) ~= "function" or type(isfolder) ~= "function") then
                setStatus("This executor cannot create folders - turn on Output as ZIP")
                return
        end

        local asZip = outputAsZip

        cancelRequested = false

        extracting = true

        task.spawn(function()
                local zipEntries = {}
                local zipPath = nil

                local function writeZipNow()
                        local zipData = buildZip(zipEntries)
                        local zipOk, zipErr = pcall(writefile, zipPath, zipData)

                        if not zipOk then
                                error("zip write failed: " .. tostring(zipErr))
                        end

                        lastOutputPath = zipPath
                end

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

                        if asZip then
                                zipPath = "GameIntel_"
                                        .. tostring(game.PlaceId)
                                        .. "_"
                                        .. sanitizeName(placeName, 40)
                                        .. ".zip"
                        else
                                if not isfolder("GameIntel") then
                                        makefolder("GameIntel")
                                end

                                if not isfolder(root) then
                                        makefolder(root)
                                end

                                if not isfolder(scriptsDir) then
                                        makefolder(scriptsDir)
                                end

                                lastOutputPath = root
                        end

                        local function writeFile(path, content)
                                if asZip then
                                        zipEntries[#zipEntries + 1] = { path = path, content = content }
                                        return
                                end

                                local writeOk, writeErr = pcall(writefile, path, content)

                                if not writeOk then
                                        error("write failed: " .. path .. " - " .. tostring(writeErr))
                                end
                        end

                        local liveContainers = {}
                        local legacyContainers = {}

                        do
                                local function addContainer(container, legacyToo)
                                        if container then
                                                liveContainers[#liveContainers + 1] = container

                                                if legacyToo then
                                                        legacyContainers[#legacyContainers + 1] = container
                                                end
                                        end
                                end

                                addContainer(game:GetService("ReplicatedFirst"), true)
                                addContainer(game:GetService("ReplicatedStorage"), false)

                                for _, className in ipairs({ "PlayerScripts", "PlayerGui", "Backpack" }) do
                                        addContainer(LocalPlayer:FindFirstChildOfClass(className), true)
                                end

                                addContainer(LocalPlayer.Character, true)
                                addContainer(Workspace, false)
                        end

                        local function inLiveContainer(instance)
                                for _, container in ipairs(liveContainers) do
                                        if instance:IsDescendantOf(container) then
                                                return true
                                        end
                                end

                                return false
                        end

                        local DEFAULT_SCRIPT_NAMES = {
                                PlayerModule = true,
                                PlayerScriptsLoader = true,
                                RbxCharacterSounds = true,
                                ChatScript = true
                        }

                        local function isRobloxDefaultScript(instance)
                                local node = instance

                                while node and node ~= game do
                                        if DEFAULT_SCRIPT_NAMES[node.Name] then
                                                return true
                                        end

                                        node = node.Parent
                                end

                                return false
                        end

                        local characterOwnerCache = {}

                        local function isOtherPlayersCopy(instance)
                                local node = instance.Parent

                                while node and node ~= Workspace do
                                        if node.Parent == Workspace then
                                                local known = characterOwnerCache[node]

                                                if known == nil then
                                                        local player = Players:GetPlayerFromCharacter(node)
                                                        known = (player ~= nil and player ~= LocalPlayer) or false
                                                        characterOwnerCache[node] = known
                                                end

                                                return known
                                        end

                                        node = node.Parent
                                end

                                return false
                        end

                        local function shouldExtractScript(instance)
                                if not inLiveContainer(instance) then
                                        return false, "outside"
                                end

                                if isRobloxDefaultScript(instance) then
                                        return false, "default"
                                end

                                if isOtherPlayersCopy(instance) then
                                        return false, "otherplayer"
                                end

                                return true, nil
                        end

                        local function runsLegacyClient(instance)
                                for _, container in ipairs(legacyContainers) do
                                        if instance:IsDescendantOf(container) then
                                                return true
                                        end
                                end

                                return false
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
                        local skippedDefaults = 0
                        local skippedOtherPlayers = 0
                        local skippedOutside = 0
                        local boundsMin = nil
                        local boundsMax = nil

                        local function classifyScript(instance)
                                local extract, why = shouldExtractScript(instance)

                                if extract then
                                        scriptEntries[#scriptEntries + 1] = {
                                                instance = instance,
                                                className = instance.ClassName,
                                                name = instance.Name,
                                                path = instance:GetFullName()
                                        }
                                        return
                                end

                                if why == "default" then
                                        skippedDefaults = skippedDefaults + 1
                                elseif why == "otherplayer" then
                                        skippedOtherPlayers = skippedOtherPlayers + 1
                                else
                                        skippedOutside = skippedOutside + 1
                                end
                        end

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
                                        classifyScript(instance)
                                elseif className == "Script" then
                                        local contextOk, runContext = pcall(function()
                                                return instance.RunContext
                                        end)

                                        local clientSide = contextOk and runContext == Enum.RunContext.Client

                                        if not clientSide and (not contextOk or runContext == Enum.RunContext.Legacy) then
                                                clientSide = runsLegacyClient(instance)
                                        end

                                        if clientSide then
                                                classifyScript(instance)
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
                                "Scope: game scripts only - live copies under ReplicatedStorage, ReplicatedFirst, Workspace, your PlayerScripts, PlayerGui, Backpack and character; Roblox defaults, other players' copies and everything else are skipped",
                                ""
                        }

                        if #scriptEntries == 0 then
                                manifestLines[#manifestLines + 1] = "no game scripts found in ReplicatedStorage, ReplicatedFirst, Workspace, PlayerScripts, PlayerGui or Backpack"
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
                                                local writeOk, writeErr = pcall(writeFile, scriptsDir .. "/" .. fileName, source)

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

                        manifestLines[#manifestLines + 1] = "skipped: "
                                .. skippedDefaults
                                .. " roblox defaults, "
                                .. skippedOtherPlayers
                                .. " other player copies, "
                                .. skippedOutside
                                .. " outside game containers"

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
                                        skippedRobloxDefaults = skippedDefaults,
                                        skippedOtherPlayerCopies = skippedOtherPlayers,
                                        skippedOutsideGameContainers = skippedOutside,
                                        decompilerAvailable = type(decompile) == "function",
                                        serverScriptsVisibleButNotReadable = serverScriptCount
                                }
                        }

                        writeFile(root .. "/overview.json", jsonEncode(overview, 0) .. "\n")

                        if asZip then
                                setStatus("Packing zip (" .. #zipEntries .. " files)...")
                                task.wait()

                                if abortNow() then
                                        return
                                end

                                writeZipNow()
                        end

                        setStatus("Done: "
                                .. total
                                .. " instances, "
                                .. partCount
                                .. " parts, "
                                .. decompiledCount
                                .. "/"
                                .. #scriptEntries
                                .. " game scripts, "
                                .. #remotesLines
                                .. " remotes, "
                                .. #assetsLines
                                .. " assets -> "
                                .. toFullPath(asZip and zipPath or root))
                end)

                local wasCancelled = cancelRequested

                extracting = false
                cancelRequested = false

                if not ok then
                        setStatus("Extract failed: " .. tostring(err):sub(1, 140))
                elseif wasCancelled then
                        if asZip then
                                if #zipEntries > 0 and zipPath then
                                        local packOk, packErr = pcall(writeZipNow)

                                        if packOk then
                                                setStatus("Cancelled - zip written: " .. toFullPath(zipPath))
                                        else
                                                setStatus("Cancelled - " .. tostring(packErr):sub(1, 100))
                                        end
                                else
                                        setStatus("Cancelled - nothing was written")
                                end
                        elseif lastOutputPath then
                                setStatus("Cancelled - partial files kept in " .. toFullPath(lastOutputPath))
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
        Text = "Idle."
})

ExtractSection:Toggle({
        Text = "Output as ZIP",
        Value = false,
        Callback = function(value)
                outputAsZip = value and true or false
        end
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
                        setStatus("Already cancelling")
                        return
                end

                cancelRequested = true
                setStatus("Cancelling...")
        end
})

ExtractSection:Button({
        Text = "Copy Path",
        Callback = function()
                if extracting then
                        setStatus("Still extracting")
                        return
                end

                if not lastOutputPath then
                        setStatus("Nothing to copy yet")
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

                local fullPath = toFullPath(lastOutputPath)

                if not clip then
                        setStatus("No clipboard function: " .. fullPath)
                        return
                end

                local copyOk = pcall(clip, fullPath)

                if copyOk then
                        setStatus("Copied: " .. fullPath)
                else
                        setStatus("Clipboard copy failed: " .. fullPath)
                end
        end
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
