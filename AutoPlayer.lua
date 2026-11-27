local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local VERSION = "0.9.1"
local MIDI_FOLDER = "midis"
local CONFIG_FILE = "AutoPlayer.json"
local REBORN_URL = "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
local UNLOAD_KEY = "AutoPlayerInstance"
local NOTE_OFFSET = 35
local MIN_NOTE = -14
local MAX_NOTE = 73
local MIN_NOTE_SECONDS = 0.03
local PROGRESS_INTERVAL = 0.25
local RECAPTURE_INTERVAL = 2

local global = getgenv()
local previousInstance = global[UNLOAD_KEY]
if type(previousInstance) == "function" then
    pcall(previousInstance)
end
if global[UNLOAD_KEY] == previousInstance then
    global[UNLOAD_KEY] = nil
end

local Reborn = loadstring(game:HttpGet(REBORN_URL .. "?t=" .. tostring(DateTime.now().UnixTimestampMillis)))()

local function fileFunction(name)
    local fn = getfenv()[name]
    if type(fn) == "function" then return fn end
    fn = global[name]
    if type(fn) == "function" then return fn end
    fn = rawget(_G, name)
    if type(fn) == "function" then return fn end
end

local function ensureFolder()
    local exists, create = fileFunction("isfolder"), fileFunction("makefolder")
    if not exists or not create then return true end
    local ok, found = pcall(exists, MIDI_FOLDER)
    if not ok then return false, "Could not check MIDI folder" end
    if found then return true end
    local made = pcall(create, MIDI_FOLDER)
    if not made then
        local checked, present = pcall(exists, MIDI_FOLDER)
        if not checked or not present then return false, "Could not create MIDI folder" end
    end
    return true
end

local function isMidiName(name)
    return type(name) == "string"
        and not name:find("[/\\]")
        and not name:find("%z")
        and name:lower():match("%.midi?$") ~= nil
end

local function listMidiNames()
    local list = fileFunction("listfiles")
    if not list then return nil, "File listing unavailable" end
    local ready, err = ensureFolder()
    if not ready then return nil, err end
    local ok, files = pcall(list, MIDI_FOLDER)
    if not ok or type(files) ~= "table" then return nil, "Could not list MIDI files" end
    local names, seen = {}, {}
    for _, path in ipairs(files) do
        if type(path) == "string" then
            local name = path:match("[^/\\]+$")
            if isMidiName(name) and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    table.sort(names, function(a, b)
        local lowerA, lowerB = a:lower(), b:lower()
        if lowerA == lowerB then return a < b end
        return lowerA < lowerB
    end)
    return names
end

local function readMidiFile(name)
    if not isMidiName(name) then return nil, "Invalid MIDI filename" end
    local read = fileFunction("readfile")
    if not read then return nil, "File reading unavailable" end
    local ok, data = pcall(read, MIDI_FOLDER .. "/" .. name)
    if not ok or type(data) ~= "string" then return nil, "Could not read file" end
    if #data == 0 then return nil, "MIDI file is empty" end
    return data
end

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local function midiName(midi)
    local pitch = midi % 12
    local octave = math.floor(midi / 12) - 1
    return NOTE_NAMES[pitch + 1] .. tostring(octave)
end

local function fmtTime(sec)
    if sec ~= sec or sec == math.huge or sec == -math.huge then
        return "0:00"
    end
    sec = math.max(0, sec)
    return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local MidiParser = {}

function MidiParser.parse(data)
    if type(data) ~= "string" or #data < 14 then
        return nil, "file too small"
    end
    local buf = buffer.fromstring(data)
    local len = buffer.len(buf)

    local function u8(p)
        if p < 0 or p >= len then
            return 0
        end
        return buffer.readu8(buf, p)
    end
    local function be16(p)
        return u8(p) * 256 + u8(p + 1)
    end
    local function be32(p)
        return u8(p) * 16777216 + u8(p + 1) * 65536 + u8(p + 2) * 256 + u8(p + 3)
    end
    local function vlq(p, limit)
        local v = 0
        for _ = 1, 4 do
            if p >= limit then return nil, p end
            local b = u8(p)
            p += 1
            v = v * 128 + bit32.band(b, 0x7F)
            if b < 0x80 then return v, p end
        end
        return nil, p
    end

    if data:sub(1, 4) ~= "MThd" then
        return nil, "missing MThd header"
    end
    local headerLen = be32(4)
    if headerLen < 6 or 8 + headerLen > len then
        return nil, "bad header length"
    end
    local trackCount = be16(10)
    local division = be16(12)
    if trackCount == 0 or trackCount > 512 then
        return nil, "bad track count"
    end

    local smpte = nil
    local ppq = bit32.band(division, 0x7FFF)
    if bit32.band(division, 0x8000) ~= 0 then
        local fps = 256 - bit32.band(bit32.rshift(division, 8), 0xFF)
        local tpf = bit32.band(division, 0xFF)
        if fps < 24 or fps > 30 or tpf == 0 then
            return nil, "bad SMPTE timing"
        end
        smpte = 1 / (fps * tpf)
    elseif ppq == 0 then
        ppq = 480
    end

    local tempoChanges = {}
    local allNotes = {}
    local sustainRaw = {}
    local pos = 8 + headerLen
    local tracksRead = 0

    while tracksRead < trackCount do
        if pos + 8 > len then return nil, "missing track header" end
        local chunk = data:sub(pos + 1, pos + 4)
        local trackLen = be32(pos + 4)
        local p = pos + 8
        local trackEnd = p + trackLen
        if trackEnd > len then return nil, "truncated track chunk" end
        pos = trackEnd
        if chunk ~= "MTrk" then continue end

        local ticks = 0
        local running = nil
        local open = {}

        local function finishNote(first, note, at)
            allNotes[#allNotes + 1] = {
                startTicks = first.t,
                durTicks = math.max(at - first.t, 1),
                note = note,
                vel = first.vel,
            }
        end

        while p < trackEnd do
            local delta, np = vlq(p, trackEnd)
            if delta == nil or np >= trackEnd then
                return nil, "invalid event delta"
            end
            ticks += delta
            p = np
            local status = u8(p)
            if status == 0xFF then
                if p + 2 >= trackEnd then return nil, "truncated meta event" end
                local metaType = u8(p + 1)
                local mlen, payload = vlq(p + 2, trackEnd)
                if mlen == nil or payload + mlen > trackEnd then
                    return nil, "invalid meta event length"
                end
                if metaType == 0x51 and mlen == 3 then
                    local tempo = u8(payload) * 65536 + u8(payload + 1) * 256 + u8(payload + 2)
                    if tempo > 0 then
                        tempoChanges[#tempoChanges + 1] = {ticks = ticks, tempo = tempo, order = #tempoChanges + 1}
                    end
                end
                p = payload + mlen
                if metaType == 0x2F then break end
            elseif status == 0xF0 or status == 0xF7 then
                running = nil
                local slen, payload = vlq(p + 1, trackEnd)
                if slen == nil or payload + slen > trackEnd then
                    return nil, "invalid SysEx length"
                end
                p = payload + slen
            else
                local op
                if status >= 0x80 and status <= 0xEF then
                    op = status
                    running = status
                    p += 1
                elseif status < 0x80 then
                    op = running
                end
                if not op then return nil, "invalid running status" end
                local hi = bit32.band(op, 0xF0)
                local size = (hi == 0xC0 or hi == 0xD0) and 1 or 2
                if p + size > trackEnd then return nil, "truncated channel event" end
                local first = u8(p)
                local second = size == 2 and u8(p + 1) or 0
                if first >= 0x80 or second >= 0x80 then
                    return nil, "invalid channel data"
                end
                p += size

                if hi == 0x90 or hi == 0x80 then
                    local key = bit32.band(op, 0x0F) * 128 + first
                    local queue = open[key]
                    if hi == 0x90 and second > 0 then
                        if not queue then
                            queue = {head = 1, tail = 0, notes = {}}
                            open[key] = queue
                        end
                        queue.tail += 1
                        queue.notes[queue.tail] = {t = ticks, vel = second}
                    elseif queue then
                        finishNote(queue.notes[queue.head], first, ticks)
                        queue.notes[queue.head] = nil
                        queue.head += 1
                        if queue.head > queue.tail then open[key] = nil end
                    end
                elseif hi == 0xB0 and first == 64 then
                    sustainRaw[#sustainRaw + 1] = {t = ticks, on = second >= 64}
                end
            end
        end

        for key, queue in pairs(open) do
            for index = queue.head, queue.tail do
                finishNote(queue.notes[index], key % 128, ticks)
            end
        end
        tracksRead += 1
    end

    table.sort(tempoChanges, function(a, b)
        if a.ticks == b.ticks then return a.order < b.order end
        return a.ticks < b.ticks
    end)
    local map = {}
    for _, tc in ipairs(tempoChanges) do
        if #map > 0 and map[#map].ticks == tc.ticks then
            map[#map] = tc
        else
            map[#map + 1] = tc
        end
    end
    if #map == 0 or map[1].ticks > 0 then
        table.insert(map, 1, {ticks = 0, tempo = 500000})
    end
    local cum = {0}
    for i = 2, #map do
        local prev = map[i - 1]
        cum[i] = cum[i - 1] + (map[i].ticks - prev.ticks) * prev.tempo / (1000000 * ppq)
    end

    local tickToSec
    if smpte then
        tickToSec = function(t)
            return t * smpte
        end
    else
        tickToSec = function(t)
            local lo, hi = 1, #map
            while lo < hi do
                local mid = (lo + hi + 1) // 2
                if map[mid].ticks <= t then
                    lo = mid
                else
                    hi = mid - 1
                end
            end
            return cum[lo] + (t - map[lo].ticks) * map[lo].tempo / (1000000 * ppq)
        end
    end

    local notes = {}
    local minMidi, maxMidi = 128, -1
    local velSum = 0
    local totalSeconds = 0
    for _, tn in ipairs(allNotes) do
        local st = tickToSec(tn.startTicks)
        local et = tickToSec(tn.startTicks + tn.durTicks)
        if et - st < MIN_NOTE_SECONDS then
            et = st + MIN_NOTE_SECONDS
        end
        table.insert(notes, {midi = tn.note, vel = tn.vel, startTime = st, endTime = et})
        if tn.note < minMidi then
            minMidi = tn.note
        end
        if tn.note > maxMidi then
            maxMidi = tn.note
        end
        velSum += tn.vel
        if et > totalSeconds then
            totalSeconds = et
        end
    end
    if #notes == 0 then
        return nil, "no notes"
    end

    local sustain = {}
    for _, se in ipairs(sustainRaw) do
        local t = tickToSec(se.t)
        table.insert(sustain, {time = t, on = se.on})
        if t > totalSeconds then
            totalSeconds = t
        end
    end
    table.sort(sustain, function(a, b)
        if a.time ~= b.time then
            return a.time < b.time
        end
        return not a.on and b.on
    end)

    local shifted = 0
    for _, n in ipairs(notes) do
        local g = n.midi - NOTE_OFFSET
        if g < MIN_NOTE or g > MAX_NOTE then
            shifted += 1
        end
    end

    return {
        notes = notes,
        sustain = sustain,
        totalSeconds = totalSeconds,
        noteCount = #notes,
        minMidi = minMidi,
        maxMidi = maxMidi,
        avgVel = velSum / #notes,
        shifted = shifted,
    }
end

local Api = {
    play = nil,
    release = nil,
    sustain = nil,
    sustainOn = false,
    playRaw = nil,
    releaseRaw = nil,
    sustainRaw = nil,
}

local function captureApi(beforeChange)
    local pianoClient = ReplicatedStorage:FindFirstChild("PianoClient")
    local midiModule = pianoClient and pianoClient:FindFirstChild("MidiConnect")
    if not midiModule then return false, "MidiConnect unavailable" end
    local ok, MidiConnect = pcall(require, midiModule)
    if not ok or type(MidiConnect) ~= "table" or type(MidiConnect.init) ~= "function" then
        return false, "MidiConnect unavailable"
    end
    local okUps, ups = pcall(getupvalues, MidiConnect.init)
    if not okUps or type(ups) ~= "table" then
        return false, "executor missing getupvalues"
    end
    local play, release, sustain = ups[1], ups[2], ups[3]
    if type(play) ~= "function" or type(release) ~= "function" then
        return false, "sit at a piano first"
    end
    sustain = type(sustain) == "function" and sustain or nil
    local changed = Api.playRaw ~= play or Api.releaseRaw ~= release or Api.sustainRaw ~= sustain
    if changed then
        if Api.playRaw and beforeChange then beforeChange() end
        Api.playRaw = play
        Api.releaseRaw = release
        Api.sustainRaw = sustain
        Api.play = function(gameNote, volume)
            return play(gameNote, nil, nil, volume)
        end
        Api.release = function(gameNote)
            return release(gameNote)
        end
        if Api.sustainRaw then
            Api.sustain = function(on)
                local result = sustain(on)
                Api.sustainOn = on == true
                return result
            end
        else
            Api.sustain = nil
        end
        Api.sustainOn = false
    end
    return true, nil, changed
end

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self.timeline = {}
    self.totalSeconds = 0
    self.speed = 1
    self.transpose = 0
    self.volumeMult = 1
    self.velocityMode = "MIDI"
    self.sustainMode = "Auto"
    self.loop = false
    self.running = false
    self.paused = false
    self.anchor = 0
    self.anchorSong = 0
    self.pausedAt = 0
    self.cursor = 1
    self.pausedHeld = nil
    self.held = {}
    self.keyCounts = {}
    self.conn = nil
    self.onState = nil
    self.onProgress = nil
    self.onFinish = nil
    self.playedCount = 0
    self.lastProgressPush = 0
    self.lastRecapture = 0
    self.recovering = false
    self.connectionError = nil
    self.noteFailures = 0
    return self
end

function Scheduler:songTime()
    if not self.running then
        return 0
    end
    if self.paused then
        return self.pausedAt
    end
    return math.max(0, self.anchorSong + (os.clock() - self.anchor) * self.speed)
end

function Scheduler:load(song)
    local tl = {}
    for id, n in ipairs(song.notes) do
        tl[#tl + 1] = {time = n.startTime, kind = 3, id = id, midi = n.midi, vel = n.vel}
        tl[#tl + 1] = {time = n.endTime, kind = 1, id = id}
    end
    for id, s in ipairs(song.sustain) do
        tl[#tl + 1] = {time = s.time, kind = 2, id = id, on = s.on}
    end
    table.sort(tl, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.id < b.id
    end)
    self.timeline = tl
    self.totalSeconds = song.totalSeconds
end

local function mapNote(midi, transpose)
    local key = midi - NOTE_OFFSET + transpose
    if key < MIN_NOTE then
        key += math.ceil((MIN_NOTE - key) / 12) * 12
    elseif key > MAX_NOTE then
        key -= math.ceil((key - MAX_NOTE) / 12) * 12
    end
    return key
end

function Scheduler:noteVolume(velocity)
    local effective = self.velocityMode == "MIDI" and velocity or 100
    return math.clamp(5 * effective / 127 * self.volumeMult, 0, 5)
end

function Scheduler:press(id, key, volume)
    if self.held[id] or not Api.play then return end
    Api.play(key, volume)
    self.held[id] = {g = key, volume = volume}
    self.keyCounts[key] = (self.keyCounts[key] or 0) + 1
end

function Scheduler:release(id)
    local entry = self.held[id]
    if not entry then return end
    local key = entry.g
    local count = (self.keyCounts[key] or 1) - 1
    if count <= 0 then
        if Api.release then Api.release(key) end
        self.keyCounts[key] = nil
    else
        self.keyCounts[key] = count
    end
    self.held[id] = nil
end

function Scheduler:fire(ev)
    if ev.kind == 3 then
        self:press(ev.id, mapNote(ev.midi, self.transpose), self:noteVolume(ev.vel))
        self.playedCount += 1
    elseif ev.kind == 1 then
        self:release(ev.id)
    elseif ev.kind == 2 then
        if self.sustainMode == "Auto" and Api.sustain then
            Api.sustain(ev.on)
        end
    end
end

function Scheduler:releaseAll()
    if Api.release then
        for key in pairs(self.keyCounts) do
            pcall(Api.release, key)
        end
    end
    table.clear(self.held)
    table.clear(self.keyCounts)
end

function Scheduler:setPedal(on)
    if Api.sustain then
        pcall(Api.sustain, on == true)
    end
end

function Scheduler:pedalAt(t)
    if self.sustainMode == "On" then return true end
    if self.sustainMode == "Off" then return false end
    for i = self.cursor - 1, 1, -1 do
        local ev = self.timeline[i]
        if ev.kind == 2 and ev.time <= t then return ev.on end
    end
    return false
end

function Scheduler:beginRecovery(reason)
    if not self.running then return end
    if not self.paused then self:pause() end
    self.recovering = true
    self.connectionError = tostring(reason or "Piano unavailable")
    self.lastRecapture = os.clock()
    if self.onState then self.onState("Reconnecting", self.connectionError) end
end

function Scheduler:refreshConnection()
    local ok, captured, reason = pcall(captureApi)
    if not self.running then return false end
    if not ok or not captured then
        self:beginRecovery(ok and reason or captured)
        return false
    end
    if self.recovering then
        return self:resume()
    end
    return true
end

function Scheduler:tick()
    if not self.running then return end
    local now = os.clock()
    if self.recovering then
        if now - self.lastRecapture >= RECAPTURE_INTERVAL then
            self.lastRecapture = now
            self:refreshConnection()
        end
        return
    end
    if self.paused then return end
    local st = self:songTime()
    local tl = self.timeline
    while self.cursor <= #tl and tl[self.cursor].time <= st do
        local ev = tl[self.cursor]
        local ok, err = pcall(self.fire, self, ev)
        if ok then
            self.noteFailures = 0
        else
            self.noteFailures += 1
            if self.noteFailures >= 3 then
                self:beginRecovery(err)
                return
            end
        end
        self.cursor += 1
        if not self.running or self.paused then return end
    end

    if self.onProgress and now - self.lastProgressPush >= PROGRESS_INTERVAL then
        self.lastProgressPush = now
        pcall(self.onProgress, math.min(st, self.totalSeconds), self.totalSeconds)
    end

    if self.cursor > #tl and st >= self.totalSeconds + 0.2 then
        self:releaseAll()
        self:setPedal(false)
        if self.loop then
            self.cursor = 1
            self.playedCount = 0
            self.anchorSong = 0
            self.anchor = os.clock()
            self:setPedal(self.sustainMode == "On")
        else
            self:stop()
            if self.onProgress then
                self.onProgress(self.totalSeconds, self.totalSeconds)
            end
            if self.onFinish then
                self.onFinish(true)
            end
        end
    end
end

function Scheduler:start()
    if self.running then
        return
    end
    self.running = true
    self.paused = false
    self.anchorSong = 0
    self.anchor = os.clock()
    self.pausedAt = 0
    self.cursor = 1
    self.pausedHeld = nil
    self.playedCount = 0
    self.lastProgressPush = 0
    self.lastRecapture = os.clock()
    self.recovering = false
    self.connectionError = nil
    self.noteFailures = 0
    self:setPedal(self.sustainMode == "On")
    if self.conn then
        self.conn:Disconnect()
    end
    local ticking = false
    self.conn = RunService.Heartbeat:Connect(function()
        if ticking or not self.running then return end
        ticking = true
        local ok, err = pcall(self.tick, self)
        ticking = false
        if not ok and self.running then
            self:beginRecovery(err)
        end
    end)
    if self.onState then
        self.onState("Playing")
    end
end

function Scheduler:pause()
    if not self.running or self.paused then
        return
    end
    self.pausedAt = self:songTime()
    self.paused = true
    self.pausedHeld = table.clone(self.held)
    self:releaseAll()
    self:setPedal(false)
    if self.onProgress then
        pcall(self.onProgress, math.min(self.pausedAt, self.totalSeconds), self.totalSeconds)
    end
    if self.onState then
        self.onState("Paused")
    end
end

function Scheduler:resume()
    if not self.running or not self.paused then
        return
    end
    self:setPedal(self:pedalAt(self.pausedAt))
    if self.pausedHeld then
        local ids = {}
        for id in pairs(self.pausedHeld) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local entry = self.pausedHeld[id]
            local ok, err = pcall(self.press, self, id, entry.g, entry.volume)
            if not ok then
                self:releaseAll()
                self:setPedal(false)
                self:beginRecovery(err)
                return false
            end
        end
        self.pausedHeld = nil
    end
    self.anchorSong = self.pausedAt
    self.anchor = os.clock()
    self.paused = false
    self.recovering = false
    self.connectionError = nil
    self.noteFailures = 0
    self.lastRecapture = self.anchor
    if self.onState then
        self.onState("Playing")
    end
    return true
end

function Scheduler:seek(t)
    if not self.running then
        return
    end
    t = math.clamp(t, 0, self.totalSeconds)
    self:releaseAll()
    self.pausedHeld = nil
    local tl = self.timeline
    local lo, hi = 1, #tl + 1
    while lo < hi do
        local mid = (lo + hi) // 2
        if tl[mid] and tl[mid].time < t then
            lo = mid + 1
        else
            hi = mid
        end
    end
    self.cursor = lo
    self:setPedal(false)
    if self.paused then
        self.pausedAt = t
    else
        self.anchorSong = t
        self.anchor = os.clock()
        self:setPedal(self:pedalAt(t))
    end
    if self.onProgress then
        self.onProgress(t, self.totalSeconds)
    end
end

function Scheduler:setSpeed(v)
    if type(v) ~= "number" or v ~= v or v <= 0 or v == math.huge then return end
    if self.running and not self.paused then
        self.anchorSong = self:songTime()
        self.anchor = os.clock()
    end
    self.speed = v
end

function Scheduler:stop()
    local wasRunning = self.running
    self.running = false
    self.paused = false
    self.recovering = false
    self.connectionError = nil
    self.pausedHeld = nil
    if self.conn then
        self.conn:Disconnect()
        self.conn = nil
    end
    self:releaseAll()
    if Api.sustain and Api.sustainOn then
        pcall(Api.sustain, false)
        Api.sustainOn = false
    end
    if wasRunning and self.onState then
        self.onState("Stopped")
    end
end

local scheduler = Scheduler.new()

local function validateNumber(value, default, minimum, maximum, step)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
        return default
    end
    return math.clamp(math.round(value / step) * step, minimum, maximum)
end

local function readSettings()
    local read = fileFunction("readfile")
    if not read then return {} end
    local ok, data = pcall(read, CONFIG_FILE)
    if not ok or type(data) ~= "string" or #data > 16384 then return {} end
    local decoded, settings = pcall(HttpService.JSONDecode, HttpService, data)
    if decoded and type(settings) == "table" then return settings end
    return {}
end

local settings = readSettings()
scheduler.speed = validateNumber(settings.speed, 1, 0.25, 3, 0.05)
scheduler.transpose = validateNumber(settings.transpose, 0, -48, 48, 1)
scheduler.volumeMult = validateNumber(settings.volume, 1, 0, 1, 0.05)
scheduler.loop = settings.loop == true
scheduler.sustainMode = table.find({"Auto", "On", "Off"}, settings.sustain) and settings.sustain or "Auto"
scheduler.velocityMode = settings.velocity == "Fixed" and "Fixed" or "MIDI"

local songState = {
    song = nil,
    name = nil,
    selected = isMidiName(settings.selected) and settings.selected or nil,
    files = {},
    cachedData = nil,
    cachedSong = nil,
}
local statsPara
local settingsReady = false
local settingsDirty = false
local saveGeneration = 0
local writeSettings = fileFunction("writefile")

local function saveSettings()
    if not settingsDirty or not writeSettings then return end
    local snapshot = {
        speed = scheduler.speed,
        transpose = scheduler.transpose,
        volume = scheduler.volumeMult,
        loop = scheduler.loop,
        sustain = scheduler.sustainMode,
        velocity = scheduler.velocityMode,
        selected = songState.selected,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, snapshot)
    if ok and pcall(writeSettings, CONFIG_FILE, encoded) then
        settingsDirty = false
    end
end

local function queueSave()
    if not settingsReady or not writeSettings then return end
    settingsDirty = true
    saveGeneration += 1
    local generation = saveGeneration
    task.delay(0.5, function()
        if settingsReady and generation == saveGeneration then
            saveSettings()
        end
    end)
end

local function updateStatsDisplay()
    if not songState.song then
        if statsPara then
            statsPara:Set("No song loaded")
        end
        return
    end
    local rangeText = "None"
    if songState.song.minMidi <= songState.song.maxMidi then
        rangeText = midiName(songState.song.minMidi) .. " - " .. midiName(songState.song.maxMidi)
    end
    if statsPara then
        statsPara:Set(string.format(
            "Notes: %d\nDuration: %s\nRange: %s\nAverage velocity: %d\nOctave-shifted: %d",
            songState.song.noteCount,
            fmtTime(songState.song.totalSeconds),
            rangeText,
            math.floor(songState.song.avgVel + 0.5),
            songState.song.shifted
        ))
    end
end

local Window = Reborn:CreateWindow({
    Title = "Auto Player - " .. VERSION,
    Size = Vector2.new(640, 440),
    SharpRendering = true,
})

local unloaded = false
local destroyConnection

local function unloadAll(external)
    if unloaded then
        return
    end
    unloaded = true
    settingsReady = false
    saveGeneration += 1
    saveSettings()
    if destroyConnection then
        destroyConnection:Disconnect()
        destroyConnection = nil
    end
    scheduler.onState = nil
    scheduler.onProgress = nil
    scheduler.onFinish = nil
    scheduler:stop()
    songState.cachedData = nil
    songState.cachedSong = nil
    if global[UNLOAD_KEY] == unloadAll then
        global[UNLOAD_KEY] = nil
    end
    if not external then
        Window:Destroy()
    end
end

global[UNLOAD_KEY] = unloadAll
destroyConnection = Window.Gui.Destroying:Connect(function()
    unloadAll(true)
end)

local PlayerTab = Window:Tab("Player", "music")
local SettingsTab = Window:Tab("Settings", "settings")
local InfoTab = Window:Tab("Info", "info")
PlayerTab:SetColumns(2)
SettingsTab:SetColumns(2)

local PlaySection = PlayerTab:Section("Playback")
local FileSection = PlayerTab:Section("Library")
local AdjustSection = SettingsTab:Section("Playback")
local PedalSection = SettingsTab:Section("Expression")
local StatsSection = InfoTab:Section("Song")
local SessionSection = InfoTab:Section("Session")

local playingNamePara = PlaySection:Paragraph("No song loaded")
local timePara = PlaySection:Paragraph("0:00 / 0:00")
local statusPara = PlaySection:Paragraph("Idle")

local fileDd
local playBtn
local progressHandle
local seekSlider
local libraryPara

local function setStatus(text)
    statusPara:Set(text)
end

local function refreshLibrary()
    local names, err = listMidiNames()
    if not names then
        if not scheduler.running then setStatus(err) end
        Window:Notify({Title = "Auto Player", Description = err, Type = "error"})
        return
    end
    local selected = songState.selected
    if not table.find(names, selected or "") then
        selected = table.find(names, songState.name or "") and songState.name or names[1]
    end
    songState.files = names
    if songState.selected ~= selected then
        songState.selected = selected
        queueSave()
    end
    fileDd:SetOptions(names)
    fileDd:Set(selected, false)
    libraryPara:Set(#names .. (#names == 1 and " MIDI file" or " MIDI files"))
    local message = #names == 0 and ("No MIDI files found in '" .. MIDI_FOLDER .. "'") or ("Found " .. #names .. " MIDI files")
    Window:Notify({Title = "Auto Player", Description = message, Type = "info"})
end

local function loadSong(name)
    local data, readError = readMidiFile(name)
    if not data then return false, readError end
    local song
    if songState.cachedData == data and songState.cachedSong then
        song = songState.cachedSong
    else
        local ok, parsed, err = pcall(MidiParser.parse, data)
        if not ok then return false, tostring(parsed) end
        if not parsed then return false, err or "Parse failed" end
        song = parsed
        if #data <= 2 * 1024 * 1024 then
            songState.cachedData = data
            songState.cachedSong = song
        else
            songState.cachedData = nil
            songState.cachedSong = nil
        end
    end
    if scheduler.running then
        scheduler:stop()
    end
    songState.song = song
    songState.name = name
    scheduler:load(song)
    local shiftNote = ""
    if song.shifted > 0 then
        shiftNote = string.format(", %d octave-shifted", song.shifted)
    end
    playingNamePara:Set(name)
    timePara:Set("0:00 / " .. fmtTime(song.totalSeconds))
    progressHandle:SetRange(0, math.max(song.totalSeconds, 0.1))
    progressHandle:Set(0, false)
    seekSlider:SetRange(0, math.max(song.totalSeconds, 0.1))
    seekSlider:Set(0, false)
    setStatus(string.format("Loaded %d notes, %s%s", song.noteCount, fmtTime(song.totalSeconds), shiftNote))
    updateStatsDisplay()
    Window:Notify({Title = "Auto Player", Description = name .. " loaded (" .. song.noteCount .. " notes)", Type = "success"})
    return true
end

local function tryLoad(name)
    if not name or name == "" then
        return
    end
    local ok, err = loadSong(name)
    if not ok then
        if not scheduler.running then setStatus("Load failed: " .. tostring(err)) end
        Window:Notify({Title = "Auto Player", Description = "Could not load: " .. tostring(err), Type = "error"})
    end
    return ok
end

local function startPlayback()
    local ok, captured, reason = pcall(captureApi)
    if not ok or not captured then
        local message = tostring(ok and reason or captured)
        setStatus(message)
        Window:Notify({Title = "Auto Player", Description = message, Type = "error"})
        return false
    end
    scheduler:start()
    return true
end

local function togglePlayPause()
    if scheduler.running and not scheduler.paused then
        scheduler:pause()
    elseif scheduler.running and scheduler.paused then
        if scheduler:refreshConnection() and scheduler.paused then
            scheduler:resume()
        end
    else
        if not songState.song then
            setStatus("Select a MIDI file first")
            return
        end
        if startPlayback() then
            setStatus("Playing " .. (songState.name or ""))
        end
    end
end

scheduler.onState = function(state, reason)
    if state == "Playing" then
        playBtn:Set("Pause")
        setStatus("Playing " .. (songState.name or ""))
    elseif state == "Paused" then
        playBtn:Set("Resume")
        setStatus("Paused")
    elseif state == "Reconnecting" then
        playBtn:Set("Resume")
        setStatus("Reconnecting: " .. tostring(reason))
    else
        playBtn:Set("Play")
    end
end

scheduler.onProgress = function(elapsed, total)
    pcall(function() timePara:Set(fmtTime(elapsed) .. " / " .. fmtTime(total)) end)
    pcall(function() progressHandle:Set(elapsed, true) end)
    pcall(function() seekSlider:Set(elapsed, false) end)
end

scheduler.onFinish = function(completed)
    if completed then
        setStatus("Finished " .. (songState.name or ""))
        Window:Notify({Title = "Auto Player", Description = "Finished: " .. (songState.name or ""), Type = "success"})
    end
end

local names, libraryError = listMidiNames()
names = names or {}
songState.files = names
if not table.find(names, songState.selected or "") then
    songState.selected = names[1]
end
libraryPara = FileSection:Paragraph(#names .. (#names == 1 and " MIDI file" or " MIDI files"))
fileDd = FileSection:Dropdown({
    Text = "MIDI File",
    Options = names,
    Value = songState.selected,
    Callback = function(value)
        songState.selected = table.find(songState.files, value) and value or nil
        queueSave()
    end,
})

local libraryRow = FileSection:Row()
libraryRow:Button({
    Text = "Refresh",
    Callback = refreshLibrary,
})
libraryRow:Button({
    Text = "Load",
    Primary = true,
    Callback = function()
        if songState.selected then
            tryLoad(songState.selected)
        else
            setStatus("Pick a file from the dropdown")
        end
    end,
})

local controlsRow = PlaySection:Row()
playBtn = controlsRow:Button({
    Text = "Play",
    Primary = true,
    Callback = function()
        if not songState.song and songState.selected then
            if not tryLoad(songState.selected) then return end
        end
        if songState.song then
            togglePlayPause()
        else
            setStatus("Select a MIDI file first")
            Window:Notify({Title = "Auto Player", Description = "Select a MIDI file first", Type = "error"})
        end
    end,
})
controlsRow:Button({
    Text = "Stop",
    Callback = function()
        scheduler:stop()
        setStatus("Stopped")
        local total = songState.song and songState.song.totalSeconds or 0
        scheduler.onProgress(0, total)
    end,
})

progressHandle = PlaySection:ProgressBar({
    Text = "Progress",
    Min = 0,
    Max = 100,
    Value = 0,
    Duration = 0.12,
    ShowValue = false,
})

seekSlider = PlaySection:Slider({
    Text = "Seek",
    Min = 0,
    Max = 100,
    Step = 0.1,
    Value = 0,
    Suffix = "s",
    Callback = function(value)
        if scheduler.running then
            scheduler:seek(value)
        end
    end,
})

PlaySection:Keybind({
    Text = "Play / Pause",
    Value = "P",
    Callback = function(_, _, processed)
        if processed then
            return
        end
        if songState.song then
            togglePlayPause()
        end
    end,
})

AdjustSection:Slider({
    Text = "Speed",
    Min = 0.25,
    Max = 3,
    Step = 0.05,
    Value = scheduler.speed,
    Suffix = "x",
    Callback = function(value)
        scheduler:setSpeed(value)
        queueSave()
    end,
})

AdjustSection:Slider({
    Text = "Transpose",
    Min = -48,
    Max = 48,
    Step = 1,
    Value = scheduler.transpose,
    Suffix = " st",
    Callback = function(value)
        scheduler.transpose = value
        queueSave()
    end,
})

PedalSection:Slider({
    Text = "Volume",
    Min = 0,
    Max = 1,
    Step = 0.05,
    Value = scheduler.volumeMult,
    Suffix = "x",
    Callback = function(value)
        scheduler.volumeMult = value
        queueSave()
    end,
})

AdjustSection:Toggle({
    Text = "Loop",
    Value = scheduler.loop,
    Callback = function(value)
        scheduler.loop = value
        queueSave()
    end,
})

PedalSection:Dropdown({
    Text = "Sustain Mode",
    Options = {"Auto", "On", "Off"},
    Value = scheduler.sustainMode,
    Callback = function(value)
        scheduler.sustainMode = value
        queueSave()
        if scheduler.running and not scheduler.paused then
            if value == "On" and Api.sustain then
                Api.sustain(true)
            elseif value ~= "Auto" and Api.sustain and Api.sustainOn then
                Api.sustain(false)
            end
        end
    end,
})

PedalSection:Dropdown({
    Text = "Velocity",
    Options = {"MIDI", "Fixed"},
    Value = scheduler.velocityMode,
    Callback = function(value)
        scheduler.velocityMode = value
        queueSave()
    end,
})

statsPara = StatsSection:Paragraph("No song loaded")

StatsSection:Button({
    Text = "Reload Song",
    Callback = function()
        if songState.name then
            tryLoad(songState.name)
        end
    end,
})

SessionSection:Paragraph("MIDI folder: " .. MIDI_FOLDER .. "\nAdd .mid or .midi files, refresh the library, and sit at a piano before playing.")
SessionSection:Button({
    Text = "Stop & Unload",
    Callback = function()
        unloadAll()
    end,
})

settingsReady = true

if libraryError then
    setStatus(libraryError)
    Window:Notify({Title = "Auto Player", Description = libraryError, Type = "error"})
elseif #names == 0 then
    setStatus("No MIDI files found in '" .. MIDI_FOLDER .. "'")
    Window:Notify({Title = "Auto Player", Description = "No MIDI files in '" .. MIDI_FOLDER .. "'. Add files and press Refresh Files.", Type = "info"})
else
    local okCap, captured = pcall(captureApi)
    if okCap and captured then
        setStatus("Ready")
    else
        setStatus("Sit at a piano, then press Play")
    end
end
