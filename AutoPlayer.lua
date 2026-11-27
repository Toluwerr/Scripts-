local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "0.3"
local MIDI_FOLDER = "midis"
local REBORN_URL = "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
local UNLOAD_KEY = "AutoPlayerInstance"
local NOTE_OFFSET = 35
local MIN_NOTE = -14
local MAX_NOTE = 73
local SCHEDULE_AHEAD = 0.15
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

local Reborn = loadstring(game:HttpGet(REBORN_URL))()

local function hasGlobal(name)
    local env = getfenv()
    if type(env[name]) == "function" then
        return true
    end
    local genv = getgenv()
    if type(genv[name]) == "function" then
        return true
    end
    return type(rawget(_G, name)) == "function"
end

local function ensureFolder()
    if hasGlobal("isfolder") and hasGlobal("makefolder") and not isfolder(MIDI_FOLDER) then
        pcall(makefolder, MIDI_FOLDER)
    end
end

local function listMidiNames()
    if not hasGlobal("listfiles") then
        return {}
    end
    ensureFolder()
    local ok, files = pcall(listfiles, MIDI_FOLDER)
    if not ok or type(files) ~= "table" then
        return {}
    end
    local names = {}
    for _, raw in ipairs(files) do
        local path = tostring(raw)
        local name = path:match("[^/\\]+$")
        if name and name:lower():match("%.midi?$") then
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    return names
end

local function readMidiFile(name)
    if not hasGlobal("readfile") then
        return nil
    end
    local ok, data = pcall(readfile, MIDI_FOLDER .. "/" .. name)
    if not ok or type(data) ~= "string" or #data == 0 then
        return nil
    end
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

local function captureApi()
    local ok, MidiConnect = pcall(require, ReplicatedStorage.PianoClient.MidiConnect)
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
    if Api.playRaw ~= play or Api.releaseRaw ~= release then
        Api.playRaw = play
        Api.releaseRaw = release
        Api.sustainRaw = type(sustain) == "function" and sustain or nil
        Api.play = function(gameNote, volume)
            return play(gameNote, nil, nil, volume)
        end
        Api.release = function(gameNote)
            return release(gameNote)
        end
        if Api.sustainRaw then
            Api.sustain = function(on)
                Api.sustainOn = on and true or false
                return Api.sustainRaw(on)
            end
        else
            Api.sustain = nil
        end
        Api.sustainOn = false
    end
    return true
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
    self.pausedTotal = 0
    self.pauseStart = 0
    self.pausedAt = 0
    self.cursor = 1
    self.firedUpTo = 0
    self.pending = {}
    self.held = {}
    self.conn = nil
    self.onState = nil
    self.onProgress = nil
    self.onFinish = nil
    self.playedCount = 0
    self.lastProgressPush = 0
    self.lastRecapture = 0
    return self
end

function Scheduler:songTime()
    if not self.running then
        return 0
    end
    if self.paused then
        return self.pausedAt
    end
    local t = os.clock() - self.anchor - self.pausedTotal
    if t < 0 then
        return 0
    end
    return t * self.speed
end

function Scheduler:load(song)
    local tl = {}
    for _, n in ipairs(song.notes) do
        tl[#tl + 1] = {time = n.startTime, kind = 3, midi = n.midi, vel = n.vel}
        tl[#tl + 1] = {time = n.endTime, kind = 1, midi = n.midi}
    end
    for _, s in ipairs(song.sustain) do
        tl[#tl + 1] = {time = s.time, kind = 2, on = s.on}
    end
    table.sort(tl, function(a, b)
        if a.time ~= b.time then
            return a.time < b.time
        end
        return a.kind < b.kind
    end)
    self.timeline = tl
    self.totalSeconds = song.totalSeconds
end

function Scheduler:fire(ev)
    if ev.kind == 3 then
        local g = ev.midi - NOTE_OFFSET + self.transpose
        while g < MIN_NOTE do
            g += 12
        end
        while g > MAX_NOTE do
            g -= 12
        end
        local vol
        if self.velocityMode == "MIDI" then
            vol = 5 * ev.vel / 127 * self.volumeMult
        else
            vol = 500 / 127 * self.volumeMult
        end
        if vol > 5 then
            vol = 5
        end
        if Api.play then
            Api.play(g, vol)
        end
        local entry = self.held[ev.midi]
        if entry then
            entry.count += 1
            entry.g = g
        else
            self.held[ev.midi] = {g = g, count = 1}
        end
        self.playedCount += 1
    elseif ev.kind == 1 then
        local entry = self.held[ev.midi]
        if entry and entry.count > 0 then
            if Api.release then
                Api.release(entry.g)
            end
            entry.count -= 1
            if entry.count == 0 then
                self.held[ev.midi] = nil
            end
        end
    elseif ev.kind == 2 then
        if self.sustainMode == "Auto" and Api.sustain then
            Api.sustain(ev.on)
        end
    end
end

function Scheduler:cancelPending()
    local first = self.firedUpTo + 1
    for thread, idx in pairs(self.pending) do
        pcall(task.cancel, thread)
        if idx < first then
            first = idx
        end
    end
    table.clear(self.pending)
    if first < self.cursor then
        self.cursor = first
    end
    self.firedUpTo = self.cursor - 1
end

function Scheduler:releaseAll()
    for midi, entry in pairs(self.held) do
        if Api.release and entry.g then
            for _ = 1, entry.count do
                pcall(Api.release, entry.g)
            end
        end
    end
    table.clear(self.held)
end

function Scheduler:tick()
    if not self.running or self.paused then
        return
    end
    local now = os.clock()
    if now - self.lastRecapture > RECAPTURE_INTERVAL then
        self.lastRecapture = now
        pcall(captureApi)
    end
    local st = self:songTime()
    local tl = self.timeline
    local i = self.cursor
    local horizon = st + SCHEDULE_AHEAD * self.speed
    while i <= #tl do
        local ev = tl[i]
        if ev.time <= st then
            self:fire(ev)
            self.firedUpTo = i
            i += 1
        elseif ev.time <= horizon then
            local idx = i
            local thread
            thread = task.delay((ev.time - st) / self.speed, function()
                if not self.running or self.paused or self.pending[thread] ~= idx then
                    return
                end
                self.pending[thread] = nil
                self:fire(ev)
                if self.firedUpTo < idx then
                    self.firedUpTo = idx
                end
            end)
            self.pending[thread] = idx
            i += 1
        else
            break
        end
    end
    self.cursor = i

    if self.onProgress and now - self.lastProgressPush >= PROGRESS_INTERVAL then
        self.lastProgressPush = now
        self.onProgress(st, self.totalSeconds)
    end

    if self.cursor > #tl and st >= self.totalSeconds + 0.2 then
        if self.loop then
            self:releaseAll()
            if Api.sustain and Api.sustainOn then
                Api.sustain(false)
            end
            self.cursor = 1
            self.firedUpTo = 0
            self.playedCount = 0
            self.pausedTotal = 0
            self.anchor = os.clock()
        else
            self.running = false
            if self.conn then
                self.conn:Disconnect()
                self.conn = nil
            end
            if Api.sustain and Api.sustainOn then
                Api.sustain(false)
            end
            if self.onState then
                self.onState("Stopped")
            end
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
    self.pausedTotal = 0
    self.anchor = os.clock()
    self.cursor = 1
    self.firedUpTo = 0
    self.playedCount = 0
    self.lastProgressPush = 0
    self.lastRecapture = 0
    if self.sustainMode == "On" and Api.sustain then
        Api.sustain(true)
    elseif self.sustainMode == "Off" and Api.sustain then
        Api.sustain(false)
    end
    if self.conn then
        self.conn:Disconnect()
    end
    self.conn = RunService.Heartbeat:Connect(function()
        self:tick()
    end)
    if self.onState then
        self.onState("Playing")
    end
end

function Scheduler:pause()
    if not self.running or self.paused then
        return
    end
    self.paused = true
    self.pausedAt = self:songTime()
    self.pauseStart = os.clock()
    self:cancelPending()
    if self.onState then
        self.onState("Paused")
    end
end

function Scheduler:resume()
    if not self.running or not self.paused then
        return
    end
    self.paused = false
    self.pausedTotal += os.clock() - self.pauseStart
    self.anchor = os.clock() - self.pausedTotal - self.pausedAt / self.speed
    if self.onState then
        self.onState("Playing")
    end
end

function Scheduler:seek(t)
    if not self.running then
        return
    end
    t = math.clamp(t, 0, self.totalSeconds)
    self:cancelPending()
    self:releaseAll()
    local tl = self.timeline
    local lo, hi = 1, #tl + 1
    while lo < hi do
        local mid = (lo + hi) // 2
        if tl[mid] and tl[mid].time <= t then
            lo = mid + 1
        else
            hi = mid
        end
    end
    self.cursor = lo
    self.firedUpTo = lo - 1
    if self.paused then
        self.pausedAt = t
    else
        self.anchor = os.clock() - self.pausedTotal - t / self.speed
    end
end

function Scheduler:setSpeed(v)
    if self.running and not self.paused then
        local st = self:songTime()
        self.speed = v
        self.anchor = os.clock() - self.pausedTotal - st / v
    else
        self.speed = v
    end
end

function Scheduler:stop()
    local wasRunning = self.running
    self.running = false
    self.paused = false
    self:cancelPending()
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
local songState = {
    song = nil,
    name = nil,
    selected = nil,
}
local statsPara

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
    Size = Vector2.new(640, 520),
})

local unloaded = false
local destroyConnection

local function unloadAll(external)
    if unloaded then
        return
    end
    unloaded = true
    if destroyConnection then
        destroyConnection:Disconnect()
        destroyConnection = nil
    end
    scheduler.onState = nil
    scheduler.onProgress = nil
    scheduler.onFinish = nil
    scheduler:stop()
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
local AdjustSection = SettingsTab:Section("Adjustments")
local PedalSection = SettingsTab:Section("Pedal")
local StatusSection = InfoTab:Section("Status")
local StatsSection = InfoTab:Section("Song")

local statusPara = StatusSection:Paragraph("Idle")
local timePara = StatusSection:Paragraph("0:00 / 0:00")

local fileDd
local playBtn
local progressHandle
local seekSlider
local playingNamePara

local function setStatus(text)
    statusPara:Set(text)
end

local function refreshLibrary(keepSelection)
    local names = listMidiNames()
    if keepSelection and songState.name then
        fileDd:Set(songState.name)
    end
    fileDd:SetOptions(names)
    if #names == 0 then
        setStatus("No MIDI files found in '" .. MIDI_FOLDER .. "'")
    end
    return names
end

local function loadSong(name)
    local data = readMidiFile(name)
    if not data then
        return false, "could not read file"
    end
    local song, err = MidiParser.parse(data)
    if not song then
        return false, err or "parse failed"
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
    progressHandle:Set(0)
    seekSlider:SetRange(0, math.max(math.floor(song.totalSeconds), 1))
    seekSlider:Set(0)
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
        setStatus("Load failed: " .. tostring(err))
        Window:Notify({Title = "Auto Player", Description = "Could not load: " .. tostring(err), Type = "error"})
    end
end

local function startPlayback()
    local okCap = captureApi()
    if not okCap then
        setStatus("Sit at a piano first")
        Window:Notify({Title = "Auto Player", Description = "Sit at a piano, then press Play", Type = "error"})
        return false
    end
    scheduler:start()
    return true
end

local function togglePlayPause()
    if scheduler.running and not scheduler.paused then
        scheduler:pause()
        setStatus("Paused")
    elseif scheduler.running and scheduler.paused then
        scheduler:resume()
        setStatus("Playing " .. (songState.name or ""))
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

scheduler.onState = function(state)
    if state == "Playing" then
        playBtn:Set("Pause")
    elseif state == "Paused" then
        playBtn:Set("Resume")
    else
        playBtn:Set("Play")
    end
end

scheduler.onProgress = function(elapsed, total)
    timePara:Set(fmtTime(elapsed) .. " / " .. fmtTime(total))
    progressHandle:Set(elapsed, true)
end

scheduler.onFinish = function(completed)
    if completed then
        setStatus("Finished " .. (songState.name or ""))
        Window:Notify({Title = "Auto Player", Description = "Finished: " .. (songState.name or ""), Type = "success"})
    end
end

playingNamePara = FileSection:Paragraph("No file selected")

local names = listMidiNames()
fileDd = FileSection:Dropdown({
    Text = "MIDI File",
    Options = names,
    Value = names[1],
    Callback = function(value)
        songState.selected = value
    end,
})

FileSection:Button({
    Text = "Refresh Files",
    Callback = function()
        refreshLibrary(false)
        setStatus("Library refreshed")
    end,
})

local loadRow = FileSection:Row()
loadRow:Button({
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
            tryLoad(songState.selected)
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
    Step = 1,
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
    Value = 1,
    Suffix = "x",
    Callback = function(value)
        scheduler:setSpeed(value)
    end,
})

AdjustSection:Slider({
    Text = "Transpose",
    Min = -48,
    Max = 48,
    Step = 1,
    Value = 0,
    Suffix = " st",
    Callback = function(value)
        scheduler.transpose = value
    end,
})

AdjustSection:Slider({
    Text = "Volume",
    Min = 0,
    Max = 1,
    Step = 0.05,
    Value = 1,
    Suffix = "x",
    Callback = function(value)
        scheduler.volumeMult = value
    end,
})

AdjustSection:Toggle({
    Text = "Loop",
    Value = false,
    Callback = function(value)
        scheduler.loop = value
    end,
})

PedalSection:Dropdown({
    Text = "Sustain Mode",
    Options = {"Auto", "On", "Off"},
    Value = "Auto",
    Callback = function(value)
        scheduler.sustainMode = value
        if scheduler.running then
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
    Value = "MIDI",
    Callback = function(value)
        scheduler.velocityMode = value
    end,
})

statsPara = StatsSection:Paragraph("No song loaded")

StatsSection:Button({
    Text = "Reload Song",
    Callback = function()
        if songState.name then
            loadSong(songState.name)
        end
    end,
})

InfoTab:Section("Usage"):Paragraph(
    "1. Put .mid or .midi files in the '" .. MIDI_FOLDER .. "' folder inside your executor workspace\n" ..
    "2. Press Refresh Files\n" ..
    "3. Pick a song and press Load\n" ..
    "4. Sit at any piano and press Play\n\n" ..
    "Notes outside the 88-key range are octave-shifted into range automatically."
)

local unloadRow = StatusSection:Row()
unloadRow:Button({
    Text = "Stop & Unload",
    Callback = function()
        unloadAll()
    end,
})

if #names == 0 then
    ensureFolder()
    Window:Notify({Title = "Auto Player", Description = "No MIDI files in '" .. MIDI_FOLDER .. "'. Add files and press Refresh Files.", Type = "info"})
else
    songState.selected = names[1]
end

local okCap, captured = pcall(captureApi)
if okCap and captured then
    setStatus("Ready")
else
    setStatus("Sit at a piano, then press Play")
end
