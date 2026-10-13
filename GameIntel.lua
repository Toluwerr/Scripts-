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
        ImageLabel = { "Image" },
        ImageButton = { "Image" },
        ShirtGraphic = { "Graphic" },
        VideoFrame = { "Video" },
        SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" },
        Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
}

local REMOTE_CLASSES = {
        RemoteEvent = true,
        UnreliableRemoteEvent = true,
        RemoteFunction = true,
        BindableEvent = true,
        BindableFunction = true
}

local VALUE_CLASSES = {
        StringValue = true,
        NumberValue = true,
        IntValue = true,
        FloatValue = true,
        BoolValue = true,
        ObjectValue = true,
        BrickColorValue = true,
        CFrameValue = true,
        RayValue = true,
        Vector3Value = true,
        Color3Value = true
}

local EXECUTOR_TOKENS = {
        "getgenv",
        "hookmetamethod",
        "hookfunction",
        "getrawmetatable",
        "setreadonly",
        "checkcaller",
        "getcallingscript",
        "identifyexecutor",
        "is_synapse_function",
        "gethui"
}

local STAT_TOKENS = {
        "WalkSpeed",
        "JumpPower",
        "JumpHeight",
        "HipHeight",
        "MaxHealth"
}

local REMOTE_CODE_TOKENS = {
        "loadstring(",
        "HttpGet(",
        "HttpPost("
}

local HTTP_TOKENS = {
        "GetAsync(",
        "RequestAsync(",
        "PostAsync(",
        "HttpEnabled"
}

local TELEPORT_TOKENS = {
        "TeleportService",
        ":Teleport("
}

local FINDING_ORDER = {
        "executor-detect",
        "kick",
        "stats-watch",
        "remote-code",
        "http-api",
        "teleport",
        "fires-remotes"
}

local FINDING_SCORES = {
        ["executor-detect"] = 100,
        ["kick"] = 60,
        ["stats-watch"] = 40,
        ["remote-code"] = 30,
        ["http-api"] = 25,
        ["teleport"] = 15,
        ["fires-remotes"] = 10
}

local function patternEscape(text)
        return (tostring(text):gsub("([^%w%s])", "%%%1"))
end

local function trimText(text, limit)
        local value = tostring(text):gsub("%c", " ")
        value = value:gsub("%s+", " ")
        value = value:gsub("^ ", "")
        return value:sub(1, limit or 160)
end

local typeOf = typeof or type

local function formatValue(value)
        local kind = typeOf(value)

        if kind == "string" then
                return '"' .. trimText(value, 160) .. '"'
        elseif kind == "number" then
                return string.format("%.14g", value)
        elseif kind == "boolean" then
                return tostring(value)
        elseif kind == "nil" then
                return "nil"
        elseif kind == "Instance" then
                local pathOk, instancePath = pcall(function()
                        return value:GetFullName()
                end)

                if pathOk then
                        return tostring(value) .. " (" .. instancePath .. ")"
                end

                return tostring(value)
        end

        return trimText(value, 200)
end

local function makeAnalyzer(remoteByName)
        local analyzer = {
                findings = {},
                urls = {},
                placeIds = {},
                unresolved = {},
                analyzed = 0
        }

        local nameSet = {}
        local urlSeen = {}
        local placeIdSeen = {}

        for remoteName in pairs(remoteByName) do
                nameSet[remoteName] = true
        end

        local function noteCall(record, fileName, lineNo, callText)
                record.calls = record.calls or {}

                if #record.calls < 8 then
                        record.calls[#record.calls + 1] = fileName .. ":" .. lineNo .. "  " .. callText
                elseif #record.calls == 8 then
                        record.calls[#record.calls + 1] = "(more calls omitted)"
                end

                record.callCount = (record.callCount or 0) + 1
        end

        local function noteRef(record, fileName)
                record.refs = record.refs or {}
                record.refs[fileName] = true
        end

        local function collectQuotedNames(line, out)
                for literal in line:gmatch('"([^"]+)"') do
                        if nameSet[literal] then
                                out[#out + 1] = literal
                        end
                end

                for literal in line:gmatch("'([^']+)'") do
                        if nameSet[literal] then
                                out[#out + 1] = literal
                        end
                end
        end

        local function assignmentNames(line, varName)
                local esc = patternEscape(varName)
                local pos = 1

                while true do
                        local matchStart = line:find(esc .. "%s*=[^=~<>]", pos)

                        if not matchStart then
                                return nil
                        end

                        local before = matchStart > 1 and line:sub(matchStart - 1, matchStart - 1) or ""
                        local boundaryOk = before == "" or not before:match("[%w_%.%]%\"']")

                        if boundaryOk then
                                local names = {}
                                collectQuotedNames(line, names)

                                for tail in line:gmatch("([%w_]+)%s*$") do
                                        if nameSet[tail] then
                                                names[#names + 1] = tail
                                        end
                                end

                                return names
                        end

                        pos = matchStart + 1
                end
        end

        local function resolveReceiver(receiver, lines, lineNo, currentLine)
                if receiver and nameSet[receiver] then
                        return { receiver }
                end

                if receiver then
                        local scanFrom = math.max(1, lineNo - 300)

                        for j = lineNo - 1, scanFrom, -1 do
                                local names = assignmentNames(lines[j], receiver)

                                if names then
                                        if #names > 0 then
                                                return names
                                        end

                                        break
                                end
                        end
                end

                local lineNames = {}
                collectQuotedNames(currentLine, lineNames)

                for tail in currentLine:gmatch("%.([%w_]+)%s*:") do
                        if nameSet[tail] then
                                lineNames[#lineNames + 1] = tail
                        end
                end

                return lineNames
        end

        local function callTextFrom(lines, lineNo, lineText)
                local text = lineText
                local opens = select(2, text:gsub("%(", ""))
                local closes = select(2, text:gsub("%)", ""))
                local last = lineNo

                while opens > closes and last < #lines and last - lineNo < 3 do
                        last = last + 1
                        local nextLine = lines[last]
                        text = text .. " " .. trimText(nextLine, 120)
                        opens = opens + select(2, nextLine:gsub("%(", ""))
                        closes = closes + select(2, nextLine:gsub("%)", ""))
                end

                return trimText(text, 300)
        end

        function analyzer.analyze(fileName, source, scriptPath)
                analyzer.analyzed = analyzer.analyzed + 1

                local script = {
                        file = fileName,
                        path = scriptPath or "",
                        hits = {},
                        extra = {},
                        score = 0
                }

                local seenCategory = {}

                local function hit(categoryId, lineNo, lineText)
                        local bucket = script.hits[categoryId]

                        if not bucket then
                                bucket = {}
                                script.hits[categoryId] = bucket
                        end

                        if #bucket < 6 then
                                bucket[#bucket + 1] = lineNo .. ": " .. trimText(lineText, 200)
                        else
                                script.extra[categoryId] = (script.extra[categoryId] or 0) + 1
                        end

                        if not seenCategory[categoryId] then
                                seenCategory[categoryId] = true
                                script.score = script.score + (FINDING_SCORES[categoryId] or 0)
                        end
                end

                local lines = {}

                for line in source:gmatch("[^\r\n]+") do
                        lines[#lines + 1] = line
                end

                for lineNo, line in ipairs(lines) do
                        local fireServerAt = line:find(":FireServer(", 1, true)
                        local invokeServerAt = line:find(":InvokeServer(", 1, true)
                        local fireBindableAt = line:find(":Fire(", 1, true)
                        local invokeBindableAt = line:find(":Invoke(", 1, true)

                        if fireServerAt or invokeServerAt then
                                local receiver = fireServerAt
                                        and line:match("([%w_]+)%s*:%s*FireServer%s*%(")
                                        or line:match("([%w_]+)%s*:%s*InvokeServer%s*%(")
                                local names = resolveReceiver(receiver, lines, lineNo, line)
                                local callText = callTextFrom(lines, lineNo, line)

                                hit("fires-remotes", lineNo, line)

                                if #names > 0 then
                                        for _, remoteName in ipairs(names) do
                                                for _, record in ipairs(remoteByName[remoteName]) do
                                                        noteCall(record, fileName, lineNo, callText)
                                                end
                                        end
                                elseif #analyzer.unresolved < 40 then
                                        analyzer.unresolved[#analyzer.unresolved + 1] = {
                                                file = fileName,
                                                lineNo = lineNo,
                                                text = callText
                                        }
                                end
                        elseif fireBindableAt or invokeBindableAt then
                                local receiver = fireBindableAt
                                        and line:match("([%w_]+)%s*:%s*Fire%s*%(")
                                        or line:match("([%w_]+)%s*:%s*Invoke%s*%(")
                                local names = resolveReceiver(receiver, lines, lineNo, line)

                                if #names > 0 then
                                        local callText = callTextFrom(lines, lineNo, line)

                                        for _, remoteName in ipairs(names) do
                                                for _, record in ipairs(remoteByName[remoteName]) do
                                                        noteCall(record, fileName, lineNo, callText)
                                                end
                                        end
                                end
                        end

                        if line:find("OnClientEvent", 1, true) or line:find("OnClientInvoke", 1, true) then
                                local receiver = line:match("([%w_]+)%s*%.%s*OnClientEvent")
                                        or line:match("([%w_]+)%s*%.%s*OnClientInvoke")
                                local names = resolveReceiver(receiver, lines, lineNo, line)

                                for _, remoteName in ipairs(names) do
                                        for _, record in ipairs(remoteByName[remoteName]) do
                                                record.listenerCount = (record.listenerCount or 0) + 1
                                                record.listenerFile = record.listenerFile or fileName
                                        end
                                end
                        end

                        local lowerLine = nil

                        for _, token in ipairs(EXECUTOR_TOKENS) do
                                lowerLine = lowerLine or line:lower()

                                if lowerLine:find(token, 1, true) then
                                        hit("executor-detect", lineNo, line)
                                        break
                                end
                        end

                        for _, token in ipairs(STAT_TOKENS) do
                                if line:find(token, 1, true) then
                                        hit("stats-watch", lineNo, line)
                                        break
                                end
                        end

                        if line:find(":Kick(", 1, true) then
                                hit("kick", lineNo, line)
                        end

                        for _, token in ipairs(REMOTE_CODE_TOKENS) do
                                if line:find(token, 1, true) then
                                        hit("remote-code", lineNo, line)
                                        break
                                end
                        end

                        for _, token in ipairs(HTTP_TOKENS) do
                                if line:find(token, 1, true) then
                                        hit("http-api", lineNo, line)
                                        break
                                end
                        end

                        for _, token in ipairs(TELEPORT_TOKENS) do
                                if line:find(token, 1, true) then
                                        hit("teleport", lineNo, line)
                                        break
                                end
                        end
                end

                for url in source:gmatch("https?://[%w%.%-_%~%:%/%?%#%[%]@!%$&%(%)%*%+%,%;=%%]+") do
                        if not urlSeen[url] and #analyzer.urls < 300 then
                                urlSeen[url] = true
                                analyzer.urls[#analyzer.urls + 1] = { url = url:sub(1, 300), file = fileName }
                        end
                end

                for placeId in source:gmatch("Teleport%s*%(%s*(%d+)") do
                        if not placeIdSeen[placeId] and #analyzer.placeIds < 50 then
                                placeIdSeen[placeId] = true
                                analyzer.placeIds[#analyzer.placeIds + 1] = { id = placeId, file = fileName }
                        end
                end

                for placeId in source:gmatch("TeleportToPlaceInstance%s*%(%s*(%d+)") do
                        if not placeIdSeen[placeId] and #analyzer.placeIds < 50 then
                                placeIdSeen[placeId] = true
                                analyzer.placeIds[#analyzer.placeIds + 1] = { id = placeId, file = fileName }
                        end
                end

                for remoteName in pairs(nameSet) do
                        if source:find('"' .. remoteName .. '"', 1, true)
                                or source:find("'" .. remoteName .. "'", 1, true) then
                                for _, record in ipairs(remoteByName[remoteName]) do
                                        noteRef(record, fileName)
                                end
                        end
                end

                if next(script.hits) then
                        analyzer.findings[#analyzer.findings + 1] = script
                end
        end

        return analyzer
end

local function makeRemoteReport(remoteRecords, analyzer, header)
        local fireable = {}
        local bindables = {}

        for _, record in ipairs(remoteRecords) do
                if record.className == "BindableEvent" or record.className == "BindableFunction" then
                        bindables[#bindables + 1] = record
                else
                        fireable[#fireable + 1] = record
                end
        end

        local function byCalls(a, b)
                if (a.callCount or 0) ~= (b.callCount or 0) then
                        return (a.callCount or 0) > (b.callCount or 0)
                end

                return a.path < b.path
        end

        table.sort(fireable, byCalls)
        table.sort(bindables, byCalls)

        local function recordBlock(record)
                local block = { record.className .. "  " .. record.path }

                if record.calls and #record.calls > 0 then
                        block[#block + 1] = "  calls:"

                        for _, callText in ipairs(record.calls) do
                                block[#block + 1] = "    " .. callText
                        end
                end

                if (record.listenerCount or 0) > 0 then
                        block[#block + 1] = "  client listeners: " .. record.listenerCount .. "  (" .. tostring(record.listenerFile) .. ")"
                end

                local refFiles = {}

                if record.refs then
                        for fileName in pairs(record.refs) do
                                refFiles[#refFiles + 1] = fileName
                        end
                end

                table.sort(refFiles)

                if #refFiles > 0 then
                        local shown = {}

                        for i = 1, math.min(#refFiles, 10) do
                                shown[#shown + 1] = refFiles[i]
                        end

                        local refLine = "  referenced by: " .. table.concat(shown, ", ")

                        if #refFiles > 10 then
                                refLine = refLine .. " (+" .. (#refFiles - 10) .. " more)"
                        end

                        block[#block + 1] = refLine
                end

                if (record.callCount or 0) == 0 and #refFiles == 0 and (record.listenerCount or 0) == 0 then
                        block[#block + 1] = "  no client references found"
                end

                return block
        end

        local parts = { header }

        parts[#parts + 1] = "FIREABLE BY CLIENT  (RemoteEvent / UnreliableRemoteEvent / RemoteFunction)  -  " .. #fireable
        parts[#parts + 1] = ""

        if #fireable == 0 then
                parts[#parts + 1] = "none visible to the client"
        else
                for _, record in ipairs(fireable) do
                        for _, blockLine in ipairs(recordBlock(record)) do
                                parts[#parts + 1] = blockLine
                        end

                        parts[#parts + 1] = ""
                end
        end

        parts[#parts + 1] = "LOCAL BINDABLES  (BindableEvent / BindableFunction)  -  " .. #bindables
        parts[#parts + 1] = ""

        if #bindables == 0 then
                parts[#parts + 1] = "none visible to the client"
        else
                for _, record in ipairs(bindables) do
                        for _, blockLine in ipairs(recordBlock(record)) do
                                parts[#parts + 1] = blockLine
                        end

                        parts[#parts + 1] = ""
                end
        end

        if #analyzer.unresolved > 0 then
                parts[#parts + 1] = "UNRESOLVED CLIENT CALLS  -  " .. #analyzer.unresolved
                parts[#parts + 1] = ""

                for _, call in ipairs(analyzer.unresolved) do
                        parts[#parts + 1] = "  " .. call.file .. ":" .. call.lineNo .. "  " .. call.text
                end
        end

        return table.concat(parts, "\n") .. "\n"
end

local function makeFindingsReport(analyzer, header)
        local sorted = {}

        for _, script in ipairs(analyzer.findings) do
                sorted[#sorted + 1] = script
        end

        table.sort(sorted, function(a, b)
                if a.score ~= b.score then
                        return a.score > b.score
                end

                return a.file < b.file
        end)

        local function categoryTag(script)
                local tags = {}

                for _, categoryId in ipairs(FINDING_ORDER) do
                        if script.hits[categoryId] then
                                tags[#tags + 1] = categoryId
                        end
                end

                return table.concat(tags, " ")
        end

        local parts = { header }

        if analyzer.analyzed == 0 then
                parts[#parts + 1] = "no decompiled sources to analyze"
                parts[#parts + 1] = ""
        elseif #sorted == 0 then
                parts[#parts + 1] = "no security-relevant patterns found in " .. analyzer.analyzed .. " scripts"
                parts[#parts + 1] = ""
        else
                parts[#parts + 1] = "RANKED SCRIPTS  (" .. #sorted .. " of " .. analyzer.analyzed .. " analyzed)"

                for i, script in ipairs(sorted) do
                        parts[#parts + 1] = i .. ". " .. script.file .. "  [" .. categoryTag(script) .. "]  " .. script.path
                end

                parts[#parts + 1] = ""
        end

        parts[#parts + 1] = "URLS  (" .. #analyzer.urls .. ")"

        if #analyzer.urls == 0 then
                parts[#parts + 1] = "none found"
        else
                for _, urlRecord in ipairs(analyzer.urls) do
                        parts[#parts + 1] = urlRecord.url .. "  <-  " .. urlRecord.file
                end
        end

        parts[#parts + 1] = ""
        parts[#parts + 1] = "TELEPORT PLACE IDS  (" .. #analyzer.placeIds .. ")"

        if #analyzer.placeIds == 0 then
                parts[#parts + 1] = "none found"
        else
                for _, placeRecord in ipairs(analyzer.placeIds) do
                        parts[#parts + 1] = placeRecord.id .. "  <-  " .. placeRecord.file
                end
        end

        if #sorted > 0 then
                parts[#parts + 1] = ""
                parts[#parts + 1] = "DETAILS"

                for _, script in ipairs(sorted) do
                        parts[#parts + 1] = ""
                        parts[#parts + 1] = script.file .. "  " .. script.path

                        for _, categoryId in ipairs(FINDING_ORDER) do
                                local bucket = script.hits[categoryId]

                                if bucket then
                                        parts[#parts + 1] = "  " .. categoryId

                                        for _, hitLine in ipairs(bucket) do
                                                parts[#parts + 1] = "    " .. hitLine
                                        end

                                        if script.extra[categoryId] then
                                                parts[#parts + 1] = "    (+" .. script.extra[categoryId] .. " more)"
                                        end
                                end
                        end
                end
        end

        return table.concat(parts, "\n") .. "\n"
end

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
                        local zipOk, zipErr = pcall(writefile, zipPath, buildZip(zipEntries))

                        if not zipOk then
                                return false, tostring(zipErr)
                        end

                        lastOutputPath = zipPath
                        return true
                end

                local function zipRefusal(err)
                        local text = tostring(err):lower()
                        return text:find("forbidden", 1, true)
                                or text:find("extension", 1, true)
                                or text:find("not allowed", 1, true)
                                or text:find("blocked", 1, true) ~= nil
                end

                local function zipFailMessage(err)
                        if zipRefusal(err) then
                                return "Your executor refuses to write .zip files - turn off Output as ZIP and extract as a folder"
                        end

                        return "Zip write failed: " .. tostring(err):sub(1, 120)
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

                                local probeOk, probeErr = writeZipNow()

                                if not probeOk then
                                        setStatus(zipFailMessage(probeErr))
                                        return
                                end
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
                        local assetsLines = {}
                        local scriptEntries = {}
                        local valuesLines = {}
                        local interactLines = {}
                        local remoteRecords = {}
                        local remoteByName = {}
                        local valueInstanceCount = 0
                        local attributeLineCount = 0
                        local humanoidLineCount = 0
                        local clickDetectorCount = 0
                        local proximityPromptCount = 0

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
                                local fullName = instance:GetFullName()

                                classCounts[className] = (classCounts[className] or 0) + 1
                                treeLines[#treeLines + 1] = className .. "  " .. fullName

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
                                                                .. fullName
                                                end
                                        end
                                end

                                if REMOTE_CLASSES[className] then
                                        local record = {
                                                className = className,
                                                name = instance.Name,
                                                path = fullName,
                                                calls = {},
                                                callCount = 0,
                                                refs = {},
                                                listenerCount = 0,
                                                listenerFile = nil
                                        }

                                        remoteRecords[#remoteRecords + 1] = record

                                        local bucket = remoteByName[instance.Name]

                                        if not bucket then
                                                bucket = {}
                                                remoteByName[instance.Name] = bucket
                                        end

                                        bucket[#bucket + 1] = record
                                end

                                if VALUE_CLASSES[className] then
                                        local readOk, currentValue = pcall(function()
                                                return instance.Value
                                        end)

                                        if readOk then
                                                valueInstanceCount = valueInstanceCount + 1
                                                valuesLines[#valuesLines + 1] = className
                                                        .. "  "
                                                        .. instance.Name
                                                        .. " = "
                                                        .. formatValue(currentValue)
                                                        .. "  "
                                                        .. fullName
                                        end
                                end

                                if className == "ClickDetector" then
                                        clickDetectorCount = clickDetectorCount + 1

                                        local rangeOk, maxRange = pcall(function()
                                                return instance.MaxActivationDistance
                                        end)

                                        interactLines[#interactLines + 1] = "ClickDetector  MaxActivationDistance="
                                                .. (rangeOk and string.format("%.14g", maxRange) or "?")
                                                .. "  "
                                                .. fullName
                                elseif className == "ProximityPrompt" then
                                        proximityPromptCount = proximityPromptCount + 1

                                        local promptOk, actionText, objectText, holdTime, promptRange, lineOfSight = pcall(function()
                                                return instance.ActionText, instance.ObjectText, instance.HoldDuration, instance.MaxActivationDistance, instance.RequiresLineOfSight
                                        end)

                                        if promptOk then
                                                interactLines[#interactLines + 1] = "ProximityPrompt  Action="
                                                        .. trimText(actionText, 40)
                                                        .. "  Object="
                                                        .. trimText(objectText, 40)
                                                        .. "  Hold="
                                                        .. string.format("%.14g", holdTime)
                                                        .. "  MaxActivationDistance="
                                                        .. string.format("%.14g", promptRange)
                                                        .. "  LineOfSight="
                                                        .. tostring(lineOfSight)
                                                        .. "  "
                                                        .. fullName
                                        else
                                                interactLines[#interactLines + 1] = "ProximityPrompt  " .. fullName
                                        end
                                end

                                if className == "Humanoid" and instance:IsDescendantOf(Players) then
                                        local snapOk, walkSpeed, jumpPower, jumpHeight, health, maxHealth = pcall(function()
                                                return instance.WalkSpeed, instance.JumpPower, instance.JumpHeight, instance.Health, instance.MaxHealth
                                        end)

                                        if snapOk then
                                                humanoidLineCount = humanoidLineCount + 1
                                                valuesLines[#valuesLines + 1] = "Humanoid  WalkSpeed="
                                                        .. string.format("%.14g", walkSpeed)
                                                        .. "  JumpPower="
                                                        .. string.format("%.14g", jumpPower)
                                                        .. "  JumpHeight="
                                                        .. string.format("%.14g", jumpHeight)
                                                        .. "  Health="
                                                        .. string.format("%.14g", health)
                                                        .. "/"
                                                        .. string.format("%.14g", maxHealth)
                                                        .. "  "
                                                        .. fullName
                                        end
                                end

                                local attrOk, attributes = pcall(instance.GetAttributes, instance)

                                if attrOk and type(attributes) == "table" then
                                        local attrNames = {}

                                        for attributeName in pairs(attributes) do
                                                attrNames[#attrNames + 1] = attributeName
                                        end

                                        if #attrNames > 0 then
                                                table.sort(attrNames)

                                                for _, attributeName in ipairs(attrNames) do
                                                        attributeLineCount = attributeLineCount + 1
                                                        valuesLines[#valuesLines + 1] = "Attribute  "
                                                                .. attributeName
                                                                .. " = "
                                                                .. formatValue(attributes[attributeName])
                                                                .. "  "
                                                                .. fullName
                                                end
                                        end
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

                        setStatus("Writing values (" .. #valuesLines .. " lines)...")

                        if #valuesLines > 0 then
                                writeFile(root .. "/values.txt", header .. table.concat(valuesLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/values.txt", header .. "no value instances, attributes or humanoids found\n")
                        end

                        setStatus("Writing interactables (" .. #interactLines .. ")...")

                        if #interactLines > 0 then
                                writeFile(root .. "/interactables.txt", header .. table.concat(interactLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/interactables.txt", header .. "no click detectors or proximity prompts found\n")
                        end

                        setStatus("Writing assets (" .. #assetsLines .. ")...")

                        if #assetsLines > 0 then
                                writeFile(root .. "/assets.txt", header .. table.concat(assetsLines, "\n") .. "\n")
                        else
                                writeFile(root .. "/assets.txt", header .. "no asset ids found\n")
                        end

                        local analyzer = makeAnalyzer(remoteByName)

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
                                                        analyzer.analyze(fileName, source, entry.path)
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

                        setStatus("Writing remotes report (" .. #remoteRecords .. " remotes)...")
                        writeFile(root .. "/remotes.txt", makeRemoteReport(remoteRecords, analyzer, header))

                        if abortNow() then
                                return
                        end

                        setStatus("Writing findings (" .. #analyzer.findings .. " flagged scripts)...")
                        writeFile(root .. "/findings.txt", makeFindingsReport(analyzer, header))

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
                        local descriptionText = nil
                        local priceInRobux = nil
                        local createdDate = nil
                        local updatedDate = nil

                        if infoOk and type(info) == "table" then
                                if type(info.Creator) == "table" and type(info.Creator.Name) == "string" then
                                        creatorName = info.Creator.Name
                                end

                                if type(info.Description) == "string" then
                                        descriptionText = trimText(info.Description, 600)
                                end

                                if type(info.PriceInRobux) == "number" then
                                        priceInRobux = info.PriceInRobux
                                end

                                if type(info.Created) == "string" then
                                        createdDate = info.Created
                                end

                                if type(info.Updated) == "string" then
                                        updatedDate = info.Updated
                                end
                        end

                        local playersInfo = {}

                        for _, player in ipairs(Players:GetPlayers()) do
                                playersInfo[#playersInfo + 1] = {
                                        name = player.Name,
                                        displayName = player.DisplayName,
                                        userId = player.UserId,
                                        team = player.Team and player.Team.Name or nil,
                                        accountAge = player.AccountAge
                                }
                        end

                        local fireableCount = 0
                        local bindableCount = 0
                        local remoteWithCalls = 0
                        local remoteWithRefsOnly = 0
                        local remoteUnreferenced = 0

                        for _, record in ipairs(remoteRecords) do
                                local isBindable = record.className == "BindableEvent" or record.className == "BindableFunction"

                                if isBindable then
                                        bindableCount = bindableCount + 1
                                else
                                        fireableCount = fireableCount + 1
                                end

                                if record.callCount > 0 then
                                        remoteWithCalls = remoteWithCalls + 1
                                elseif next(record.refs) then
                                        remoteWithRefsOnly = remoteWithRefsOnly + 1
                                elseif not isBindable then
                                        remoteUnreferenced = remoteUnreferenced + 1
                                end
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
                                        description = descriptionText,
                                        priceInRobux = priceInRobux,
                                        created = createdDate,
                                        updated = updatedDate,
                                        playerCount = #Players:GetPlayers(),
                                        maxPlayers = Players.MaxPlayers,
                                        privateServerId = game.PrivateServerId ~= "" and game.PrivateServerId or nil
                                },
                                players = playersInfo,
                                workspace = {
                                        streamingEnabled = Workspace.StreamingEnabled,
                                        streamingCaveat = Workspace.StreamingEnabled and "workspace streaming is on - distant parts may not have been replicated during this extraction" or nil,
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
                                values = {
                                        valueInstances = valueInstanceCount,
                                        attributes = attributeLineCount,
                                        humanoidSnapshots = humanoidLineCount
                                },
                                interactables = {
                                        clickDetectors = clickDetectorCount,
                                        proximityPrompts = proximityPromptCount
                                },
                                remoteAnalysis = {
                                        total = #remoteRecords,
                                        fireableByClient = fireableCount,
                                        bindables = bindableCount,
                                        withClientCalls = remoteWithCalls,
                                        referencedOnly = remoteWithRefsOnly,
                                        unreferenced = remoteUnreferenced,
                                        unresolvedCalls = #analyzer.unresolved
                                },
                                codeAnalysis = {
                                        scriptsAnalyzed = analyzer.analyzed,
                                        scriptsFlagged = #analyzer.findings,
                                        urls = #analyzer.urls,
                                        teleportPlaceIds = #analyzer.placeIds
                                },
                                extraction = {
                                        remotesFound = #remoteRecords,
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

                                local packOk, packErr = writeZipNow()

                                if not packOk then
                                        setStatus(zipFailMessage(packErr))
                                        return
                                end
                        end

                        setStatus("Done: "
                                .. total
                                .. " instances, "
                                .. decompiledCount
                                .. "/"
                                .. #scriptEntries
                                .. " scripts, "
                                .. #remoteRecords
                                .. " remotes, "
                                .. #valuesLines
                                .. " values, "
                                .. #analyzer.findings
                                .. " flagged, "
                                .. #analyzer.urls
                                .. " urls -> "
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
                                        local packOk, packErr = writeZipNow()

                                        if packOk then
                                                setStatus("Cancelled - zip written: " .. toFullPath(zipPath))
                                        else
                                                setStatus("Cancelled - " .. zipFailMessage(packErr))
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
