local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local Global = (getgenv and getgenv()) or _G

if type(Global.__MonochromePlayerCleanup) == "function" then
        pcall(Global.__MonochromePlayerCleanup)
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
        table.clear(connections)
end

local httpRequest = nil
if syn and type(syn.request) == "function" then
        httpRequest = syn.request
elseif type(http_request) == "function" then
        httpRequest = http_request
elseif http and type(http.request) == "function" then
        httpRequest = http.request
elseif type(request) == "function" then
        httpRequest = request
end

if not httpRequest then
        warn("[Monochrome] This executor has no HTTP request function.")
        return
end

local TRACKS_BASE = "https://tracks.monochrome.st"
local SC_HOME = "https://soundcloud.com/"
local SC_API = "https://api-v2.soundcloud.com"
local SC_FALLBACK_ID = "vI5BsvpTIlavDLl7RDbbcFAPg8kls8Bg"
local CACHE_FOLDER = "monochrome"
local CACHE_LIMIT = 12
local USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

local function urlEncode(s)
        s = tostring(s or "")
        return (s:gsub("[^%w%-_%.~]", function(c)
                return string.format("%%%02X", string.byte(c))
        end))
end

local function clampN(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
end

local function fmtTime(sec)
        sec = math.floor(tonumber(sec) or 0)
        if sec < 0 then sec = 0 end
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local s = sec % 60
        if h > 0 then
                return string.format("%d:%02d:%02d", h, m, s)
        end
        return string.format("%d:%02d", m, s)
end

local FS = {
        write = (type(writefile) == "function") and writefile or nil,
        read = (type(readfile) == "function") and readfile or nil,
        isFile = (type(isfile) == "function") and isfile or nil,
        isFolder = (type(isfolder) == "function") and isfolder or nil,
        makeFolder = (type(makefolder) == "function") and makefolder or nil,
        delFile = (type(delfile) == "function") and delfile or nil,
        listFiles = (type(listfiles) == "function") and listfiles or nil,
}

local customAsset = nil
if type(getcustomasset) == "function" then
        customAsset = getcustomasset
elseif type(getsynasset) == "function" then
        customAsset = getsynasset
end

local function httpGet(url)
        local ok, res = pcall(httpRequest, {
                Url = url,
                Method = "GET",
                Headers = {
                        ["Accept"] = "*/*",
                        ["User-Agent"] = USER_AGENT,
                },
        })
        if not ok or type(res) ~= "table" then
                return nil, 0
        end
        local code = tonumber(res.StatusCode or res.Status or 0) or 0
        local clen = nil
        if type(res.Headers) == "table" then
                for k, v in pairs(res.Headers) do
                        if tostring(k):lower() == "content-length" then
                                clen = tonumber(v) or nil
                                break
                        end
                end
        end
        return tostring(res.Body or ""), code, clen
end

local function ensureCacheFolder()
        if FS.isFolder and FS.makeFolder and not FS.isFolder(CACHE_FOLDER) then
                pcall(FS.makeFolder, CACHE_FOLDER)
        end
end

local function cacheOrderPath()
        return CACHE_FOLDER .. "/.order"
end

local function readCacheOrder()
        if FS.read then
                local ok, body = pcall(FS.read, cacheOrderPath())
                if ok and type(body) == "string" and #body > 2 then
                        local okD, data = pcall(function()
                                return HttpService:JSONDecode(body)
                        end)
                        if okD and type(data) == "table" then
                                local names = {}
                                for _, n in ipairs(data) do
                                        if type(n) == "string" then
                                                table.insert(names, n)
                                        end
                                end
                                return names
                        end
                end
        end
        if FS.listFiles then
                local ok, files = pcall(FS.listFiles, CACHE_FOLDER)
                if ok and type(files) == "table" then
                        local names = {}
                        for _, f in ipairs(files) do
                                local name = tostring(f):gsub("^" .. CACHE_FOLDER .. "/", "")
                                if name:sub(-5) == ".flac" or name:sub(-4) == ".mp3" or name:sub(-4) == ".ogg" then
                                        table.insert(names, name)
                                end
                        end
                        return names
                end
        end
        return {}
end

local function writeCacheOrder(names)
        if FS.write then
                pcall(FS.write, cacheOrderPath(), HttpService:JSONEncode(names))
        end
end

local function trimCache(names)
        if FS.delFile then
                while #names > CACHE_LIMIT do
                        local victim = table.remove(names, 1)
                        pcall(FS.delFile, CACHE_FOLDER .. "/" .. victim)
                end
        end
        return names
end

local CACHE_EXTS = { "flac", "mp3", "ogg" }

local function evictCache(trackId)
        if not FS.delFile then return end
        for _, ext in ipairs(CACHE_EXTS) do
                pcall(FS.delFile, CACHE_FOLDER .. "/" .. tostring(trackId) .. "." .. ext)
        end
        local victim = {}
        for _, n in ipairs(readCacheOrder()) do
                local keep = true
                for _, ext in ipairs(CACHE_EXTS) do
                        if n == tostring(trackId) .. "." .. ext then
                                keep = false
                                break
                        end
                end
                if keep then
                        table.insert(victim, n)
                end
        end
        writeCacheOrder(victim)
end

local ART_CACHE_LIMIT = 40

local function artOrderPath()
        return CACHE_FOLDER .. "/.artorder"
end

local function readArtOrder()
        if FS.read then
                local ok, body = pcall(FS.read, artOrderPath())
                if ok and type(body) == "string" and #body > 2 then
                        local okD, data = pcall(function()
                                return HttpService:JSONDecode(body)
                        end)
                        if okD and type(data) == "table" then
                                local names = {}
                                for _, n in ipairs(data) do
                                        if type(n) == "string" then
                                                table.insert(names, n)
                                        end
                                end
                                return names
                        end
                end
        end
        return {}
end

local function writeArtOrder(names)
        if FS.write then
                pcall(FS.write, artOrderPath(), HttpService:JSONEncode(names))
        end
end

local function trimArtCache(names)
        if FS.delFile then
                while #names > ART_CACHE_LIMIT do
                        local victim = table.remove(names, 1)
                        pcall(FS.delFile, CACHE_FOLDER .. "/" .. victim)
                end
        end
        return names
end

-- Artwork is displayed through a locally cached file served by getcustomasset,
-- because Roblox's own texture fetcher often fails on third-party URLs.
local function cacheArtwork(tr)
        if not FS.write or not customAsset then return nil end
        local url = tostring(tr and tr.artwork or "")
        if url == "" then return nil end
        ensureCacheFolder()
        local name = "art_" .. tostring(tr.id) .. ".jpg"
        local path = CACHE_FOLDER .. "/" .. name
        if FS.isFile and FS.isFile(path) then
                local okC, cached = pcall(customAsset, path)
                if okC and type(cached) == "string" and #cached > 0 then
                        return cached
                end
        end
        local body, code = httpGet(url)
        if code ~= 200 or type(body) ~= "string" or #body < 100 then
                return nil
        end
        local isPng = body:byte(1) == 137 and body:byte(2) == 80
        local isJpg = body:byte(1) == 255 and body:byte(2) == 216
        if not isJpg and not isPng then
                return nil
        end
        if isPng then
                name = "art_" .. tostring(tr.id) .. ".png"
                path = CACHE_FOLDER .. "/" .. name
        end
        if not pcall(FS.write, path, body) then
                return nil
        end
        local names = readArtOrder()
        local present = false
        for _, n in ipairs(names) do
                if n == name then
                        present = true
                        break
                end
        end
        if not present then
                table.insert(names, name)
        end
        writeArtOrder(trimArtCache(names))
        local okA, asset = pcall(customAsset, path)
        if okA and type(asset) == "string" and #asset > 0 then
                return asset
        end
        return nil
end

local refreshCacheStatus = function() end

local function audioFormatOf(body)
        if type(body) ~= "string" or #body < 8 then return nil end
        if body:sub(1, 4) == "fLaC" then return "flac" end
        if body:sub(1, 4) == "OggS" then return "ogg" end
        if body:sub(1, 3) == "ID3" or body:byte(1) == 255 then return "mp3" end
        return nil
end

local function downloadToCache(tr, url)
        if not FS.write or not customAsset then
                return nil, "no file system"
        end
        ensureCacheFolder()
        for _, ext in ipairs(CACHE_EXTS) do
                local cpath = CACHE_FOLDER .. "/" .. tostring(tr.id) .. "." .. ext
                if FS.isFile and FS.isFile(cpath) then
                        local okC, cached = pcall(customAsset, cpath)
                        if okC and type(cached) == "string" and #cached > 0 then
                                return cached
                        end
                end
        end
        local body, code, clen = httpGet(url)
        if code ~= 200 or type(body) ~= "string" or #body == 0 then
                return nil, "download HTTP " .. tostring(code)
        end
        if clen and clen > 0 and #body < clen * 0.98 then
                return nil, "truncated download"
        end
        local ext = audioFormatOf(body)
        if not ext then
                return nil, "response is not an audio stream"
        end
        if #body > 83886080 then
                return nil, "file too large to cache"
        end
        if ext == "flac" then
                if #body < 4096 then
                        return nil, "download too small"
                end
        elseif #body < 65536 then
                return nil, "download too small"
        end
        local name = tostring(tr.id) .. "." .. ext
        local path = CACHE_FOLDER .. "/" .. name
        local okW, errW = pcall(FS.write, path, body)
        if not okW then
                return nil, "writefile: " .. tostring(errW)
        end
        local names = readCacheOrder()
        local present = false
        for _, n in ipairs(names) do
                if n == name then
                        present = true
                        break
                end
        end
        if not present then
                table.insert(names, name)
        end
        names = trimCache(names)
        writeCacheOrder(names)
        refreshCacheStatus()
        local okA, asset = pcall(customAsset, path)
        if okA and type(asset) == "string" and #asset > 0 then
                return asset
        end
        evictCache(tr.id)
        return nil, "getcustomasset failed"
end

local scClientId = SC_FALLBACK_ID
local scRefreshed = false

local function refreshScId()
        scRefreshed = true
        local body, code = httpGet(SC_HOME)
        if code ~= 200 or type(body) ~= "string" then
                return nil
        end
        local seen = {}
        local tried = 0
        for assetUrl in body:gmatch("https://a%-v2%.sndcdn%.com/assets/[%w%.%-]+%.js") do
                if not seen[assetUrl] then
                        seen[assetUrl] = true
                        tried = tried + 1
                        if tried > 10 then
                                break
                        end
                        local js, jsCode = httpGet(assetUrl)
                        if jsCode == 200 and type(js) == "string" then
                                local cid = js:match('client_id:"([%w%-_]+)"')
                                if cid and #cid >= 20 then
                                        scClientId = cid
                                        return cid
                                end
                        end
                end
        end
        return nil
end

local function scSearchUrl(query, offset)
        return SC_API .. "/search/tracks?q=" .. urlEncode(query)
                .. "&limit=50&offset=" .. tostring(offset or 0)
                .. "&client_id=" .. scClientId
end

local SC_NOISE_WORDS = {
        official = true, video = true, audio = true, lyric = true, lyrics = true,
        visualizer = true, hq = true, hd = true, feat = true, ft = true,
        prod = true, free = true, download = true, topic = true, w = true,
        full = true, by = true,
}

local SC_VARIANT_TAGS = {
        "remix", "sped", "slowed", "nightcore", "karaoke", "cover",
        "instrumental", "acapella", "extended", "bootleg", "mashup",
        "flip", "edit", "reverb", "8d", "16d", "acoustic", "tribute",
        "version", "mix", "live", "remodel", "rework", "refix", "retouch",
        "rethink", "remake", "rmx", "dub", "vip", "radio",
}

local SC_PAREN_ALLOW = { "feat", "ft.", "with", "from", "prod", "original" }

local function scParenPenalty(title, targetRaw)
        local raw = tostring(title or ""):lower()
        local target = tostring(targetRaw or ""):lower()
        local penalty = 0
        local function scan(content)
                if content == "" then return end
                for _, mk in ipairs(SC_PAREN_ALLOW) do
                        if content:find(mk, 1, true) then return end
                end
                for w in content:gmatch("%w+") do
                        if not tonumber(w) and not SC_NOISE_WORDS[w] and not target:find(w, 1, true) then
                                penalty = penalty + 5
                        end
                end
        end
        for content in raw:gmatch("%(([^()]*)%)") do
                scan(content)
        end
        for content in raw:gmatch("%[([^%[%]]*)%]") do
                scan(content)
        end
        return math.min(15, penalty)
end

local function scNormWords(s)
        s = tostring(s or ""):lower()
        s = s:gsub("[^%w%s]", " ")
        s = s:gsub("%s+", " ")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        if s == "" then return " " end
        return " " .. s .. " "
end

local function scNormTitle(s)
        s = tostring(s or ""):lower()
        s = s:gsub("%b()", " "):gsub("%b[]", " ")
        s = s:gsub("[^%w%s]", " ")
        s = s:gsub("%s+", " ")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        if s == "" then return " " end
        return " " .. s .. " "
end

local function scTokenSet(padded)
        local set, list = {}, {}
        for w in padded:gmatch("%S+") do
                if not SC_NOISE_WORDS[w] and not set[w] then
                        set[w] = true
                        table.insert(list, w)
                end
        end
        return set, list
end

local function scJaccard(aSet, aList, bSet, bList)
        if #aList == 0 or #bList == 0 then return 0 end
        local inter = 0
        for _, w in ipairs(aList) do
                if bSet[w] then inter = inter + 1 end
        end
        return inter / (#aList + #bList - inter)
end

local function scArtistScore(candText, targetArtists)
        if #targetArtists == 0 then return 60 end
        local hit = 0
        for _, toks in ipairs(targetArtists) do
                local found = false
                for _, w in ipairs(toks) do
                        if candText:find(" " .. w .. " ", 1, true) or (#w >= 5 and candText:find(w, 1, true)) then
                                found = true
                                break
                        end
                end
                if found then hit = hit + 1 end
        end
        return (hit / #targetArtists) * 100
end

local function scBestProgressive(data, tr)
        local collection = type(data.collection) == "table" and data.collection or {}
        local targetTitle = scNormTitle(tr.title)
        local targetTags = scNormWords(tr.title)
        local targetRaw = tostring(tr.title or ""):lower()
        local tSet, tList = scTokenSet(targetTitle)
        local targetArtists = {}
        for name in tostring(tr.artist or ""):gmatch("[^,]+") do
                local toks = {}
                for w in scNormWords(name):gmatch("%S+") do
                        if #w >= 3 then table.insert(toks, w) end
                end
                if #toks > 0 then table.insert(targetArtists, toks) end
        end
        local artistWords = {}
        for _, toks in ipairs(targetArtists) do
                for _, w in ipairs(toks) do
                        artistWords[w] = true
                end
        end
        local targetMs = (tonumber(tr.duration) or 0) * 1000
        local ranked = {}
        for _, item in ipairs(collection) do
                if type(item) == "table" and item.kind == "track" then
                        local policy = tostring(item.policy or "")
                        if policy ~= "BLOCK" and policy ~= "SNIP" then
                                local hasMpeg = false
                                local media = type(item.media) == "table" and item.media or {}
                                local transcodings = type(media.transcodings) == "table" and media.transcodings or {}
                                for _, tc in ipairs(transcodings) do
                                        if type(tc) == "table" then
                                                local fmt = type(tc.format) == "table" and tc.format or {}
                                                if fmt.mime_type == "audio/mpeg" then
                                                        hasMpeg = true
                                                        break
                                                end
                                        end
                                end
                                if hasMpeg then
                                        local candTags = scNormWords(item.title)
                                        local candTitle = scNormTitle(item.title)
                                        local cSet, cList = scTokenSet(candTitle)
                                        local cListF, cSetF = {}, {}
                                        for _, w in ipairs(cList) do
                                                if not artistWords[w] then
                                                        table.insert(cListF, w)
                                                        cSetF[w] = true
                                                end
                                        end
                                        local titleSim = scJaccard(tSet, tList, cSetF, cListF) * 100
                                        local userObj = type(item.user) == "table" and item.user or {}
                                        local candArtistText = candTags .. " "
                                                .. scNormWords(userObj.username) .. " "
                                                .. scNormWords(userObj.full_name)
                                        local artistScore = scArtistScore(candArtistText, targetArtists)
                                        local dur = tonumber(item.duration) or 0
                                        local diff = math.abs(dur - targetMs)
                                        if diff <= 25000 then
                                                local durScore = math.max(0, 100 - (diff / 1000) * 8)
                                                local penalty = 0
                                                local variantTags = 0
                                                for _, tag in ipairs(SC_VARIANT_TAGS) do
                                                        local inT = targetTags:find(" " .. tag .. " ", 1, true) ~= nil
                                                        local inC = candTags:find(" " .. tag .. " ", 1, true) ~= nil
                                                        if inC and not inT then
                                                                variantTags = variantTags + 1
                                                        elseif inT and not inC then
                                                                penalty = penalty + 12
                                                        end
                                                end
                                                penalty = penalty + 30 * variantTags
                                                local extra = 0
                                                for _, w in ipairs(cListF) do
                                                        if not tSet[w] then
                                                                extra = extra + 1
                                                        end
                                                end
                                                penalty = penalty + math.min(24, 8 * extra)
                                                penalty = penalty + scParenPenalty(item.title, targetRaw)
                                                local score = titleSim * 0.45 + artistScore * 0.25 + durScore * 0.30 - penalty
                                                if score >= 35 then
                                                        table.insert(ranked, { item = item, diff = diff, score = score })
                                                end
                                        end
                                end
                        end
                end
        end
        table.sort(ranked, function(a, b)
                return a.score > b.score
        end)
        while #ranked > 5 do
                table.remove(ranked)
        end
        return ranked
end

local function scDirectMp3(item)
        local media = type(item.media) == "table" and item.media or {}
        local transcodings = type(media.transcodings) == "table" and media.transcodings or {}
        local tried = {}
        for _, tc in ipairs(transcodings) do
                if type(tc) == "table" and type(tc.url) == "string" and not tried[tc.url] then
                        tried[tc.url] = true
                        local fmt = type(tc.format) == "table" and tc.format or {}
                        if fmt.mime_type == "audio/mpeg" then
                                local signed, code = httpGet(tc.url .. "?client_id=" .. scClientId)
                                if code == 200 and type(signed) == "string" then
                                        local okS, sdata = pcall(function()
                                                return HttpService:JSONDecode(signed)
                                        end)
                                        if okS and type(sdata) == "table" and type(sdata.url) == "string"
                                                and sdata.url ~= "" and not sdata.url:find(".m3u8", 1, true) then
                                                return sdata.url
                                        end
                                end
                        end
                end
        end
        return nil
end

local function scFetchRanked(query, offset, tr, ranked, seenIds)
        local body, code = httpGet(scSearchUrl(query, offset))
        if code == 401 or code == 403 then
                if scRefreshed then
                        return false, "SoundCloud rejected the client id"
                end
                if not refreshScId() then
                        return false, "SoundCloud rejected the client id"
                end
                body, code = httpGet(scSearchUrl(query, offset))
        end
        if code ~= 200 or type(body) ~= "string" then
                return false, "SoundCloud HTTP " .. tostring(code)
        end
        local okD, data = pcall(function()
                return HttpService:JSONDecode(body)
        end)
        if not okD or type(data) ~= "table" then
                return false, "SoundCloud sent an unreadable response"
        end
        for _, entry in ipairs(scBestProgressive(data, tr)) do
                local id = tostring((type(entry.item) == "table" and entry.item.id) or "")
                if id == "" or not seenIds[id] then
                        seenIds[id] = true
                        table.insert(ranked, entry)
                end
        end
        table.sort(ranked, function(a, b)
                return a.score > b.score
        end)
        return true
end

local function scPickTrack(tr)
        local query = tostring(tr.title or "")
        local hasArtist = tr.artist ~= nil and tr.artist ~= "" and tr.artist ~= "Unknown Artist"
        if hasArtist then
                query = query .. " " .. tr.artist
        end
        for attempt = 1, 2 do
                local ranked, seenIds = {}, {}
                local ok, err = scFetchRanked(query, 0, tr, ranked, seenIds)
                if not ok then
                        return nil, err
                end
                if #ranked > 0 and ranked[1].score < 70 then
                        scFetchRanked(query, 50, tr, ranked, seenIds)
                end
                for _, entry in ipairs(ranked) do
                        local mp3 = scDirectMp3(entry.item)
                        if mp3 then
                                local off = math.floor(entry.diff / 1000 + 0.5)
                                if off <= 0 then
                                        return mp3, "SoundCloud (exact length)"
                                end
                                return mp3, "SoundCloud (off by " .. off .. "s)"
                        end
                end
                if attempt == 1 and hasArtist then
                        query = tostring(tr.title or "")
                else
                        break
                end
        end
        return nil, "no SoundCloud match"
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[Monochrome] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Monochrome",
        Size = Vector2.new(560, 470),
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

local function clearCache()
        local names = readCacheOrder()
        for _, n in ipairs(readArtOrder()) do
                table.insert(names, n)
        end
        if FS.listFiles then
                local ok, files = pcall(FS.listFiles, CACHE_FOLDER)
                if ok and type(files) == "table" then
                        for _, f in ipairs(files) do
                                local name = tostring(f):gsub("^" .. CACHE_FOLDER .. "/", "")
                                table.insert(names, name)
                        end
                end
        end
        local removed = 0
        if FS.delFile then
                for _, n in ipairs(names) do
                        if pcall(FS.delFile, CACHE_FOLDER .. "/" .. n) then
                                removed = removed + 1
                        end
                end
        end
        writeCacheOrder({})
        writeArtOrder({})
        refreshCacheStatus()
        notify("Cache cleared", removed .. " files removed.")
end

local ui = {}
local state = {
        queue = {},
        index = 0,
        results = {},
        current = nil,
        loopMode = "Off",
        shuffle = false,
        scEnabled = true,
        monoEnabled = true,
        monoBroken = true,
        gen = 0,
        consecutiveFails = 0,
        lastSeekInput = 0,
        searchGen = 0,
        artGen = 0,
        sourceLabel = "-",
}

local SETTINGS_FILE = CACHE_FOLDER .. "/settings.json"

local function loadSettings()
        if FS.read then
                local ok, body = pcall(FS.read, SETTINGS_FILE)
                if ok and type(body) == "string" and #body > 2 then
                        local okD, data = pcall(function()
                                return HttpService:JSONDecode(body)
                        end)
                        if okD and type(data) == "table" and data.monoBroken ~= nil then
                                state.monoBroken = data.monoBroken and true or false
                        end
                end
        end
end

local function saveSettings()
        if FS.write then
                ensureCacheFolder()
                pcall(FS.write, SETTINGS_FILE, HttpService:JSONEncode({ monoBroken = state.monoBroken }))
        end
end

local function updateLosslessStatus()
        if ui.losslessStatus then
                ui.losslessStatus:Set(state.monoBroken
                        and "Lossless: disabled (Roblox cannot decode FLAC)"
                        or "Lossless: enabled - trying FLAC first")
        end
end

loadSettings()

local sound = Instance.new("Sound")
sound.Name = "MonochromePlayer"
sound.Volume = 0.5
sound.Parent = SoundService

local saveGen = 0
local function scheduleSave()
        saveGen = saveGen + 1
        local g = saveGen
        task.delay(1.5, function()
                if g == saveGen and running then
                        pcall(function()
                                Window:SaveConfig("default")
                        end)
                end
        end)
end

local function setSearchStatus(text)
        if ui.searchStatus then
                ui.searchStatus:Set(tostring(text))
        end
end

local function updateMetaLine()
        if ui.art then
                ui.art:SetMeta("Source: " .. tostring(state.sourceLabel or "-")
                        .. " - " .. fmtTime(sound.TimePosition) .. " / " .. fmtTime(sound.TimeLength))
        end
end

local function updateNowPlaying(tr, sourceLabel)
        state.sourceLabel = tostring(sourceLabel or "-")
        if ui.art then
                ui.art:SetVisible(tr ~= nil)
        end
        if tr == nil then
                updateMetaLine()
                return
        end
        if ui.art then
                ui.art:SetTitle(tr.title or "Unknown Title")
                ui.art:SetSubtitle(tr.artist or "-")
                local hasArt = (tr.artwork ~= nil and tr.artwork ~= "")
                if hasArt then
                        ui.art:SetImage(tr.artwork)
                        state.artGen = state.artGen + 1
                        local gen = state.artGen
                        task.spawn(function()
                                local asset = cacheArtwork(tr)
                                if running and asset and state.artGen == gen and ui.art then
                                        ui.art:SetImage(asset)
                                end
                        end)
                else
                        ui.art:SetImage("")
                end
        end
        updateMetaLine()
end

local function renderQueue()
        if not ui.queueList then return end
        local items = {}
        for i, tr in ipairs(state.queue) do
                local marker = (i == state.index and state.current) and "> " or ""
                table.insert(items, {
                        Text = marker .. tr.title,
                        Secondary = tr.artist,
                        Trailing = fmtTime(tr.duration),
                })
        end
        ui.queueList:SetItems(items)
        if state.current and state.index >= 1 and state.queue[state.index] then
                ui.queueList:SetSelected(state.index, false)
        end
        local total = 0
        for _, tr in ipairs(state.queue) do
                total = total + (tr.duration or 0)
        end
        if ui.queueStatus then
                ui.queueStatus:Set(#state.queue .. " tracks - " .. fmtTime(total))
        end
end

local function stopPlayback()
        state.gen = state.gen + 1
        sound:Stop()
        state.current = nil
        updateNowPlaying(nil, "-")
        if ui.playBtn then ui.playBtn:Set("Play") end
        renderQueue()
end

local playFromQueue, advance

local function onLoaded(sourceLabel)
        state.consecutiveFails = 0
        state.sourceLabel = tostring(sourceLabel or "-")
        updateMetaLine()
        if sound.TimeLength > 0 and ui.seek then
                ui.seek:SetRange(0, math.max(1, math.floor(sound.TimeLength)))
                ui.seek:Set(0, false)
        end
        if ui.playBtn then ui.playBtn:Set("Pause") end
        if state.current then
                notify(state.current.title, state.current.artist .. " - " .. tostring(sourceLabel or ""))
        end
end

local function buildSources(tr)
        local list = {}
        if state.monoEnabled and not state.monoBroken then
                table.insert(list, {
                        label = "Monochrome",
                        kind = "mono",
                        url = TRACKS_BASE .. "/track/" .. tostring(tr.id),
                })
        end
        if state.scEnabled then
                table.insert(list, { label = "SoundCloud", kind = "sc" })
        end
        return list
end

local function runResolver(src, tr)
        if src.kind == "sc" then
                return scPickTrack(tr)
        end
        return src.url, src.label
end

local function waitForSound(gen, budget)
        local waited = 0
        while waited < budget do
                task.wait(0.2)
                if not running or state.gen ~= gen then return false end
                if sound.IsLoaded or sound.TimeLength > 0 or sound.TimePosition > 0 then
                        return true
                end
                waited = waited + 0.2
        end
        return false
end

local function loadTrack(tr, gen)
        task.spawn(function()
                local sources = buildSources(tr)
                local reason = "no playback sources enabled"
                for _, src in ipairs(sources) do
                        if not running or state.gen ~= gen then return end
                        state.sourceLabel = "Loading via " .. src.label
                        updateMetaLine()
                        local url, info = runResolver(src, tr)
                        if not running or state.gen ~= gen then return end
                        if url then
                                local asset, err = downloadToCache(tr, url)
                                if not running or state.gen ~= gen then return end
                                if asset then
                                        sound:Stop()
                                        sound.SoundId = asset
                                        sound:Play()
                                        if waitForSound(gen, src.kind == "mono" and 8 or 15) then
                                                onLoaded(info or src.label)
                                                return
                                        end
                                        if not running or state.gen ~= gen then return end
                                        sound:Stop()
                                        evictCache(tr.id)
                                        reason = src.label .. " audio never loaded"
                                        if src.kind == "mono" and not state.monoBroken then
                                                state.monoBroken = true
                                                saveSettings()
                                                updateLosslessStatus()
                                                notify("Lossless disabled", "Roblox cannot decode FLAC - using MP3 sources.")
                                        end
                                else
                                        reason = src.label .. ": " .. tostring(err)
                                end
                        else
                                reason = tostring(info)
                        end
                end
                if not running or state.gen ~= gen then return end
                state.consecutiveFails = state.consecutiveFails + 1
                if state.current then
                        notify("Could not load", state.current.title .. " - " .. tostring(reason))
                end
                if state.consecutiveFails >= 5 then
                        state.consecutiveFails = 0
                        stopPlayback()
                        notify("Stopped", "Too many tracks failed in a row.")
                        return
                end
                advance(1, true)
        end)
end

function playFromQueue(userInitiated)
        local tr = state.queue[state.index]
        if not tr then return end
        state.gen = state.gen + 1
        local gen = state.gen
        state.current = tr
        if userInitiated then
                state.consecutiveFails = 0
        end
        sound:Stop()
        updateNowPlaying(tr, "Loading...")
        if ui.playBtn then ui.playBtn:Set("Pause") end
        renderQueue()
        if not customAsset or not FS.write then
                notify("Cannot play", "This executor has no getcustomasset/writefile, audio cannot be loaded.")
                return
        end
        loadTrack(tr, gen)
end

function advance(delta, auto)
        local n = #state.queue
        if n == 0 then
                notify("Queue is empty", "Search for a song and click a result.")
                return
        end
        if state.shuffle and n > 1 then
                local pick = state.index
                while pick == state.index do
                        pick = math.random(1, n)
                end
                state.index = pick
        else
                local nextIdx = state.index + delta
                if nextIdx > n then
                        if auto and state.loopMode ~= "All" then
                                stopPlayback()
                                return
                        end
                        nextIdx = 1
                elseif nextIdx < 1 then
                        nextIdx = (state.loopMode == "All") and n or 1
                end
                state.index = nextIdx
        end
        playFromQueue(not auto)
end

local function prevTrack()
        if state.current and sound.TimeLength > 0 and sound.TimePosition > 3 then
                sound.TimePosition = 0
                return
        end
        advance(-1, false)
end

local function togglePlayPause()
        if not state.current then
                if #state.queue > 0 then
                        if state.index < 1 then state.index = 1 end
                        playFromQueue(true)
                else
                        notify("Nothing to play", "Search for a song and click a result.")
                end
                return
        end
        if sound.Playing then
                sound:Pause()
                if ui.playBtn then ui.playBtn:Set("Play") end
        else
                sound:Play()
                if ui.playBtn then ui.playBtn:Set("Pause") end
        end
end

local function autoAdvance()
        if not running then return end
        if state.loopMode == "One" and state.current then
                sound:Play()
                return
        end
        advance(1, true)
end

local function playNow(tr)
        if not tr then return end
        local existing = 0
        for i, q in ipairs(state.queue) do
                if q.id == tr.id then
                        existing = i
                        break
                end
        end
        if existing > 0 then
                state.index = existing
        else
                table.insert(state.queue, tr)
                state.index = #state.queue
        end
        playFromQueue(true)
end

local function jumpTo(i)
        if state.queue[i] then
                state.index = i
                playFromQueue(true)
        end
end

local function removeCurrent()
        if state.index < 1 or not state.queue[state.index] then
                notify("Nothing playing", "Play a track first.")
                return
        end
        local i = state.index
        state.gen = state.gen + 1
        sound:Stop()
        table.remove(state.queue, i)
        state.index = math.min(i, #state.queue)
        state.current = nil
        updateNowPlaying(nil, "-")
        if ui.playBtn then ui.playBtn:Set("Play") end
        renderQueue()
end

local function clearQueue()
        state.queue = {}
        state.index = 0
        stopPlayback()
end

local function renderResults()
        if not ui.resultList then return end
        local items = {}
        for _, tr in ipairs(state.results) do
                table.insert(items, {
                        Text = tr.title .. (tr.explicit and " [E]" or ""),
                        Secondary = tr.artist,
                        Trailing = (tr.playable == false) and "N/A" or fmtTime(tr.duration),
                        Track = tr,
                })
        end
        ui.resultList:SetItems(items)
end

local function runSearch(query)
        query = tostring(query or "")
        query = query:gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then
                setSearchStatus("Type something to search.")
                return
        end
        state.searchGen = state.searchGen + 1
        local gen = state.searchGen
        setSearchStatus("Searching...")
        task.spawn(function()
                local ok, res = pcall(httpRequest, {
                        Url = TRACKS_BASE .. "/search/tracks?q=" .. urlEncode(query) .. "&limit=25",
                        Method = "GET",
                        Headers = {
                                ["Accept"] = "application/json",
                                ["User-Agent"] = USER_AGENT,
                        },
                })
                if not running or gen ~= state.searchGen then return end
                if not ok or type(res) ~= "table" or (type(res.StatusCode) == "number" and res.StatusCode ~= 200) then
                        setSearchStatus("Search failed.")
                        return
                end
                local okDecode, data = pcall(function()
                        return HttpService:JSONDecode(tostring(res.Body or ""))
                end)
                if not okDecode or type(data) ~= "table" or type(data.tracks) ~= "table" then
                        setSearchStatus("Search returned an unreadable response.")
                        return
                end
                state.results = {}
                local seenKeys = {}
                for _, raw in ipairs(data.tracks) do
                        if type(raw) == "table" and raw.trackId ~= nil then
                                local dur = tonumber(raw.duration) or 0
                                if dur > 1000 then dur = math.floor(dur / 1000) end
                                local names = type(raw.artistNames) == "table" and raw.artistNames or {}
                                local t = {
                                        id = tostring(raw.trackId),
                                        title = tostring(raw.title or "Unknown Title"),
                                        artist = (#names > 0 and table.concat(names, ", ")) or "Unknown Artist",
                                        duration = dur,
                                        isrc = (raw.isrc ~= nil and raw.isrc ~= "") and tostring(raw.isrc) or nil,
                                        artwork = (raw.artwork ~= nil and raw.artwork ~= "") and tostring(raw.artwork) or "",
                                        explicit = raw.explicit and true or false,
                                        playable = (raw.playable == false) and false or true,
                                }
                                local key = string.lower(t.title) .. "\t" .. string.lower(t.artist)
                                local prev = seenKeys[key]
                                if prev == nil then
                                        seenKeys[key] = t
                                        table.insert(state.results, t)
                                elseif (t.playable and not prev.playable)
                                        or (t.playable == prev.playable and t.isrc and not prev.isrc) then
                                        for k, v in pairs(t) do
                                                prev[k] = v
                                        end
                                end
                        end
                end
                renderResults()
                setSearchStatus(#state.results .. " results")
        end)
end

local function applyConfig()
        pcall(function()
                Window:LoadConfig("default")
        end)
        local loopVal = ui.loop and ui.loop.Value
        if loopVal ~= "One" and loopVal ~= "All" then
                loopVal = "Off"
        end
        state.loopMode = loopVal
        state.shuffle = (ui.shuffle and ui.shuffle.Value) and true or false
        state.scEnabled = not (ui.scEnabled and ui.scEnabled.Value == false)
        state.monoEnabled = not (ui.monoEnabled and ui.monoEnabled.Value == false)
        local vol = 50
        if ui.volume and type(ui.volume.Value) == "number" then
                vol = ui.volume.Value
        end
        sound.Volume = vol / 100
end

local searchTab = Window:Tab("Search", "search")
local searchSection = searchTab:Section("Search")

ui.query = searchSection:Input({
        Text = "Query",
        Placeholder = "Song or artist...",
        Live = true,
        Debounce = 0.5,
        Callback = function(text, enter)
                if enter then
                        runSearch(text)
                elseif tostring(text):gsub("%s+", "") ~= "" then
                        runSearch(text)
                end
        end,
})

searchSection:Button({
        Text = "Search",
        Primary = true,
        Callback = function()
                runSearch(ui.query and ui.query.Text or "")
        end,
})

ui.searchStatus = searchSection:Paragraph({
        Text = "Type to search.",
})

ui.resultList = searchSection:List({
        Text = "Results",
        Height = 130,
        MaxHeight = 250,
        Callback = function(item)
                if item and item.Track then
                        playNow(item.Track)
                end
        end,
})

local playerTab = Window:Tab("Player", "music")
local playerSection = playerTab:Section("Now Playing")

ui.art = playerSection:Image({
        Height = 104,
        ScaleType = "Fit",
        Title = "Nothing playing",
        Subtitle = "-",
        Meta = "Source: -",
})
ui.art:SetVisible(false)

ui.seek = playerSection:Slider({
        Text = "Seek",
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 0,
        Format = function(v)
                return fmtTime(v)
        end,
        Callback = function(v)
                state.lastSeekInput = os.clock()
                if sound.IsLoaded and sound.TimeLength > 0 then
                        sound.TimePosition = clampN(v, 0, sound.TimeLength)
                end
        end,
})

local controlsRow = playerSection:Row({ Gap = 8 })

controlsRow:Button({
        Text = "Prev",
        Callback = function()
                prevTrack()
        end,
})

ui.playBtn = controlsRow:Button({
        Text = "Play",
        Primary = true,
        Callback = function()
                togglePlayPause()
        end,
})

controlsRow:Button({
        Text = "Next",
        Callback = function()
                advance(1, false)
        end,
})

controlsRow:Button({
        Text = "Stop",
        Callback = function()
                stopPlayback()
        end,
})

ui.volume = playerSection:Slider({
        Text = "Volume",
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 50,
        Suffix = "%",
        Flag = "Volume",
        Callback = function(v)
                sound.Volume = v / 100
                scheduleSave()
        end,
})

local modeRow = playerSection:Row({ Gap = 8 })

ui.loop = modeRow:Dropdown({
        Text = "Loop",
        Options = { "Off", "One", "All" },
        Value = "Off",
        Flag = "Loop",
        Callback = function(v)
                state.loopMode = tostring(v)
                scheduleSave()
        end,
})

ui.shuffle = modeRow:Toggle({
        Text = "Shuffle",
        Value = false,
        Flag = "Shuffle",
        Callback = function(v)
                state.shuffle = v and true or false
                scheduleSave()
        end,
})

local queueTab = Window:Tab("Queue", "list")
local queueSection = queueTab:Section("Queue")

ui.queueList = queueSection:List({
        Text = "Queue",
        Height = 130,
        MaxHeight = 250,
        Callback = function(item, index)
                jumpTo(index)
        end,
})

local queueRow = queueSection:Row({ Gap = 8 })

queueRow:Button({
        Text = "Remove Playing",
        Callback = function()
                removeCurrent()
        end,
})

queueRow:Button({
        Text = "Clear Queue",
        Callback = function()
                clearQueue()
        end,
})

ui.queueStatus = queueSection:Paragraph({
        Text = "0 tracks",
})

local settingsTab = Window:Tab("Settings", "settings")
local sourcesSection = settingsTab:Section("Playback Sources")

ui.monoEnabled = sourcesSection:Toggle({
        Text = "Use Monochrome (lossless)",
        Value = true,
        Flag = "MonoEnabled",
        Callback = function(v)
                state.monoEnabled = v and true or false
                scheduleSave()
        end,
})

ui.scEnabled = sourcesSection:Toggle({
        Text = "Use SoundCloud",
        Value = true,
        Flag = "ScEnabled",
        Callback = function(v)
                state.scEnabled = v and true or false
                scheduleSave()
        end,
})

ui.losslessStatus = sourcesSection:Paragraph({
        Text = "Lossless: -",
})

sourcesSection:Button({
        Text = "Retry lossless (FLAC)",
        Callback = function()
                state.monoBroken = false
                saveSettings()
                updateLosslessStatus()
                notify("Lossless retry", "The next track will try the FLAC source again.")
        end,
})

sourcesSection:Paragraph({
        Text = "Roblox only decodes MP3/OGG, so lossless FLAC is skipped until it works. SoundCloud matches by title, artist, version tags and duration.",
})

updateLosslessStatus()

local cacheSection = settingsTab:Section("Cache")

ui.cacheStatus = cacheSection:Paragraph({
        Text = "0 cached tracks",
})

refreshCacheStatus = function()
        if ui.cacheStatus then
                ui.cacheStatus:Set(#readCacheOrder() .. " cached tracks (max " .. CACHE_LIMIT .. ")")
        end
end

refreshCacheStatus()

cacheSection:Button({
        Text = "Clear cache",
        Callback = function()
                clearCache()
        end,
})

local keybindsSection = settingsTab:Section("Keybinds")

keybindsSection:Keybind({
        Text = "Toggle UI",
        Value = "RightShift",
        Mode = "Always",
        Flag = "BindToggle",
        Callback = function()
                Window:Toggle()
        end,
})

keybindsSection:Keybind({
        Text = "Play / Pause",
        Value = "None",
        Mode = "Always",
        Flag = "BindPlay",
        Callback = function()
                togglePlayPause()
        end,
})

keybindsSection:Keybind({
        Text = "Next",
        Value = "None",
        Mode = "Always",
        Flag = "BindNext",
        Callback = function()
                advance(1, false)
        end,
})

keybindsSection:Keybind({
        Text = "Previous",
        Value = "None",
        Mode = "Always",
        Flag = "BindPrev",
        Callback = function()
                prevTrack()
        end,
})

local configSection = settingsTab:Section("Config")

ui.cfgStatus = configSection:Paragraph({
        Text = "Settings auto-save.",
})

configSection:Button({
        Text = "Save Now",
        Callback = function()
                local ok = false
                pcall(function()
                        ok = Window:SaveConfig("default")
                end)
                ui.cfgStatus:Set(ok and "Saved." or "Save failed - this executor has no file system.")
        end,
})

configSection:Button({
        Text = "Reload",
        Callback = function()
                applyConfig()
                ui.cfgStatus:Set("Reloaded.")
        end,
})

track(sound.Ended:Connect(autoAdvance))

task.spawn(function()
        while running do
                task.wait(0.25)
                if sound.IsLoaded and sound.TimeLength > 0 then
                        if ui.seek and os.clock() - state.lastSeekInput > 0.5 then
                                ui.seek:Set(sound.TimePosition, false)
                        end
                        updateMetaLine()
                end
        end
end)

applyConfig()
renderQueue()

local function cleanup()
        if not running then
                return
        end
        running = false
        pcall(function()
                Window:SaveConfig("default")
        end)
        disconnectAll()
        pcall(function()
                sound:Stop()
        end)
        pcall(function()
                sound:Destroy()
        end)
end

Global.__MonochromePlayerCleanup = cleanup

track(Window.Gui.Destroying:Connect(cleanup))
