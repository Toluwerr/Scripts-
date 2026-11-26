local outerState = ... 
if game.GameId ~= 10770730129 then error("Open Ragdoll Soccer before running this script.") end
setthreadidentity(8)
local Reborn = assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau?t=" .. tostring(DateTime.now().UnixTimestampMillis)), "@Reborn"))()
assert(type(Reborn) == "table" and type(Reborn.CreateWindow) == "function" and type(Reborn.Destroy) == "function", "Reborn could not load")
local env = getgenv()
local previous = env.__PoopSoccer
local retainedSettings = type(previous) == "table" and type(previous.settings) == "table" and table.clone(previous.settings)
local retainedShots = type(previous) == "table" and type(previous.shots) == "table" and previous.shots
local retainedClosed = type(previous) == "table" and previous.window and previous.window.Closed
if env.__PoopSoccerLife then env.__PoopSoccerLife.cleanup() end
local life = {active = true, cleaners = {}, errors = {}}
function life.alive() return life.active end
function life.onCleanup(fn)
    if not life.active then fn(); return function() end end
    table.insert(life.cleaners, fn)
    return function()
        local index = table.find(life.cleaners, fn)
        if index then table.remove(life.cleaners, index) end
    end
end
function life.connect(signal, fn)
    local connection = signal:Connect(function(...)
        if life.active then fn(...) end
    end)
    life.onCleanup(function() connection:Disconnect() end)
    return connection
end
function life.override(object, key, value)
    local original = object[key]
    local frozen = table.isfrozen(object)
    if frozen then setreadonly(object, false) end
    object[key] = value
    if frozen then setreadonly(object, true) end
    local restored = false
    local unregister
    local function restore()
        if restored then return end
        restored = true
        if unregister then unregister() end
        if object[key] == value then
            local currentlyFrozen = table.isfrozen(object)
            if currentlyFrozen then setreadonly(object, false) end
            object[key] = original
            if currentlyFrozen then setreadonly(object, true) end
        end
    end
    unregister = life.onCleanup(restore)
    return restore
end
function life.cleanup()
    if not life.active then return end
    life.active = false
    local cleaners = life.cleaners
    life.cleaners = {}
    for i = #cleaners, 1, -1 do
        local ok, err = pcall(cleaners[i])
        if not ok then table.insert(life.errors, tostring(err)) end
    end
end
life.onCleanup(function() Reborn:Destroy() end)
env.__PoopSoccerLife = life
if outerState then outerState.onCleanup(life.cleanup) end

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Tags = game:GetService("CollectionService")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local gameModules = shared:WaitForChild("Game")
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game")
local function module(parent, name) return require(parent:WaitForChild(name, 15)) end
local Dribble = module(client, "DribbleClient")
local Ball = module(client, "BallView")
local Mannequin = module(client, "MannequinClient")
local Flight = module(gameModules:WaitForChild("Kick"), "Flight")
local Families = module(gameModules.Kick, "Families")
local Strike = module(gameModules.Kick, "Strike")
local KickPlan = module(gameModules.Kick, "Plan")
local KickRules = module(gameModules.Kick, "Rules")
local Path = module(gameModules:WaitForChild("Dribble"), "BallPath")
local Contacts = module(gameModules.Dribble, "Contacts")
local Tuning = module(gameModules:WaitForChild("MannequinAnimation"), "Tuning")
local PokeLegs = module(gameModules.MannequinAnimation, "PokeLegs")
local Net = module(shared, "Net")
local kickPlanRemote = Net:RemoteEvent("KickPlan")
local kickCancelRemote = Net:RemoteEvent("KickCancel")

local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local defaults = {
    shooting = true, style = "Finesse", corner = "Auto", curve = "Automatic",
    power = 100, spin = 50, assist = false, 
    speedEnabled = false, speed = 1.5, sprint = false,
    trajectory = true, marker = true, notifications = true,
    passStrength = 100, passType = "Direct pass", passPower = 85, passCurve = "Automatic", passSpin = 25,
    passTargets = "Teammates", passCone = 14, passLead = true, aimDot = true,
    autoPoke = true, walkfling = false,
    jumpEnabled = true, infiniteJump = true, jumpHeight = 18, playerHitboxes = false, playerHitboxSize = 12, hitboxVisuals = true, ballExpander = true, ballHitboxRadius = 4, ballHitboxVisual = true,
    freezeBall = false,
    hotPotato = false,
    ballGlue = true, ballOrbit = false, ballGrabRange = 24, orbitRadius = 4, orbitSpeed = 32, autoDribble = false,
    antiRagdoll = true, antiSlide = true,
    passHeightMode = "Automatic", passAngle = 37, passAdaptive = false,
    autoGK = false, gkPosition = false,
    passDecision = "Balanced", smartPassType = "Automatic", 
    antiAFK = true, rejoinGK = true, performance = true, reducePostEffects = true, keepShadows = false, fpsCap = 240,
}
local S: any = {version = "0.45", settings = table.clone(defaults), shots = retainedShots or {}, status = "Ready | F to shoot", passStatus = "B | Look at a teammate to pass", pokeStatus = "Watching the opposing ball carrier", pokeHistory = {}, busy = false, controls = {}, }
local settingsPath = "Poop/soccer.settings.json"
pcall(function()
    if isfile(settingsPath) then
        local saved = Http:JSONDecode(readfile(settingsPath))
        if type(saved) == "table" then
            for k, v in pairs(defaults) do
                if type(saved[k]) == type(v) then S.settings[k] = saved[k] end
            end
        end
    end
end)
if retainedSettings then
    for k, v in pairs(defaults) do
        if type(retainedSettings[k]) == type(v) then S.settings[k] = retainedSettings[k] end
    end
end

for key, default in pairs(defaults) do
    if type(default) == "number" and not finite(S.settings[key]) then S.settings[key] = default end
end
S.settings.speed = math.clamp(S.settings.speed, 0.5, 4)
S.settings.power = math.clamp(S.settings.power, 50, 108)
S.settings.spin = math.clamp(S.settings.spin, 0, 70)
local styles = {"Power", "Finesse", "Trivela", "Laced", "Knuckleball (low spin)", "Curve"}
local corners = {"Auto", "Top left", "Top right", "Low left", "Low right", "Centre"}
local passTypes = {"Direct pass", "Curled pass", "Driven pass", "Lofted pass", "Power pass"}
if not table.find(passTypes, S.settings.passType) then S.settings.passType = "Direct pass" end
if not table.find({"Automatic", "Left", "Right"}, S.settings.passCurve) then S.settings.passCurve = "Automatic" end
S.settings.passTargets = "Teammates"
if S.settings.passPower ~= S.settings.passPower or math.abs(S.settings.passPower) == math.huge or S.settings.passPower < 0 then S.settings.passPower = 85 end
if S.settings.passAngle ~= S.settings.passAngle or S.settings.passAngle < 0 or S.settings.passAngle >= 90 then S.settings.passAngle = 37 end
if not table.find({"Automatic", "Custom"}, S.settings.passHeightMode) then S.settings.passHeightMode = "Automatic" end
S.settings.passSpin = math.clamp(S.settings.passSpin, 0, 60)
S.settings.passCone = math.clamp(S.settings.passCone, 5, 25)
if not table.find(styles, S.settings.style) then S.settings.style = "Power" end
if not table.find(corners, S.settings.corner) then S.settings.corner = "Auto" end
if not table.find({"Automatic", "Left", "Right"}, S.settings.curve) then S.settings.curve = "Automatic" end
env.__PoopSoccer = S
local cfg = S.settings
cfg.curve = "Automatic"
cfg.passStrength = math.clamp(cfg.passStrength, 25, 150)
if cfg.smartPassType == "Curve left" or cfg.smartPassType == "Curve right" then cfg.smartPassType = "Curved" end
local function save()
    local ok, err = pcall(function()
        if not isfolder("Poop") then makefolder("Poop") end
        writefile(settingsPath, Http:JSONEncode(cfg))
    end)
    S.saveError = if ok then nil else tostring(err)
    return ok, err
end
local notifySink
local function notify(title, message, force)
    if (not cfg.notifications and not force) or not notifySink or not life.alive() then return end
    local identity = getthreadidentity()
    setthreadidentity(8)
    local ok, err = pcall(notifySink, title, message)
    setthreadidentity(identity)
    if not ok then S.notificationError = tostring(err) end
end
local function root()
    local char = player.Character
    return char and char:FindFirstChild("Root")
end
local function now() return workspace:GetServerTimeNow() end
local function ownState() return Dribble.kickState() end

local nativeHoldFree = Dribble.holdFree
local externalHoldUntil = 0
local releaseGuard
local function guardHoldUntil()
    return if releaseGuard then math.min(now() + 0.2, releaseGuard.started + 1) else 0
end
life.override(Dribble, "holdFree", function(untilTime)
    externalHoldUntil = untilTime
    return nativeHoldFree(math.max(untilTime, guardHoldUntil()))
end)
local function clearReleaseGuard(reason)
    if not releaseGuard then return end
    releaseGuard.ended = reason
    releaseGuard.duration = now() - releaseGuard.started
    releaseGuard = nil
    nativeHoldFree(externalHoldUntil)
end
local function guardRelease(sample)
    releaseGuard = {ball = sample.ball, pid = sample.pid + 1, character = player.Character, started = now()}
    S.releaseGuard = releaseGuard
    nativeHoldFree(math.max(externalHoldUntil, guardHoldUntil()))
end
life.onCleanup(function() clearReleaseGuard("Hub unloaded") end)
life.connect(Run.PreSimulation, function()
    if not releaseGuard then return end
    local r = root()
    local b = Ball.getBall()
    if not r or player.Character ~= releaseGuard.character or b ~= releaseGuard.ball then
        clearReleaseGuard("Character or ball changed")
        return
    end
    local pid = b:GetAttribute("PossessionId")
    if pid and pid ~= releaseGuard.pid and pid ~= releaseGuard.pid - 1 then
        clearReleaseGuard("Another touch")
        return
    end
    local position = Ball.getPosition()
    if position and (position - r.Position).Magnitude > 9 then
        clearReleaseGuard("Ball cleared reach")
    elseif now() - releaseGuard.started >= 1 then
        clearReleaseGuard("Release ended")
    else
        nativeHoldFree(math.max(externalHoldUntil, guardHoldUntil()))
    end
end)
local function possessionId()
    local b = Ball.getBall()
    return b and b:GetAttribute("PossessionId")
end
local function mouth(ball)
    local lines = Contacts.goalLines()
    local char = player.Character
    if not lines or not char then return nil end
    local area = module(gameModules, "KeeperRules").area(char:GetAttribute("Team"))
    if not area or (area.side ~= -1 and area.side ~= 1) then return nil end
    local out = -area.side
    local line = lines[if out == 1 then 2 else 1]
    if not finite(line) then return nil end

    local radius = if ball then ball.Size.X * 0.5 else 0.84
    local ok, params = pcall(function()
        return module(gameModules.BallSim, "World").params()
    end)
    if ok and params and finite(params.radius) and params.radius > 0 then
        radius = params.radius
    end

    local boundsOk, bounds = pcall(function()
        return module(gameModules, "PitchBounds").get()
    end)
    if boundsOk and bounds and type(bounds.goals) == "table" then
        for _, goal in ipairs(bounds.goals) do
            if goal.side == out and typeof(goal.lo) == "Vector3" and typeof(goal.hi) == "Vector3"
                and finite(goal.lo.Y) and finite(goal.hi.Y) and finite(goal.lo.Z) and finite(goal.hi.Z)
                and goal.hi.Y > goal.lo.Y and goal.hi.Z > goal.lo.Z then
                return {
                    x = line, z = (goal.lo.Z + goal.hi.Z) * 0.5,
                    out = out, width = (goal.hi.Z - goal.lo.Z) * 0.5,
                    ground = goal.lo.Y, top = goal.hi.Y, radius = radius,
                }
            end
        end
    end

    for _, frame in ipairs(Tags:GetTagged("SoccerGoalFrame")) do
        if frame:IsA("BasePart") and frame:IsDescendantOf(workspace) and (frame.Position.X - area.centre.X) * out > 0 then
            local scale = frame.Size.Y / 9.142857142857142
            local ground = frame.Position.Y - frame.Size.Y / 2
            return {
                x = line, z = frame.Position.Z,
                out = out, width = 13.071428571428571 * scale,
                ground = ground, top = ground + 8.714285714285714 * scale, radius = radius,
            }
        end
    end
    return nil
end
local function ballSample()
    local b = Ball.getBall()
    local r = root()
    if not b or not r then return nil, "Spawn on the pitch first" end
    local at = now()
    local state = ownState()
    if state then
        if not finite(state.pid) then return nil, "Ball possession is syncing; try again" end
        return {ball = b, from = Path.sample(state.seg, at, state.P), time = at, state = state, pid = state.pid}
    end
    local source = Ball.getSource()
    local position = Ball.getPosition()
    if not position then return nil, "Ball is unavailable" end
    if (r.Position - position).Magnitude > 11 then return nil, "Get close to the ball or take possession" end
    if source ~= "free" and source ~= "released" then return nil, "Another player has possession" end
    local sample = Ball.freeSample(at)
    if not sample or sample == Vector3.zero then sample = position end
    local pid = possessionId()
    if not finite(pid) then return nil, "Ball possession is syncing; try again" end
    return {ball = b, from = sample, time = at, pid = pid}
end
local function opponents(includeAllies)
    local char = player.Character
    local team = char and char:GetAttribute("Team")
    local result = {}
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char then
            local otherRoot = model:FindFirstChild("Root")
            local otherTeam = model:GetAttribute("Team")
            if otherRoot and otherRoot:IsA("BasePart") and otherTeam and (includeAllies or otherTeam ~= team) then
                local engine = S.passingEngine
                local actor = engine and engine.actor(model, Players:GetPlayerFromCharacter(model), now())
                table.insert(result, {root = otherRoot, model = model, actor = actor, enemy = otherTeam ~= team})
            end
        end
    end
    return result
end
local function targetFor(goal, from, configuration)
    local options = configuration or cfg
    local radius = goal.radius or 0.84
    local side = math.max(0, goal.width - radius - 1.25)
    local top = goal.top - radius - 1.1
    local low = goal.ground + radius + 1.15
    if low > top then
        low = (goal.ground + goal.top) * 0.5
        top = low
    end
    local function point(left, high)
        return Vector3.new(goal.x, if high then top else low, goal.z + (if left then -1 else 1) * goal.out * side)
    end
    if options.corner == "Top left" then return point(true, true) end
    if options.corner == "Top right" then return point(false, true) end
    if options.corner == "Low left" then return point(true, false) end
    if options.corner == "Low right" then return point(false, false) end
    if options.corner == "Centre" then return Vector3.new(goal.x, (top + low) / 2, goal.z) end
    local enemies = opponents()
    local ranked = {}
    for _, candidate in ipairs({point(true, true), point(false, true), point(true, false), point(false, false)}) do
        local score = if candidate.Y > (top + low) / 2 then 3 else 0
        local closest = 80
        for _, enemy in ipairs(enemies) do
            local predicted = enemy.root.Position + enemy.root.AssemblyLinearVelocity * 0.15
            local flatDistance = Vector2.new(predicted.X - candidate.X, predicted.Z - candidate.Z).Magnitude
            closest = math.min(closest, flatDistance)
        end
        score = score + closest - (candidate - from).Magnitude * 0.012
        table.insert(ranked, {point = candidate, score = score})
    end
    table.sort(ranked, function(a, b) return a.score > b.score end)
    local points = {}
    for _, item in ipairs(ranked) do table.insert(points, item.point) end
    return points[1], points
end
local function profile(style, from, target, configuration)
    local options = configuration or cfg
    local familyName = if style == "Curve" then "Finesse" elseif style == "Knuckleball (low spin)" then "Power" else style
    local family = Families[familyName] or Families.Power
    local side = 0
    local back = family.back or 0
    if style == "Finesse" or style == "Curve" or style == "Trivela" then
        local direction = if options.curve == "Left" then 1 elseif options.curve == "Right" then -1 else math.sign((target.Z - from.Z) * (target.X - from.X))
        if direction == 0 then direction = 1 end
        side = options.spin * direction
    end
    if style == "Knuckleball (low spin)" then back = 0 end
    local speed = family.speed[2] * 1.05 * math.clamp(options.power, 50, 108) / 100
    return familyName, speed, side, back
end

local function goalPassage(simulation, goal, radius)
    local lowerZ = goal.z - goal.width + radius + 0.4
    local upperZ = goal.z + goal.width - radius - 0.4
    local lowerY = goal.ground + radius - 0.12
    local upperY = goal.top - radius - 0.4
    if lowerZ > upperZ or lowerY > upperY or not simulation.pos[1] then
        return nil, "Invalid goal passage"
    end
    local firstDepth = (simulation.pos[1].X - goal.x) * goal.out
    if firstDepth >= radius then return nil, "Ball is already behind the goal line" end
    local entered = firstDepth >= -radius
    local centre = if firstDepth == 0 then simulation.pos[1] else nil
    local minZ, maxZ, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    local function include(point)
        minZ, maxZ = math.min(minZ, point.Z), math.max(maxZ, point.Z)
        minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
    end
    if entered then include(simulation.pos[1]) end
    for i = 2, simulation.n do
        local a, b = simulation.pos[i - 1], simulation.pos[i]
        local da, db = (a.X - goal.x) * goal.out, (b.X - goal.x) * goal.out
        if not entered and da < -radius and db >= -radius then
            entered = true
            include(a:Lerp(b, (-radius - da) / (db - da)))
        end
        if entered then
            if db < -radius then return nil, "Shot turns back before entering the goal" end
            if da < 0 and db >= 0 then centre = a:Lerp(b, -da / (db - da)) end
            if da < radius and db >= radius then
                local exit = a:Lerp(b, (radius - da) / (db - da))
                include(exit)
                local dz = if minZ < lowerZ then lowerZ - minZ elseif maxZ > upperZ then upperZ - maxZ else 0
                local dy = if maxY > upperY then upperY - maxY elseif minY < lowerY then lowerY - minY else 0
                return {
                    valid = dz == 0 and dy == 0,
                    shiftZ = dz, shiftY = dy,
                    position = exit, centre = centre,
                    time = (i - 2 + (radius - da) / (db - da)) * Flight.STEP,
                    margin = math.min(minZ - lowerZ, upperZ - maxZ, minY - lowerY, upperY - maxY),
                    minZ = minZ, maxZ = maxZ, minY = minY, maxY = maxY,
                }
            end
            include(b)
        end
    end
    return nil, "Shot does not fully cross the goal line"
end

local function choiceKey(options)
    return table.concat({options.style, options.corner, options.curve, tostring(options.power), tostring(options.spin)}, ":")
end

local function makeShotPlanner(Flight, budget)
    local function validVector(value)
        return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
    end

    local function constrainInputs(familyName, from, target, speed, side, back)
        if not finite(speed) or speed <= 0 or not finite(side) or not finite(back) then return nil end
        local family = Families[familyName]
        if not family then return nil end

        local maximum = math.max(family.speed[2], family.shotSpeed and family.shotSpeed[2] or 0)
            * KickRules.Server.SpeedSlack * KickRules.KickButton.FullPower
        if finite(maximum) and maximum > 0 then
            speed = math.min(speed, maximum * 0.9999)
        end

        local flat = (target - from) * Vector3.new(1, 0, 1)
        if flat.Magnitude > 0.001 then
            local spin = Flight.spinFrom(flat.Unit, side, back)
            local maxSpin = KickRules.Server.MaxSpin
            if not validVector(spin) then return nil end
            if finite(maxSpin) and maxSpin > 0 and spin.Magnitude > maxSpin then
                local scale = maxSpin * 0.9999 / spin.Magnitude
                side, back = side * scale, back * scale
            end
        end

        return speed, side, back
    end

    local function fitShot(sample, target, goal, family, speed, side, back, attempts)
        if not validVector(sample.from) or not validVector(target) then return nil end
        speed, side, back = constrainInputs(family, sample.from, target, speed, side, back)
        if not speed then return nil end
        local radius = goal.radius or sample.ball.Size.X * 0.5
        local params = Flight.params(sample.ball)
        local groundY = Ball.groundBallY()
        local aim = target
        local best, bestError
        for _ = 1, attempts or 3 do
            local velocity, spin, flightTime, miss = Flight.solve(sample.from, aim, speed, side, back, params, groundY, math.rad(70))
            if not finite(flightTime) or flightTime <= 0 or not finite(miss)
                or not validVector(velocity) or not validVector(spin) then break end
            local acceptedVelocity, acceptedSpin = KickRules.checkStrike(family, velocity, spin)
            if not validVector(acceptedVelocity) or not validVector(acceptedSpin) then break end
            velocity, spin = acceptedVelocity, acceptedSpin
            local simulation = Flight.simulate(sample.from, velocity, spin, 0, params, groundY, math.min(flightTime + 1, 10))
            local passage = goalPassage(simulation, goal, radius)
            if not passage then break end

            local shiftY, shiftZ = passage.shiftY, passage.shiftZ
            if passage.valid then
                local crossing = passage.centre
                local placementError = if crossing then (crossing - target).Magnitude else miss
                if (miss <= 1.1 or placementError <= 1.1) and (not bestError or placementError < bestError) then
                    bestError = placementError
                    best = {
                        target = target, aim = aim, family = family, velocity = velocity, spin = spin,
                        flightTime = passage.time, miss = placementError, solverMiss = miss, sample = sample, passage = passage,
                        simulation = simulation, side = side, back = back, speed = speed, goal = goal,
                    }
                end
                if not crossing or placementError <= 0.35 then break end
                shiftY, shiftZ = target.Y - crossing.Y, target.Z - crossing.Z
            end

            local nextAim = Vector3.new(goal.x,
                math.clamp(aim.Y + shiftY * 1.12, goal.ground + radius + 0.2, goal.top - radius - 0.3),
                math.clamp(aim.Z + shiftZ * 1.12, goal.z - goal.width + radius + 0.3, goal.z + goal.width - radius - 0.3))
            if (nextAim - aim).Magnitude < 0.01 then break end
            aim = nextAim
        end
        return best
    end

    local function clearanceScore(plan, bodies)
        local closest, interception = 35, 0.8
        local reachTime = S.passingEngine and S.passingEngine.reachTime
        local stride = math.max(1, math.floor(plan.simulation.n / 28))
        for i = 1, plan.simulation.n, stride do
            if budget then budget() end
            local time = (i - 1) * Flight.STEP
            if time > plan.flightTime then break end
            local point = plan.simulation.pos[i]
            for _, body in ipairs(bodies) do
                local predicted = body.root.Position + body.root.AssemblyLinearVelocity * math.min(time, 0.3)
                local keeper = body.model:GetAttribute("Role") == "Goalkeeper"
                local bodyY = math.clamp(point.Y, predicted.Y - 2.8, predicted.Y + 3.1)
                local radius = if keeper then 3.5 else 2.1
                closest = math.min(closest, (point - Vector3.new(predicted.X, bodyY, predicted.Z)).Magnitude - radius)
                if body.enemy and body.actor and reachTime then
                    local jump = if keeper and time > 0.35 then math.min((time - 0.35) * 12, 4) else 0
                    if point.Y <= body.actor.pos.Y + 3.1 + jump then
                        local arrival = reachTime(body.actor, point, radius + 0.84, if body.actor.available then 0.14 else 0.65)
                        interception = math.min(interception, arrival - time)
                    end
                end
            end
        end
        return interception * 20 + closest * 0.3 - plan.flightTime * 3 + math.min(plan.passage.margin, 2)
    end

    local previewChoice
    local function calculate(sample, preview, configuration)
        local options = configuration or cfg
        local goal = mouth(sample.ball)
        if not goal then return nil, "No opponent goal is loaded" end
        if goal.width <= goal.radius + 0.4 or goal.top - goal.ground <= 2 * goal.radius + 0.5 then
            return nil, "Goal opening is too small for the ball"
        end
        local target, ranked = targetFor(goal, sample.from, options)
        local points = ranked or {target}
        if not preview and options.corner == "Auto" then
            table.insert(points, Vector3.new(goal.x, (goal.ground + goal.top) / 2, goal.z))
        end
        local key = choiceKey(options)
        local preferredSide
        if preview then
            local preferred = previewChoice and previewChoice.key == key and previewChoice.out == goal.out and previewChoice.target
            points = {preferred or target}
            if preferred then preferredSide = previewChoice.side end
        end
        local bodies = if preview then {} else opponents(true)
        local best, bestScore
        for _, point in ipairs(points) do
            local family, speed, side, back = profile(options.style, sample.from, point, options)
            if preferredSide ~= nil then side = preferredSide end
            local directions = {side}
            if not preview and options.curve == "Automatic" and side ~= 0 then table.insert(directions, -side) end
            for _, chosenSide in ipairs(directions) do
                local plan = fitShot(sample, point, goal, family, speed, chosenSide, back, if preview then 1 else 3)
                if plan then
                    local score = clearanceScore(plan, bodies)
                    if not bestScore or score > bestScore then best, bestScore = plan, score end
                end
            end
        end

        if not preview and not best and options.curve == "Automatic" and (options.style == "Power" or options.style == "Laced" or options.style == "Knuckleball (low spin)") then
            local amounts = if options.style == "Knuckleball (low spin)" then {8} else {12, 30}
            for _, amount in ipairs(amounts) do
                for _, point in ipairs(points) do
                    local family, speed, _, back = profile(options.style, sample.from, point, options)
                    for _, side in ipairs({amount, -amount}) do
                        local plan = fitShot(sample, point, goal, family, speed, side, back)
                        if plan then
                            local score = clearanceScore(plan, bodies)
                            if not bestScore or score > bestScore then best, bestScore = plan, score end
                        end
                    end
                end
                if best then break end
            end
        end
        if best and not preview and not configuration then previewChoice = {target = best.target, key = key, out = goal.out, side = best.side} end
        return best, if best then nil else "No clear route through the goal at this power; move closer or change technique"
    end

    return calculate, fitShot
end

local calculate, fitShot = makeShotPlanner(Flight)
S.calculate = calculate
S.goalPassage = goalPassage
function S.planAt(position, options)
    local ball = Ball.getBall()
    if not ball then return nil, "No ball is loaded" end
    local configuration = table.clone(cfg)
    for key, value in pairs(options or {}) do configuration[key] = value end
    return calculate({ball = ball, from = position, time = now(), pid = possessionId()}, false, configuration)
end
local goalRemote = game:GetService("ReplicatedStorage"):FindFirstChild("GoalPopup")
if goalRemote then
    life.connect(goalRemote.OnClientEvent, function(payload)
        if type(payload) == "table" and payload.scorer == player.UserId then
            S.lastGoalEvent = {at = now(), payload = payload}
            local b = Ball.getBall()
            local flight = b and b:GetAttribute("KickFlight")
            local fields = type(flight) == "string" and string.split(flight, "|")
            local pid = fields and tonumber(fields[2])
            if payload.ownGoal ~= 1 and payload.ownGoal ~= true and pid then
                for i = #S.shots, 1, -1 do
                    local shot = S.shots[i]
                    if shot.pid and pid == shot.pid + 1 and fields[14] == shot.family
                        and tonumber(fields[13]) == shot.characterId and now() - shot.at < 12 then
                        shot.goalConfirmed = true
                        shot.goalEvent = S.lastGoalEvent
                        break
                    end
                end
            end
        end
    end)
end
local function trackShot(plan, before, style, motion)
    local entry = {
        at = now(), family = plan.family, style = style, miss = plan.miss,
        from = tostring(plan.sample.from), target = tostring(plan.target), velocity = tostring(plan.velocity),
        accepted = false, goalConfirmed = false, result = "Awaiting server", pid = plan.sample.pid,
        trackingVersion = "0.3",
        expectedTime = plan.sample.time,
        passageMargin = plan.passage.margin, planningVersion = "0.4",
        solverMiss = plan.solverMiss,
        plannedSpeed = plan.speed, releaseSpeed = plan.velocity.Magnitude,
        side = plan.side, spin = tostring(plan.spin), spinMagnitude = plan.spin.Magnitude,
        samples = {},
        sampleAge = now() - plan.sample.time,
        contactOffset = motion and motion.contactOffset,
        contactDrift = motion and motion.contactDrift,
        characterId = player.Character and player.Character:GetAttribute("DribbleId"),
    }
    table.insert(S.shots, entry)
    if #S.shots > 30 then table.remove(S.shots, 1) end
    S.lastShot = entry
    task.spawn(function()
        local finishAt = os.clock() + math.clamp(plan.flightTime + 3.5, 4, 12)
        local b = plan.sample.ball
        while life.alive() and b.Parent and Ball.getBall() == b and os.clock() < finishAt do
            local flight = b.Parent and b:GetAttribute("KickFlight")
            if flight and flight ~= before then
                local fields = string.split(flight, "|")
                local by = tonumber(fields[13])
                if not entry.accepted and entry.characterId and by == entry.characterId and fields[14] == plan.family
                    and type(entry.pid) == "number" and tonumber(fields[2]) == entry.pid + 1 then
                    entry.accepted = true
                    entry.serverFlight = flight
                    local decoded, event = pcall(Flight.decode, flight)
                    if decoded and event then
                        if typeof(event.pos) == "Vector3" then entry.serverPositionError = (event.pos - plan.sample.from).Magnitude end
                        if typeof(event.vel) == "Vector3" then entry.serverVelocityError = (event.vel - plan.velocity).Magnitude end
                        if typeof(event.spin) == "Vector3" then entry.serverSpinError = (event.spin - plan.spin).Magnitude end
                        if finite(event.t) then entry.serverTimeOffset = event.t - plan.sample.time end
                    end
                end
            end
            if entry.goalConfirmed then
                entry.result = "Goal confirmed"
                if S.lastShot == entry then S.status = "Goal confirmed | " .. entry.style end
                notify("Goal", entry.style .. " scored.")
                return
            end
            if #entry.samples < 50 then
                table.insert(entry.samples, {at = now(), pos = tostring(Ball.getPosition()), sim = b:GetAttribute("BallSim")})
            end
            task.wait(0.12)
        end
        if not life.alive() then return end
        entry.result = if entry.accepted then "Server accepted; no goal confirmed" else "Release not confirmed by server"
        if S.lastShot == entry then S.status = entry.result end
    end)
end
local lastAction = -10
S.lastKickMotion = nil
local kickMotion
local function cancelKickMotion(reason)
    local motion = kickMotion
    if not motion then return end
    kickMotion = nil
    if motion.animator.kick and motion.animator.kick.id == motion.id then motion.animator.kick = nil end
    if not motion.released then
        pcall(function() kickCancelRemote:FireServer(motion.id) end)
        motion.status = reason or "Cancelled"
    end
end
life.onCleanup(function() cancelKickMotion("Hub unloaded") end)
life.connect(Net:RemoteEvent("KickPlanRelay").OnClientEvent, function(sender, packet)
    local motion = S.lastKickMotion
    if sender == player and motion and type(packet) == "table" and packet.id == motion.id then
        motion.relayed = true
        motion.relayAt = now()
        motion.status = "Server relayed kick motion"
    end
end)
local motionRenderName = "PoopSoccerKickMotion"
Run:BindToRenderStep(motionRenderName, Enum.RenderPriority.Camera.Value - 2, function()
    local motion = kickMotion
    if not motion then return end
    local character = player.Character
    if not life.alive() or character ~= motion.character or character:GetAttribute("BodyState") ~= "Animated" then
        cancelKickMotion("Kick interrupted")
        return
    end
    local remaining = motion.contactAt - now()
    if motion.released or remaining < -0.25 then
        
        if motion.animator.kick and motion.animator.kick.id == motion.id then motion.animator.kick = nil end
        kickMotion = nil
        return
    end
    motion.spec.at = math.max(remaining, 0.001)
    motion.animator.kick = motion.spec
end)
life.onCleanup(function() Run:UnbindFromRenderStep(motionRenderName) end)
local function beginKickMotion(sample, plan)
    local character = player.Character
    local animator = character and Mannequin.getAnimator(character)
    local r = root()
    local family = Families[plan.family]
    if not animator or not r or not family or character:GetAttribute("BodyState") ~= "Animated" then return nil end
    cancelKickMotion("Replaced")
    local lead = math.clamp(math.max((family.plantAt or 0.12) + 0.17, (family.swing or 0.08) + 0.2), 0.28, 0.4)
    local contactAt = now() + lead
    local contact = if sample.state then Path.sample(sample.state.seg, contactAt, sample.state.P) else Ball.freeSample(contactAt)
    if not contact or contact == Vector3.zero then contact = sample.from end
    if (contact - plan.sample.from).Magnitude > 0.1 then
        local predicted = {ball = sample.ball, from = contact, time = contactAt, state = sample.state, pid = sample.pid}
        local adjusted = fitShot(predicted, plan.target, plan.goal, plan.family, plan.speed, plan.side, plan.back)
        if not adjusted then return nil, nil, "No valid shot from the predicted contact position" end
        plan = adjusted
    end
    local remaining = contactAt - now()
    if remaining <= (family.plantAt or 0.12) then
        return nil, nil, "Shot calculation exceeded the windup; try F again"
    end
    local current = ballSample()
    if player.Character ~= character or not current or current.ball ~= sample.ball or current.pid ~= sample.pid then
        return nil, nil, "Possession changed before the kick"
    end
    local direction = plan.velocity * Vector3.new(1, 0, 1)
    if direction.Magnitude < 0.01 then direction = r.CFrame.LookVector * Vector3.new(1, 0, 1) end
    direction = direction.Unit
    local leg = if r.CFrame:PointToObjectSpace(contact).X < -0.4 then 1 else 2
    local ground = Ball.groundBallY(contact) - (plan.goal.radius or 0.84)
    local _, plant, plantYaw = KickPlan.spots(contact, direction, leg, family, ground, 1, r.CFrame.LookVector)
    env.__PoopSoccerKickId = (env.__PoopSoccerKickId or 1000000) + 1
    local id = env.__PoopSoccerKickId
    local plantAt = family.plantAt or 0.12
    local spec = {id = id, leg = leg, at = remaining, ball = contact, dir = direction, family = family,
        power = 1, plant = plant, plantYaw = plantYaw, plantAt = plantAt}
    local motion = {id = id, character = character, animator = animator, spec = spec, contactAt = contactAt,
        requestedAt = now(), pid = sample.pid, family = plan.family, relayed = false, released = false,
        status = "Kick motion sent | checking server relay"}
    kickMotion = motion
    S.lastKickMotion = motion
    if sample.state then Dribble.holdTouches(contactAt + 0.12) end
    animator.kick = spec
    kickPlanRemote:FireServer({id = id, leg = leg, t = contactAt, shift = 0, ball = contact, dir = direction,
        family = plan.family, power = 1, plant = plant, plantYaw = plantYaw, plantAt = plantAt,
        vel = plan.velocity, spin = plan.spin or Vector3.zero})
    return motion, plan
end
function S.shoot(silent)
    if not life.alive() then return false end
    if S.busy or os.clock() - lastAction < 0.5 then return false end
    S.busy = true
    local style = cfg.style
    local ok, sent, reason = pcall(function()
        local sample, why = ballSample()
        if not sample then return false, why end
        local character = player.Character
        local function resample()
            if not life.alive() then return nil, "Hub unloaded" end
            if player.Character ~= character then return nil, "Character changed; try F again" end
            local current, message = ballSample()
            if not current or current.ball ~= sample.ball or current.pid ~= sample.pid then
                return nil, message or "Possession changed; try F again"
            end
            return current
        end

        local plan, whyPlan = calculate(sample)
        if not plan then return false, whyPlan end
        local windupSample, windupWhy = resample()
        if not windupSample then return false, windupWhy end
        local motion, motionPlan, motionWhy = beginKickMotion(windupSample, plan)
        if motionWhy then return false, motionWhy end
        if motion then
            plan = motionPlan
            S.status = "Planting foot | " .. style
            while life.alive() and now() < motion.contactAt do
                if player.Character ~= motion.character or motion.character:GetAttribute("BodyState") ~= "Animated"
                    or kickMotion ~= motion or Ball.getBall() ~= sample.ball then
                    return false, "Kick interrupted; try F again when standing"
                end
                Run.Heartbeat:Wait()
            end
            if kickMotion ~= motion or player.Character ~= motion.character or motion.character:GetAttribute("BodyState") ~= "Animated" then
                return false, "Kick interrupted; try F again when standing"
            end
        end

        local fresh, freshWhy = resample()
        if not fresh then return false, freshWhy end
        plan = fitShot(fresh, plan.target, plan.goal, plan.family, plan.speed, plan.side, plan.back)
        if not plan then return false, "The ball moved out of this shot's route; try F again" end
        local latest, latestWhy = resample()
        if not latest then return false, latestWhy end
        if (latest.from - fresh.from).Magnitude > 0.25 then
            fresh = latest
            plan = fitShot(fresh, plan.target, plan.goal, plan.family, plan.speed, plan.side, plan.back)
            if not plan then return false, "The ball moved out of this shot's route; try F again" end
            latest, latestWhy = resample()
            if not latest then return false, latestWhy end
            if (latest.from - fresh.from).Magnitude > 0.25 then
                return false, "The ball is moving too quickly for this shot; try F again"
            end
        end
        sample = fresh
        if motion then motion.contactDrift = (sample.from - motion.spec.ball).Magnitude end
        local before = sample.ball:GetAttribute("KickFlight")
        local released
        if sample.state then
            released = Dribble.strike(sample.from, plan.velocity, plan.spin, plan.family, sample.time)
        else
            released = Dribble.strikeFree(sample.from, plan.velocity, plan.spin, plan.family, sample.time)
        end
        if not released then return false, "Ball is no longer available" end
        if motion then
            motion.released = true
            motion.releasedAt = now()
            motion.contactOffset = motion.releasedAt - motion.contactAt
            motion.status = if motion.relayed then "Server relayed kick motion" else "Kick motion sent | relay not confirmed"
        end
        guardRelease(sample)
        lastAction = os.clock()
        S.status = style .. " released | checking goal"
        trackShot(plan, before, style, motion)
        return true
    end)
    S.busy = false
    if not ok or not sent then cancelKickMotion("Shot cancelled") end
    if not ok then
        S.error = tostring(sent)
        S.status = "Shot error | " .. tostring(sent)
        if not silent then notify("Shot unavailable", "The ball state changed. Try F again.") end
        return false
    end
    if not sent then
        S.status = reason or "Shot unavailable"
        if not silent then notify("Shot unavailable", S.status) end
    end
    return sent
end

local passSight = RaycastParams.new()
passSight.FilterType = Enum.RaycastFilterType.Exclude
passSight.RespectCanCollide = false

local baseline = table.clone(Tuning.Speed)
local speedFields = {"Walk", "Jog", "Sprint", "SideStep", "BackStep", "SideStepSprint", "BackStepSprint", "Strafe", "StrafeBack", "SideSprint", "BackSprint"}
local lastApplied = {}
local function applySpeed()
    if not life.alive() then return end
    for _, key in ipairs(speedFields) do
        local value = baseline[key] * (if cfg.speedEnabled then cfg.speed else 1)
        Tuning.Speed[key] = value
        lastApplied[key] = value
    end
end
life.onCleanup(function()
    for _, key in ipairs(speedFields) do
        if Tuning.Speed[key] == lastApplied[key] then Tuning.Speed[key] = baseline[key] end
    end
end)
applySpeed()
S.applySpeed = applySpeed
local nativeSprint = Mannequin.keepSprint
life.override(Mannequin, "keepSprint", function()
    if cfg.sprint then return true end
    return nativeSprint and nativeSprint() or false
end)
local nativeSolve = Strike.solve
life.override(Strike, "solve", function(request)
    if cfg.assist then
        local replacement = table.clone(request)
        replacement.exact = true
        replacement.errorScale = 0
        return nativeSolve(replacement)
    end
    return nativeSolve(request)
end)

local pokeSight = RaycastParams.new()
pokeSight.FilterType = Enum.RaycastFilterType.Exclude
pokeSight.RespectCanCollide = true
local pokeAction, pokeCallback
local lastPokeAttempt = -10
function S.pokeOpportunity()
    if not life.alive() then return nil, "Hub unloaded" end
    local character, r = player.Character, root()
    local ball = Ball.getBall()
    if not character or not r or not ball then return nil, "Spawn on the pitch first" end
    if S.busy or ownState() or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return nil, "Waiting for controls" end
    if character:GetAttribute("BodyState") ~= "Animated" then return nil, "Waiting until standing" end
    local team = character:GetAttribute("Team")
    if team ~= "Blue" and team ~= "Red" then return nil, "Join a team first" end
    if workspace:GetAttribute("ProServer") == true then
        local phase = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
        if phase and phase:GetAttribute("Phase") ~= "Play" then return nil, "Waiting for play" end
    end
    local carrierId = ball:GetAttribute("Possessor")
    if type(carrierId) ~= "number" or carrierId <= 0 or carrierId == character:GetAttribute("DribbleId") then return nil, "No opposing ball carrier" end
    local carrier, carrierRoot, carrierPlayer
    for _, other in ipairs(Players:GetPlayers()) do
        local model = other.Character
        if other ~= player and model and model:GetAttribute("DribbleId") == carrierId then
            carrier, carrierRoot, carrierPlayer = model, model:FindFirstChild("Root"), other
            break
        end
    end
    if not carrier or not carrierRoot or carrier:GetAttribute("Team") == team then return nil, "No opposing ball carrier" end
    if carrier:GetAttribute("Team") ~= "Blue" and carrier:GetAttribute("Team") ~= "Red" then return nil, "Carrier is off the pitch" end
    local controller = character:FindFirstChild("ControllerManager")
    if not controller or controller.ActiveController ~= controller:FindFirstChild("GroundController") then return nil, "Waiting until grounded" end
    if now() < (player:GetAttribute("PokeReadyAt") or 0) then return nil, "Poke cooling down" end
    local animator = Mannequin.getAnimator(character)
    if not animator or animator.kick or (animator.kickS and not animator.kickS.done) or PokeLegs.reaching(animator) then return nil, "Waiting for current action" end
    local position, velocity = Ball.freeState()
    position = position or Ball.getPosition()
    if not position then return nil, "Ball unavailable" end
    velocity = velocity or carrierRoot.AssemblyLinearVelocity
    local predicted = position + velocity * Vector3.new(1, 0, 1) * PokeLegs.CONTACT
    local origin = r.Position + (animator.visualOffset or Vector3.zero)
    local delta = (predicted - origin) * Vector3.new(1, 0, 1)
    local distance = delta.Magnitude
    local carrierDistance = ((carrierRoot.Position - r.Position) * Vector3.new(1, 0, 1)).Magnitude
    if distance > PokeLegs.MAX_REACH - 0.25 or carrierDistance > PokeLegs.MAX_REACH + 3 then return nil, "Carrier outside poke reach" end
    local forward = r.CFrame.LookVector * Vector3.new(1, 0, 1)
    local turn = distance > 0.5 and forward.Magnitude > 0.001 and forward.Unit:Dot(delta.Unit) < math.cos(PokeLegs.MAX_TURN)
    local futureOrigin = origin + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * (PokeLegs.CONTACT * 0.8)
    if ((predicted - futureOrigin) * Vector3.new(1, 0, 1)).Magnitude > PokeLegs.MAX_REACH - 0.1 then return nil, "Ball moving out of reach" end
    if predicted.Y - (Ball.groundBallY(predicted) - 0.84) > PokeLegs.MAX_HEIGHT then return nil, "Ball above poke height" end
    local ignored = {character, ball}
    local ballView = workspace:FindFirstChild("BallView")
    if ballView then table.insert(ignored, ballView) end
    pokeSight.FilterDescendantsInstances = ignored
    local obstacle = workspace:Raycast(origin, predicted - origin, pokeSight)
    if obstacle and not obstacle.Instance:IsDescendantOf(carrier) then return nil, "Poke path blocked" end
    return {ball = ball, model = carrier, root = carrierRoot, player = carrierPlayer, id = carrierId,
        pid = ball:GetAttribute("PossessionId"), distance = distance, carrierDistance = carrierDistance, animator = animator,
        turn = turn, direction = if distance > 0.01 then delta.Unit else forward, characterRoot = r, controller = controller}
end
local function nativePokeCallback()
    if pokeAction and pokeAction.Parent and pokeCallback then return pokeCallback end
    local context = player.PlayerScripts:FindFirstChild("Poke")
    local action = context and context:FindFirstChild("Poke")
    if not action then return nil end
    for _, connection in ipairs(getconnections(action.Pressed)) do
        local callback = connection.Function
        if callback and string.find(debug.info(callback, "s"), "PokeClient", 1, true) then
            pokeAction, pokeCallback = action, callback
            return callback
        end
    end
    return nil
end
function S.pokeCarrier(silent)
    if not life.alive() then return false end
    local opportunity, reason = S.pokeOpportunity()
    if not opportunity then
        S.pokeStatus = reason
        if not silent then notify("Poke", reason) end
        return false
    end
    if opportunity.turn then
        local r, direction = opportunity.characterRoot, opportunity.direction
        opportunity.controller.FacingDirection = direction
        r.CFrame = CFrame.lookAt(r.Position, r.Position + direction)
        S.lastPokeAlignment = {at = now(), pid = opportunity.pid, direction = direction}
        return false
    end
    if S.lastPokeAlignment and S.lastPokeAlignment.pid == opportunity.pid and now() - S.lastPokeAlignment.at < 0.04 then return false end
    if os.clock() - lastPokeAttempt < 0.2 then return false end
    lastPokeAttempt = os.clock()
    local callback = nativePokeCallback()
    if not callback then S.pokeStatus = "Native poke control is loading"; return false end
    if opportunity.ball:GetAttribute("Possessor") ~= opportunity.id or opportunity.ball:GetAttribute("PossessionId") ~= opportunity.pid then return false end
    local before = opportunity.animator.poke
    local ok, err = pcall(callback)
    if not ok then S.pokeError = tostring(err); S.pokeStatus = "Poke unavailable"; return false end
    local active = opportunity.animator.poke
    if not active or active == before then S.pokeStatus = "Native poke is not ready"; return false end
    local record: any = {at = now(), target = opportunity.player.DisplayName, userId = opportunity.player.UserId,
        ball = opportunity.ball, ownId = player.Character:GetAttribute("DribbleId"), carrierId = opportunity.id, possessorAtAttempt = opportunity.ball:GetAttribute("Possessor"), pid = opportunity.pid,
        distance = opportunity.distance, carrierDistance = opportunity.carrierDistance, pokeId = active.id,
        won = false, status = "Poking the ball carrier"}
    S.lastPoke = record
    if cfg.autoPoke then S.pokeRecovery.cushion(record) end
    table.insert(S.pokeHistory, record)
    if #S.pokeHistory > 20 then table.remove(S.pokeHistory, 1) end
    S.pokeStatus = "Poking " .. record.target
    if not silent then notify("Poke", "Targeting ball carrier " .. record.target .. ".") end
    task.spawn(function()
        local finish = os.clock() + 1.7
        while life.alive() and opportunity.ball.Parent and os.clock() < finish do
            local character = player.Character
            local mine = character and character:GetAttribute("DribbleId")
            local holder = opportunity.ball:GetAttribute("Possessor")
            local pid = opportunity.ball:GetAttribute("PossessionId")
            if Ball.getBall() ~= opportunity.ball then break end
            local poke = opportunity.animator.pokeS
            if character and poke and poke.id == record.pokeId and not poke.done
                and now() - record.at < PokeLegs.REACH + PokeLegs.HOLD + 0.1 then
                local position = Ball.getPosition()
                if position then
                    for _, name in ipairs({"LeftFoot", "RightFoot"}) do
                        local foot = character:FindFirstChild(name)
                        if foot and foot:IsA("BasePart") then
                            local p, half = foot.CFrame:PointToObjectSpace(position), foot.Size * 0.5
                            local closest = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
                            local gap = (p - closest).Magnitude
                            record.footGap = math.min(record.footGap or math.huge, gap)
                            if gap < opportunity.ball.Size.X * 0.5 + 0.12 then record.contactAt = now() end
                        end
                    end
                end
            end
            local flight = Flight.decode(opportunity.ball:GetAttribute("KickFlight"))
            local freshShot = flight and flight.by == record.ownId and flight.t >= record.at - 0.05
            local release = {pid = pid, owner = tonumber(holder) or 0, by = opportunity.ball:GetAttribute("ReleasedBy"),
                at = opportunity.ball:GetAttribute("ReleasedAt"), now = now(), freshShot = freshShot == true}
            if S.pokeRecovery.releaseMatches(record, release) then
                record.releaseConfirmed = true
                record.releaseAt, record.releasedBy = release.at, release.by
                if release.owner <= 0 then
                    record.recoveryPid = pid
                    if not record.recoveryUntil then record.recoveryUntil = math.min(record.at + 1.5, now() + 0.85) end
                end
            end
            if pid ~= record.pid and holder ~= record.carrierId then
                record.changed = true
                record.status = "Carrier lost possession"
            end
            if mine == record.ownId and holder == mine and pid ~= record.pid and record.releaseConfirmed then
                record.won = true
                record.receipt = {at = now(), pid = pid, owner = holder, releasedBy = opportunity.ball:GetAttribute("ReleasedBy"), releasedAt = opportunity.ball:GetAttribute("ReleasedAt")}
                record.status = "Ball won from " .. record.target
                break
            end
            task.wait(0.04)
        end
        if life.alive() and S.lastPoke == record then
            if not record.changed and not record.won then record.status = "Poke finished; carrier kept possession" end
            S.pokeStatus = record.status
            if record.won then notify("Pickpocket", record.status) end
        end
    end)
    return true
end
local guides = Instance.new("Folder")
guides.Name = "PoopSoccerGuides"
guides.Parent = workspace
life.onCleanup(function() guides:Destroy() end)
local function guidePart(name, size, colour)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = colour
    part.Size = size
    part.Transparency = 1
    part.Parent = guides
    return part
end
local targetMarker = guidePart("Target", Vector3.one * 0.65, Color3.fromRGB(255, 191, 92))
targetMarker.Shape = Enum.PartType.Ball
local ballMarker = guidePart("Ball", Vector3.new(0.08, 2.2, 2.2), Color3.fromRGB(104, 211, 171))
ballMarker.Shape = Enum.PartType.Cylinder

local Grasp = (function()
    local M: any = {maxRange = 32, sent = 0, accepted = 0, refused = 0, nextAt = 0}
    local rules = module(gameModules:WaitForChild("Dribble"), "Rules")
    local sim = module(gameModules, "BallSim")
    local remote = Net:RemoteEvent("DribbleClaim")
    function M.range()
        return math.clamp(tonumber(cfg.ballGrabRange) or 24, 4, M.maxRange)
    end
    function M.availableRange()
        local ball, r = Ball.getBall(), root()
        local event = ball and sim.decode(ball:GetAttribute("BallSim"))
        if not event or not r then return math.min(8, M.range()) end
        local age = math.clamp(now() - event.t - 0.03, 0, 1.75)
        local speed = math.max(r.AssemblyLinearVelocity.Magnitude, rules.Server.MinSpeed)
        return math.min(M.range(), speed * (age + rules.Server.SeeLate) + 4.5, (rules.Touch.MaxLaunch + 1) * 0.9)
    end
    function M.request(allowAir)
        if os.clock() < M.nextAt or M.pending or S.busy or not life.alive() then return false end
        local character, r, ball = player.Character, root(), Ball.getBall()
        local pro = game.ReplicatedStorage:FindFirstChild("ProState")
        if not character or not r or not ball or ball:GetAttribute("Possessor") ~= 0
            or character:GetAttribute("BodyState") ~= "Animated" or r.Anchored
            or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or (pro and pro:GetAttribute("Phase") ~= "Play") then return false end
        local ownId, pid = character:GetAttribute("DribbleId"), ball:GetAttribute("PossessionId")
        local event = sim.decode(ball:GetAttribute("BallSim"))
        local clock = now()
        local current = Ball.freeSample(clock)
        if type(ownId) ~= "number" or ownId <= 0 or type(pid) ~= "number" or not event or not current then return false end
        local distance = ((current - r.Position) * Vector3.new(1, 0, 1)).Magnitude
        if distance > M.range() or distance < 1 then return false end
        for _, lag in ipairs({0, 0.35, 0.75, 1.2, 1.75}) do
            local at = clock - lag
            if at >= event.t + 0.01 then
                local position = Ball.freeSample(at)
                if position and (allowAir or math.abs(position.Y - Ball.groundBallY(position)) < 1.2) then
                    local target = r.Position + r.CFrame.LookVector * 0.9
                    local offset = (target - position) * Vector3.new(1, 0, 1)
                    local meta = {pid = pid + 1, seq = 1, nleg = 0, leg = 1, part = "Sole", kind = "Glue",
                        stride = 0, root = r.Position * Vector3.new(1, 0, 1), nt = at}
                    local segment = Path.carry(meta, at, position, offset / 0.9, at + 0.9, target, Vector3.zero)
                    if rules.checkTouch(nil, segment, clock, r.Position, r.AssemblyLinearVelocity.Magnitude, Path.params(ball)) then
                        M.pending = {pid = pid, ownId = ownId, sentAt = os.clock(), distance = distance,
                            clock = at, segment = segment, ball = ball, character = character}
                        remote:FireServer(pid, Path.encode(segment))
                        M.sent += 1
                        M.nextAt = os.clock() + 0.35
                        return true
                    end
                end
            end
        end
        return false
    end
    life.connect(Net:RemoteEvent("DribbleReject").OnClientEvent, function(pid)
        if M.pending and (pid == M.pending.pid or pid == M.pending.pid + 1) then
            M.refused += 1
            M.pending = nil
        end
    end)
    life.connect(Run.Heartbeat, function()
        local record = M.pending
        if not record then return end
        local ball = record.ball
        if not ball.Parent or player.Character ~= record.character or os.clock() - record.sentAt > 1.1 then M.pending = nil; return end
        local path = Path.decode(ball:GetAttribute("DribblePath"))
        if ball:GetAttribute("Possessor") == record.ownId and ball:GetAttribute("PossessionId") == record.pid + 1
            and path and path.pid == record.pid + 1 then
            record.accepted = true
            record.receipt = path
            M.lastAccepted, M.pending = record, nil
            M.accepted += 1
        end
    end)
    life.onCleanup(function() M.pending = nil end)
    return M
end)()
S.grasp = Grasp


local Magnet = {range = 32, cooldown = 0.35, lastAt = -math.huge, bindings = {}}
local MagnetSim = module(gameModules, "BallSim")
local magnetRemote = Net:RemoteEvent("DribbleKnock")
function Magnet.allowed(context)
    return context.alive and not context.busy and not context.owned and not context.typing and not context.menu
        and context.animated and context.onPitch and context.playing and context.loose and context.free
        and finite(context.distance) and context.distance > 1 and context.distance <= math.min(Magnet.range, tonumber(cfg.ballGrabRange) or Magnet.range)
        and finite(context.height) and context.height <= 2.4 and finite(context.pid) and context.pid > 0
        and context.sinceLast >= Magnet.cooldown and not context.justShot
end
function Magnet.velocity(position, target)
    local offset = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
    if offset.Magnitude < 0.01 then return Vector3.zero end
    return offset.Unit * math.clamp(offset.Magnitude * 5, 10, 24)
end
function Magnet.matches(record, event)
    return event ~= nil and event.pid > record.pid and event.by == record.ownId and event.kind == "knock"
        and math.abs(event.t - record.clock) < 0.1 and (event.pos - record.position).Magnitude < 0.15
        and (event.vel - record.velocity).Magnitude < 0.1
end
function Magnet.pull(silent)
    local character, r = player.Character, root()
    local ball = Ball.getBall()
    local position = Ball.getPosition()
    if not character or not r or not ball or not position then return false end
    local phase = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    local floor = Ball.groundBallY(position)
    local own = character:GetAttribute("DribbleId")
    local source = Ball.getSource()
    local context = {
        alive = life.alive(), busy = S.busy, owned = ownState() ~= nil,
        typing = Input:GetFocusedTextBox() ~= nil, menu = GuiService.MenuIsOpen,
        animated = character:GetAttribute("BodyState") == "Animated",
        onPitch = character:GetAttribute("Team") == "Blue" or character:GetAttribute("Team") == "Red",
        playing = not phase or phase:GetAttribute("Phase") == "Play",
        loose = ball:GetAttribute("Possessor") == 0, free = source == "free" or source == "released" or source == "server",
        distance = ((position - r.Position) * Vector3.new(1, 0, 1)).Magnitude,
        height = math.abs(position.Y - floor), pid = ball:GetAttribute("PossessionId"),
        sinceLast = os.clock() - Magnet.lastAt, justShot = S.lastShot and now() - S.lastShot.at < 0.8,
    }
    if not Magnet.allowed(context) or type(own) ~= "number" or own <= 0 then
        if not silent then notify("Ball magnet", "No loose ball in reach.") end
        return false
    end
    if Grasp.request() then Magnet.lastAt = os.clock(); Magnet.last = Grasp.pending; return true end
    if context.distance > 8 then return false end
    local target = r.Position + r.CFrame.LookVector * 0.9
    local velocity = Magnet.velocity(position, target)
    Magnet.lastAt = os.clock()
    local record = {at = now(), clock = Ball.drawnTime(), position = position, velocity = velocity,
        ownId = own, pid = context.pid, distance = context.distance, ball = ball, accepted = false, owned = false}
    Magnet.last = record
    magnetRemote:FireServer(record.pid, position, velocity, record.clock)
    task.spawn(function()
        local began = os.clock()
        while life.alive() and Magnet.last == record and ball.Parent and os.clock() - began < 0.9 do
            local event = MagnetSim.decode(ball:GetAttribute("BallSim"))
            if Magnet.matches(record, event) then
                record.accepted = true
                record.receipt = {pid = event.pid, at = event.t, by = event.by, position = event.pos, velocity = event.vel,
                    positionError = (event.pos - position).Magnitude, velocityError = (event.vel - velocity).Magnitude}
            end
            if player.Character == character and ball:GetAttribute("Possessor") == own then record.owned = true end
            if record.accepted and record.owned then break end
            task.wait(0.03)
        end
    end)
    return true
end
local function reserveMagnetKey(binding)
    if not binding:IsA("InputBinding") or Magnet.bindings[binding] then return end
    local action = binding.Parent
    if not action or not action:IsA("InputAction") or (action.Name ~= "SkillRight" and action.Name ~= "LowDiveRight" and action.Name ~= "SimpleLow") then return end
    local record = {}
    Magnet.bindings[binding] = record
    local function update()
        if binding.KeyCode == Enum.KeyCode.C then
            record.original = Enum.KeyCode.C
            binding.KeyCode = Enum.KeyCode.Unknown
        end
    end
    life.connect(binding:GetPropertyChangedSignal("KeyCode"), update)
    life.onCleanup(function()
        if record.original and binding.Parent and binding.KeyCode == Enum.KeyCode.Unknown then binding.KeyCode = record.original end
    end)
    update()
end
for _, binding in ipairs(player.PlayerScripts:GetDescendants()) do reserveMagnetKey(binding) end
life.connect(player.PlayerScripts.DescendantAdded, function(binding)
    task.defer(function() if life.alive() and binding.Parent then reserveMagnetKey(binding) end end)
end)
S.magnet = Magnet

local RestartAccess = {reads = 0, installed = false}
function RestartAccess.allowed(phase, kind, taker)
    return (phase == "Dead" or phase == "Restart") and (kind == "FreeKick" or kind == "IndirectFreeKick" or kind == "ThrowIn" or kind == "Throw-in" or kind == "Throw" or kind == "Penalty" or kind == "GoalKick" or kind == "Corner" or kind == "KickOff")
        and taker ~= player.UserId
end
S.restartAccess = RestartAccess
do
    local pro = client:FindFirstChild("Pro")
    local setPiece = pro and pro:FindFirstChild("SetPiece")
    local state = game.ReplicatedStorage:FindFirstChild("ProState")
    if setPiece and state then
        local ok, err = pcall(function()
            local native = require(setPiece)
            local step
            for _, value in pairs(debug.getupvalues(native.start)) do
                if type(value) == "function" and debug.info(value, "n") == "step" then step = value; break end
            end
            if not step then error("Set-piece movement callback unavailable") end
            local index
            for i, value in pairs(debug.getupvalues(step)) do if value == state then index = i; break end end
            if not index then error("Set-piece state unavailable") end
            local proxy = {}
            function proxy:GetAttribute(key)
                if key == "KeepTeam" and RestartAccess.allowed(state:GetAttribute("Phase"), state:GetAttribute("Restart"), state:GetAttribute("Taker")) then
                    RestartAccess.reads += 1
                    RestartAccess.lastAllowed = {at = now(), phase = state:GetAttribute("Phase"), kind = state:GetAttribute("Restart"), taker = state:GetAttribute("Taker")}
                    return ""
                end
                return state:GetAttribute(key)
            end
            function proxy:GetAttributeChangedSignal(key) return state:GetAttributeChangedSignal(key) end
            debug.setupvalue(step, index, proxy)
            RestartAccess.installed = debug.getupvalue(step, index) == proxy
            life.onCleanup(function()
                if debug.getupvalue(step, index) == proxy then debug.setupvalue(step, index, state) end
            end)
        end)
        if not ok then RestartAccess.error = tostring(err) end
    end
end

do
    local pro = client:FindFirstChild("Pro")
    local penaltyLine = pro and pro:FindFirstChild("PenaltyLine")
    local state = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    if penaltyLine and state then
        local ok, err = pcall(function()
            local seen = {}
            local function find(fn, depth)
                if seen[fn] or depth > 4 then return nil end
                seen[fn] = true
                if debug.info(fn, "n") == "holding" then return fn end
                for _, value in pairs(debug.getupvalues(fn)) do
                    if type(value) == "function" then
                        local result = find(value, depth + 1)
                        if result then return result end
                    end
                end
                return nil
            end
            local holding = find(require(penaltyLine).start, 0)
            if not holding then error("Penalty movement callback unavailable") end
            for index, value in pairs(debug.getupvalues(holding)) do
                if value == state then
                    local proxy = {}
                    function proxy:GetAttribute(key)
                        if key == "LineKeep" and state:GetAttribute("Restart") == "Penalty"
                            and RestartAccess.allowed(state:GetAttribute("Phase"), "Penalty", state:GetAttribute("Taker")) then
                            RestartAccess.penaltyReads = (RestartAccess.penaltyReads or 0) + 1
                            return 0
                        end
                        return state:GetAttribute(key)
                    end
                    function proxy:GetAttributeChangedSignal(key) return state:GetAttributeChangedSignal(key) end
                    debug.setupvalue(holding, index, proxy)
                    RestartAccess.penaltyInstalled = debug.getupvalue(holding, index) == proxy
                    life.onCleanup(function()
                        if debug.getupvalue(holding, index) == proxy then debug.setupvalue(holding, index, state) end
                    end)
                    return
                end
            end
            error("Penalty state unavailable")
        end)
        if not ok then RestartAccess.penaltyError = tostring(err) end
    end
end
do
    local kickoff = client:FindFirstChild("KickoffHold")
    if kickoff then
        local ok, err = pcall(function()
            local native = module(client, "KickoffHold")
            local keep = table.clone(native.FREEZE_KEEP)
            keep.Mannequin = true
            local restore = life.override(native, "FREEZE_KEEP", keep)
            local hold, held
            for _, value in pairs(debug.getupvalues(native.hold)) do
                if type(value) == "function" and debug.info(value, "n") == "hold" then hold = value; break end
            end
            if not hold then restore(); error("Kickoff movement callback unavailable") end
            for _, value in pairs(debug.getupvalues(hold)) do
                if type(value) == "table" and value ~= native then held = value; break end
            end
            if not held then restore(); error("Kickoff input state unavailable") end
            for action, record in pairs(held) do
                local context = action:FindFirstAncestorOfClass("InputContext")
                if context and context.Name == "Mannequin" then
                    record.watch:Disconnect()
                    held[action] = nil
                    action.Enabled = record.was
                end
            end
            RestartAccess.kickoffInstalled = true
            life.onCleanup(function()
                restore()
                if native.holding() then
                    for _, action in ipairs(player.PlayerScripts:GetDescendants()) do
                        if action:IsA("InputAction") then hold(action) end
                    end
                end
            end)
        end)
        if not ok then RestartAccess.kickoffError = tostring(err) end
    end
end
local Visual = (function()
    local Sim = module(gameModules, "BallSim")
    local World = module(gameModules.BallSim, "World")
    local Bounds = module(gameModules, "PitchBounds")
    local V: any = {generation = 0, planning = false, nextAt = 0, drawFrames = 0, forecastCount = 0}
    local parts, drawn, velocities, shown = {}, {}, {}, {}
    local green = Color3.fromRGB(104, 211, 171)
    for i = 1, 48 do parts[i] = guidePart("Flight", Vector3.new(0.055, 0.055, 1), green) end
    local hidden = true
    local function validVector(value)
        return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
    end
    local function currentPid()
        local state = ownState()
        return if state then state.pid else possessionId()
    end
    local function hide()
        if not hidden then
            for _, part in ipairs(parts) do part.Transparency = 1 end
            targetMarker.Transparency = 1
        end
        hidden = true
        table.clear(drawn); table.clear(velocities); table.clear(shown)
    end
    V.hide = hide
    function V.smooth(position, velocity, target, dt)
        local time, frequency = math.clamp(dt, 0, 0.1), 28
        local decay = math.exp(-frequency * time)
        local delta = position - target
        local term = velocity + delta * frequency
        return target + (delta + term * time) * decay, (velocity - term * (frequency * time)) * decay
    end
    function V.goalCrossing(previous, current, bounds, lines, radius)
        if not lines then return nil end
        local earliest, point
        for _, goal in ipairs(bounds and bounds.goals or {}) do
            local side = goal.side
            if side ~= -1 and side ~= 1 then continue end
            local line = lines[if side == -1 then 1 else 2]
            if not finite(line) then continue end
            local a, b = (previous.X - line) * side, (current.X - line) * side
            if a < radius and b >= radius then
                local fraction = (radius - a) / (b - a)
                local crossing = previous:Lerp(current, fraction)
                if crossing.Z >= goal.lo.Z + radius and crossing.Z <= goal.hi.Z - radius
                    and crossing.Y >= goal.lo.Y + radius - 0.12 and crossing.Y <= goal.hi.Y - radius
                    and (not earliest or fraction < earliest) then earliest, point = fraction, crossing end
            end
        end
        return earliest, point
    end
    function V.trace(from, velocity, spin, seconds, work)
        local world, params = World.get(), World.params()
        local ground = world.groundY
        local state = Sim.fromEvent(World.FLIGHT, {t = 0, kind = "kick", n = 0, pos = from, vel = velocity, spin = spin}, ground)
        local sandbox = {groundY = ground, frames = {}, bodies = {}}
        local rows = {{t = 0, p = state.pos, v = state.vel}}
        local bounds = Bounds.get()
        local lines = Contacts.goalLines()
        local pro = workspace:GetAttribute("ProServer") == true
        local stop
        for i = 1, math.ceil(math.clamp(seconds, 0.05, 6) / Sim.STEP) do
            local previous = state
            local hitTime, hitPosition
            for _, frame in ipairs(world.frames) do
                local time, point = frame:sweep(previous.pos, previous.vel, if previous.rolling then 0 else params.gravity, Sim.STEP, params.radius)
                if time and point and time >= 0 and time <= Sim.STEP and (not hitTime or time < hitTime) then hitTime, hitPosition = time, point end
            end
            if hitTime then
                rows[#rows + 1] = {t = previous.t + hitTime, p = hitPosition, v = previous.vel}
                state = {t = previous.t + hitTime, pos = hitPosition, vel = previous.vel}
                stop = "Contact"
                break
            end
            state = Sim.step(World.FLIGHT, state, Sim.STEP, params, sandbox, false, 0, nil)
            if not validVector(state.pos) then return nil end
            local fraction, crossing = V.goalCrossing(previous.pos, state.pos, bounds, lines, params.radius)
            if fraction then
                rows[#rows + 1] = {t = previous.t + (state.t - previous.t) * fraction, p = crossing, v = previous.vel:Lerp(state.vel, fraction)}
                stop = "Goal"
                break
            end
            rows[#rows + 1] = {t = state.t, p = state.pos, v = state.vel}
            if bounds and (pro or bounds.lines) then
                local edge, radius = bounds.edge, params.radius
                local outsideZ = state.pos.Z < edge.lo.Z - radius or state.pos.Z > edge.hi.Z + radius
                local outsideX = state.pos.X < edge.lo.X - radius or state.pos.X > edge.hi.X + radius
                local opening = false
                for _, goal in ipairs(bounds.goals or {}) do
                    if state.pos.Z > goal.lo.Z + radius and state.pos.Z < goal.hi.Z - radius and state.pos.Y < goal.hi.Y - radius then opening = true; break end
                end
                if outsideZ or (outsideX and not opening) then stop = "Out"; break end
            end
            if Sim.resting(state, World.FLIGHT) then break end
            if work and i % 12 == 0 then work() end
        end
        if #rows < 2 or rows[#rows].t < 0.005 then return nil end
        return {rows = rows, horizon = rows[#rows].t, ground = ground, stop = stop, endpoint = rows[#rows].p}
    end
    function V.sample(trace, time)
        local rows = trace.rows
        if time <= 0 then return rows[1].p end
        if time >= rows[#rows].t then return rows[#rows].p end
        local lo, hi = 1, #rows
        while hi - lo > 1 do local mid = math.floor((lo + hi) * 0.5); if rows[mid].t <= time then lo = mid else hi = mid end end
        local a, b = rows[lo], rows[hi]
        local dt = b.t - a.t
        local u = math.clamp((time - a.t) / math.max(dt, 1e-7), 0, 1)
        local u2, u3 = u * u, u * u * u
        local point = a.p * (2 * u3 - 3 * u2 + 1) + a.v * (dt * (u3 - 2 * u2 + u))
            + b.p * (-2 * u3 + 3 * u2) + b.v * (dt * (u3 - u2))
        return Vector3.new(point.X, math.max(point.Y, trace.ground), point.Z)
    end
    local nativeMissAt
    for _, value in pairs(debug.getupvalues(Flight.solve)) do
        if type(value) == "function" and debug.info(value, "n") == "missAt" then nativeMissAt = value; break end
    end
    assert(nativeMissAt, "Preview physics unavailable")
    local warmSolutions, warmCount = {}, 0
    local function visualFlight(cancelled, synchronous)
        local NativeFlight = Flight
        local Flight = table.clone(NativeFlight)
        local rollStep, airStep, bounceOff = NativeFlight.rollStep, NativeFlight.airStep, NativeFlight.bounce
        local missAt = nativeMissAt
        local slice, work = os.clock(), 0
        local function budget()
            if cancelled and cancelled() then error("Preview superseded", 0) end
            if synchronous then return end
            local at = os.clock()
            local cost = at - slice
            if cost >= 0.003 then
                work += cost
                V.planWorkMs = work * 1000
                V.maxWorkSliceMs = math.max(V.maxWorkSliceMs or 0, cost * 1000)
                Run.Heartbeat:Wait()
                slice = os.clock()
                if cancelled and cancelled() then error("Preview superseded", 0) end
            end
        end
        function Flight.simulate(a1, a2, a3, a4, a5, a6, a7, a8)
            local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13
            local v14 = math.min(a7 or 12, 12)
            local v15 = {a1}
            local v16 = {a2}
            local v17 = {a3}
            local v18 = a1
            local v19 = a2
            local v20 = a3
            local v21 = nil
            local v22 = nil
            local v23 = nil
            local v24 = 0
            local v25 = 0
            local v26 = false

            if v18.Y <= a6 + 0.05 then
                v26 = v19.Y <= 2
            end

            if v26 then
                v22 = 0
                v18 = Vector3.new(v18.X, a6, v18.Z)
                v1, v2 = Flight.toGround(v19, v20)
                v19 = v1
                v20 = v2
            end

            v1 = 1
            local v27, v28, v29, v30 = a5, a6, a8, a4

            while v25 < v14 - 1e-09 do
                if v1 % 8 == 1 then budget() end
                if not v26 then
                    v8 = Vector3.new(0, -v27.gravity, 0)
                    v10 = v19 + (v8 + Flight.airAccel(v19, v20, v27)) * 0.004166666666666667
                    v11 = v8 + Flight.airAccel(v10, v20 * 0.9993751952718163, v27)
                    v2 = v18 + v10 * 0.008333333333333333
                    v3 = v19 + v11 * 0.008333333333333333
                    v4 = v20 * 0.9987507809245809

                    if v2.Y < v28 and v3.Y < 0 then
                        v5 = math.clamp((v18.Y - v28) / math.max(v18.Y - v2.Y, 1e-06), 0, 1)
                        v6, v7, v8 = airStep(v18, v19, v20, v5 * 0.008333333333333333, v27)
                        v21 = v21 or v25 + v5 * 0.008333333333333333
                        v24 = v24 + 1
                        v9, v10 = bounceOff(v7, v8, v27)
                        v6 = Vector3.new(v6.X, v28, v6.Z)

                        if v9.Y < 2 or v24 > 40 then
                            v26 = true
                            v22 = v25 + v5 * 0.008333333333333333
                            v11, v12 = Flight.toGround(v9, v10)
                            v9 = v11
                            v10 = v12
                        end

                        v8 = (1 - v5) * 0.008333333333333333

                        if not v26 then
                            v11, v12, v13 = airStep(v6, v9, v10, v8, v27)
                        else
                            v11, v12, v13 = rollStep(v6, v9, v10, v8, v27)
                        end

                        v2 = v11
                        v3 = v12
                        v4 = v13
                    end

                    v18 = v2
                    v19 = v3
                    v20 = v4
                elseif not Flight.atRest(v19, v20) then
                    v2, v3, v4 = rollStep(v18, v19, v20, 0.008333333333333333, v27)
                    v18 = v2
                    v19 = v3
                    v20 = v4
                else
                    v23 = v23 or v25
                    v19 = Vector3.new(0, 0, 0)
                    v20 = Vector3.new(0, 0, 0)
                end

                v25 = v25 + 0.008333333333333333
                v1 = v1 + 1
                v15[v1] = v18
                v16[v1] = v19
                v17[v1] = v20

                if v23 then
                    break
                end

                if v29 then
                    v3 = v18 - v29.from

                    if v29.dist <= ((Vector3.new(v3.X, 0, v3.Z)):Dot(v29.dir)) then
                        break
                    end
                end
            end

            return {
                t0 = v30,
                n = v1,
                pos = v15,
                vel = v16,
                spin = v17,
                landT = v21,
                rollAt = v22,
                restAt = v23,
                groundY = v28,
            }
        end
        function Flight.solve(a1, a2, a3, a4, a5, a6, a7, a8, a9)
            local v1, v2, v3, v4, v5, v6
            local v7 = a2 - a1
            local v8 = Vector3.new(v7.X, 0, v7.Z)
            local Magnitude = v8.Magnitude
            local u19 = if not (Magnitude > 0.001) then Vector3.new(0, 0, -1) else v8 / Magnitude
            local u20 = {from = a1, dir = u19, dist = Magnitude}
            local u29 = Magnitude / math.max(a3, 1)
            local v9 = math.atan2(a2.Y - a1.Y + a6.gravity * 0.5 * u29 * u29, (math.max(Magnitude, 1)))
            local v10 = 0
            local v11 = a8 or 1.2217304763960306
            local v12 = nil
            local cacheKey = table.concat({a2.X, a2.Y, a2.Z, a3, a4, a5, a6.gravity, a6.airDrag, a6.curve,
                a6.friction, a6.roll, a6.rollDrag, a6.bounce, a7, a8 or 0, a9 or 0}, ":")
            local cached = not synchronous and warmSolutions[cacheKey]
            local seeded = cached and (cached.from - a1).Magnitude < 12 and os.clock() - cached.at < 8
            if seeded then
                local velocity = cached.velocity
                v9 = math.atan2(velocity.Y, (velocity * Vector3.new(1, 0, 1)).Magnitude)
                local angle = math.atan2(u19.Z, u19.X) - math.atan2(velocity.Z, velocity.X)
                v10 = math.atan2(math.sin(angle), math.cos(angle))
                V.warmHits = (V.warmHits or 0) + 1
            end

            local function fly(a1_2, a2_2)
                local v1 = (CFrame.Angles(0, a2_2, 0)) * u19
                local v2 = (v1 * math.cos(a1_2) + Vector3.new(0, 1, 0) * math.sin(a1_2))
                    * a3
                local v3 = Flight.spinFrom(v1, a4, a5)
                v1 = Flight.simulate(a1, v2, v3, 0, a6, a7, math.min(u29 * 3 + 0.5, 12), u20)
                local v4, v5, v6 = missAt(v1, a1, a2)

                return v4, v5, v6, v2, v3
            end

            for i = 1, 8 do
                budget()
                v9 = math.clamp(v9, a9 or -0.17453292519943295, v11)
                v1, v2, v3, v4, v5 = fly(v9, v10)

                if v1 then
                    v6 = math.sqrt(v2 * v2 + v3 * v3)

                    if not v12 or v6 < v12.miss then
                        v12 = {vel = v4, spin = v5, t = v1, miss = v6}
                    end

                    if v6 < 0.05 then
                        break
                    end

                    v6 = math.max(Magnitude, 1)
                    v9 = v9 + v2 / v6 * 0.9
                    v10 = v10 - v3 / v6 * 0.9
                else
                    if v12 == nil or v12.t ~= v12.t then
                        v12 = {t = (1 / 0), miss = (1 / 0), vel = v4, spin = v5}
                    end

                    v9 = math.min(v9 + 0.13962634015954636, v11)
                end
            end

            local v13 = v12
            if seeded and v13.miss > 0.05 then
                warmSolutions[cacheKey] = nil
                return Flight.solve(a1, a2, a3, a4, a5, a6, a7, a8, a9)
            end
            if not synchronous and v13.miss <= 0.05 then
                if not warmSolutions[cacheKey] then
                    if warmCount >= 48 then table.clear(warmSolutions); warmCount = 0 end
                    warmCount += 1
                end
                warmSolutions[cacheKey] = {from = a1, velocity = v13.vel, at = os.clock()}
            end
            budget()

            return v13.vel, v13.spin, v13.t, v13.miss
        end
        return Flight, budget
    end
    V.physics = visualFlight
    local function calculateVisual(sample, options, cancelled, synchronous)
        local Flight, budget = visualFlight(cancelled, synchronous)
        if not synchronous then V.planWorkMs = 0 end
        local calculate, fitShot = makeShotPlanner(Flight, budget)
        local result, message = calculate(sample, false, options)
        if result then
            result.refit = function(fresh)
                return fitShot(fresh, result.target, result.goal, result.family, result.speed, result.side, result.back)
            end
        end
        return result, message
    end
    V.calculate = calculateVisual
    local function workerBudget(cancelled)
        local slice = os.clock()
        return function()
            if cancelled() then error("Preview superseded", 0) end
            if os.clock() - slice > 0.0015 then task.wait(); slice = os.clock() end
        end
    end
    function V.request()
        if not life.alive() or not cfg.trajectory or S.busy or V.planning or os.clock() < V.nextAt then return end
        local sample = ballSample()
        if not sample then return end
        local generation, key = V.generation, choiceKey(cfg)
        local character = player.Character
        local options = table.clone(cfg)
        V.planning = true
        V.nextAt = os.clock() + 0.1
        local function cancelled()
            return not life.alive() or V.generation ~= generation or Ball.getBall() ~= sample.ball
                or player.Character ~= character or currentPid() ~= sample.pid or choiceKey(cfg) ~= key or S.busy
        end
        task.defer(function()
            local began = os.clock()
            local ok, result = pcall(function()
                local plan = calculateVisual(sample, options, cancelled, false)
                if not plan then return nil end
                local fresh = ballSample()
                if fresh and fresh.ball == sample.ball and fresh.pid == sample.pid and (fresh.from - sample.from).Magnitude > 0.1 then
                    if cancelled() then error("Preview superseded", 0) end
                    local adjusted = plan.refit(fresh)
                    if not adjusted then return nil end
                    plan, sample = adjusted, fresh
                end
                local trace = V.trace(sample.from, plan.velocity, plan.spin, math.min(plan.flightTime + 0.1, 6), workerBudget(cancelled))
                if not trace then return nil end
                return {trace = trace, plan = plan, from = sample.from, at = now(), key = key, pid = sample.pid, ball = sample.ball}
            end)
            V.planning = false
            if not life.alive() then return end
            if ok and result and not cancelled() then
                V.preview = result
                V.forecastCount += 1
                V.error = nil
            elseif not cancelled() then
                V.preview = nil
                if not ok and not tostring(result):find("Preview superseded", 1, true) then
                    V.error = tostring(result)
                    S.guideError = V.error
                end
            end
            S.previewCostMs = (os.clock() - began) * 1000
            V.nextAt = os.clock() + math.clamp((V.planWorkMs or 0) * 0.003, 0.2, 0.75)
        end)
    end
    local function vectorText(text)
        if type(text) ~= "string" then return nil end
        local x, y, z = text:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if finite(x) and finite(y) and finite(z) then return Vector3.new(x, y, z) end
        return nil
    end
    local lastReleasedKey
    local function releaseForecast(ball, pid)
        local shot = S.lastShot
        if not shot or now() - shot.at > 12 or not finite(shot.pid) or not finite(shot.expectedTime)
            or (pid ~= shot.pid and pid ~= shot.pid + 1) or not Ball.freeSim() then
            if V.released or lastReleasedKey then V.releaseGeneration = (V.releaseGeneration or 0) + 1 end
            V.released, lastReleasedKey = nil, nil
            return
        end
        local event = Flight.decode(ball:GetAttribute("KickFlight"))
        local server = event and event.pid == shot.pid + 1 and event.by == shot.characterId and event.family == shot.family
            and math.abs(event.t - shot.expectedTime) < 1
        local key = if server then ball:GetAttribute("KickFlight") else tostring(shot)
        if key == lastReleasedKey then return end
        local from = if server then event.pos else vectorText(shot.from)
        local velocity = if server then event.vel else vectorText(shot.velocity)
        local spin = if server then event.spin else vectorText(shot.spin)
        if not from or not velocity or not spin then return end
        lastReleasedKey = key
        V.releaseGeneration = (V.releaseGeneration or 0) + 1
        local generation = V.releaseGeneration
        task.defer(function()
            local ok, trace = pcall(V.trace, from, velocity, spin, 6, workerBudget(function()
                return not life.alive() or generation ~= V.releaseGeneration or Ball.getBall() ~= ball
            end))
            if ok and trace and life.alive() and generation == V.releaseGeneration then
                V.released = {trace = trace, from = from, time = if server then event.t else shot.expectedTime, wall = shot.at, pid = shot.pid,
                    server = server == true, key = key}
            end
        end)
    end
    life.connect(Net:RemoteEvent("KickPlanRelay").OnClientEvent, function(sender, packet)
        local motion = S.lastKickMotion
        if sender ~= player or type(packet) ~= "table" or not motion or packet.id ~= motion.id
            or not S.busy or not S.status:find("Planting foot", 1, true) then return end
        if not validVector(packet.ball) or not validVector(packet.vel) or not validVector(packet.spin) then return end
        task.defer(function()
            local ok, trace = pcall(V.trace, packet.ball, packet.vel, packet.spin, 6, workerBudget(function() return not life.alive() end))
            if ok and life.alive() and trace then V.windup = {trace = trace, from = packet.ball, id = motion.id, at = now()} end
        end)
    end)
    local renderName = "PoopSoccerVisualPath"
    Run:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 2, function(dt)
        if not life.alive() then return end
        local began = os.clock()
        local ball, position = Ball.getBall(), Ball.getPosition()
        ballMarker.Transparency = if cfg.marker and position then 0.2 else 1
        if position then ballMarker.CFrame = CFrame.new(position + Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.pi / 2) end
        if not cfg.trajectory or not ball or not validVector(position) then hide(); return end
        V.request()
        local state = ownState()
        local pid = if state then state.pid else Ball.pendingPid() or possessionId()
        releaseForecast(ball, pid)
        local forecast, elapsed, released = V.preview, 0, false
        if V.windup and S.busy and S.lastKickMotion and S.lastKickMotion.id == V.windup.id and now() - V.windup.at < 1 then forecast = V.windup end
        local flight = V.released
        if flight then
            local clock = Ball.drawnTime()
            if not finite(clock) or clock < flight.time - 0.05 then clock = now() end
            elapsed = math.max(clock - flight.time, 0)
            if elapsed < flight.trace.horizon then forecast, released = flight, true else V.released = nil end
        end
        local lifetime = math.clamp(0.5 + (S.previewCostMs or 0) * 0.002, 1.1, 3)
        if not forecast or (not released and forecast ~= V.windup and (forecast.pid ~= currentPid() or now() - forecast.at > lifetime)) then hide(); return end
        local trace = forecast.trace
        local anchor = V.sample(trace, elapsed)
        local offset = position - anchor
        if offset.Magnitude > (if released then 8 else 20) then hide(); return end
        local remaining = trace.horizon - elapsed
        if remaining < 0.02 then hide(); return end
        local previous = position
        hidden = false
        for i, part in ipairs(parts) do
            local progress = i / #parts
            local point = V.sample(trace, elapsed + remaining * progress) + offset * ((1 - progress) ^ 2)
            if drawn[i] and not released then point, velocities[i] = V.smooth(drawn[i], velocities[i] or Vector3.zero, point, dt)
            else velocities[i] = Vector3.zero end
            point = Vector3.new(point.X, math.max(point.Y, trace.ground), point.Z)
            drawn[i] = point
            local length = (point - previous).Magnitude
            if length > 0.004 then
                if not shown[i] then part.Transparency = 0.35; shown[i] = true end
                part.Size = Vector3.new(0.055, 0.055, length)
                part.CFrame = CFrame.lookAt((previous + point) * 0.5, point)
            elseif shown[i] then part.Transparency = 1; shown[i] = false end
            previous = point
        end
        targetMarker.Position = previous
        targetMarker.Transparency = 0.15
        V.drawFrames += 1
        V.drawMs = (os.clock() - began) * 1000
        V.maxDrawMs = math.max(V.maxDrawMs or 0, V.drawMs)
    end)
    life.onCleanup(function() V.generation += 1; Run:UnbindFromRenderStep(renderName); hide() end)
    return V
end)()
S.previewVisual = Visual
local function hideTrajectory() Visual.hide() end
local function updateGuides() Visual.request() end

local Performance = (function()
    local Lighting = game:GetService("Lighting")
    local P: any = {changed = 0, fps = 0, frameMs = 0, enabled = false}
    local snapshots = {}
    local originalCap = getfpscap()
    local appliedCap
    local generation = 0
    local function change(object, property, value)
        local ok, previousValue = pcall(function() return object[property] end)
        if not ok or previousValue == value then return end
        local entry = snapshots[object]
        if not entry then entry = {}; snapshots[object] = entry end
        if not entry[property] then entry[property] = {original = previousValue, applied = value} end
        local success, err = pcall(function() object[property] = value end)
        if success then entry[property].applied = value; P.changed = P.changed + 1 else P.error = tostring(err) end
    end
    local function restore()
        for object, properties in pairs(snapshots) do
            for property, values in pairs(properties) do
                pcall(function()
                    if object[property] == values.applied then object[property] = values.original end
                end)
            end
        end
        snapshots = {}
        P.changed = 0
        if appliedCap and getfpscap() == appliedCap and originalCap > 0 then setfpscap(originalCap) end
        appliedCap = nil
    end
    local function process(object)
        if not cfg.performance then return end
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby and object:IsDescendantOf(lobby) then
            
            if object:IsA("Beam") or object:IsA("ParticleEmitter") or object:IsA("Trail") then
                change(object, "Enabled", false)
            end
        end
        if cfg.reducePostEffects and (object:IsA("BloomEffect") or object:IsA("SunRaysEffect")
            or object:IsA("DepthOfFieldEffect") or object:IsA("BlurEffect")) then
            change(object, "Enabled", false)
        end
    end
    function P.apply()
        generation = generation + 1
        local currentGeneration = generation
        restore()
        P.enabled = cfg.performance
        if not cfg.performance then return end
        if not cfg.keepShadows then change(Lighting, "GlobalShadows", false) end
        appliedCap = math.clamp(cfg.fpsCap, 60, 360)
        setfpscap(appliedCap)
        local work = Lighting:GetDescendants()
        local camera = workspace.CurrentCamera
        if camera then for _, object in ipairs(camera:GetDescendants()) do table.insert(work, object) end end
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then for _, object in ipairs(lobby:GetDescendants()) do table.insert(work, object) end end
        task.spawn(function()
            for index, object in ipairs(work) do
                if not life.alive() or generation ~= currentGeneration then return end
                process(object)
                if index % 150 == 0 then task.wait() end
            end
            P.ready = true
        end)
    end
    life.connect(workspace.DescendantAdded, function(object)
        if cfg.performance and (object:IsA("PostEffect") or object:IsA("Beam")
            or object:IsA("ParticleEmitter") or object:IsA("Trail")) then process(object) end
    end)
    life.connect(Lighting.DescendantAdded, process)
    local elapsed, frames, worst = 0, 0, 0
    life.connect(Run.Heartbeat, function(dt)
        elapsed = elapsed + dt
        frames = frames + 1
        worst = math.max(worst, dt)
        if elapsed >= 1 then
            P.fps, P.frameMs, P.worstMs = frames / elapsed, elapsed / frames * 1000, worst * 1000
            elapsed, frames, worst = 0, 0, 0
        end
    end)
    life.onCleanup(function()
        generation = generation + 1
        restore()
        P.enabled = false
    end)
    P.apply()
    return P
end)()
S.performance = Performance

local AntiAFK = (function()
    local Rules = module(gameModules, "Afk")
    local afkRemote = Net:RemoteEvent(Rules.REMOTE)
    local joinRemote = Net:RemoteEvent("LobbyChooseTeam")
    local A: any = {pulses = 0, warnings = 0, lobbyEvents = 0, rejoinAttempts = 0,
        lastPulse = -math.huge, lastJoin = -math.huge, status = "Starting keepalive"}
    local existing = previous and previous.antiAFK
    A.lastTeam = player.Character and player.Character:GetAttribute("Team") or existing and existing.lastTeam
    A.lastRole = player.Character and player.Character:GetAttribute("Role") or existing and existing.lastRole
    A.recoveryUntil = existing and existing.recoveryUntil
    function A.rejoinAllowed(options, lastRole, recoveryUntil, at)
        return options.antiAFK == true and options.autoGK == true and options.rejoinGK == true
            and lastRole == "Goalkeeper" and type(recoveryUntil) == "number" and at <= recoveryUntil
    end
    local function pulse()
        if not cfg.antiAFK or not life.alive() then return end
        local ok, err = pcall(function() afkRemote:FireServer("active") end)
        if ok then
            A.lastPulse = os.clock()
            A.pulses = A.pulses + 1
            A.status = "Keepalive active"
        else
            A.error = tostring(err)
        end
    end
    A.pulse = pulse
    life.connect(afkRemote.OnClientEvent, function(event)
        if event == "warn" then
            A.warnings = A.warnings + 1
            pulse()
        elseif event == "sent" then
            A.lobbyEvents = A.lobbyEvents + 1
            A.recoveryUntil = if cfg.antiAFK and cfg.autoGK and cfg.rejoinGK and A.lastRole == "Goalkeeper" then now() + 60 else nil
            A.status = "Returned to lobby"
        end
    end)
    life.connect(player.Idled, function()
        if not cfg.antiAFK then return end
        pulse()
        local ok, err = pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        if not ok then A.idleError = tostring(err) end
    end)
    life.connect(Run.Heartbeat, function()
        if not cfg.antiAFK then A.status = "Keepalive off"; return end
        if not cfg.autoGK then A.recoveryUntil = nil end
        if os.clock() - A.lastPulse >= math.max(8, Rules.ACTIVE_GAP) then pulse() end
        local character = player.Character
        local team = character and character:GetAttribute("Team")
        if team == "Red" or team == "Blue" then
            A.lastTeam = team
            A.lastRole = character:GetAttribute("Role")
            if character:GetAttribute("Role") == "Goalkeeper" then A.keeperVerifiedAt = now() end
            if A.requestedTeam and team == A.requestedTeam and A.lastRole == "Goalkeeper" then
                A.recoveryUntil, A.requestedTeam = nil, nil
            end
            return
        end
        if not A.rejoinAllowed(cfg, A.lastRole, A.recoveryUntil, now()) or not character or player:GetAttribute("InTutorial") == true
            or os.clock() - A.lastJoin < 5 then return end
        local available = {Blue = true, Red = true}
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            if other ~= player and model and model:GetAttribute("Role") == "Goalkeeper" then
                local occupiedTeam = model:GetAttribute("Team")
                if occupiedTeam then available[occupiedTeam] = false end
            end
        end
        local choice = if A.lastTeam and available[A.lastTeam] then A.lastTeam
            elseif available.Blue then "Blue" elseif available.Red then "Red" else nil
        if choice then
            joinRemote:FireServer(choice, "Keeper")
            A.lastJoin, A.requestedTeam = os.clock(), choice
            A.rejoinAttempts = A.rejoinAttempts + 1
            A.status = "Requesting " .. choice .. " goalkeeper slot"
        else
            A.status = "Waiting for an available goalkeeper slot"
        end
    end)
    pulse()
    return A
end)()
S.antiAFK = AntiAFK

local Passing = (function()
    local Sim = module(gameModules, "BallSim")
    local World = module(gameModules.BallSim, "World")
    local Bounds = module(gameModules, "PitchBounds")
    local Rules = module(gameModules.Dribble, "Rules")
    local Hands = module(gameModules, "KeeperHands")
    local Animation = module(gameModules, "AIGoalie")
    local NativeKick = module(client, "KickClient")
    local KeeperRules = module(gameModules, "KeeperRules")
    local M: any = {status = "Waiting for the ball", history = {}, ranked = {}, planning = false}
    if previous and previous.passingEngine then M.history = previous.passingEngine.history or {} end
    local observations = setmetatable({}, {__mode = "k"})
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function unit(v) return if v.Magnitude > 0.0001 then v.Unit else Vector3.new(1, 0, 0) end
    local function bounded(v, limit) return if v.Magnitude > limit then v.Unit * limit else v end
    local function push(row)
        table.insert(M.history, row)
        if #M.history > 40 then table.remove(M.history, 1) end
    end
    local function stateObject() return game.ReplicatedStorage:FindFirstChild("ProState") end
    function M.restart()
        local state = stateObject()
        if not state then return nil end
        local phase = state:GetAttribute("Phase")
        if phase ~= "Restart" and phase ~= "Dead" then return nil end
        return {kind = state:GetAttribute("Restart"), team = state:GetAttribute("RestartTeam"),
            taker = state:GetAttribute("Taker"), spot = state:GetAttribute("TakerSpot"),
            ball = state:GetAttribute("RestartAt"), walkAt = state:GetAttribute("WalkUpAt"),
            bannerAt = state:GetAttribute("BannerAt"), phase = phase}
    end
    local function actor(model, other, at)
        local r = model:FindFirstChild("Root")
        if not r or not r:IsA("BasePart") then return nil end
        local id = model:GetAttribute("DribbleId")
        if type(id) ~= "number" or id == 0 then return nil end
        local cm = model:FindFirstChildOfClass("ControllerManager")
        local ground = cm and cm:FindFirstChild("GroundController")
        local speed = math.max(cm and cm.BaseMoveSpeed or 26, 1)
        local velocity = bounded(flat(r.AssemblyLinearVelocity), math.max(speed * 1.25, 32))
        local old = observations[model]
        local acceleration = Vector3.zero
        local uncertainty = 0.3
        if old and at - old.at > 0.035 and at - old.at < 0.4 then
            acceleration = bounded((velocity - old.velocity) / (at - old.at), 45)
            uncertainty += math.min((velocity - old.velocity).Magnitude * 0.12, 1.8)
        end
        if not old or at - old.at >= 0.06 then observations[model] = {at = at, velocity = velocity} end
        local animated = model:GetAttribute("BodyState") == "Animated"
        return {id = id, player = other, model = model, pos = r.Position, vel = velocity,
            acceleration = acceleration, uncertainty = uncertainty, speed = speed,
            accel = speed / math.max(ground and ground.AccelerationTime or 0.18, 0.06),
            available = animated, team = model:GetAttribute("Team"), role = model:GetAttribute("Role")}
    end
    local function predict(a, time)
        local turnTime = math.min(time, 0.3)
        return a.pos + a.vel * time + a.acceleration * (0.25 * turnTime * turnTime)
    end
    M.predictActor = predict
    M.actor = actor
    local function reachTime(a, point, reach, reaction)
        local delta = flat(point - a.pos)
        local distance = math.max(delta.Magnitude - reach, 0)
        if distance <= 0 then return 0 end
        local direction = unit(delta)
        local closing = math.clamp(a.vel:Dot(direction), -a.speed, a.speed)
        local delay = reaction or 0.1
        distance = math.max(distance - math.max(closing, 0) * delay, 0)
        if distance == 0 then return delay end
        local acceleration = math.max(a.accel, 1)
        local accelerateFor = math.max(a.speed - closing, 0) / acceleration
        local accelerateDistance = closing * accelerateFor + 0.5 * acceleration * accelerateFor * accelerateFor
        if distance <= accelerateDistance then
            return delay + (-closing + math.sqrt(closing * closing + 2 * acceleration * distance)) / acceleration
        end
        return delay + accelerateFor + (distance - accelerateDistance) / a.speed
    end
    M.reachTime = reachTime
    local function inPitch(point, bounds, margin)
        if not bounds then return true end
        local edge = bounds.edge or bounds.ball
        return point.X >= edge.lo.X + margin and point.X <= edge.hi.X - margin
            and point.Z >= edge.lo.Z + margin and point.Z <= edge.hi.Z - margin
    end
    M.inPitch = inPitch
    function M.snapshot(allowRestart)
        local character = player.Character
        local ball = Ball.getBall()
        local r = character and character:FindFirstChild("Root")
        if not r or not ball then return nil, "Waiting to spawn" end
        local team = character:GetAttribute("Team")
        if team ~= "Red" and team ~= "Blue" then return nil, "Join a team first" end
        local ownId = character:GetAttribute("DribbleId")
        local state = Dribble.kickState()
        local pid = if state then state.pid else ball:GetAttribute("PossessionId")
        local possession = ball:GetAttribute("Possessor")
        local restart = M.restart()
        local restartMine = allowRestart and restart and restart.kind == "GoalKick" and restart.phase == "Restart"
            and restart.team == team and restart.taker == player.UserId
        if restart and not restartMine then return nil, "Waiting for the restart" end
        if character:GetAttribute("BodyState") ~= "Animated" then return nil, "Recovering" end
        if not state and possession ~= ownId and not restartMine then return nil, "Waiting for the ball" end
        local held = not state and possession == ownId and ball:GetAttribute("DribblePath") == ""
        if not held and not state and not restartMine then return nil, "Settling the ball" end
        local at = now()
        local world, params = World.get(), World.params()
        local from = Ball.getPosition()
        if state then from = Path.sample(state.seg, at, state.P) end
        if not from then return nil, "Waiting for the ball" end
        if restartMine and possession ~= ownId and flat(from - r.Position).Magnitude > 4.5 then return nil, "Moving to the ball" end
        local ownArea = KeeperRules.area(team)
        if not ownArea then return nil, "Waiting for the pitch" end
        local scene = {character = character, ball = ball, ownId = ownId, pid = pid, team = team,
            held = held, freeRestart = restartMine and possession ~= ownId, at = at, from = from,
            root = r, attack = Vector3.new(-ownArea.side, 0, 0), floor = world.groundY - params.radius,
            params = params, world = {groundY = world.groundY, frames = world.frames, bodies = {}},
            bounds = Bounds.get(), teammates = {}, enemies = {}, restart = restart,
            offside = workspace:GetAttribute("ProServer") == true and not restartMine}
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            if model and model ~= character then
                local a = actor(model, other, at)
                if a and (a.team == "Red" or a.team == "Blue") then
                    if a.team == team then
                        if a.available then table.insert(scene.teammates, a) end
                    else table.insert(scene.enemies, a) end
                end
            end
        end
        return scene
    end
    local modes = {
        {name = "Ground", family = "SideFoot", pace = 72, ground = true},
        {name = "Driven", family = "Power", pace = 111, ground = true},
        {name = "Chip", family = "Chip", pace = 48, minimum = 0.65},
        {name = "Lofted", family = "Lofted", pace = 82, minimum = 1.55},
        {name = "Curve left", family = "Finesse", pace = 86, curve = 26},
        {name = "Curve right", family = "Trivela", pace = 86, curve = -26},
    }
    local handModes = {
        {name = "Roll", kind = "roll", pace = 65, ground = true},
        {name = "Throw", kind = "throw", pace = 68, minimum = 0.65},
        {name = "Punt", kind = "punt", pace = Hands.PUNT_PACE, minimum = Hands.PUNT_TIME[1]},
    }
    M.modes, M.handModes = modes, handModes
    local function onside(scene, receiver, delay)
        if not scene.offside or #scene.enemies < 2 or not scene.bounds then return true end
        local edge = scene.bounds.edge or scene.bounds.ball
        local centre = (edge.lo.X + edge.hi.X) * 0.5
        local receiverX = (predict(receiver, delay or 0).X - centre) * scene.attack.X
        if receiverX <= 0 then return true end
        local first, second = -math.huge, -math.huge
        for _, enemy in ipairs(scene.enemies) do
            local x = (predict(enemy, delay or 0).X - centre) * scene.attack.X
            if x > first then first, second = x, first elseif x > second then second = x end
        end
        return receiverX <= math.max(second, (scene.from.X - centre) * scene.attack.X) - 0.6
    end
    M.onside = onside
    local function releasePoint(scene, mode, point)
        local direction = unit(flat(point - scene.root.Position))
        if not scene.held then return scene.from, 0, direction end
        if mode.kind == "punt" then
            local from, _, fall = Hands.punt(scene.root.CFrame, direction)
            return from, Animation.PUNT_EXTEND + fall, direction
        end
        local move = if mode.kind == "roll" then Animation.ROLL else Animation.THROW
        local at = scene.root.Position + direction * Animation.travel(move, move.release)
        return Hands.moveBall(move, CFrame.new(at), direction, move.release), move.release, direction
    end
    local function simulate(scene, from, velocity, spin, duration, keepRows)
        local current = Sim.fromEvent(World.FLIGHT, {t = 0, kind = "kick", n = 0, pos = from,
            vel = velocity, spin = spin}, scene.world.groundY)
        local rows = if keepRows then {{t = 0, p = current.pos, v = current.vel}} else nil
        local step = Sim.STEP
        local count = math.ceil(duration / step)
        for index = 1, count do
            current = Sim.step(World.FLIGHT, current, math.min(step, duration - current.t), scene.params, scene.world, false, 0, nil)
            if rows and (index % 4 == 0 or index == count) then
                table.insert(rows, {t = current.t, p = current.pos, v = current.vel})
            end
        end
        return current, rows
    end
    M.simulate = simulate
    local function accepted(mode, velocity, spin)
        if mode.kind then return bounded(velocity, Hands.MAX_SPEED[mode.kind]), bounded(spin, KickRules.Server.MaxSpin) end
        return KickRules.checkStrike(mode.family, velocity, spin)
    end
    local function solve(scene, receiver, mode, space, paceScale)
        local initialDistance = flat(receiver.pos - scene.from).Magnitude
        if initialDistance < 4 then return nil end
        local family = mode.family and Families[mode.family]
        local maximum = if mode.kind then Hands.MAX_SPEED[mode.kind] else math.max(family.speed[2], family.shotSpeed and family.shotSpeed[2] or 0) * KickRules.Server.SpeedSlack * KickRules.KickButton.FullPower
        local pace = math.min(mode.pace * paceScale, maximum * 0.84)
        local duration = math.clamp(initialDistance / pace, mode.minimum or 0.18, 5)
        local receiveHeight = scene.floor + scene.params.radius + (if mode.ground then 0 else 1.2)
        local point, from, windup, direction
        for _ = 1, 2 do
            point = predict(receiver, duration + (windup or 0)) + scene.attack * space
            point = Vector3.new(point.X, receiveHeight, point.Z)
            from, windup, direction = releasePoint(scene, mode, point)
            duration = math.clamp(flat(point - from).Magnitude / pace, mode.minimum or 0.18, 5)
        end
        point = predict(receiver, duration + windup) + scene.attack * space
        point = Vector3.new(point.X, receiveHeight, point.Z)
        if not inPitch(point, scene.bounds, 2) then return nil, "Outside pitch" end
        if not onside(scene, receiver, windup) then return nil, "Offside" end
        if reachTime(receiver, point, Rules.Pickup.CushionReach, 0.14) > duration + windup then return nil, "Receiver cannot arrive" end
        local delta = point - from
        local velocity = delta / duration
        if mode.ground then velocity = flat(velocity) + Vector3.new(0, if mode.kind == "roll" then Hands.ROLL_DOWN else 0, 0)
        else velocity += Vector3.new(0, scene.params.gravity * duration * 0.5, 0) end
        if not mode.ground and velocity.Magnitude > maximum * 1.12 then return nil, "Launch exceeds available speed" end
        local spin
        local best, bestError = nil, math.huge
        for _ = 1, 6 do
            spin = if mode.ground then Flight.rollingSpin(velocity) else Flight.spinFrom(unit(flat(velocity)), mode.curve or 0, 0)
            velocity, spin = accepted(mode, velocity, spin)
            if not velocity then return nil end
            local endpoint = simulate(scene, from, velocity, spin, duration, false)
            local errorVector = point - endpoint.pos
            local error = errorVector.Magnitude
            if error < bestError then best, bestError = {vel = velocity, spin = spin}, error end
            if error < 0.12 then break end
            local correction = errorVector / duration * 1.08
            if mode.ground then correction = flat(correction) end
            velocity += correction
        end
        if not best or bestError > 1.3 then return nil, {reason = "Trajectory miss", miss = bestError, time = duration, from = from, point = point, fit = best} end
        local endpoint, rows = simulate(scene, from, best.vel, best.spin, duration, true)
        if endpoint.pos.Y > scene.floor + scene.params.radius + Rules.Pickup.MaxHeight then return nil, "Arrival is too high" end
        if not Rules.takeable(endpoint.vel, receiver.vel) then return nil, "Arrival cannot be controlled" end
        return {receiver = receiver, mode = mode, space = space, from = from, velocity = best.vel,
            spin = best.spin, time = duration, windup = windup, direction = direction,
            point = point, rows = rows, error = bestError, arrivalVelocity = endpoint.vel}
    end
    M.solve = solve
    local trajectoryCache = {}
    local cacheKey
    local function physicsKey(params)
        return table.concat({params.radius, params.gravity, params.airDrag, params.curve, params.friction,
            params.mass, params.roll, params.rollDrag, params.bounce}, ":")
    end
    local function coarseSolve(scene, receiver, mode, space, paceScale)
        if scene.held or paceScale ~= 1 or math.abs(scene.from.Y - scene.world.groundY) > 0.2
            or cacheKey ~= physicsKey(scene.params) then return solve(scene, receiver, mode, space, paceScale) end
        local duration = math.max(flat(receiver.pos - scene.from).Magnitude / mode.pace, mode.minimum or 0.18)
        local point
        for _ = 1, 3 do
            point = predict(receiver, duration) + scene.attack * space
            duration = math.max(flat(point - scene.from).Magnitude / mode.pace, mode.minimum or 0.18)
        end
        point = predict(receiver, duration) + scene.attack * space
        point = Vector3.new(point.X, scene.world.groundY + (if mode.ground then 0 else 1.2), point.Z)
        local delta = flat(point - scene.from)
        local distance = delta.Magnitude
        local bucket = math.max(8, math.floor(distance / 8 + 0.5) * 8)
        local template = trajectoryCache[mode.name .. ":" .. bucket]
        if template == nil then return solve(scene, receiver, mode, space, paceScale) end
        if template == false then return solve(scene, receiver, mode, space, paceScale) end
        if distance < 4 or not inPitch(point, scene.bounds, 2) or not onside(scene, receiver, 0) then return nil end
        if reachTime(receiver, point, Rules.Pickup.CushionReach, 0.14) > duration then return nil end
        local scale = distance / bucket
        local timeScale = duration / template.time
        local direction = unit(delta)
        local basis = CFrame.fromMatrix(Vector3.zero, direction, Vector3.yAxis, direction:Cross(Vector3.yAxis))
        local function position(v)
            local relative = v - template.from
            return scene.from + basis:VectorToWorldSpace(Vector3.new(relative.X * scale, relative.Y * timeScale * timeScale, relative.Z * scale))
        end
        local function velocity(v)
            return basis:VectorToWorldSpace(Vector3.new(v.X * scale / timeScale, v.Y * timeScale, v.Z * scale / timeScale))
        end
        local rows = {}
        for _, row in ipairs(template.rows) do
            table.insert(rows, {t = row.t * timeScale, p = position(row.p), v = velocity(row.v)})
        end
        local arrivalVelocity = velocity(template.arrivalVelocity)
        if not Rules.takeable(arrivalVelocity, receiver.vel) then return nil end
        return {receiver = receiver, mode = mode, space = space, from = scene.from,
            velocity = velocity(template.velocity), spin = basis:VectorToWorldSpace(template.spin),
            time = duration, windup = 0, direction = direction, point = point, rows = rows,
            error = template.error * scale + 0.15, arrivalVelocity = arrivalVelocity, approximate = true}
    end
    M.coarseSolve = coarseSolve
    task.spawn(function()
        while life.alive() do
            local params, world = World.params(), World.get()
            local key = physicsKey(params)
            if key ~= cacheKey then table.clear(trajectoryCache); cacheKey = key end
            local origin = Vector3.new(0, world.groundY, 0)
            local scene = {from = origin, root = {Position = origin + Vector3.new(0, 3.84, 0)}, held = false,
                floor = world.groundY - params.radius, params = params,
                world = {groundY = world.groundY, frames = {}, bodies = {}}, attack = Vector3.xAxis}
            local complete = true
            for bucket = 8, 240, 8 do
                for _, mode in ipairs(modes) do
                    if not life.alive() then return end
                    local cacheId = mode.name .. ":" .. bucket
                    if trajectoryCache[cacheId] ~= nil then continue end
                    complete = false
                    if M.planning or S.busy or Dribble.kickState() then task.wait(0.1); continue end
                    local receiver = {pos = origin + Vector3.new(bucket, 3.84, 0), vel = Vector3.zero,
                        acceleration = Vector3.zero, speed = 26, accel = 145}
                    trajectoryCache[cacheId] = solve(scene, receiver, mode, 0, 1) or false
                    M.cacheEntries = (M.cacheEntries or 0) + 1
                    task.wait()
                end
            end
            if complete then break end
            task.wait(0.25)
        end
    end)
    local function assess(scene, plan, look)
        local margin, blocker = 4, nil
        for _, row in ipairs(plan.rows) do
            local time = row.t + plan.windup
            if not inPitch(row.p, scene.bounds, 0.3) then return nil end
            if row.t > 0.02 then
                for _, enemy in ipairs(scene.enemies) do
                    local height = scene.floor + 8.5 + (if time > 0.45 then 3.2 else 0)
                    if row.p.Y <= height then
                        local reach = 2.5 + scene.params.radius + math.min(time * 0.7 + enemy.uncertainty, 2)
                        local travel = reachTime(enemy, row.p, reach, if enemy.available then 0.08 else 0.6)
                        local difference = travel - time
                        if difference < margin then margin, blocker = difference, enemy end
                    end
                end
            end
        end
        local room = 35
        local receivesAt = plan.time + plan.windup
        for _, enemy in ipairs(scene.enemies) do
            room = math.min(room, flat(predict(enemy, receivesAt) - plan.point).Magnitude)
        end
        local receiverUncertainty = plan.receiver.uncertainty * receivesAt + math.max(receivesAt - 1, 0) * 1.1
        local probability = 1 / (1 + math.exp(-math.clamp(margin / 0.17, -20, 20)))
        local progress = math.clamp((plan.point - scene.from):Dot(scene.attack), -100, 170)
        local score = probability * 100 + progress * 0.065 + math.min(room, 25) * 0.35
            - receivesAt * 1.8 - receiverUncertainty * 2 - plan.error * 4
        if plan.mode.ground then score += 1.5 end
        if cfg.passDecision == "Safe" then score -= math.max(progress, 0) * 0.035
        elseif cfg.passDecision == "Attacking" then score += progress * 0.06 end
        if look then score += math.max(unit(flat(plan.receiver.pos - scene.from)):Dot(look), -1) * 22 end
        if plan.approximate then margin -= 0.06 end
        plan.margin, plan.score, plan.blocker, plan.room = margin, score, blocker, room
        plan.receiverUncertainty = receiverUncertainty
        return plan
    end
    M.assess = assess
    function M.plan(scene, options)
        options = options or {}
        local ranked = {}
        local sliceAt = os.clock()
        for _, receiver in ipairs(scene.teammates) do
            if options.receiverId and receiver.id ~= options.receiverId then continue end
            for _, mode in ipairs(if scene.held then handModes else modes) do
                if options.type and options.type ~= "Automatic" and options.type ~= mode.name
                    and not (options.type == "Curved" and mode.curve) then continue end
                for _, space in ipairs({0, 5}) do
                    local plan = if options.exact then solve(scene, receiver, mode, space, options.paceScale or 1)
                        else coarseSolve(scene, receiver, mode, space, options.paceScale or 1)
                    if plan then
                        plan = assess(scene, plan, options.look)
                        if plan then table.insert(ranked, plan) end
                    end
                    if options.yield and os.clock() - sliceAt > 0.003 then
                        options.yield()
                        if not life.alive() then return nil, {} end
                        sliceAt = os.clock()
                    end
                end
            end
        end
        table.sort(ranked, function(a, b) return a.score > b.score end)
        return ranked[1], ranked
    end
    local function minimumMargin()
        return if cfg.passDecision == "Safe" then 0.18 elseif cfg.passDecision == "Attacking" then -0.08 else 0.04
    end
    function M.safe(plan) return plan and plan.margin >= minimumMargin() end
    local function stillOwn(scene)
        if not life.alive() or player.Character ~= scene.character or Ball.getBall() ~= scene.ball then return false end
        local state = Dribble.kickState()
        if state and not scene.held and not scene.freeRestart then return state.pid == scene.pid end
        if scene.ball:GetAttribute("PossessionId") ~= scene.pid then return false end
        if scene.freeRestart then
            local restart = M.restart()
            return restart and restart.phase == "Restart" and restart.kind == "GoalKick" and restart.team == scene.team
                and restart.taker == player.UserId and flat(scene.from - scene.root.Position).Magnitude <= 4.5
        end
        return scene.ball:GetAttribute("Possessor") == scene.ownId
    end
    M.stillOwn = stillOwn
    local function release(scene, plan)
        if not stillOwn(scene) or S.busy then return false end
        local sent
        S.busy = true
        local ok, err = pcall(function()
            if scene.held then
                if not NativeKick.hands or not NativeKick.hands.release then return end
                local restoreAim = life.override(Hands, "aimIn", function() return plan.direction end)
                local distance = flat(plan.point - scene.root.Position).Magnitude
                local restoreKind = life.override(Hands, "kindFor", function() return plan.mode.kind, distance end)
                local original = Hands.launch
                local restoreLaunch = life.override(Hands, "launch", function(kind, from, at, direction, amount, yielding)
                    if kind == plan.mode.kind and (from - plan.from).Magnitude < 4 then return plan.velocity, plan.spin end
                    return original(kind, from, at, direction, amount, yielding)
                end)
                local invoked, value = pcall(NativeKick.hands.release, if plan.mode.kind == "punt" then "Shoot" else "Pass", 0.5)
                restoreAim(); restoreKind()
                task.delay(0.12, restoreLaunch)
                if not invoked then error(value) end
                sent = value == true
            else
                local state = Dribble.kickState()
                local from = if state and state.pid == scene.pid then Path.sample(state.seg, now(), state.P) else scene.from
                if (from - plan.from).Magnitude > 1.4 then return end
                if scene.freeRestart then sent = Dribble.strikeFree(from, plan.velocity, plan.spin, plan.mode.family, now())
                elseif state and state.pid == scene.pid then sent = Dribble.strike(from, plan.velocity, plan.spin, plan.mode.family, now()) end
            end
        end)
        task.delay((if sent then plan.windup else 0) + 0.12, function() if life.alive() then S.busy = false end end)
        if not ok then M.error = tostring(err); return false end
        if sent then
            local record = {at = now(), pid = scene.pid, ball = scene.ball, ownId = scene.ownId,
                receiverId = plan.receiver.id, receiver = plan.receiver.player.DisplayName, receiverModel = plan.receiver.model,
                style = plan.mode.name, point = plan.point, margin = plan.margin, score = plan.score,
                time = plan.time, windup = plan.windup, requestedVelocity = plan.velocity, state = "Sent"}
            M.active = record
            push(record)
            M.status = "Passing to " .. record.receiver .. " | " .. record.style
            return true
        end
        return false
    end
    M.release = release
    function M.lookTarget(scene)
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local origin, direction = camera.CFrame.Position, camera.CFrame.LookVector
        local threshold = math.cos(math.rad(cfg.passCone))
        local best, bestAlignment, bestDistance = nil, threshold, math.huge
        for _, receiver in ipairs(scene.teammates) do
            local delta = receiver.pos - origin
            local distance = delta.Magnitude
            if distance < 0.01 then continue end
            local alignment = delta:Dot(direction) / distance
            if alignment >= threshold and (alignment > bestAlignment + 0.0001 or (math.abs(alignment - bestAlignment) <= 0.0001 and distance < bestDistance)) then
                best, bestAlignment, bestDistance = receiver, alignment, distance
            end
        end
        return best
    end
    local nextAttempt = 0
    local function observe()
        local record = M.active
        if not record then return end
        local ball = record.ball
        if not ball.Parent or Ball.getBall() ~= ball then record.state = "Ball changed"; M.active = nil; return end
        local pid, possessor = ball:GetAttribute("PossessionId"), ball:GetAttribute("Possessor")
        local flight = Flight.decode(ball:GetAttribute(KickRules.ATTR_FLIGHT))
        if flight and flight.pid == record.pid + 1 and flight.by == record.ownId then
            record.accepted = true
            record.acceptedVelocity = flight.vel
        end
        if possessor and possessor ~= 0 and possessor ~= record.ownId then
            record.resultPid, record.resultHolder = pid, possessor
            for _, other in ipairs(Players:GetPlayers()) do
                local model = other.Character
                if model and model:GetAttribute("DribbleId") == possessor then
                    record.resultPlayer, record.resultTeam = other.DisplayName, model:GetAttribute("Team")
                    break
                end
            end
            local received = record.accepted and pid == record.pid + 2 and possessor == record.receiverId
                and record.receiverModel:GetAttribute("DribbleId") == record.receiverId
            record.state = if received then "Received" else "Interrupted"
            M.status = if received then "Received by " .. record.receiver else "Pass interrupted"
            M.active = nil
        elseif pid and pid > record.pid + 1 then record.state = "Interrupted"; record.resultPid, record.resultHolder = pid, possessor; M.active = nil
        elseif now() - record.at > record.windup + record.time + 2 then
            record.state = if record.accepted then "Not received" else "Release not confirmed"
            M.active = nil
        end
    end
    function M.request(source)
        local fromRestart = source == "restart"
        if M.planning or S.busy or now() < nextAttempt then return false end
        nextAttempt = now() + 0.1
        local scene, reason = M.snapshot(true)
        if not scene then M.status = reason; M.choice = nil; return false end
        if fromRestart and (not scene.restart or scene.restart.kind ~= "GoalKick" or scene.restart.taker ~= player.UserId) then return false end
        local receiver = if fromRestart then nil else M.lookTarget(scene)
        if not fromRestart and not receiver then M.status = "Look at a teammate"; return false end
        local receiverId = receiver and receiver.id
        if scene.held and M.heldPid ~= scene.pid then M.heldPid, M.heldSince = scene.pid, now() end
        if M.active and M.active.pid == scene.pid then return false end
        M.planning = true
        nextAttempt = now() + 0.18
        task.spawn(function()
            local ok, err = pcall(function()
                local began = os.clock()
                local options: any = {yield = function() task.wait() end}
                options.type = if fromRestart then "Automatic" else cfg.smartPassType
                options.paceScale = if fromRestart then 1 else cfg.passStrength / 100
                options.receiverId = receiverId
                options.look = if fromRestart then nil else unit(flat(workspace.CurrentCamera.CFrame.LookVector))
                local _, ranked = M.plan(scene, options)
                M.planMs = (os.clock() - began) * 1000
                if not stillOwn(scene) then return end
                local fresh = M.snapshot(true)
                if not fresh or fresh.pid ~= scene.pid then return end
                local choice
                for index = 1, math.min(#ranked, 3) do
                    local prior = ranked[index]
                    local receiver
                    for _, a in ipairs(fresh.teammates) do if a.id == prior.receiver.id then receiver = a; break end end
                    if receiver then
                        local candidate = solve(fresh, receiver, prior.mode, prior.space, options.paceScale or 1)
                        if candidate then candidate = assess(fresh, candidate, options.look) end
                        if candidate and (not choice or candidate.score > choice.score) then choice = candidate end
                    end
                    task.wait()
                    if not stillOwn(fresh) then return end
                end
                local finalScene = M.snapshot(true)
                if not finalScene or finalScene.pid ~= scene.pid then return end
                if choice then
                    local receiver
                    for _, a in ipairs(finalScene.teammates) do if a.id == choice.receiver.id then receiver = a; break end end
                    choice = if receiver then solve(finalScene, receiver, choice.mode, choice.space, options.paceScale or 1) else nil
                    if choice then choice = assess(finalScene, choice, options.look) end
                end
                M.ranked, M.choice = ranked, choice
                if M.safe(choice) or (choice and scene.held and now() - M.heldSince > Hands.HOLD_MAX - 1.25) then release(finalScene, choice)
                else M.status = if #fresh.teammates == 0 then "No teammate available" else "Waiting for an opening" end
            end)
            M.planning = false
            if not ok then M.error = tostring(err); M.status = "Could not plan a pass" end
        end)
        return true
    end
    life.connect(Run.Heartbeat, function()
        observe()
    end)
    life.onCleanup(function() table.clear(observations) end)
    return M
end)()
S.passingEngine = Passing
function S.passToLook() return Passing.request() end
function S.findPassTarget()
    local scene = Passing.snapshot(true)
    return scene and Passing.lookTarget(scene)
end

local GK = (function()
    local KeeperRules = module(gameModules, "KeeperRules")
    local Hands = module(gameModules, "KeeperHands")
    local Dives = module(gameModules, "KeeperDives")
    local Sim = module(gameModules, "BallSim")
    local World = module(gameModules.BallSim, "World")
    local Motion = module(gameModules.Dribble, "Motion")
    local M: any = {status = "Waiting for goalkeeper role", passStatus = "Waiting for possession",
        saves = {}, decisions = {}, history = {}, samples = {}, enabledAt = now()}
    if previous and type(previous.gk) == "table" then
        for _, key in ipairs({"saves", "decisions", "history", "samples"}) do
            if type(previous.gk[key]) == "table" then M[key] = previous.gk[key] end
        end
    end
    local function flat(v) return v * Vector3.new(1, 0, 1) end
    local function unit(v, fallback) return if v.Magnitude > 0.001 then v.Unit else fallback end
    local function validVector(v)
        return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
    end
    local function push(list, value, limit)
        table.insert(list, value)
        if #list > limit then table.remove(list, 1) end
    end
    local function geometry(character)
        if not character then return nil end
        local area = KeeperRules.area(character:GetAttribute("Team"))
        if not area then return nil end
        local lines = Contacts.goalLines()
        for _, frame in ipairs(Tags:GetTagged("SoccerGoalFrame")) do
            if frame:IsA("BasePart") and frame:IsDescendantOf(workspace)
                and (frame.Position.X - area.centre.X) * area.side > 0 then
                local scale = frame.Size.Y / 9.142857142857142
                local floor = frame.Position.Y - frame.Size.Y / 2
                return {side = area.side, out = Vector3.new(-area.side, 0, 0),
                    x = if lines then lines[if area.side > 0 then 2 else 1] else area.centre.X + area.line * area.side,
                    z = frame.Position.Z, half = 13.071428571428571 * scale,
                    floor = floor, top = floor + 8.714285714285714 * scale, area = area}
            end
        end
        return nil
    end
    M.geometry = geometry

    local function forecast(state, startAt, duration, goal)
        if not state or not validVector(state.pos) or not validVector(state.vel)
            or not validVector(state.spin) or not finite(state.t) then return nil end
        local world = World.get()
        local params = World.params()
        local predictionWorld = {groundY = world.groundY, frames = world.frames, bodies = {}}
        local current = table.clone(state)
        local step = Sim.STEP
        local behind = startAt - state.t
        if behind < -0.15 or behind > 0.55 then return nil end
        for _ = 1, math.ceil(math.max(behind, 0) / step) do
            current = Sim.step(World.FLIGHT, current, math.min(step, startAt - current.t), params, predictionWorld, false, 0, nil)
        end
        local output = {{t = 0, p = current.pos, v = current.vel}}
        local previous = current.pos
        local threat
        for i = 1, math.ceil(duration / step) do
            current = Sim.step(World.FLIGHT, current, step, params, predictionWorld, false, 0, nil)
            local t = i * step
            if goal and not threat then
                local before = (previous.X - goal.x) * goal.side
                local after = (current.pos.X - goal.x) * goal.side
                if before < 0 and after >= 0 then
                    local fraction = -before / math.max(after - before, 1e-8)
                    local crossing = previous:Lerp(current.pos, fraction)
                    if math.abs(crossing.Z - goal.z) <= goal.half + params.radius
                        and crossing.Y >= goal.floor - params.radius and crossing.Y <= goal.top + params.radius then
                        threat = {t = t - step + step * fraction, p = crossing}
                    end
                end
            end
            if i % 2 == 0 then table.insert(output, {t = t, p = current.pos, v = current.vel}) end
            previous = current.pos
            if Sim.resting(current, World.FLIGHT) then break end
        end
        return {rows = output, threat = threat, at = startAt, radius = params.radius}
    end
    M.forecast = forecast
    local function samplePrediction(prediction, time)
        local rows = prediction.rows
        local index = math.clamp(math.floor(time * 60) + 1, 1, #rows)
        local a, b = rows[index], rows[math.min(index + 1, #rows)]
        local alpha = if b.t > a.t then math.clamp((time - a.t) / (b.t - a.t), 0, 1) else 0
        return a.p:Lerp(b.p, alpha), a.v:Lerp(b.v, alpha)
    end
    M.samplePrediction = samplePrediction

    local templateCharacter, templateSkeleton
    local templates = {}
    local partNames = {"LeftHand", "RightHand", "LeftForearm", "RightForearm", "Chest", "LeftFoot", "RightFoot"}
    local function buildTemplates(character)
        local animator = Mannequin.getAnimator(character)
        local sk = animator and animator.skeleton
        if not sk then return {} end
        if character == templateCharacter and sk == templateSkeleton then return templates end
        templates = {}
        for _, kind in ipairs({"Low", "Mid", "High", "Block", "Smother"}) do
            local track = Dives.track(kind)
            if track then
                for _, mirror in ipairs({false, true}) do
                    local side = if mirror then track.left else track.right
                    local initial = Dives.hips(side, 0)
                    local rows = {}
                    local maxTime = math.min(track.ragAt or track.touch + 0.18, 0.95)
                    for _, time in ipairs({0, 0.06, 0.1, 0.15, 0.2, 0.26, 0.33, 0.42, 0.53, 0.67, 0.82, 0.95}) do
                        if time <= maxTime then
                            local pose = Dives.pose(sk, side, time, CFrame.identity)
                            local solved = sk:solve(pose)
                            local parts = {}
                            for _, name in ipairs(partNames) do
                                local actual = character:FindFirstChild(name)
                                if actual and actual:IsA("BasePart") and solved[name] then
                                    table.insert(parts, {name = name, cf = solved[name] - flat(initial), half = actual.Size / 2})
                                end
                            end
                            table.insert(rows, {t = time, parts = parts})
                        end
                    end
                    table.insert(templates, {kind = kind, mirror = mirror, rows = rows, takeoff = math.max(track.takeoff, 0.15)})
                end
            end
        end
        templateCharacter, templateSkeleton = character, sk
        M.templates = templates
        return templates
    end
    M.buildTemplates = buildTemplates
    local function gapToBox(cf, half, point)
        local localPoint = cf:PointToObjectSpace(point)
        return Vector3.new(math.max(math.abs(localPoint.X) - half.X, 0),
            math.max(math.abs(localPoint.Y) - half.Y, 0), math.max(math.abs(localPoint.Z) - half.Z, 0)).Magnitude
    end
    M.gapToBox = gapToBox
    local function moveWish(position, velocity, target, speed, acceleration, deceleration)
        local delta = flat(target - position)
        if delta.Magnitude < 0.12 and velocity.Magnitude < 0.45 then return Vector3.zero end
        local direction = unit(delta, Vector3.zero)
        local closing = velocity:Dot(direction)
        local brakeSpeed = math.sqrt(math.max(0, 2 * deceleration * math.max(delta.Magnitude - 0.12, 0)))
        local desired = direction * math.min(speed, brakeSpeed)
        local lateral = velocity - direction * closing
        return unit(desired - lateral * math.min(1, acceleration / math.max(speed * 4, 1)), Vector3.zero)
            * math.min(desired.Magnitude / math.max(speed, 1), 1)
    end
    local function movementPath(r, cm, target)
        local ground = cm:FindFirstChild("GroundController")
        local speed = math.max(cm.BaseMoveSpeed, 1)
        local acceleration = speed / math.max(ground and ground.AccelerationTime or 0.15, 0.04)
        local deceleration = speed / math.max(ground and ground.DecelerationTime or 0.12, 0.04)
        local position, velocity = r.Position, flat(r.AssemblyLinearVelocity)
        local rows = {{p = position, v = velocity}}
        for _ = 1, 60 do
            local wish = moveWish(position, velocity, target, speed, acceleration, deceleration)
            velocity = Motion.stepVelocity(velocity, wish * speed, acceleration, deceleration, 1 / 60)
            position = position + velocity / 60
            table.insert(rows, {p = position, v = velocity})
        end
        return rows, moveWish(r.Position, flat(r.AssemblyLinearVelocity), target, speed, acceleration, deceleration)
    end
    local function currentMoveWish(r, cm, target)
        local ground = cm:FindFirstChild("GroundController")
        local speed = math.max(cm.BaseMoveSpeed, 1)
        return moveWish(r.Position, flat(r.AssemblyLinearVelocity), target, speed,
            speed / math.max(ground and ground.AccelerationTime or 0.15, 0.04),
            speed / math.max(ground and ground.DecelerationTime or 0.12, 0.04))
    end

    local function sweepGap(cfA, cfB, half, ballA, ballB, radius)
        local a, b = ballA - cfA.Position, ballB - cfB.Position
        local delta = b - a
        local squared = delta:Dot(delta)
        local centreAlpha = if squared > 1e-8 then math.clamp(-a:Dot(delta) / squared, 0, 1) else 0.5
        if (a + delta * centreAlpha).Magnitude > half.Magnitude + radius then return math.huge, nil end
        local function at(alpha)
            return gapToBox(cfA:Lerp(cfB, alpha), half, ballA:Lerp(ballB, alpha))
        end
        local low, high = 0, 1
        for _ = 1, 4 do
            local third = (high - low) / 3
            local left, right = low + third, high - third
            if at(left) < at(right) then high = right else low = left end
        end
        local alpha = (low + high) * 0.5
        local gap = at(alpha)
        local value = at(0)
        if value < gap then gap, alpha = value, 0 end
        value = at(1)
        if value < gap then gap, alpha = value, 1 end
        value = at(centreAlpha)
        if value < gap then gap, alpha = value, centreAlpha end
        if gap > 0 then
            for _ = 1, 8 do
                local third = (high - low) / 3
                local left, right = low + third, high - third
                local leftGap, rightGap = at(left), at(right)
                if leftGap < gap then gap, alpha = leftGap, left end
                if rightGap < gap then gap, alpha = rightGap, right end
                if leftGap < rightGap then high = right else low = left end
                if gap == 0 then break end
            end
        end
        return gap, alpha
    end
    M.sweepGap = sweepGap

    local function standbyTarget(position, goal, depth, y)
        local plane = goal.x - goal.side * depth
        local left = Vector3.new(goal.x, position.Y, goal.z - goal.half)
        local right = Vector3.new(goal.x, position.Y, goal.z + goal.half)
        local bisector = unit(flat(left - position), -goal.out) + unit(flat(right - position), -goal.out)
        local z = goal.z
        if math.abs(bisector.X) > 0.001 and (position.X - goal.x) * goal.side < -depth then
            z = position.Z + bisector.Z * (plane - position.X) / bisector.X
        end
        return Vector3.new(plane, y, math.clamp(z, goal.z - goal.half + 1, goal.z + goal.half - 1))
    end
    M.standbyTarget = standbyTarget
    local function lineIntercept(prediction, plane, side)
        for i = 2, #prediction.rows do
            local a, b = prediction.rows[i - 1], prediction.rows[i]
            local da, db = (a.p.X - plane) * side, (b.p.X - plane) * side
            if da < 0 and db >= 0 then
                local alpha = -da / math.max(db - da, 1e-8)
                return a.p:Lerp(b.p, alpha), a.t + (b.t - a.t) * alpha
            end
        end
        return nil
    end
    M.lineIntercept = lineIntercept
    local function orientedRows(template, goal, turn)
        template.oriented = template.oriented or {}
        local key = tostring(goal.side) .. ":" .. tostring(turn)
        local cached = template.oriented[key]
        if cached then return cached.rows, cached.orientation, cached.face end
        local face = CFrame.Angles(0, turn, 0) * goal.out
        local orientation = CFrame.lookAt(Vector3.zero, face)
        local rows = {}
        for _, row in ipairs(template.rows) do
            local parts = {}
            local reach = 0
            for _, part in ipairs(row.parts) do
                table.insert(parts, {name = part.name, half = part.half, cf = orientation * part.cf})
                reach = math.max(reach, part.cf.Position.Magnitude + part.half.Magnitude)
            end
            table.insert(rows, {t = row.t, parts = parts, reach = reach})
        end
        template.oriented[key] = {rows = rows, orientation = orientation, face = face}
        return rows, orientation, face
    end
    local function chooseSave(prediction, character, goal, moveTarget, dispatchLead)
        local r = character:FindFirstChild("Root")
        local cm = character:FindFirstChildOfClass("ControllerManager")
        local animator = Mannequin.getAnimator(character)
        if not r or not cm or not animator or not animator.body then return nil end
        local motion = movementPath(r, cm, moveTarget)
        local lead = dispatchLead or 0
        local deadline = (if prediction.threat then prediction.threat.t else math.min(prediction.rows[#prediction.rows].t, 0.8)) - lead
        local best, bestScore
        local pelvis = animator.skeleton.parts[animator.skeleton.pelvisName]
        local rootToPelvis = flat(pelvis.Position - r.Position)
        for _, template in ipairs(buildTemplates(character)) do
            for _, turn in ipairs({-0.4, 0, 0.4}) do
                local rows, orientation, face = orientedRows(template, goal, turn)
                for _, delay in ipairs({0, 0.05, 0.1, 0.17, 0.25, 0.35, 0.48, 0.62, 0.8, 1}) do
                    if delay >= deadline then break end
                    if bestScore and prediction.radius + Hands.MEET_SLACK - 0.4 - delay * 0.09 - 0.055 * 0.025 <= bestScore then break end
                    local moving = motion[math.clamp(math.floor((delay + lead) * 60) + 1, 1, #motion)]
                    local anchor = Vector3.new(moving.p.X, goal.floor, moving.p.Z) + rootToPelvis
                    local carry = moving.v
                    if carry.Magnitude > Dives.Tuning.CarryMax then carry = carry.Unit * Dives.Tuning.CarryMax end
                    local function shiftAt(t)
                        local carryAt = math.min(t, template.takeoff)
                        return anchor + carry * (carryAt - carryAt * carryAt / (2 * template.takeoff))
                    end
                    for i = 2, #rows do
                        local a, b = rows[i - 1], rows[i]
                        local endTime = math.min(b.t, deadline + 0.012 - delay)
                        if endTime <= a.t then break end
                        if bestScore and prediction.radius + Hands.MEET_SLACK - 0.4 - delay * 0.09 - math.max(a.t, 0.055) * 0.025 <= bestScore then break end
                        local duration = endTime - a.t
                        local fraction = duration / (b.t - a.t)
                        local ballA = samplePrediction(prediction, lead + delay + a.t)
                        local ballB = samplePrediction(prediction, lead + delay + endTime)
                        local shiftA, shiftB = shiftAt(a.t), shiftAt(endTime)
                        local relativeA, relativeB = ballA - shiftA, ballB - shiftB
                        local relativeDelta = relativeB - relativeA
                        local relativeSquared = relativeDelta:Dot(relativeDelta)
                        local closest = if relativeSquared > 1e-8 then math.clamp(-relativeA:Dot(relativeDelta) / relativeSquared, 0, 1) else 0
                        if (relativeA + relativeDelta * closest).Magnitude > math.max(a.reach, b.reach) + prediction.radius + Hands.MEET_SLACK then continue end
                        for index, partA in ipairs(a.parts) do
                            local partB = b.parts[index]
                            if partB and partB.name == partA.name then
                                local uncertainty = if partA.name == "Chest" then 0.4 elseif string.find(partA.name, "Hand", 1, true) then 0.9 else 0.65
                                local upperScore = prediction.radius + Hands.MEET_SLACK - uncertainty - delay * 0.09 - math.max(a.t, 0.055) * 0.025
                                if bestScore and upperScore <= bestScore then continue end
                                local maxGap = math.min(prediction.radius + Hands.MEET_SLACK, upperScore - (bestScore or -math.huge))
                                local cfA = partA.cf + shiftA
                                local cfB = partA.cf:Lerp(partB.cf, fraction) + shiftB
                                local gap, alpha = sweepGap(cfA, cfB, partA.half, ballA, ballB, maxGap)
                                if alpha ~= nil then
                                    local elapsed = a.t + duration * alpha
                                    local time = lead + delay + elapsed
                                    local margin = prediction.radius + Hands.MEET_SLACK - gap
                                    local score = margin - uncertainty - delay * 0.09 - elapsed * 0.025
                                    if elapsed >= 0.055 and (not bestScore or score > bestScore) then
                                        best, bestScore = {kind = template.kind, mirror = template.mirror, face = face,
                                            direction = orientation.RightVector * (if template.mirror then -1 else 1),
                                            delay = delay, contact = time, point = ballA:Lerp(ballB, alpha), margin = margin,
                                            confidenceMargin = margin - uncertainty, actionAt = prediction.at + lead + delay,
                                            contactAt = prediction.at + time, rootAtAction = moving.p, score = score,
                                            part = partA.name, deadline = deadline + lead}, score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end
    M.chooseSave = chooseSave

    local function scheduleSave(candidate, prediction, pid, position)
        local pending = M.pendingSave
        local clock = now()
        if pending and pending.pid == pid and pending.actionAt >= clock - 0.035 and pending.contactAt > clock
            and prediction.threat and pending.contactAt <= prediction.at + prediction.threat.t + 0.02 then
            local expected = samplePrediction(prediction, math.max(pending.contactAt - prediction.at, 0))
            local ballStillMatches = (expected - pending.point).Magnitude < 1.2
            local rootStillMatches = pending.actionAt - clock > 0.06 or flat(position - pending.rootAtAction).Magnitude < 1.75
            if ballStillMatches and rootStillMatches then
                local improves = candidate and ((candidate.actionAt < pending.actionAt - 0.025 and candidate.score >= pending.score - 0.1)
                    or (candidate.score > pending.score + 0.3 and candidate.actionAt <= pending.actionAt + 0.015))
                if not improves then return pending end
            end
        end
        if candidate then candidate.pid = pid end
        M.pendingSave = candidate
        return candidate
    end
    M.scheduleSave = scheduleSave

    local diveCharacter, diveBody, diveDispatcher
    local function resolveDive(character)
        local animator = Mannequin.getAnimator(character)
        local body = animator and animator.body
        if not body then return nil end
        if diveCharacter ~= character or diveBody ~= body or not diveDispatcher then
            diveCharacter, diveBody, diveDispatcher = character, body, nil
            local seen, queue = {}, {Mannequin.keeperDiveTo}
            for _ = 1, 32 do
                local fn = table.remove(queue, 1)
                if not fn then break end
                if type(fn) == "function" and not seen[fn] then
                    seen[fn] = true
                    local source = debug.info(fn, "s")
                    local upvalues = debug.getupvalues(fn)
                    local ownsBody = false
                    for _, value in pairs(upvalues) do if value == body then ownsBody = true; break end end
                    if type(source) == "string" and string.find(source, "MannequinClient", 1, true) and ownsBody then
                        diveDispatcher = fn
                        break
                    end
                    for _, upvalue in pairs(upvalues) do
                        if type(upvalue) == "function" and not seen[upvalue] then table.insert(queue, upvalue) end
                    end
                end
            end
        end
        return diveDispatcher
    end
    function M.dispatcherReady() return resolveDive(player.Character) ~= nil end
    local function nativeDive(character, plan)
        if not life.alive() or player.Character ~= character or not KeeperRules.inGoal(character)
            or not Mannequin.keeperReady() then return false, "Goalkeeper controls are not ready" end
        resolveDive(character)
        if not diveDispatcher then return false, "Native dive dispatcher unavailable" end
        return diveDispatcher(plan.kind, plan.direction, plan.face)
    end
    M.nativeDive = nativeDive

    local function restartDecision(restart, team, userId)
        if not restart then return nil end
        if restart.kind ~= "GoalKick" or restart.team ~= team then return "Yield" end
        if type(restart.taker) == "number" and restart.taker > 0 then
            return if restart.taker == userId then "Take" else "Retreat"
        end
        return "Available"
    end
    M.restartDecision = restartDecision
    local function restartPolicy(character, r, goal, position)
        local restart = Passing.restart()
        local action = restartDecision(restart, character:GetAttribute("Team"), player.UserId)
        if not action then return nil end
        if action == "Yield" then return "Yield" end
        if action == "Take" then
            
            if restart.phase == "Restart" then Passing.request("restart") end
            return "Yield"
        end
        local home = standbyTarget(position, goal, 3.5, r.Position.Y)
        if action == "Retreat" or restart.phase ~= "Restart" then return "Retreat", home end
        local spot = if typeof(restart.spot) == "Vector3" then restart.spot else restart.ball
        if typeof(spot) ~= "Vector3" then return "Retreat", home end
        local distance = flat(spot - r.Position).Magnitude
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            local otherRoot = model and model:FindFirstChild("Root")
            if other ~= player and otherRoot and model:GetAttribute("Team") == character:GetAttribute("Team")
                and model:GetAttribute("BodyState") == "Animated" then
                local otherDistance = flat(otherRoot.Position - spot).Magnitude
                if otherDistance <= math.max(distance - 1, 5) then return "Retreat", home end
            end
        end
        return "Approach", Vector3.new(spot.X, r.Position.Y, spot.Z)
    end
    local function nearbyActors(character)
        local allies, enemies = {}, {}
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            if model and model ~= character then
                local a = Passing.actor(model, other, now())
                if a and (a.team == "Red" or a.team == "Blue") then
                    table.insert(if a.team == character:GetAttribute("Team") then allies else enemies, a)
                end
            end
        end
        return allies, enemies
    end
    local function gatherDecision(scene)
        if scene.possessor ~= 0 or not scene.free or not scene.grounded then return nil end
        if scene.speed > 28 or scene.distance > 8.5 then return nil end
        
        for _, row in ipairs(scene.prediction.rows) do
            if row.t > 0.42 then break end
            if flat(row.p - scene.position).Magnitude < Hands.GATHER_REACH - 0.3
                and row.p.Y <= scene.goal.floor + scene.prediction.radius + Hands.GATHER_HIGH then return nil end
        end
        for _, row in ipairs(scene.prediction.rows) do
            if row.t < 0.06 then continue end
            if row.t > 0.42 then break end
            local depth = (scene.goal.x - row.p.X) * scene.goal.side
            if depth < 0.8 or depth > 10 or math.abs(row.p.Z - scene.goal.z) > scene.goal.half - 1 then continue end
            if row.v.Magnitude > 28 or row.p.Y > scene.goal.floor + scene.prediction.radius + Hands.GATHER_HIGH - 0.4 then continue end
            if scene.prediction.threat and scene.prediction.threat.t <= row.t + 0.2 then continue end
            local eta = scene.arrival(row.p, row.t)
            if eta > row.t then continue end
            local safe = true
            for _, enemy in ipairs(scene.enemies) do
                if Passing.reachTime(enemy, row.p, 4, 0.06) <= row.t + 0.18 then safe = false; break end
            end
            if not safe then continue end
            for _, ally in ipairs(scene.allies) do
                if flat(ally.pos - row.p).Magnitude < math.min(scene.distance - 1, 5) then safe = false; break end
            end
            if safe then return {point = row.p, time = row.t} end
        end
        return nil
    end
    M.gatherDecision = gatherDecision
    local function safeGather(prediction, character, r, goal, ball)
        if not prediction or not cfg.gkPosition then return nil end
        local first = prediction.rows[1]
        if ball:GetAttribute("Possessor") ~= 0 or Ball.getSource() ~= "free"
            or first.v.Magnitude > 28 or flat(first.p - r.Position).Magnitude > 8.5 then return nil end
        local cm = character:FindFirstChildOfClass("ControllerManager")
        local sensor = cm and cm.GroundSensor
        if not cm then return nil end
        local allies, enemies = nearbyActors(character)
        local decision = gatherDecision({prediction = prediction, goal = goal,
            possessor = ball:GetAttribute("Possessor"), free = Ball.getSource() == "free",
            grounded = sensor and sensor.SensedPart ~= nil, speed = first.v.Magnitude,
            distance = flat(first.p - r.Position).Magnitude, position = r.Position, allies = allies, enemies = enemies,
            arrival = function(point, time)
                local path = movementPath(r, cm, point)
                local position = path[math.clamp(math.floor(time * 60) + 1, 1, #path)].p
                return if flat(position - point).Magnitude <= Hands.GATHER_REACH - 0.35 then time else math.huge
            end})
        if decision then
            M.lastGather = {at = now(), pid = ball:GetAttribute("PossessionId"), point = decision.point, time = decision.time}
            return Vector3.new(decision.point.X, r.Position.Y, decision.point.Z)
        end
        return nil
    end
    local lastJump = -10
    local function aerialDecision(scene)
        if scene.possessor ~= 0 or not scene.free or not scene.grounded then return nil end
        local best
        for _, row in ipairs(scene.prediction.rows) do
            if row.t < 0.28 then continue end
            if row.t > 1.1 then break end
            local depth = (scene.goal.x - row.p.X) * scene.goal.side
            local horizontal = flat(row.p - scene.position).Magnitude
            if depth < 0.7 or depth > 9 or math.abs(row.p.Z - scene.goal.z) > scene.goal.half then continue end
            if row.p.Y < scene.standingReach + 0.7 or row.p.Y > scene.standingReach + 3.8 then continue end
            if row.v.Y > 12 or horizontal > math.min(7, scene.speed * math.max(row.t - 0.18, 0) + 1.5) then continue end
            if scene.prediction.threat and scene.prediction.threat.t < row.t - 0.02 then continue end
            local score = horizontal + math.abs(row.t - 0.43) * 3
            if not best or score < best.score then
                best = {point = row.p, contactAt = scene.prediction.at + row.t,
                    jumpAt = scene.prediction.at + row.t - 0.43, score = score,
                    target = Vector3.new(row.p.X, scene.position.Y, row.p.Z)}
            end
        end
        return best
    end
    M.aerialDecision = aerialDecision
    local function standingReach(character, r)
        local head = character:FindFirstChild("Head")
        return (if head then head.Position.Y + head.Size.Y / 2 else r.Position.Y + 3) + 1.4
    end
    local function aerialOpportunity(prediction, character, r, goal, ball)
        if not prediction or not cfg.gkPosition or now() - lastJump < 1.1 then return nil end
        local cm = character:FindFirstChildOfClass("ControllerManager")
        local sensor = cm and cm.GroundSensor
        if not cm then return nil end
        local result = aerialDecision({prediction = prediction, goal = goal, possessor = ball:GetAttribute("Possessor"),
            free = Ball.getSource() == "free", grounded = sensor and sensor.SensedPart ~= nil,
            position = r.Position, standingReach = standingReach(character, r), speed = cm.BaseMoveSpeed})
        if result then result.pid = ball:GetAttribute("PossessionId") end
        return result
    end
    local function attemptJump(aerial, character, r, goal, ball)
        if now() - lastJump < 1.1 or aerial.pid ~= ball:GetAttribute("PossessionId")
            or S.busy or not Mannequin.keeperReady() or not KeeperRules.inGoal(character) then return false end
        local remaining = aerial.contactAt - now()
        if remaining < 0.26 or remaining > 0.49 or now() < aerial.jumpAt - 0.015 then return false end
        if flat(aerial.point - r.Position).Magnitude > 2.2 then return false end
        if aerial.point.Y > standingReach(character, r) + 3.8 then return false end
        local depth = (goal.x - aerial.point.X) * goal.side
        if depth < 0.7 or depth > 9 then return false end
        Mannequin.keeperJump()
        lastJump = now()
        M.lastDive = {at = now(), pid = aerial.pid, kind = "Jump", predictedContact = aerial.point,
            contactIn = remaining, characterId = character:GetAttribute("DribbleId")}
        push(M.samples, M.lastDive, 40)
        return true
    end

    local wished = Vector3.zero
    local faceWish
    local lastPlanning, lastDive = 0, -10
    local activeCharacter
    local nativeShape = Mannequin.shapeMove
    life.override(Mannequin, "shapeMove", function(input)
        local shaped = if nativeShape then nativeShape(input) else input
        local character = player.Character
        if not cfg.autoGK or not cfg.gkPosition or not character or character ~= activeCharacter
            or M.yieldMovement or character:GetAttribute("Role") ~= "Goalkeeper" or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return shaped end
        local team = character:GetAttribute("Team")
        if team ~= "Red" and team ~= "Blue" then return shaped end
        local camera = workspace.CurrentCamera
        if not camera then return shaped end
        local forward = unit(flat(camera.CFrame.LookVector), Vector3.new(0, 0, -1))
        local right = unit(flat(camera.CFrame.RightVector), Vector3.xAxis)
        local determinant = right.X * forward.Z - right.Z * forward.X
        if math.abs(determinant) < 0.001 then return shaped end
        local localMove = Vector2.new((wished.X * forward.Z - wished.Z * forward.X) / determinant,
            (right.X * wished.Z - right.Z * wished.X) / determinant)
        return if nativeShape then nativeShape(localMove) else localMove
    end)
    local function observeSave(ball, character)
        local attempt = M.lastDive
        if not attempt or now() - attempt.at > 1.3 then return end
        local position = Ball.getPosition()
        if not position then return end
        local closest = math.huge
        for _, name in ipairs(partNames) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                closest = math.min(closest, gapToBox(part.CFrame, part.Size / 2, position))
            end
        end
        attempt.closestGap = math.min(attempt.closestGap or math.huge, closest)
        if closest < ball.Size.X / 2 + Hands.MEET_SLACK then attempt.contactObserved = true end
        local _, _, event = Ball.freeSim()
        if event and event.pid == attempt.pid + 1 and event.by == attempt.characterId then
            attempt.parryConfirmed = true
        end
    end
    local function step()
        wished, faceWish = Vector3.zero, nil
        M.yieldMovement = false
        local character = player.Character
        local r = root()
        if not character or not r then M.status = "Waiting to spawn"; return end
        local team = character:GetAttribute("Team")
        local ball = Ball.getBall()
        if not ball or (team ~= "Red" and team ~= "Blue") then M.status = "Join a team to begin"; return end
        activeCharacter = character
        local goal = geometry(character)
        if not goal then return end
        observeSave(ball, character)
        local pid = ball:GetAttribute("PossessionId")
        local ownId = character:GetAttribute("DribbleId")
        local mine = ownId and ownId ~= 0 and ball:GetAttribute("Possessor") == ownId
        if mine then
            local save = M.lastThreat
            if save and not save.saveConfirmed and now() - save.at < 4 and pid == save.pid + 1
                and save.characterId == ownId then
                save.saveConfirmed = true
                save.savedAt = now()
                push(M.saves, save, 30)
            end
            M.status = "Ball secured"
            return
        end
        if not cfg.autoGK then
            M.plan, M.pendingSave, M.target, M.gatherTarget, M.aerial = nil, nil, nil, nil, nil
            M.status = "Automatic goalkeeper off"
            return
        end
        if character:GetAttribute("Role") ~= "Goalkeeper" then M.status = "Select goalkeeper to defend automatically"; return end
        local bodyState = character:GetAttribute("BodyState")
        local animator = Mannequin.getAnimator(character)
        if not animator or not animator.body or bodyState ~= "Animated" or animator.body.active then
            M.status = "Finishing save / recovering"
            return
        end
        local position = Ball.getPosition()
        if not position then return end
        local restartAction, restartTarget = restartPolicy(character, r, goal, position)
        if restartAction then
            M.pendingSave, M.plan = nil, nil
            if restartAction == "Yield" then M.yieldMovement = true
            elseif restartTarget then
                local cm = character:FindFirstChildOfClass("ControllerManager")
                if cm and cfg.gkPosition then wished = currentMoveWish(r, cm, restartTarget) end
            end
            return
        end
        local plane = goal.x - goal.side * 3.5
        local target = standbyTarget(position, goal, 3.5, r.Position.Y)
        local state, _, event = Ball.freeSim()
        if now() - lastPlanning >= math.max(1 / 30, (M.costMs or 0) / 1000 * 2) then
            local began = os.clock()
            lastPlanning = now()
            local prediction = state and forecast(state, now(), 2.2, goal)
            M.prediction = prediction
            M.plan = nil
            local gather = safeGather(prediction, character, r, goal, ball)
            local aerial = aerialOpportunity(prediction, character, r, goal, ball)
            M.gatherTarget, M.aerial = gather, aerial
            if gather then target = gather end
            if prediction and prediction.threat and not gather then
                local intercept = lineIntercept(prediction, plane, goal.side) or prediction.threat.p
                if not gather then target = Vector3.new(plane, r.Position.Y, math.clamp(intercept.Z, goal.z - goal.half + 0.8, goal.z + goal.half - 0.8)) end
                local candidate = chooseSave(prediction, character, goal, target, math.clamp((M.saveCostMs or 16) / 1000, 0.005, 0.09))
                M.plan = scheduleSave(candidate, prediction, event and event.pid or pid, r.Position)
                if event and (not M.lastThreat or M.lastThreat.pid ~= event.pid) then
                    M.lastThreat = {at = now(), pid = event.pid, by = event.by, characterId = ownId,
                        position = prediction.threat.p, crossingIn = prediction.threat.t}
                    push(M.history, M.lastThreat, 50)
                end
            end
            if not prediction or not prediction.threat then M.pendingSave = nil end
            if aerial and (not M.plan or M.plan.margin <= 0.08) then target = aerial.target end
            M.target = target
            M.costMs = (os.clock() - began) * 1000
            if prediction and prediction.threat then
                M.saveCostMs = (M.saveCostMs or M.costMs) * 0.6 + M.costMs * 0.4
            end
        else
            target = M.target or target
        end
        local cm = character:FindFirstChildOfClass("ControllerManager")
        if cm and cfg.gkPosition then
            wished = currentMoveWish(r, cm, target)
        end
        faceWish = unit(flat(position - r.Position), goal.out)
        local aerial = M.aerial
        if aerial and (not M.plan or M.plan.margin <= 0.08) then attemptJump(aerial, character, r, goal, ball) end
        local plan = M.plan
        M.status = if plan then string.format("%s save | %.2fs | margin %.2f", plan.kind, plan.contact, plan.margin) else "Positioning | watching the ball"
        if plan and plan.margin > 0.08 and plan.actionAt - now() <= 0.015 and now() - lastDive > 0.5
            and Mannequin.keeperReady() and not S.busy then
            local sent, reason = nativeDive(character, plan)
            if sent then
                lastDive = now()
                M.pendingSave = nil
                M.lastDive = {at = now(), pid = pid, kind = plan.kind, part = plan.part, margin = plan.margin,
                    predictedContact = plan.point, contactIn = plan.contact, characterId = ownId}
                push(M.samples, M.lastDive, 40)
            elseif reason then M.error = reason end
        end
    end
    local renderName = "PoopAutoGoalkeeper"
    Run:BindToRenderStep(renderName, Enum.RenderPriority.Input.Value, function()
        if not life.alive() then return end
        local ok, err = pcall(step)
        if not ok then M.error = tostring(err); wished, faceWish = Vector3.zero, nil end
    end)
    local faceRenderName = "PoopAutoGoalkeeperFace"
    Run:BindToRenderStep(faceRenderName, Enum.RenderPriority.Input.Value + 2, function()
        if not life.alive() or not faceWish or not cfg.autoGK or not cfg.gkPosition then return end
        local character = player.Character
        local cm = character and character:FindFirstChildOfClass("ControllerManager")
        if cm and character:GetAttribute("BodyState") == "Animated" then cm.FacingDirection = faceWish end
    end)
    life.onCleanup(function()
        wished, faceWish = Vector3.zero, nil
        Run:UnbindFromRenderStep(renderName)
        Run:UnbindFromRenderStep(faceRenderName)
    end)
    return M
end)()
S.gk = GK

local Protection = (function()
    local M: any = {blocked = {fall = 0, slide = 0, knock = 0, kick = 0, launch = 0}, recoveryRequests = 0, recoveryAcks = 0}
    local animation = module(gameModules, "MannequinAnimation")
    local bodyClass = module(gameModules.MannequinAnimation, "Body")
    local airKnock = module(gameModules.MannequinAnimation, "AirKnock")
    local replay = module(client, "InstantReplay")
    local recovered = Net:RemoteEvent("MannequinRecovered")
    local originalFall, originalKnock, originalKick = bodyClass.fall, bodyClass.knock, bodyClass.kickFall
    local originalStep, originalLaunched = airKnock.step, animation.launched
    local function ownBody(body)
        return life.alive() and body.model == player.Character and not replay.playing()
    end
    local function incoming(kind)
        M.blocked[kind] += 1
        M.lastBlock = {kind = kind, at = os.clock()}
    end
    life.override(bodyClass, "fall", function(body, impulse, point, part, swept)
        if ownBody(body) and (cfg.antiRagdoll or (cfg.antiSlide and swept == true)) then
            incoming(if swept == true then "slide" else "fall")
            M.recoverCharacter = player.Character
            M.recoverUntil = os.clock() + 0.8
            return
        end
        return originalFall(body, impulse, point, part, swept)
    end)
    life.override(bodyClass, "knock", function(body, ...)
        if ownBody(body) and cfg.antiRagdoll then incoming("knock"); return end
        return originalKnock(body, ...)
    end)
    life.override(bodyClass, "kickFall", function(body, ...)
        if ownBody(body) and cfg.antiRagdoll then incoming("kick"); return false end
        return originalKick(body, ...)
    end)
    life.override(airKnock, "step", function(detector)
        local contact = originalStep(detector)
        if contact and ownBody(detector) and cfg.antiRagdoll then incoming("knock"); return nil end
        return contact
    end)
    life.override(animation, "launched", function(velocity, scale)
        local r = root()
        if cfg.antiRagdoll and life.alive() and r and not replay.playing()
            and (velocity - r.AssemblyLinearVelocity).Magnitude < 0.001 then
            if originalLaunched(velocity, scale) then incoming("launch") end
            return false
        end
        return originalLaunched(velocity, scale)
    end)
    life.connect(recovered.OnClientEvent, function(reason)
        M.recoveryAcks += 1
        M.lastRecoveryAck = {at = os.clock(), reason = tostring(reason)}
    end)
    function M.recover()
        local c = player.Character
        local animator = c and Mannequin.getAnimator(c)
        local body = animator and animator.body
        if not c or not body or not (cfg.antiRagdoll or cfg.antiSlide) or replay.playing() then return end
        local mode = body.mode
        if mode == "Slide" or mode == "Dive" or mode == "KeyDive" or mode == "Block" then return end
        local state = c:GetAttribute("BodyState")
        if cfg.antiRagdoll and (state == "Ragdoll" or body.active) then
            M.recoverCharacter, M.recoverUntil = c, os.clock() + 0.8
        end
        if M.recoverCharacter ~= c or os.clock() > (M.recoverUntil or 0) then return end
        if os.clock() < (M.nextRecovery or 0) then return end
        if not body.active and state == "Ragdoll" then originalFall(body) end
        if body.active then body:standNow(); animator:standNow() end
        recovered:FireServer()
        M.recoveryRequests += 1
        M.nextRecovery = os.clock() + 0.15
        if state == "Animated" and not body.active then M.recoverUntil = os.clock() + 0.15 end
    end
    life.connect(Run.Heartbeat, function()
        local ok, err = pcall(M.recover)
        if not ok then M.error = tostring(err) end
    end)
    return M
end)()
S.protection = Protection


local Walkfling = (function()
    local M: any = {enabled = false, pulses = 0, connections = {}, scale = 10000, lift = 10000, contacts = {}, corrections = 0, blocked = {}}
    local viewName = "PoopWalkflingView"
    local replay = module(client, "InstantReplay")
    local pending
    function M.restore()
        local saved = pending
        pending = nil
        if saved and saved.root.Parent == saved.character then
            saved.root.AssemblyLinearVelocity = saved.velocity
            return saved.root, saved.velocity
        end
        return nil, nil
    end
    local function clearContacts()
        if M.folder then M.folder:Destroy(); M.folder = nil end
        table.clear(M.contacts)
        M.contactCharacter = nil
    end
    function M.syncContacts()
        local character = player.Character
        local collider = character and character:FindFirstChild("Collider")
        if not character or not collider or not collider:IsA("BasePart") then clearContacts(); return end
        if M.contactCharacter ~= character or not M.folder or not M.folder.Parent then
            clearContacts()
            M.folder = Instance.new("Folder")
            M.folder.Name = "PoopWalkflingContacts"
            M.folder.Parent = character
            M.contactCharacter = character
        end
        local seen = {}
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other ~= player and other.Character
            if model then
                for _, part in ipairs(model:GetChildren()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        seen[part] = true
                        if not M.contacts[part] then
                            local constraint = Instance.new("NoCollisionConstraint")
                            constraint.Name = "WalkflingContact"
                            constraint.Part0, constraint.Part1 = collider, part
                            constraint.Parent = M.folder
                            M.contacts[part] = constraint
                        end
                    end
                end
            end
        end
        for part, constraint in pairs(M.contacts) do
            if not seen[part] then constraint:Destroy(); M.contacts[part] = nil end
        end
        M.nextContacts = os.clock() + 0.5
    end
    function M.stop()
        M.enabled = false
        if M.renderBound then
            Run:UnbindFromRenderStep(viewName)
            M.renderBound = false
        end
        for _, connection in ipairs(M.connections) do connection:Disconnect() end
        table.clear(M.connections)
        local restoredRoot, velocity = M.restore()
        clearContacts()
        return restoredRoot, velocity
    end
    local function guarded(fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then M.error = tostring(err); M.stop() end
        end
    end
    local function blocked(reason)
        M.lastReason = reason
        M.blocked[reason] = (M.blocked[reason] or 0) + 1
    end
    function M.step()
        M.restore()
        if not M.enabled or not life.alive() then return end
        local at = os.clock()
        if os.clock() >= (M.nextContacts or 0) or player.Character ~= M.contactCharacter then M.syncContacts() end
        if replay.playing() then blocked("Replay"); return end
        if S.busy or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then blocked("Input"); return end
        local character = player.Character
        local r = character and character:FindFirstChild("Root")
        if not r or not r:IsA("BasePart") or character:GetAttribute("BodyState") ~= "Animated"
            or r.Anchored or not isnetworkowner(r) then blocked("Own rig"); return end
        local velocity = r.AssemblyLinearVelocity
        local previous = M.previous
        M.previous = {character = character, position = r.Position, at = at}
        if previous and previous.character == character and at - previous.at < 0.3
            and (r.Position - previous.position).Magnitude > math.max(16, velocity.Magnitude * (at - previous.at) * 3 + 3) then
            M.corrections += 1
            M.lastCorrection = {from = previous.position, to = r.Position, at = at}
        end
        if at < (M.pauseUntil or 0) then blocked("Jump"); return end
        local motion = velocity * Vector3.new(1, 0, 1)
        local manager = character:FindFirstChildOfClass("ControllerManager")
        local wish = manager and manager.MovingDirection or Vector3.zero
        if motion.Magnitude < 2 and wish.Magnitude >= 0.01 then
            motion = wish.Unit * math.max(manager and manager.BaseMoveSpeed or 16, 16)
        end
        local closest, distance = nil, 8
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other ~= player and other.Character
            local otherRoot = model and model:FindFirstChild("Root")
            if otherRoot and otherRoot:IsA("BasePart") and not otherRoot.Anchored then
                local d = (otherRoot.Position - r.Position).Magnitude
                if d < distance then closest, distance = otherRoot, d end
            end
        end
        if not closest then blocked("No contact"); return end
        local pulse = motion * M.scale + Vector3.new(0, M.lift, 0)
        pending = {root = r, character = character, velocity = velocity}
        r.AssemblyLinearVelocity = pulse
        M.pulses += 1
        M.lastReason = "Pulse"
        M.lastInterval = M.lastPulseAt and at - M.lastPulseAt
        M.lastPulseAt = at
        M.lastTargetState = closest.Parent and closest.Parent:GetAttribute("BodyState")
        M.lastIdle = motion.Magnitude < 2 and wish.Magnitude < 0.01
        M.lastTarget = closest.Parent and closest.Parent.Name
        M.lastDistance = (closest.Position - r.Position).Magnitude
    end
    function M.setEnabled(enabled)
        M.stop()
        if not enabled or not life.alive() then return end
        M.error = nil
        M.previous = nil
        M.enabled = true
        M.syncContacts()
        Run:BindToRenderStep(viewName, Enum.RenderPriority.First.Value - 1, guarded(M.restore))
        M.renderBound = true
        M.connections[1] = Run.PreAnimation:Connect(guarded(M.restore))
        M.connections[2] = Run.PreSimulation:Connect(guarded(M.restore))
        M.connections[3] = Run.Heartbeat:Connect(guarded(M.step))
    end
    function M.pending() return pending ~= nil end
    life.onCleanup(M.stop)
    M.setEnabled(cfg.walkfling)
    return M
end)()
S.walkfling = Walkfling


local Jump = (function()
    local M: any = {queued = false, airborne = false, boosting = false, nextAt = 0, maxHeight = 60}
    local replay = module(client, "InstantReplay")
    local state = game.ReplicatedStorage:FindFirstChild("ProState")
    function M.fire()
        if not life.alive() or S.busy or os.clock() < M.nextAt or M.queued or (M.airborne and not cfg.infiniteJump) or replay.playing()
            or (state and state:GetAttribute("Phase") ~= "Play") then return false end
        local character = player.Character
        local r = character and character:FindFirstChild("Root")
        local manager = character and character:FindFirstChildOfClass("ControllerManager")
        local sensor = manager and manager.GroundSensor
        if not r or not r:IsA("BasePart") or not manager or not sensor or (not sensor.SensedPart and not cfg.infiniteJump)
            or character:GetAttribute("BodyState") ~= "Animated" or not isnetworkowner(r) then return false end
        if character:GetAttribute("Role") == "Goalkeeper" and not cfg.infiniteJump and (tonumber(cfg.jumpHeight) or 18) <= 6 and Mannequin.keeperJump then
            Mannequin.keeperJump()
            M.nextAt = os.clock() + 0.5
            return true
        end
        Walkfling.restore()
        M.queued, M.character = true, character
        M.nextAt = os.clock() + (if cfg.infiniteJump then 0.12 else 0.45)
        return true
    end
    life.connect(Run.PreSimulation, function()
        if M.airborne and player.Character == M.character then
            local r = M.character:FindFirstChild("Root")
            if r and r:IsA("BasePart") and M.character:GetAttribute("BodyState") == "Animated" then
                local current = r.AssemblyLinearVelocity
                if M.boosting then
                    local remaining = M.targetY - r.Position.Y
                    if remaining <= 0.15 or os.clock() > M.boostUntil then M.boosting = false
                    else current = Vector3.new(current.X, math.min(M.riseSpeed, math.sqrt(2 * workspace.Gravity * remaining)), current.Z) end
                end
                local flat = current * Vector3.new(1, 0, 1)
                local maximum = Tuning.Launch.Speed * math.sqrt(math.max(0.05, 0.9 - (math.max(current.Y, 0) / Tuning.Launch.Rise) ^ 2))
                if flat.Magnitude > maximum then flat = flat.Unit * maximum end
                if M.boosting or flat ~= current * Vector3.new(1, 0, 1) then r.AssemblyLinearVelocity = flat + Vector3.new(0, current.Y, 0) end
                Walkfling.pauseUntil = os.clock() + 0.08
            else M.boosting = false end
        end
        if not M.queued then return end
        M.queued = false
        local character = player.Character
        local r = character and character:FindFirstChild("Root")
        local manager = character and character:FindFirstChildOfClass("ControllerManager")
        local air = manager and manager:FindFirstChild("AirController")
        local sensor = manager and manager.GroundSensor
        if character ~= M.character or not r or not r:IsA("BasePart") or not manager or not air
            or not sensor or (not sensor.SensedPart and not cfg.infiniteJump) or character:GetAttribute("BodyState") ~= "Animated" then return end
        Walkfling.restore()
        local height = math.clamp(tonumber(cfg.jumpHeight) or 18, 1, M.maxHeight)
        M.riseSpeed = Tuning.Launch.Rise * 0.88
        local speed = math.min(math.sqrt(2 * workspace.Gravity * height), M.riseSpeed)
        local horizontal = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
        local maximum = Tuning.Launch.Speed * math.sqrt(math.max(0.05, 0.9 - (speed / Tuning.Launch.Rise) ^ 2))
        if horizontal.Magnitude > maximum then horizontal = horizontal.Unit * maximum end
        M.targetY = r.Position.Y + height
        M.boosting = height > speed * speed / (2 * workspace.Gravity) + 0.1
        M.boostUntil = os.clock() + height / M.riseSpeed + 1.5
        M.deadline = M.boostUntil + math.sqrt(2 * height / workspace.Gravity) + 1
        manager.ActiveController = air
        r.AssemblyLinearVelocity = horizontal + Vector3.new(0, speed, 0)
        M.airborne, M.takeoffAt = true, os.clock()
        Walkfling.pauseUntil = os.clock() + 0.1
    end)
    life.connect(Run.Heartbeat, function()
        if not M.airborne then return end
        local character = player.Character
        local manager = character and character:FindFirstChildOfClass("ControllerManager")
        if character ~= M.character or os.clock() > M.deadline
            or (os.clock() - M.takeoffAt > 0.15 and manager and manager.GroundSensor and manager.GroundSensor.SensedPart
                and manager.ActiveController == manager:FindFirstChild("GroundController")) then M.airborne, M.boosting = false, false end
    end)
    life.onCleanup(function() M.queued, M.airborne, M.boosting = false, false, false end)
    return M
end)()
S.jump = Jump


local Hitboxes = (function()
    local M: any = {entries = {}, ballRequests = 0, ballAccepted = 0}
    local replay = module(client, "InstantReplay")
    local folder = Instance.new("Folder")
    folder.Name = "PoopHitboxVisuals"
    folder.Parent = workspace
    local function release(part, entry)
        if entry.bounds then entry.bounds:Destroy() end
        if entry.visual then entry.visual:Destroy() end
        M.entries[part] = nil
    end
    function M.clearPlayers()
        for part, entry in pairs(M.entries) do release(part, entry) end
    end
    function M.ballContact()
        if not cfg.ballExpander or cfg.freezeBall or cfg.hotPotato or cfg.ballOrbit or cfg.ballGlue or replay.playing() then return end
        if M.ballRecord and M.ballRecord.accepted and not M.ballRecord.counted then
            M.ballRecord.counted = true
            M.ballAccepted += 1
        end
        local ball, position = Ball.getBall(), Ball.getPosition()
        local character, r = player.Character, root()
        if not ball or not position or not character or not r then return end
        local ownId = character:GetAttribute("DribbleId")
        if ball:GetAttribute("Possessor") ~= 0 or ball:GetAttribute("ReleasedBy") == ownId then return end
        local radius = math.clamp(tonumber(cfg.ballHitboxRadius) or 4, 1, Magnet.range)
        local gap = math.huge
        for _, name in ipairs({"LeftFoot", "RightFoot", "LeftShin", "RightShin"}) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                gap = math.min(gap, (Contacts.closestOnBox(part.CFrame, part.Size, position) - position).Magnitude)
            end
        end
        if gap > radius then return end
        if Magnet.pull(true) then
            M.ballRequests += 1
            M.ballRecord = Magnet.last
        end
    end
    function M.apply()
        if not life.alive() then return end
        local showingReplay = replay.playing()
        local seen = {}
        if cfg.playerHitboxes and not showingReplay then
            local width = math.clamp(tonumber(cfg.playerHitboxSize) or 12, 4, 50)
            local size = Vector3.one * width
            for _, other in ipairs(Players:GetPlayers()) do
                local character = other ~= player and other.Character
                local part = character and character:FindFirstChild("Root")
                if part and part:IsA("BasePart") then
                    seen[part] = true
                    local entry = M.entries[part]
                    if not entry then
                        local bounds = Instance.new("Part")
                        bounds.Name = "PlayerBounds"
                        bounds.Anchored = true
                        bounds.CanCollide, bounds.CanTouch, bounds.CanQuery = false, false, false
                        bounds.Transparency = 1
                        bounds.CFrame = part.CFrame
                        bounds.Parent = folder
                        local visual = Instance.new("SelectionBox")
                        visual.Name = "PlayerBox"
                        visual.Adornee = bounds
                        visual.Color3 = Color3.fromRGB(255, 112, 88)
                        visual.SurfaceColor3 = visual.Color3
                        visual.SurfaceTransparency = 0.94
                        visual.LineThickness = 0.04
                        visual.Parent = folder
                        entry = {bounds = bounds, visual = visual}
                        M.entries[part] = entry
                    end
                    if entry.bounds.Size ~= size then entry.bounds.Size = size end
                    entry.bounds.CFrame = part.CFrame
                    entry.visual.Visible = cfg.hitboxVisuals
                end
            end
        end
        for part, entry in pairs(M.entries) do if not seen[part] then release(part, entry) end end
    end
    life.connect(Run.PreRender, function()
        for part, entry in pairs(M.entries) do
            if part.Parent and entry.bounds.Parent then entry.bounds.CFrame = part.CFrame end
        end
    end)
    local geometryAt, contactAt = 0, 0
    life.connect(Run.Heartbeat, function(dt)
        geometryAt += dt
        contactAt += dt
        if geometryAt >= 0.1 then
            geometryAt = 0
            local ok, err = pcall(M.apply)
            if not ok then M.error = tostring(err); M.clearPlayers() end
        end
        if contactAt >= 0.05 then
            contactAt = 0
            local ok, err = pcall(M.ballContact)
            if not ok then M.ballError = tostring(err) end
        end
    end)
    life.onCleanup(function() M.clearPlayers(); folder:Destroy(); M.ballVisual = nil end)
    M.apply()
    return M
end)()
S.hitboxes = Hitboxes


local Orbit = (function()
    local M: any = {sent = 0, accepted = 0, refused = 0, nextAt = 0, maxGrab = 32, interval = 0.075, inflight = {}, pipelined = 0}
    local sim = module(gameModules, "BallSim")
    local replay = module(client, "InstantReplay")
    local remote = Net:RemoteEvent("DribbleKnock")
    local releaseRemote = Net:RemoteEvent("DribbleRelease")
    local pro = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    function M.grabRange()
        return Grasp.range()
    end
    function M.radius()
        local speed = tonumber(cfg.orbitSpeed) or 32
        local maximum = math.clamp(M.grabRange() - 0.4, 2.5, 7)
        local minimum = math.min(maximum, 6, math.max(2.5, speed / 15))
        return math.clamp(tonumber(cfg.orbitRadius) or 4, minimum, maximum)
    end
    function M.velocity(position, center, centerVelocity, radius)
        local delta = (position - center) * Vector3.new(1, 0, 1)
        local distance = delta.Magnitude
        local radial = if distance > 0.01 then delta / distance else Vector3.xAxis
        local tangent = Vector3.new(-radial.Z, 0, radial.X)
        local speed = math.clamp(tonumber(cfg.orbitSpeed) or 32, 4, 90)
        local relative
        if math.abs(radius - distance) > 1.5 then
            local radialSpeed = math.clamp((radius - distance) * 5, -24, 24)
            relative = radial * radialSpeed + tangent * 5
            if relative.Magnitude > 24 then relative = relative.Unit * 24 end
        else
            local horizon = math.clamp(M.cadence or 0.09, 0.05, 0.18)
            local phase = speed / radius * horizon
            local target = radial * (radius * math.cos(phase)) + tangent * (radius * math.sin(phase))
            relative = (target - delta) / horizon
        end
        local follow = math.clamp(1 - math.abs(radius - distance) / 3, 0, 1)
        local wanted = centerVelocity * Vector3.new(1, 0, 1) * follow + relative
        if wanted.Magnitude > 90 then wanted = wanted.Unit * 90 end
        return wanted
    end
    function M.resetPrediction()
        table.clear(M.inflight)
        M.prediction, M.predictedPid, M.pipelineActive = nil, nil, false
    end
    local function matches(record, event)
        return record and event and event.pid > record.pid and event.by == record.ownId
            and math.abs(event.t - record.clock) < 0.12 and (event.pos - record.position).Magnitude < 0.2
            and (event.vel - record.velocity).Magnitude < 0.2
    end
    local function forecast(record, clock, ball)
        local elapsed = math.clamp(clock - record.clock, 0, 0.3)
        local flat = record.velocity * Vector3.new(1, 0, 1)
        local speed = flat.Magnitude
        local resistance = math.max(0, ball:GetAttribute("RollingResistance") or 4.7)
        local direction = if speed > 0.01 then flat.Unit else Vector3.zero
        local distance = math.max(0, speed * elapsed - 0.5 * resistance * elapsed * elapsed)
        local position = record.position + direction * distance
        local floor = Ball.groundBallY(position)
        local y = math.max(floor, record.position.Y - 0.5 * (ball:GetAttribute("Gravity") or 46) * elapsed * elapsed)
        return Vector3.new(position.X, y, position.Z), direction * math.max(0, speed - resistance * elapsed)
    end
    function M.setEnabled(enabled)
        M.pending, M.tracked = nil, nil
        M.resetPrediction()
        M.nextAt = 0
        if enabled then
            if S.controls.freezeBall then S.controls.freezeBall:Set(false, true) end
            if S.controls.hotPotato then S.controls.hotPotato:Set(false, true) end
            if S.controls.ballGlue then S.controls.ballGlue:Set(false, true) end
        end
    end
    life.connect(Net:RemoteEvent("DribbleKnockRefused").OnClientEvent, function(pid)
        local rejected = M.inflight[pid] or (M.pending and M.pending.pid == pid and M.pending)
        if rejected then
            M.refused += 1
            M.lastRefused = {pid = pid, at = os.clock(), distance = rejected.distance}
            for key in pairs(M.inflight) do if key >= pid then M.inflight[key] = nil end end
            if M.pending and M.pending.pid >= pid then M.pending = nil end
            M.prediction, M.predictedPid = nil, nil
            M.nextAt = os.clock() + (if (cfg.orbitSpeed or 0) > 40 then 0.055 else 0.12)
        end
    end)
    function M.step()
        if not cfg.ballOrbit and not M.pending then return end
        local at = os.clock()
        local ball = Ball.getBall()
        local event = ball and sim.decode(ball:GetAttribute("BallSim"))
        local pending = M.pending
        if not matches(pending, event) then
            pending = nil
            for _, record in pairs(M.inflight) do if matches(record, event) then pending = record; break end end
        end
        if pending and event then
            M.accepted += 1
            M.lastAccepted = {pid = event.pid, at = at, position = event.pos, velocity = event.vel,
                distance = pending.distance, center = pending.center, centerSpeed = pending.centerSpeed,
                positionError = (event.pos - pending.position).Magnitude,
                velocityError = (event.vel - pending.velocity).Magnitude}
            for key in pairs(M.inflight) do if key < event.pid then M.inflight[key] = nil end end
            if M.pending and M.pending.pid < event.pid then M.pending = nil end
        end
        for key, record in pairs(M.inflight) do if at - record.sentAt > 0.5 then M.inflight[key] = nil end end
        if not cfg.ballOrbit or not life.alive() or at < M.nextAt or at < (M.suspendUntil or 0) or replay.playing() or S.busy
            or Input:GetFocusedTextBox() or Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or GuiService.MenuIsOpen or (pro and pro:GetAttribute("Phase") ~= "Play") then return end
        local character, r = player.Character, root()
        local clock = now()
        local position, velocity = Ball.freeSample(clock)
        if not position or position == Vector3.zero then position, velocity = Ball.freeState(); clock = Ball.drawnTime() end
        if not ball or not character or not r or not position or not velocity or r.Anchored
            or character:GetAttribute("BodyState") ~= "Animated" then
            M.tracked = nil
            M.resetPrediction()
            return
        end
        local ownId = character:GetAttribute("DribbleId")
        if type(ownId) ~= "number" or ownId <= 0 then return end
        if S.lastShot and now() - S.lastShot.at < 0.9 then return end
        local pass = S.passingEngine and S.passingEngine.active
        if pass and now() - pass.at < 0.9 then return end
        local pid = ball:GetAttribute("PossessionId")
        if type(pid) ~= "number" or pid <= 0 then return end
        local possessor = ball:GetAttribute("Possessor")
        if possessor ~= 0 then
            if possessor == ownId then
                local segment = Path.decode(ball:GetAttribute("DribblePath"))
                if segment and segment.pid == pid then
                    local held = Path.sample(segment, clock, Path.params(ball))
                    local distance = ((held - r.Position) * Vector3.new(1, 0, 1)).Magnitude
                    if distance < 7.5 then
                        local offset = (held - r.Position) * Vector3.new(1, 0, 1)
                        local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.xAxis
                        local wanted = Vector3.new(-direction.Z, 0, direction.X) * 12
                        M.pending = {pid = pid, ownId = ownId, clock = clock, position = held, velocity = wanted,
                            sentAt = at, distance = distance, center = r.Position, centerSpeed = r.AssemblyLinearVelocity.Magnitude}
                        Dribble.holdFree(clock + 0.4)
                        releaseRemote:FireServer(pid, "down", held, wanted, clock)
                        M.tracked, M.nextAt = ball, at + 0.2
                        M.sent += 1
                    end
                end
            end
            M.resetPrediction()
            return
        end
        local flight = Flight.decode(ball:GetAttribute("KickFlight"))
        if flight and flight.by == ownId and flight.pid == pid then return end
        if Grasp.pending then return end
        if ((position - r.Position) * Vector3.new(1, 0, 1)).Magnitude > 7.8
            and (M.tracked ~= ball or not M.lastAccepted or at - M.lastAccepted.at > 0.6) then
            Grasp.request()
            return
        end
        if event and event.by ~= ownId and M.lastAccepted and event.pid > M.lastAccepted.pid then M.resetPrediction() end
        local pipeline = M.tracked == ball and M.lastAccepted ~= nil
            and at - M.lastAccepted.at < 0.6
        if pipeline and M.prediction and M.predictedPid and M.predictedPid >= pid and M.predictedPid - pid <= 3
            and clock - M.prediction.clock < 0.25 then
            position, velocity = forecast(M.prediction, clock, ball)
            pid = M.predictedPid
        end
        local distance = ((position - r.Position) * Vector3.new(1, 0, 1)).Magnitude
        if distance > M.grabRange() or math.abs(position.Y - Ball.groundBallY(position)) > 2.4 then
            M.tracked = nil
            return
        end
        pipeline = pipeline and distance < M.radius() + 2
        if pipeline then
            local count = 0
            for _ in pairs(M.inflight) do count += 1 end
            if count >= 3 then return end
            if not M.pipelineActive then M.cadence = 0.06 end
        elseif M.pending and M.pending.pid == pid and at - M.pending.sentAt < 0.2 then return end
        M.pipelineActive = pipeline
        local offset = (position - r.Position) * Vector3.new(1, 0, 1)
        local wantedRadius = M.radius()
        local correction = 0
        if M.tracked == ball and M.lastAccepted and at - M.lastAccepted.at < 0.5 and offset.Magnitude > 0.1
            and math.abs(offset.Magnitude - wantedRadius) < 1.25 then
            local projected = r.Position + offset.Unit * wantedRadius
            projected = Vector3.new(projected.X, position.Y, projected.Z)
            correction = (projected - position).Magnitude
            position = projected
        end
        local wanted = M.velocity(position, r.Position, r.AssemblyLinearVelocity, wantedRadius)
        Dribble.holdFree(now() + 0.25)
        local record = {pid = pid, ownId = ownId, clock = clock, position = position,
            velocity = wanted, sentAt = at, distance = distance, center = r.Position, centerSpeed = r.AssemblyLinearVelocity.Magnitude, correction = correction}
        M.pending, M.tracked = record, ball
        if pipeline then
            M.inflight[pid] = record
            M.prediction, M.predictedPid = record, pid + 1
            M.pipelined += 1
        end
        if M.lastSentAt and at - M.lastSentAt < 0.3 then
            M.cadence = (M.cadence or M.interval) * 0.7 + (at - M.lastSentAt) * 0.3
        end
        M.lastSentAt = at
        remote:FireServer(pid, position, wanted, record.clock)
        M.sent += 1
        M.nextAt = at + (if pipeline then 0.055 else M.interval)
    end
    life.connect(Run.Heartbeat, function()
        local ok, err = pcall(M.step)
        if not ok then M.error = tostring(err); M.pending, M.tracked = nil, nil end
    end)
    life.onCleanup(function() M.pending, M.tracked = nil, nil; M.resetPrediction() end)
    return M
end)()
S.orbit = Orbit


do
    local model = Instance.new("Model")
    model.Name = "BallControlRange"
    model.WorldPivot = CFrame.identity
    model.Parent = guides
    local reach, path, units = {}, {}, {}
    local count = 40
    for i = 1, count do
        local a, b = (i - 1) * math.pi * 2 / count, i * math.pi * 2 / count
        units[i] = {Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(math.cos(b), 0, math.sin(b))}
        reach[i] = guidePart("GrabReach", Vector3.one * 0.05, Color3.fromRGB(81, 211, 255))
        path[i] = guidePart("OrbitPath", Vector3.one * 0.05, Color3.fromRGB(255, 197, 97))
        reach[i].Parent, path[i].Parent = model, model
    end
    local lastGrab, lastRadius, shown, pathShown
    local floorAt, ground = 0, 0
    local function visibility(visible, orbitVisible)
        if shown ~= visible then
            shown = visible
            for _, part in ipairs(reach) do part.Transparency = if visible then 0.18 else 1 end
        end
        if pathShown ~= orbitVisible then
            pathShown = orbitVisible
            for _, part in ipairs(path) do part.Transparency = if orbitVisible then 0.3 else 1 end
        end
    end
    function Orbit.applyVisual()
        local pivot = model:GetPivot()
        local grab, radius = math.min(Orbit.displayRange or 8, Grasp.range()), Orbit.radius()
        if grab == lastGrab and radius == lastRadius then return end
        for i, pair in ipairs(units) do
            for _, row in ipairs({{reach[i], grab, 0.07}, {path[i], radius, 0.055}}) do
                local a, b = pair[1] * row[2], pair[2] * row[2]
                row[1].Size = Vector3.new(row[3], 0.045, (b - a).Magnitude + 0.015)
                row[1].CFrame = pivot * CFrame.lookAt((a + b) * 0.5, b)
            end
        end
        lastGrab, lastRadius = grab, radius
        Orbit.visualRadius, Orbit.visualGrabRange = radius, grab
    end
    life.connect(Run.PreRender, function()
        local character, r = player.Character, root()
        local visible = cfg.ballHitboxVisual and character ~= nil and r ~= nil and r.Position.Y < 20
            and (character:GetAttribute("Team") == "Blue" or character:GetAttribute("Team") == "Red")
        local orbitVisible = visible and cfg.ballOrbit
        visibility(visible, orbitVisible)
        if not visible then return end
        local at = os.clock()
        if at >= floorAt then
            ground = Ball.groundBallY(r.Position) - 0.84 + 0.065
            Orbit.displayRange = math.floor(Grasp.availableRange() * 2) / 2
            floorAt = at + 0.1
        end
        Orbit.applyVisual()
        model:PivotTo(CFrame.new(r.Position.X, ground, r.Position.Z))
        Orbit.visualCenter = Vector3.new(r.Position.X, ground, r.Position.Z)
        Orbit.visualFrames = (Orbit.visualFrames or 0) + 1
    end)
    life.onCleanup(function() model:Destroy() end)
    Orbit.visualModel = model
    Orbit.applyVisual()
end


local AutoDribble = (function()
    local M: any = {active = false, plans = 0}
    local originalShape = Mannequin.shapeMove
    local replay = module(client, "InstantReplay")
    local pro = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    function M.allowed(context)
        return context.enabled and context.forward and context.owned and context.animated
            and context.playing and not context.replay and not context.busy and not context.typing and not context.menu
    end
    function M.choose(position, target, obstacles, previous)
        local toward = (target - position) * Vector3.new(1, 0, 1)
        if toward.Magnitude < 2 then return Vector3.zero end
        local forward = toward.Unit
        local best, bestScore = forward, -math.huge
        for _, angle in ipairs({0, -22, 22, -42, 42, -65, 65}) do
            local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(forward)
            local score = direction:Dot(forward) * 6 - math.abs(angle) * 0.008
            if previous then score += direction:Dot(previous) * 0.6 end
            for _, obstacle in ipairs(obstacles) do
                local predicted = obstacle.position + obstacle.velocity * 0.22
                local offset = (predicted - position) * Vector3.new(1, 0, 1)
                local along = math.clamp(offset:Dot(direction), 0, 11)
                local clearance = (offset - direction * along).Magnitude
                if along > 0 and offset.Magnitude < 16 then
                    score -= math.exp(-clearance * clearance / 10) * 26 * (1 - along / 18)
                end
            end
            if score > bestScore then best, bestScore = direction, score end
        end
        return best
    end
    function M.reset()
        M.active, M.heading, M.desired = false, nil, nil
        M.nextPlan = 0
    end
    function M.shape(input)
        local base = if originalShape then originalShape(input) else input
        if not cfg.autoDribble or not Input:IsKeyDown(Enum.KeyCode.W) then M.reset(); return base end
        local c, r = player.Character, root()
        local ball = Ball.getBall()
        local ownId = c and c:GetAttribute("DribbleId")
        local context = {enabled = cfg.autoDribble == true, forward = Input:IsKeyDown(Enum.KeyCode.W),
            owned = type(ownId) == "number" and ownId > 0 and ball ~= nil and ball:GetAttribute("Possessor") == ownId,
            animated = c ~= nil and c:GetAttribute("BodyState") == "Animated", replay = replay.playing(),
            playing = not pro or pro:GetAttribute("Phase") == "Play", busy = S.busy,
            typing = Input:GetFocusedTextBox() ~= nil, menu = GuiService.MenuIsOpen}
        if not M.allowed(context) or not r or not workspace.CurrentCamera then M.reset(); return base end
        local at = os.clock()
        if at >= (M.nextPlan or 0) or not M.desired then
            local goal = mouth()
            if not goal then M.reset(); return base end
            local obstacles = {}
            for _, other in ipairs(Players:GetPlayers()) do
                local model = other ~= player and other.Character
                local otherRoot = model and model:FindFirstChild("Root")
                if otherRoot and otherRoot:IsA("BasePart") and model:GetAttribute("Team") ~= c:GetAttribute("Team")
                    and (otherRoot.Position - r.Position).Magnitude < 20 then
                    obstacles[#obstacles + 1] = {position = otherRoot.Position, velocity = otherRoot.AssemblyLinearVelocity}
                end
            end
            local target = Vector3.new(goal.x + goal.out * 2, r.Position.Y, goal.z)
            M.desired = M.choose(r.Position, target, obstacles, M.heading)
            M.target = target
            M.nextPlan = at + 0.08
            M.plans += 1
        end
        local elapsed = math.clamp(at - (M.lastAt or at), 0, 0.1)
        M.lastAt = at
        local desired = M.desired
        if desired.Magnitude < 0.01 then M.active = true; return Vector2.zero end
        M.heading = if M.heading then M.heading:Lerp(desired, 1 - math.exp(-elapsed * 14)) else desired
        if M.heading.Magnitude < 0.01 then return base end
        local camera = workspace.CurrentCamera
        local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
        look = if look.Magnitude > 0.001 then look.Unit else Vector3.new(0, 0, -1)
        right = if right.Magnitude > 0.001 then right.Unit else Vector3.xAxis
        M.active = true
        local direction = M.heading.Unit
        local wish = Vector2.new(direction:Dot(right), direction:Dot(look))
        if wish.Magnitude > 1 then wish = wish.Unit end
        return wish * math.min(1, input.Magnitude)
    end
    life.override(Mannequin, "shapeMove", M.shape)
    life.onCleanup(M.reset)
    return M
end)()
S.autoDribble = AutoDribble


local Glue = (function()
    local M: any = {enabled = false, sent = 0, accepted = 0, refused = 0, nextAt = 0, inflight = {}}
    local rules = module(gameModules:WaitForChild("Dribble"), "Rules")
    local replay = module(client, "InstantReplay")
    local remote = Net:RemoteEvent("DribbleTouch")
    local pro = game.ReplicatedStorage:FindFirstChild("ProState")
    local function reset()
        M.planned, M.pid, M.ball = nil, nil, nil
        table.clear(M.inflight)
    end
    local function syncPlanner(segment)
        local state = Dribble.kickState()
        local ball, character = Ball.getBall(), player.Character
        if state and state.pid == segment.pid and ball and character
            and ball:GetAttribute("PossessionId") == segment.pid and ball:GetAttribute("Possessor") == character:GetAttribute("DribbleId") then
            state.planner.seg = segment
            local r = root()
            local canonical = Path.decode(ball:GetAttribute("DribblePath"))
            local position = canonical and Path.sample(canonical, now(), Path.params(ball))
            if M.enabled and r and position and M.lastAccepted and M.lastAccepted.pid == segment.pid and os.clock() - M.lastAccepted.at < 0.35
                and ((position - r.Position) * Vector3.new(1, 0, 1)).Magnitude < 3 then
                local display = table.clone(segment)
                local height = math.max(Ball.groundBallY(r.Position), r.Position.Y - (character:GetAttribute("RootHeight") or 4.697) + rules.BALL_RADIUS)
                local from = r.Position + r.CFrame.LookVector * 1.3
                from = Vector3.new(from.X, height, from.Z)
                local velocity = r.AssemblyLinearVelocity
                display.t0, display.t1 = now(), now() + 0.08
                display.p0, display.p1 = from, from + velocity * 0.08
                display.v0, display.v1 = velocity, Vector3.zero
                Ball.setLocal(display)
            else Ball.setLocal(segment) end
        end
    end
    function M.setEnabled(enabled)
        local lastSequence = M.planned and M.planned.seq or 0
        M.enabled = enabled == true
        reset()
        if M.enabled then
            for _, key in ipairs({"ballOrbit", "freezeBall", "hotPotato"}) do
                if S.controls[key] then S.controls[key]:Set(false, true) end
            end
        else
            Dribble.holdTouches(now())
            local ball, character, r = Ball.getBall(), player.Character, root()
            local segment = ball and Path.decode(ball:GetAttribute("DribblePath"))
            if not S.busy and ball and character and r and segment and ball:GetAttribute("Possessor") == character:GetAttribute("DribbleId") then
                local clock = now()
                local from = Path.sample(segment, clock, Path.params(ball))
                from = Vector3.new(from.X, Ball.groundBallY(r.Position), from.Z)
                local meta = table.clone(segment)
                meta.seq = math.max(segment.seq, lastSequence) + 1
                local normal = Path.carry(meta, clock, from, Vector3.zero, clock + 0.1, r.Position, Vector3.zero)
                remote:FireServer(Path.encode(normal))
                syncPlanner(normal)
            end
        end
    end
    life.connect(Net:RemoteEvent("DribbleReject").OnClientEvent, function(pid)
        if not M.enabled or not M.pid or (pid ~= M.pid and pid ~= M.pid - 1) then return end
        M.refused += 1
        local ball = M.ball
        reset()
        local segment = ball and Path.decode(ball:GetAttribute("DribblePath"))
        if segment then syncPlanner(segment) end
        M.nextAt = os.clock() + 0.12
    end)
    function M.step()
        if not M.enabled or not cfg.ballGlue then return end
        local at, clock = os.clock(), now()
        local character, r, ball = player.Character, root(), Ball.getBall()
        if not character or not r or not ball then reset(); return end
        local ownId, pid = character:GetAttribute("DribbleId"), ball:GetAttribute("PossessionId")
        if type(ownId) ~= "number" or ownId <= 0 or type(pid) ~= "number" then return end
        local possessor = ball:GetAttribute("Possessor")
        local canonical = Path.decode(ball:GetAttribute("DribblePath"))
        if M.pid and (M.pid ~= pid or M.ball ~= ball or possessor ~= ownId) then reset() end
        if canonical and canonical.pid == pid then
            local record = M.inflight[canonical.seq]
            if record and (canonical.p0 - record.segment.p0).Magnitude < 0.02 and (canonical.p1 - record.segment.p1).Magnitude < 0.02 then
                M.accepted += 1
                M.lastAccepted = {at = at, pid = pid, seq = canonical.seq, position = canonical.p0,
                    target = canonical.p1, rootPosition = record.rootPosition, height = record.height,
                    error = (canonical.p0 - record.segment.p0).Magnitude}
                for seq in pairs(M.inflight) do if seq <= canonical.seq then M.inflight[seq] = nil end end
            end
        end
        if at < M.nextAt or at < (M.suspendUntil or 0) or S.busy or replay.playing()
            or Input:GetFocusedTextBox() or Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or GuiService.MenuIsOpen or (pro and pro:GetAttribute("Phase") ~= "Play")
            or character:GetAttribute("BodyState") ~= "Animated" or r.Anchored then return end
        if S.lastShot and clock - S.lastShot.at < 0.9 then return end
        local pass = S.passingEngine and S.passingEngine.active
        if pass and clock - pass.at < 0.9 then return end
        if possessor ~= ownId then
            if possessor == 0 then
                local flight = Flight.decode(ball:GetAttribute("KickFlight"))
                if flight and flight.pid == pid and flight.by == ownId then return end
                if ball:GetAttribute("ReleasedBy") == ownId and clock - (ball:GetAttribute("ReleasedAt") or 0) < 0.9 then return end
                Grasp.request(true)
            elseif M.lastOwnedAt and at - M.lastOwnedAt < 2 and at >= (M.nextPoke or 0) then
                S.pokeCarrier(true)
                M.nextPoke = at + 0.25
            end
            return
        end
        if not canonical or canonical.pid ~= pid then return end
        M.lastOwnedAt = at
        local base = canonical
        if M.planned and M.planned.pid == pid and clock - M.planned.t0 < 0.35 and M.planned.seq >= canonical.seq then base = M.planned end
        local outstanding = 0
        for seq, record in pairs(M.inflight) do
            if at - record.sentAt > 0.45 then M.inflight[seq] = nil else outstanding += 1 end
        end
        if outstanding >= 4 then return end
        local from = Path.sample(base, clock, Path.params(ball))
        local height = r.Position.Y - (tonumber(character:GetAttribute("RootHeight")) or 4.697) + rules.BALL_RADIUS
        height = math.max(Ball.groundBallY(r.Position), height)
        from = Vector3.new(from.X, height, from.Z)
        local velocity = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
        if velocity.Magnitude > 40 then velocity = velocity.Unit * 40 end
        local target = r.Position + r.CFrame.LookVector * 1.3 + velocity * 0.08
        local meta = {pid = pid, seq = math.max(base.seq, canonical.seq) + 1, nleg = 0, leg = 1, part = "Sole", kind = "Glue",
            stride = 0, root = r.Position * Vector3.new(1, 0, 1), nt = clock}
        local segment = Path.carry(meta, clock, from, velocity, clock + 0.1, target, velocity)
        if not rules.checkTouch(base, segment, clock, r.Position, r.AssemblyLinearVelocity.Magnitude, Path.params(ball)) then
            reset(); M.nextAt = at + 0.05; return
        end
        M.pid, M.ball, M.planned = pid, ball, segment
        M.inflight[segment.seq] = {segment = segment, sentAt = at, rootPosition = r.Position, height = height}
        Dribble.holdTouches(clock + 0.22)
        remote:FireServer(Path.encode(segment))
        syncPlanner(segment)
        M.sent += 1
        M.nextAt = at + 1 / 30
    end
    life.connect(Run.Heartbeat, function()
        local ok, err = pcall(M.step)
        if not ok then M.error = tostring(err); reset() end
    end)
    life.onCleanup(function() M.setEnabled(false) end)
    return M
end)()
S.ballGlue = Glue


local HotPotato = (function()
    local M: any = {sent = 0, accepted = 0, refused = 0, nextAt = 0}
    local sim = module(gameModules, "BallSim")
    local replay = module(client, "InstantReplay")
    local remote = Net:RemoteEvent("DribbleKnock")
    local pro = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    life.connect(Net:RemoteEvent("DribbleKnockRefused").OnClientEvent, function(pid)
        if M.pending and M.pending.pid == pid then
            M.refused += 1
            M.pending = nil
            M.nextAt = os.clock() + 0.35
        end
    end)
    function M.setEnabled(enabled)
        M.pending = nil
        M.nextAt = 0
        if enabled then
            if S.controls.freezeBall then S.controls.freezeBall:Set(false, true) end
            if S.controls.ballOrbit then S.controls.ballOrbit:Set(false, true) end
            if S.controls.ballGlue then S.controls.ballGlue:Set(false, true) end
        end
    end
    function M.step()
        if (not cfg.hotPotato or cfg.ballOrbit) and not M.pending then return end
        local ball = Ball.getBall()
        local event = ball and sim.decode(ball:GetAttribute("BallSim"))
        local pending = M.pending
        local at = os.clock()
        if pending and event and event.pid > pending.pid and event.by == pending.ownId
            and math.abs(event.t - pending.clock) < 0.12 and (event.pos - pending.position).Magnitude < 0.2
            and (event.vel - pending.velocity).Magnitude < 0.2 then
            M.accepted += 1
            M.lastAccepted = {pid = event.pid, at = at, target = pending.target, velocity = event.vel,
                position = event.pos, positionError = (event.pos - pending.position).Magnitude,
                velocityError = (event.vel - pending.velocity).Magnitude}
            M.pending = nil
        end
        if not cfg.hotPotato or not life.alive() or at < M.nextAt or replay.playing()
            or (pro and pro:GetAttribute("Phase") ~= "Play") or S.busy or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
        local character, r = player.Character, root()
        local position, velocity = Ball.freeState()
        if not ball or not character or not r or not position or not velocity or r.Anchored
            or character:GetAttribute("BodyState") ~= "Animated" or ball:GetAttribute("Possessor") ~= 0 then return end
        local ownId = character:GetAttribute("DribbleId")
        if type(ownId) ~= "number" or ownId <= 0 or ball:GetAttribute("ReleasedBy") == ownId then return end
        local distance = ((position - r.Position) * Vector3.new(1, 0, 1)).Magnitude
        if distance <= 1 or distance > 7.5 or math.abs(position.Y - Ball.groundBallY(position)) > 2.4 then return end
        local closest, gap = nil, 35
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other ~= player and other.Character
            local otherRoot = model and model:FindFirstChild("Root")
            if otherRoot and otherRoot:IsA("BasePart") then
                local d = ((otherRoot.Position - position) * Vector3.new(1, 0, 1)).Magnitude
                if d < gap then closest, gap = otherRoot, d end
            end
        end
        if not closest then return end
        local delta = (position - closest.Position) * Vector3.new(1, 0, 1)
        if delta.Magnitude < 0.1 then delta = (position - r.Position) * Vector3.new(1, 0, 1) end
        if delta.Magnitude < 0.1 then return end
        local wanted = delta.Unit * 24
        if velocity:Dot(delta.Unit) > 20 then return end
        local pid = ball:GetAttribute("PossessionId")
        if type(pid) ~= "number" or pid <= 0 then return end
        if M.pending and M.pending.pid == pid and at - M.pending.sentAt < 0.3 then return end
        M.pending = {pid = pid, ownId = ownId, position = position, velocity = wanted,
            clock = Ball.drawnTime(), sentAt = at, target = closest.Parent and closest.Parent.Name}
        remote:FireServer(pid, position, wanted, M.pending.clock)
        M.sent += 1
        M.nextAt = at + 0.15
    end
    life.connect(Run.Heartbeat, function()
        local ok, err = pcall(M.step)
        if not ok then M.error = tostring(err); M.pending = nil end
    end)
    life.onCleanup(function() M.pending = nil end)
    return M
end)()
S.hotPotato = HotPotato


local Freeze = (function()
    local M: any = {enabled = false, sent = 0, accepted = 0, refused = 0, nextAt = 0}
    local replay = module(client, "InstantReplay")
    local sim = module(gameModules, "BallSim")
    local remote = Net:RemoteEvent("DribbleKnock")
    local state = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
    local interval = 0.075
    function M.setEnabled(enabled)
        M.enabled = enabled == true
        M.anchor, M.pending, M.ball = nil, nil, nil
        M.nextAt = 0
    end
    life.connect(Net:RemoteEvent("DribbleKnockRefused").OnClientEvent, function(pid)
        if M.pending and pid == M.pending.pid then
            M.refused += 1
            M.pending = nil
            M.anchor = nil
            M.nextAt = os.clock() + 0.25
        end
    end)
    function M.step()
        if not M.enabled or not life.alive() or cfg.hotPotato or cfg.ballOrbit or cfg.ballGlue then return end
        if replay.playing() or (state and state:GetAttribute("Phase") ~= "Play") then
            M.anchor, M.pending = nil, nil
            return
        end
        local ball = Ball.getBall()
        local character = player.Character
        local position, velocity = Ball.freeState()
        local at = os.clock()
        local event = ball and sim.decode(ball:GetAttribute("BallSim"))
        local pending = M.pending
        if pending and event and event.pid > pending.pid and event.by == pending.ownId
            and math.abs(event.t - pending.clock) < 0.12 and (event.pos - pending.position).Magnitude < 0.2
            and (event.vel - pending.velocity).Magnitude < 0.2 then
            M.accepted += 1
            M.lastAccepted = {pid = event.pid, position = event.pos, velocity = event.vel, at = at}
            M.pending = nil
        end
        if not ball or not character or not position or not velocity or ball:GetAttribute("Possessor") ~= 0 then
            M.anchor, M.pending = nil, nil
            return
        end
        local ownId = character:GetAttribute("DribbleId")
        if type(ownId) ~= "number" or ownId <= 0 then return end
        if at < M.nextAt then return end
        if M.pending and ball:GetAttribute("PossessionId") == M.pending.pid and at - M.pending.sentAt < 0.2 then return end
        if M.ball ~= ball then M.ball, M.anchor = ball, nil end
        if not M.anchor or (position - M.anchor).Magnitude > 2.5 then M.anchor = position end
        local floor = Ball.groundBallY(M.anchor)
        local lift = if M.anchor.Y > floor + 0.15 then math.max(0, ball:GetAttribute("Gravity") or 46) * interval * 0.5 else 0
        local wanted = Vector3.new(0, lift, 0)
        local record = {pid = ball:GetAttribute("PossessionId"), clock = Ball.drawnTime(), position = M.anchor,
            velocity = wanted, ownId = ownId, sentAt = at}
        if type(record.pid) ~= "number" or record.pid <= 0 then return end
        M.pending = record
        remote:FireServer(record.pid, record.position, record.velocity, record.clock)
        M.sent += 1
        M.nextAt = at + interval
    end
    life.connect(Run.Heartbeat, function()
        local ok, err = pcall(M.step)
        if not ok then M.error = tostring(err); M.setEnabled(false) end
    end)
    life.onCleanup(function() M.setEnabled(false) end)
    M.setEnabled(cfg.freezeBall)
    return M
end)()
S.freezeBall = Freeze


local PokeRecovery: any = {steps = 0, calls = 0, lateWindow = module(gameModules.Dribble, "Rules").Server.LateMax}
function PokeRecovery.releaseMatches(record, release)
    return record.contactAt ~= nil and finite(record.ownId) and record.ownId > 0 and finite(release.pid)
        and release.pid > record.pid and release.by == record.ownId and not release.freshShot
        and finite(release.at) and release.at >= record.at - PokeRecovery.lateWindow and release.at <= release.now + 0.1
        and release.now <= record.at + 1.5
end
function PokeRecovery.applyCushion(record)
    if PokeRecovery.restoreCushion then PokeRecovery.restoreCushion() end
    local rules = module(gameModules.Dribble, "Rules").Poke
    local restoreBoost = life.override(rules, "TackleBoost", {0.55, 0.55})
    local restoreSpread = life.override(rules, "TackleSpread", 0)
    local restored = false
    local restore
    restore = function()
        if restored then return end
        restored = true
        restoreSpread()
        restoreBoost()
        if PokeRecovery.restoreCushion == restore then PokeRecovery.restoreCushion = nil end
    end
    PokeRecovery.restoreCushion = restore
    record.cushionBoost, record.cushionUntil = 0.55, record.at + 0.35
    return restore
end
function PokeRecovery.cushion(record)
    local restore = PokeRecovery.applyCushion(record)
    task.spawn(function()
        while life.alive() and cfg.autoPoke and not S.busy and not ownState()
            and player.Character and player.Character:GetAttribute("DribbleId") == record.ownId
            and player.Character:GetAttribute("BodyState") == "Animated"
            and Ball.getBall() == record.ball and now() < record.cushionUntil do task.wait() end
        restore()
    end)
end
function PokeRecovery.allowed(record, context)
    return record and record.releaseConfirmed and record.recoveryUntil and context.at < record.recoveryUntil
        and context.enabled and not context.busy and not context.owned and not context.keeper
        and context.animated and context.sameBall and context.pid == record.recoveryPid and context.owner <= 0
        and context.releasedBy == record.ownId and context.ownId == record.ownId and not context.freshShot
        and (context.source == "free" or context.source == "released") and context.playing
        and context.distance <= 14 and context.height <= 12
end

do
    local original = Mannequin.shapeMove
    life.override(Mannequin, "shapeMove", function(input)
        PokeRecovery.calls += 1
        local function native() return if original then original(input) else input end
        local record = S.lastPoke
        if not record or not record.recoveryUntil or now() >= record.recoveryUntil then return native() end
        local ball, character, r = Ball.getBall(), player.Character, root()
        local position, velocity = Ball.freeState()
        if not ball or not r or not position then return native() end
        local delta = (position - r.Position) * Vector3.new(1, 0, 1)
        local state = game:GetService("ReplicatedStorage"):FindFirstChild("ProState")
        local flight = Flight.decode(ball:GetAttribute("KickFlight"))
        local context = {at = now(), releasedBy = ball:GetAttribute("ReleasedBy"), ownId = character:GetAttribute("DribbleId"),
            freshShot = flight ~= nil and flight.by == record.ownId and flight.t >= record.at - 0.05, enabled = cfg.autoPoke, busy = S.busy or Input:GetFocusedTextBox() ~= nil or GuiService.MenuIsOpen,
            owned = ownState() ~= nil, keeper = character:GetAttribute("Role") == "Goalkeeper", animated = character:GetAttribute("BodyState") == "Animated",
            sameBall = ball == record.ball, pid = ball:GetAttribute("PossessionId"), owner = ball:GetAttribute("Possessor") or 0,
            source = Ball.getSource(), playing = not state or state:GetAttribute("Phase") == "Play", distance = delta.Magnitude,
            height = position.Y - (Ball.groundBallY(position) - 0.84)}
        PokeRecovery.lastContext = context
        if not PokeRecovery.allowed(record, context) then return native() end
        local wished = Vector3.zero
        if delta.Magnitude > 2 then
            local lead = position + (velocity or Vector3.zero) * Vector3.new(1, 0, 1) * 0.08
            local toward = (lead - r.Position) * Vector3.new(1, 0, 1)
            if toward.Magnitude > 0.01 then wished = toward.Unit end
        end
        local camera = workspace.CurrentCamera
        if not camera then return native() end
        local forward = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
        if forward.Magnitude < 0.01 or right.Magnitude < 0.01 then return native() end
        forward, right = forward.Unit, right.Unit
        local determinant = right.X * forward.Z - right.Z * forward.X
        if math.abs(determinant) < 0.001 then return native() end
        local movement = Vector2.new((wished.X * forward.Z - wished.Z * forward.X) / determinant,
            (right.X * wished.Z - right.Z * wished.X) / determinant)
        PokeRecovery.steps += 1
        record.recoverySteps = (record.recoverySteps or 0) + 1
        return if original then original(movement) else movement
    end)
end
S.pokeRecovery = PokeRecovery

Reborn.NotificationsEnabled = cfg.notifications
local okWindow, window = pcall(Reborn.CreateWindow, Reborn, {Title = "Ragdoll Soccer", Size = Vector2.new(620, 410), Parent = player:WaitForChild("PlayerGui")})
if not okWindow then life.cleanup(); error(window) end
window.ToggleKey = "Right Shift"
S.window = window
S.ui = {library = "Reborn", revision = "main", tabs = {}}
life.connect(window.Gui.Destroying, function() life.cleanup() end)
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "PoopAimDot"
aimGui.IgnoreGuiInset = true
aimGui.ResetOnSpawn = false
aimGui.DisplayOrder = 150
local aimDot = Instance.new("Frame")
aimDot.Name = "Dot"
aimDot.AnchorPoint = Vector2.new(0.5, 0.5)
aimDot.Position = UDim2.fromScale(0.5, 0.5)
aimDot.Size = UDim2.fromOffset(6, 6)
aimDot.BorderSizePixel = 0
aimDot.BackgroundColor3 = Color3.fromRGB(245, 247, 246)
aimDot.Active = false
aimDot.Parent = aimGui
local roundDot = Instance.new("UICorner")
roundDot.CornerRadius = UDim.new(1, 0)
roundDot.Parent = aimDot
local dotOutline = Instance.new("UIStroke")
dotOutline.Color = Color3.fromRGB(12, 18, 16)
dotOutline.Thickness = 1.5
dotOutline.Parent = aimDot
aimGui.Parent = player.PlayerGui
life.onCleanup(function() aimGui:Destroy() end)
notifySink = function(title, message) Reborn:Notify({Title = title, Description = message, Duration = 3}) end
local function tab(name, icon)
    local result = window:Tab(name, icon)
    result:SetColumns(2)
    S.ui.tabs[#S.ui.tabs + 1] = result
    return result
end
local shootingTab = tab("Shooting", "crosshair")
local passingTab = tab("Passing", "users")
local keeperTab = tab("Keeper", "shield-check")
local playerTab = tab("Player", "user")
local visualsTab = tab("Visuals", "eye")
local function changed(key, value)
    cfg[key] = value
    if key == "notifications" then Reborn.NotificationsEnabled = value end
    save()
end
local function toggle(section, title, key, onChange)
    local control = section:Toggle({Text = title, Flag = key, Value = cfg[key], Callback = function(value)
        changed(key, value)
        if onChange then onChange(value) end
    end})
    S.controls[key] = control
    return control
end
local function dropdown(section, title, key, options)
    local control = section:Dropdown({Text = title, Flag = key, Options = options, Value = cfg[key], Callback = function(value) changed(key, value) end})
    S.controls[key] = control
    return control
end
local function slider(section, title, key, minimum, maximum, step, onChange)
    local control = section:Slider({Text = title, Flag = key, Min = minimum, Max = maximum, Step = step, Value = cfg[key], Callback = function(value)
        changed(key, value)
        if onChange then onChange(value) end
    end})
    S.controls[key] = control
    return control
end
local shooting = shootingTab:Section("Shot")
toggle(shooting, "Shooting (F)", "shooting")
dropdown(shooting, "Shot type", "style", styles)
slider(shooting, "Power (%)", "power", 50, 108, 1)
local aiming = shootingTab:Section("Aim")
dropdown(aiming, "Aim", "corner", corners)
slider(aiming, "Spin", "spin", 0, 70, 1)
toggle(aiming, "Reduce shot spread", "assist")

local passing = passingTab:Section("Pass")
dropdown(passing, "Pass type", "smartPassType", {"Automatic", "Ground", "Driven", "Chip", "Lofted", "Curved", "Roll", "Throw", "Punt"})
slider(passing, "Power (%)", "passStrength", 25, 150, 1)
local passTarget = passingTab:Section("Target")
slider(passTarget, "Target range", "passCone", 5, 25, 1)

local keeper = keeperTab:Section("Keeper")
toggle(keeper, "Auto GK (H)", "autoGK")
toggle(keeper, "Positioning", "gkPosition")
local keeperSession = keeperTab:Section("Session")
toggle(keeperSession, "Anti-AFK", "antiAFK")
toggle(keeperSession, "Rejoin as GK", "rejoinGK")

local movement = playerTab:Section("Movement")
toggle(movement, "Speed boost", "speedEnabled", applySpeed)
slider(movement, "Speed multiplier", "speed", 0.5, 4, 0.1, applySpeed)
toggle(movement, "Always sprint", "sprint")
toggle(movement, "Auto dribble (W)", "autoDribble", AutoDribble.reset)
movement:Button({Text = "Reset movement", Callback = function()
    changed("speedEnabled", false)
    changed("sprint", false)
    applySpeed()
    S.controls.speedEnabled:Set(false, false)
    S.controls.sprint:Set(false, false)
end})
local ball = playerTab:Section("Ball")
toggle(ball, "Auto poke", "autoPoke")
ball:Button({Text = "Poke", Callback = function() S.pokeCarrier(false) end})
S.controls.ballMagnet = ball:Button({Text = "Ball magnet (C)", Callback = function() Magnet.pull(false) end})
toggle(ball, "Freeze loose ball", "freezeBall", function(enabled) if enabled then if S.controls.hotPotato then S.controls.hotPotato:Set(false, true) end; if S.controls.ballOrbit then S.controls.ballOrbit:Set(false, true) end; if S.controls.ballGlue then S.controls.ballGlue:Set(false, true) end end; Freeze.setEnabled(enabled) end)
local tricks = playerTab:Section("Tricks")
toggle(tricks, "Walkfling", "walkfling", Walkfling.setEnabled)
toggle(tricks, "Hot potato", "hotPotato", HotPotato.setEnabled)
local orbitSection = playerTab:Section("Ball control")
toggle(orbitSection, "Ball glue", "ballGlue", Glue.setEnabled)
toggle(orbitSection, "Ball orbit", "ballOrbit", Orbit.setEnabled)
slider(orbitSection, "Grab range", "ballGrabRange", 4, 32, 0.5, Orbit.applyVisual)
slider(orbitSection, "Orbit radius", "orbitRadius", 2.5, 7, 0.5, Orbit.applyVisual)
slider(orbitSection, "Orbit speed", "orbitSpeed", 4, 90, 1)
toggle(orbitSection, "Show reach", "ballHitboxVisual", Orbit.applyVisual)
local protectionSection = playerTab:Section("Protection")
toggle(protectionSection, "Anti ragdoll", "antiRagdoll")
toggle(protectionSection, "Anti slide", "antiSlide")
local jumping = playerTab:Section("Jump")
toggle(jumping, "Jump (Space)", "jumpEnabled")
toggle(jumping, "Infinite jump", "infiniteJump")
slider(jumping, "Jump height", "jumpHeight", 1, 60, 1)
jumping:Button({Text = "Jump", Callback = function() Jump.fire() end})
local hitboxesSection = playerTab:Section("Player boxes")
toggle(hitboxesSection, "Player boxes", "playerHitboxes", function(value) cfg.hitboxVisuals = value; Hitboxes.apply() end)
slider(hitboxesSection, "Box size", "playerHitboxSize", 4, 50, 1, Hitboxes.apply)
toggle(ball, "Loose-ball assist", "ballExpander", Hitboxes.apply)
slider(ball, "Collection radius", "ballHitboxRadius", 1, 32, 0.5, Hitboxes.apply)
local menu = playerTab:Section("Menu")
toggle(menu, "Notifications", "notifications")
menu:Button({Text = "Save settings", Callback = function()
    local ok = save()
    notify(if ok then "Saved" else "Could not save", if ok then "Settings saved." else "Your current settings are still active.")
end})
menu:Button({Text = "Unload", Callback = function() life.cleanup() end})

local guidesSection = visualsTab:Section("Guides")
toggle(guidesSection, "Shot path", "trajectory")
toggle(guidesSection, "Ball marker", "marker")
toggle(guidesSection, "Centre dot", "aimDot")
local performance = visualsTab:Section("Performance")
toggle(performance, "FPS mode", "performance", Performance.apply)
toggle(performance, "Reduce effects", "reducePostEffects", Performance.apply)
toggle(performance, "Shadows", "keepShadows", Performance.apply)
slider(performance, "Frame limit", "fpsCap", 60, 360, 10, Performance.apply)
if retainedClosed then window:SetVisible(false) end

local function onKeyInput(key, processed)
    Walkfling.restore()
    if processed or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
    if key.KeyCode == Enum.KeyCode.RightShift then window:Toggle(); return end
    if key.KeyCode == Enum.KeyCode.Space and cfg.jumpEnabled then Jump.fire(); return end
    if key.KeyCode == Enum.KeyCode.F or key.KeyCode == Enum.KeyCode.B or key.KeyCode == Enum.KeyCode.C then Orbit.suspendUntil = os.clock() + 0.9; Glue.suspendUntil = os.clock() + 0.9 end
    if key.KeyCode == Enum.KeyCode.C then Magnet.pull(false); return end
    if key.KeyCode == Enum.KeyCode.H then
        changed("autoGK", not cfg.autoGK)
        S.controls.autoGK:Set(cfg.autoGK, false)
        return
    end
    if key.KeyCode == Enum.KeyCode.F and cfg.shooting then S.shoot(false) end
    if key.KeyCode == Enum.KeyCode.B then S.passToLook() end
end
S.handleInput = onKeyInput
life.connect(Input.InputBegan, onKeyInput)

local pokeElapsed = 0
life.connect(Run.Heartbeat, function(dt)
    pokeElapsed += dt
    if pokeElapsed < 0.05 then return end
    pokeElapsed = 0
    if cfg.autoPoke then
        local ok, err = pcall(S.pokeCarrier, true)
        if not ok then S.pokeError = tostring(err) end
    end
end)
local elapsed = 0
life.connect(Run.Heartbeat, function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local target = S.findPassTarget()
    aimDot.Visible = cfg.aimDot
    aimDot.BackgroundColor3 = if target then Color3.fromRGB(104, 211, 171) else Color3.fromRGB(245, 247, 246)
end)
Glue.setEnabled(cfg.ballGlue)
save()
notify("Ragdoll Soccer", "F: shoot | B: pass | H: keeper | Right Shift: menu")
return S
