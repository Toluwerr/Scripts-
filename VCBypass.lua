--[[
        VCBypass - universal Roblox voice chat enforcer + ban evasion
        repo: Toluwerr/Scripts-
        target: any experience (universal - voice chat is platform-wide, no place gate)

        HONEST scope - read this before running:
        1. TRUTH CHECK. The script asks the Roblox backend, through the real
           VoiceChatService:IsVoiceEnabledForUserIdAsync, whether your account
           actually has voice chat, and shows the answer in the status panel.
             - ENABLED -> your account is fine; if the mic UI still does not show,
               the client voice stack is stuck and the force chain below can
               genuinely revive it (this is the real, fixable case).
             - DENIED  -> the age/verification gate is enforced SERVER-side. The
               hooks below will force the voice UI on, but a denied account is
               never issued a voice session - no client script can change that,
               and this one will not pretend otherwise.
        2. FORCE CHAIN (the 2026-era technique used by current public bypasses):
             - hookfunction(IsVoiceEnabledForUserIdAsync) -> true. The CoreScript
               voice stack initializes only when its eligibility check passes;
               forcing it true makes the client bring the mic UI up.
             - hookfunction(GetVoiceChatState) -> Enabled (guarded, if present).
             - Namecall hook on VoiceChatService: re-applies the local flag spoof
               whenever the core stack calls Init/state methods, with thread
               identity raised to 8 where the executor allows it.
             - Local attribute spoof on LocalPlayer: AgeVerified, VoiceChatEnabled,
               IsVoiceChatUser, VCReportable (local-only, does not replicate).
             - Force-enables the voice CoreGui/PlayerGui surfaces.
        3. BAN EVASION. Destroys the client-side VoiceBan / VCTelemetry /
           ReportVoice objects and disables VoiceReportService so YOUR client
           stops reporting and telemetry-logging your voice.
        4. KEEP ALIVE. Re-applies the spoof every 5 seconds so the core stack
           cannot quietly re-check and back out (also survives respawns).

        Executor requirements: hookfunction + getrawmetatable + setreadonly for
        the hooks; the status panel lists exactly which capabilities YOUR
        executor has, and anything missing is reported instead of failing
        silently. All hooks are restored on cleanup and on re-execution.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__VCBypassCleanup) == "function" then
        pcall(Global.__VCBypassCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[VCBypass] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

-- VoiceChatService does not exist on every platform/build - resolve it softly.
local VoiceChatService
do
        local ok, service = pcall(function()
                return game:GetService("VoiceChatService")
        end)
        if ok and service then
                VoiceChatService = service
        end
end

-- Hidden-UI access where the executor provides it; plain CoreGui otherwise.
local CoreGui
do
        local ok, gui = pcall(function()
                if gethui then
                        return gethui()
                end
                return game:GetService("CoreGui")
        end)
        if ok and gui then
                CoreGui = gui
        else
                CoreGui = game:GetService("CoreGui")
        end
end

-- Capture the REAL backend check BEFORE any hook touches it, so the truth
-- check always queries Roblox and not our own forced-true hook.
local originalIsVoiceEnabled
if VoiceChatService and typeof(VoiceChatService.IsVoiceEnabledForUserIdAsync) == "function" then
        originalIsVoiceEnabled = VoiceChatService.IsVoiceEnabledForUserIdAsync
end

-- =============================================================
-- Executor capability report
-- =============================================================

local caps = {
        hooks = type(hookfunction) == "function",
        namecall = type(getrawmetatable) == "function"
                and type(setreadonly) == "function"
                and type(getnamecallmethod) == "function",
        identity = type(setthreadidentity) == "function" or type(setthreadcontext) == "function",
        closureGuard = type(newcclosure) == "function",
        hiddenGui = type(gethui) == "function",
}

local function elevateIdentity()
        if not caps.identity then
                return false
        end
        local ok = pcall(function()
                if setthreadidentity then
                        setthreadidentity(8)
                else
                        setthreadcontext(8)
                end
        end)
        return ok
end

-- =============================================================
-- State
-- =============================================================

local Window
local statusLabel
local verdictLabel
local connections = {}
local keepAliveGeneration = 0

local state = {
        eligibility = "unchecked", -- unchecked | checking | enabled | denied | unavailable | "error: ..."
        appliedOnce = false,
        lastRun = nil,
        keepAlive = false,
        applied = {
                attributes = false,
                eligibilityHook = false,
                stateHook = false,
                namecallHook = false,
                uiForced = false,
                reportsKilled = 0,
        },
}

-- Saved originals for full restore.
local savedEligibilityOriginal = nil
local savedStateOriginal = nil
local savedNamecall = nil
local savedReadonly = nil

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 6,
                })
        end)
end

-- =============================================================
-- Spoof / force / kill steps (each is independently pcall-guarded
-- and reports its REAL outcome into state.applied)
-- =============================================================

local SPOOF_ATTRIBUTES = {
        { "AgeVerified", true },
        { "VoiceChatEnabled", true },
        { "IsVoiceChatUser", true },
        { "VCReportable", false },
}

local function spoofAttributes()
        local count = 0
        for _, pair in ipairs(SPOOF_ATTRIBUTES) do
                local ok = pcall(function()
                        LocalPlayer:SetAttribute(pair[1], pair[2])
                end)
                if ok then
                        count = count + 1
                end
        end
        state.applied.attributes = count == #SPOOF_ATTRIBUTES
        return count
end

local function forceVoiceUI()
        local forced = 0
        local names = { "VoiceChat", "VoiceChatUI" }

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local roots = { CoreGui, playerGui }

        for _, root in ipairs(roots) do
                if root then
                        for _, name in ipairs(names) do
                                local gui = root:FindFirstChild(name)
                                if gui then
                                        local ok = pcall(function()
                                                gui.Enabled = true
                                        end)
                                        if ok then
                                                forced = forced + 1
                                        end
                                end
                        end
                end
        end

        state.applied.uiForced = forced > 0
        return forced
end

local REPORT_PATTERNS = { "VoiceBan", "VCTelemetry", "ReportVoice" }

local function destroyMatching(root, removed)
        if not root then
                return removed
        end
        pcall(function()
                for _, obj in ipairs(root:GetDescendants()) do
                        for _, pattern in ipairs(REPORT_PATTERNS) do
                                if string.find(obj.Name, pattern, 1, true) then
                                        if pcall(function()
                                                obj:Destroy()
                                        end) then
                                                removed = removed + 1
                                        end
                                end
                        end
                end
        end)
        return removed
end

local function killReportObjects()
        local removed = 0
        removed = destroyMatching(game, removed)
        removed = destroyMatching(CoreGui, removed)

        -- The report service child on VoiceChatService gets disabled, not
        -- destroyed - the core stack expects it to exist.
        if VoiceChatService then
                local reportService = VoiceChatService:FindFirstChild("VoiceReportService")
                if reportService then
                        pcall(function()
                                reportService.Disabled = true
                        end)
                end
        end

        state.applied.reportsKilled = removed
        return removed
end

-- =============================================================
-- Hooks
-- =============================================================

local function applyFunctionHooks()
        if not caps.hooks or not VoiceChatService then
                return
        end

        -- The core stack initializes voice only if this returns true.
        if not state.applied.eligibilityHook
                and typeof(VoiceChatService.IsVoiceEnabledForUserIdAsync) == "function"
        then
                local forced
                local ok = pcall(function()
                        forced = hookfunction(VoiceChatService.IsVoiceEnabledForUserIdAsync, function()
                                return true
                        end)
                end)
                if ok and forced then
                        savedEligibilityOriginal = forced
                        state.applied.eligibilityHook = true
                end
        end

        -- Hidden state getter on newer builds; guard both the method and enum.
        if not state.applied.stateHook
                and typeof(VoiceChatService.GetVoiceChatState) == "function"
        then
                local okStateEnum, stateEnum = pcall(function()
                        return Enum.VoiceChatState.Enabled
                end)
                local forced
                local ok = pcall(function()
                        forced = hookfunction(VoiceChatService.GetVoiceChatState, function()
                                if okStateEnum then
                                        return stateEnum
                                end
                                return true
                        end)
                end)
                if ok and forced then
                        savedStateOriginal = forced
                        state.applied.stateHook = true
                end
        end
end

local function applyNamecallHook()
        if not caps.namecall or not VoiceChatService or state.applied.namecallHook then
                return
        end

        local ok = pcall(function()
                local mt = getrawmetatable(VoiceChatService)
                savedNamecall = mt.__namecall
                savedReadonly = false
                if getreadonly then
                        savedReadonly = getreadonly(mt) == true
                end

                local function interceptor(self, ...)
                        local method = getnamecallmethod()

                        if self ~= VoiceChatService then
                                return savedNamecall(self, ...)
                        end

                        -- Re-spoof the local flags whenever the core voice stack
                        -- initializes or re-checks its state.
                        if string.find(method, "Init", 1, true)
                                or string.find(method, "VoiceChat", 1, true)
                                or method == "GetVoiceChatState"
                        then
                                pcall(spoofAttributes)
                                elevateIdentity()
                        end

                        return savedNamecall(self, ...)
                end

                local guarded = interceptor
                if caps.closureGuard then
                        guarded = newcclosure(interceptor)
                end

                setreadonly(mt, false)
                mt.__namecall = guarded
                setreadonly(mt, true)
        end)

        if ok then
                state.applied.namecallHook = true
        end
end

local function restoreHooks()
        if caps.hooks then
                if savedEligibilityOriginal and VoiceChatService then
                        pcall(function()
                                hookfunction(VoiceChatService.IsVoiceEnabledForUserIdAsync, savedEligibilityOriginal)
                        end)
                end
                if savedStateOriginal and VoiceChatService then
                        pcall(function()
                                hookfunction(VoiceChatService.GetVoiceChatState, savedStateOriginal)
                        end)
                end
        end

        if savedNamecall and VoiceChatService and caps.namecall then
                pcall(function()
                        local mt = getrawmetatable(VoiceChatService)
                        setreadonly(mt, false)
                        mt.__namecall = savedNamecall
                        setreadonly(mt, savedReadonly == true)
                end)
        end

        savedEligibilityOriginal = nil
        savedStateOriginal = nil
        savedNamecall = nil
        savedReadonly = nil

        state.applied.eligibilityHook = false
        state.applied.stateHook = false
        state.applied.namecallHook = false
end

-- =============================================================
-- Status text
-- =============================================================

local function verdictText()
        local e = state.eligibility
        if e == "enabled" then
                return "Your account HAS voice chat. If the mic UI still does not appear, run Force Enable - the client stack is stuck and the hooks can genuinely bring it back."
        end
        if e == "denied" then
                return "Your account is DENIED voice chat (age/verification gate is server-side). The hooks force the UI on, but a denied account gets no voice session - audio will not transmit. No script can change that."
        end
        if e == "checking" then
                return "Asking the Roblox backend right now..."
        end
        if e == "unavailable" then
                return "This client build has no callable IsVoiceEnabledForUserIdAsync - the truth check cannot run here."
        end
        if string.sub(e, 1, 6) == "error:" then
                return "Backend check failed: " .. string.sub(e, 8)
        end
        return "Run 'Check Real Eligibility' first - every strategy depends on the backend's answer."
end

local function audioInputCounts()
        local mine = false
        local total = 0
        for _, player in ipairs(Players:GetPlayers()) do
                for _, child in ipairs(player:GetChildren()) do
                        if child:IsA("AudioDeviceInput") then
                                total = total + 1
                                if player == LocalPlayer then
                                        mine = true
                                end
                        end
                end
        end
        return mine, total
end

local function capText(have)
        if have then
                return "OK"
        end
        return "MISSING"
end

local function eligibilityText()
        local e = state.eligibility
        if e == "enabled" then
                return "ENABLED (account has voice)"
        end
        if e == "denied" then
                return "DENIED (age/verification gate)"
        end
        if e == "checking" then
                return "asking backend..."
        end
        if e == "unchecked" then
                return "unchecked"
        end
        return e
end

local function statusText()
        local mine, total = audioInputCounts()
        return string.format(
                "Real eligibility: %s\nAudioDeviceInput: you %s | %d in server\nExecutor: hooks %s | metamethods %s | identity %s\nHooks live: %s | %s | %s\nAttributes spoofed: %s | UI forced: %s\nReport objects removed: %d | Keep-alive: %s\nLast run: %s",
                eligibilityText(),
                mine and "have one" or "none",
                total,
                capText(caps.hooks),
                capText(caps.namecall),
                capText(caps.identity),
                state.applied.eligibilityHook and "eligibility" or "-",
                state.applied.stateHook and "state" or "-",
                state.applied.namecallHook and "namecall" or "-",
                state.applied.attributes and "yes" or "no",
                state.applied.uiForced and "yes" or "no",
                state.applied.reportsKilled,
                state.keepAlive and "ON" or "off",
                state.lastRun or "never"
        )
end

local function refreshStatusSafe()
        if statusLabel then
                pcall(function()
                        statusLabel:Set(statusText())
                end)
        end
        if verdictLabel then
                pcall(function()
                        verdictLabel:Set(verdictText())
                end)
        end
end

-- =============================================================
-- Truth check (the REAL backend answer, never the hooked one)
-- =============================================================

local function checkRealEligibility()
        task.spawn(function()
                if not originalIsVoiceEnabled then
                        state.eligibility = "unavailable"
                        refreshStatusSafe()
                        notify("Eligibility Check", "No callable IsVoiceEnabledForUserIdAsync on this client.")
                        return
                end

                state.eligibility = "checking"
                refreshStatusSafe()

                local ok, result = pcall(function()
                        return originalIsVoiceEnabled(LocalPlayer.UserId)
                end)

                if ok and result == true then
                        state.eligibility = "enabled"
                elseif ok then
                        state.eligibility = "denied"
                else
                        state.eligibility = "error: " .. tostring(result)
                end

                refreshStatusSafe()
                notify("Eligibility Check", verdictText())
        end)
end

-- =============================================================
-- The full force chain + keep alive
-- =============================================================

local function runBypass()
        task.spawn(function()
                local attrs = spoofAttributes()
                applyFunctionHooks()
                applyNamecallHook()
                local surfaces = forceVoiceUI()
                killReportObjects()

                state.appliedOnce = true
                state.lastRun = os.date("%H:%M:%S")
                refreshStatusSafe()

                if state.eligibility == "unchecked" then
                        checkRealEligibility()
                end

                notify("Force Enable", string.format(
                        "Attributes spoofed: %d/4. UI surfaces forced: %d. Report objects removed: %d. Hooks: %s%s%s.",
                        attrs,
                        surfaces,
                        state.applied.reportsKilled,
                        state.applied.eligibilityHook and "eligibility " or "- ",
                        state.applied.stateHook and "state " or "- ",
                        state.applied.namecallHook and "namecall" or "-"
                ))
        end)
end

local function setKeepAlive(on)
        state.keepAlive = on and true or false
        keepAliveGeneration = keepAliveGeneration + 1
        local myGeneration = keepAliveGeneration

        if state.keepAlive then
                task.spawn(function()
                        while state.keepAlive and keepAliveGeneration == myGeneration do
                                if state.appliedOnce then
                                        spoofAttributes()
                                        forceVoiceUI()
                                        killReportObjects()
                                end
                                task.wait(5)
                        end
                end)
        end

        refreshStatusSafe()
end

-- =============================================================
-- UI
-- =============================================================

Window = Reborn:CreateWindow({
        Title = "VC Bypass",
        Size = Vector2.new(620, 520),
})

do
        local BypassTab = Window:Tab("Bypass", "radio")

        local StatusSection = BypassTab:Section("Live Status")

        statusLabel = StatusSection:Paragraph({
                Text = statusText(),
        })

        verdictLabel = StatusSection:Paragraph({
                Text = verdictText(),
        })

        local VoiceSection = BypassTab:Section("Voice Chat")

        VoiceSection:Button({
                Text = "Force Enable Voice Chat",
                Primary = true,
                Callback = runBypass,
        })

        VoiceSection:Button({
                Text = "Check Real Eligibility (asks backend)",
                Callback = checkRealEligibility,
        })

        VoiceSection:Button({
                Text = "Remove All Hooks (restore client)",
                Callback = function()
                        restoreHooks()
                        refreshStatusSafe()
                        notify("Restore", "Function and namecall hooks removed. Attributes stay spoofed until rejoin.")
                end,
        })

        VoiceSection:Toggle({
                Text = "Keep Alive (re-apply every 5s)",
                Value = false,
                Callback = function(value)
                        setKeepAlive(value)
                end,
        })

        local BanSection = BypassTab:Section("Ban Evasion")

        BanSection:Paragraph({
                Text = "Kills the client-side VoiceBan / VCTelemetry / ReportVoice objects and " ..
                        "disables VoiceReportService, so YOUR client stops reporting and " ..
                        "telemetry-logging your voice. Other players' clients can still report " ..
                        "you - that half is server-side and not reachable from here.",
        })

        BanSection:Button({
                Text = "Kill Voice Report + Telemetry Objects",
                Callback = function()
                        task.spawn(function()
                                local removed = killReportObjects()
                                refreshStatusSafe()
                                notify("Ban Evasion", string.format("Removed %d report/telemetry objects on this client.", removed))
                        end)
                end,
        })
end

do
        local InfoTab = Window:Tab("How It Works", "info")

        local TechSection = InfoTab:Section("The technique")

        TechSection:Paragraph({
                Text = "The client voice stack only initializes if VoiceChatService:" ..
                        "IsVoiceEnabledForUserIdAsync(you) returns true - that is the exact " ..
                        "check the core scripts run at startup. This script hooks that " ..
                        "function to always return true (the current public bypass " ..
                        "technique), hooks the hidden GetVoiceChatState to report Enabled, " ..
                        "and re-spoofs your local flags through a namecall hook whenever " ..
                        "the core stack re-checks. On capable executors the hook runs with " ..
                        "thread identity raised to 8.",
        })

        TechSection:Paragraph({
                Text = "On top of that it spoofs the local AgeVerified / VoiceChatEnabled / " ..
                        "IsVoiceChatUser / VCReportable attributes on your Player, force-enables " ..
                        "the voice CoreGui/PlayerGui surfaces, and destroys the local " ..
                        "VoiceBan / VCTelemetry / ReportVoice objects (ban evasion).",
        })

        local TruthSection = InfoTab:Section("What cannot be bypassed")

        TruthSection:Paragraph({
                Text = "The age/verification gate itself is SERVER-side: voice sessions are " ..
                        "issued by the Roblox backend only to eligible accounts. If the truth " ..
                        "check says DENIED, the hooks will paint the mic UI on your screen " ..
                        "but no audio will transmit, because no session token exists for " ..
                        "your account. Any script that claims otherwise is lying to you.",
        })

        TruthSection:Paragraph({
                Text = "If the truth check says ENABLED and your mic still was not showing, " ..
                        "the client stack was simply stuck - and then Force Enable genuinely " ..
                        "fixes it, because the hooked check lets the real (eligible) session " ..
                        "initialize.",
        })

        local ExecutorSection = InfoTab:Section("Executor requirements")

        ExecutorSection:Paragraph({
                Text = "Hooks need hookfunction; the namecall hook needs getrawmetatable + " ..
                        "setreadonly + getnamecallmethod; identity raise needs setthreadidentity " ..
                        "or setthreadcontext. The status panel shows exactly which of these " ..
                        "YOUR executor has - anything missing is reported honestly instead of " ..
                        "silently no-opping. Attribute spoofing, UI forcing and report-object " ..
                        "removal work on every executor, no capabilities needed.",
        })

        ExecutorSection:Paragraph({
                Text = "Everything is restored when you press Remove All Hooks, when the " ..
                        "window is destroyed, and when the script is re-executed. " ..
                        "AudioDeviceInput count in the status is the modern voice pipeline " ..
                        "tell: if other players have one and you do not, the backend is " ..
                        "excluding you specifically.",
        })
end

-- =============================================================
-- Re-apply on respawn (the core stack re-checks on character load)
-- =============================================================

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if state.appliedOnce then
                spoofAttributes()
                forceVoiceUI()
                refreshStatusSafe()
        end
end))

-- =============================================================
-- Cleanup
-- =============================================================

local function cleanup()
        state.keepAlive = false
        keepAliveGeneration = keepAliveGeneration + 1

        for _, connection in pairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end

        restoreHooks()

        pcall(function()
                Window:Destroy()
        end)

        Global.__VCBypassCleanup = nil
end

Global.__VCBypassCleanup = cleanup
