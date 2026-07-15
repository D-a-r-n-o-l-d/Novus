-- Novus Combat Hub
-- Adonis bypass: load the Novus anti-detection module
-- Novus Anti-Detection Module (inlined)
(function() -- scoped to prevent local conflicts
-- Novus Anti-Detection Module
-- Author: Magnus (for Dan)
-- Target: Adonis anticheat, Potassium executor
-- Strategy: Neutering the Detected closure via upvalue manipulation
--           No hooks, no metatable changes, no debug.info breakage

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- SECTION 1: Potassium API Detection & Capability Check
--------------------------------------------------------------------------------

local CAPS = {
    hasMemoryAPI = pcall(function() return getthreadidentity end) and getthreadidentity ~= nil,
    hasHiddenProps = pcall(function() return sethiddenproperty end),
    hasGC = pcall(function() return getgc end),
    hasFilterGC = pcall(function() return filtergc end),
}

-- Try to elevate identity if needed
local currentIdentity = pcall(getthreadidentity) and getthreadidentity() or 2
if CAPS.hasMemoryAPI and currentIdentity < 7 then
    pcall(setthreadidentity, 7)
end

--------------------------------------------------------------------------------
-- SECTION 2: WalkSpeed / JumpPower — Memory-Level Property Write
--------------------------------------------------------------------------------

local function setWalkSpeedSafe(value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CAPS.hasHiddenProps then
        pcall(sethiddenproperty, hum, "WalkSpeed", value)
    else
        hum.WalkSpeed = value
    end
end

local function setJumpPowerSafe(value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CAPS.hasHiddenProps then
        pcall(sethiddenproperty, hum, "JumpPower", value)
    else
        hum.JumpPower = value
    end
end

--------------------------------------------------------------------------------
-- SECTION 3: Detected Function Neutering via Upvalue Manipulation
--
-- CRITICAL INSIGHT: Adonis's Detected function checks:
--   if NetworkClient and action ~= "_" then ... end
-- NetworkClient is an upvalue. If we set it to nil, the function
-- silently exits without sending anything to the server.
--
-- Benefits:
--  - No hookfunc = no FireServer hook detection
--  - No metatable changes = no metatable proxy detection
--  - debug.info sees the ORIGINAL closure = integrity check passes
--  - The function still "works" for integrity checks (Detected("_", "_", true))
--------------------------------------------------------------------------------

local DetectedNeutered = false

local function FindAndNeuterDetected()
    if DetectedNeutered then return true end
    
    local function safeGetGC()
        local ok, result = pcall(function()
            return getgc(true)
        end)
        return ok and result or {}
    end
    
    local objects = safeGetGC()
    local totalFuncs = 0
    local constMatched = 0
    local upvalAttempted = 0
    
    if #objects == 0 then
        print("[Novus] GC scan: 0 objects returned (Adonis may not be loaded)")
        return false
    end
    
    for _, v in ipairs(objects) do
        if typeof(v) ~= "function" then continue end
        totalFuncs = totalFuncs + 1
        
        -- Check for Detected function via its unique constants.
        -- KEY INSIGHT: Adonis breaks strings into individual letters:
        --   "Detected" = "D".."e".."t".."e".."c".."t".."e".."d"
        --   "kick"     = "k".."i".."c".."k"  
        --   "crash"    = "c".."r".."a".."s".."h"
        -- The ONLY full-string constants are the platform suffixes:
        --   " - On Xbox" and " - On mobile"
        -- We need BOTH to be present for a positive match.
        local ok, constants = pcall(getconstants, v)
        if not ok or not constants then continue end
        
        local hasXbox = false
        local hasMobile = false
        local hasUnderscore = false  -- "_" used for integrity check call
        
        for _, c in ipairs(constants) do
            if type(c) == "string" then
                if c == " - On Xbox" then hasXbox = true end
                if c == " - On mobile" then hasMobile = true end
                if c == "_" then hasUnderscore = true end
            end
        end
        
        -- Must have BOTH platform strings — that's the unique fingerprint
        if not (hasXbox and hasMobile) then continue end
        constMatched = constMatched + 1
        
        print(string.format("[Novus] *** DETECTED FUNCTION FOUND! (underscore=%s) ***", tostring(hasUnderscore)))
        
        -- Found a candidate! Now get its upvalues and nuke NetworkClient
        local ok2, upvalues = pcall(getupvalues, v)
        if not ok2 then
            print(string.format("[Novus] getupvalues FAILED: %s", tostring(upvalues)))
            continue 
        end
        if not upvalues or #upvalues == 0 then
            print("[Novus] getupvalues returned empty table")
            continue
        end
        
        upvalAttempted = upvalAttempted + 1
        print(string.format("[Novus] Got %d upvalues:", #upvalues))
        for idx, uv in ipairs(upvalues) do
            print(string.format("[Novus]   [%d] = %s (%s)", idx, tostring(uv), typeof(uv)))
        end
        
        -- Nuke all non-function, non-table upvalues (these are instances like
        -- NetworkClient, Player, etc. that we want nil'd out)
        -- typeof() returns class names like "NetworkClient", "Player" — not "Instance"
        local nuked = 0
        for idx, uv in ipairs(upvalues) do
            local t = typeof(uv)
            -- Skip functions (Send, Kill, etc.) and tables (configs)
            if t ~= "function" and t ~= "table" then
                local ok3 = pcall(setupvalue, v, idx, nil)
                if ok3 then
                    nuked = nuked + 1
                    print(string.format("[Novus] Nuked upvalue[%d] (was %s :: %s)", idx, tostring(uv), t))
                else
                    print(string.format("[Novus] FAILED to nuke upvalue[%d] (%s)", idx, t))
                end
            end
        end
        
        -- Verify: call Detected("_", "_", true) — should still return true
        local ok3, checkResult = pcall(v, "_", "_", true)
        if ok3 and checkResult == true then
            DetectedNeutered = true
            print(string.format("[Novus] Verified: Detected neutralized (%d upvalues nuked)", nuked))
            return true
        else
            print(string.format("[Novus] Verification failed: ok=%s, result=%s", tostring(ok3), tostring(checkResult)))
        end
    end
    
    print(string.format("[Novus] Scan complete: %d functions, %d candidates, %d upval attempts — Adonis AC likely not loaded", 
        totalFuncs, constMatched, upvalAttempted))
    
    return false
end

--------------------------------------------------------------------------------
-- SECTION 4: LogService Output Sanitization
--------------------------------------------------------------------------------

-- Redirect our print output to avoid appearing in Adonis's log scanner
-- Potassium's rconsole functions bypass LogService entirely
local function safePrint(...)
    local args = {...}
    local msg = table.concat(args, "\t")
    -- Use rconsole if available (doesn't go through LogService)
    if rconsoleprint then
        pcall(rconsoleprint, msg .. "\n")
    end
end

--------------------------------------------------------------------------------
-- SECTION 5: Comprehensive Bypass Installer
--------------------------------------------------------------------------------

local BypassInstalled = false

local function InstallBypass()
    if BypassInstalled then return true end
    
    -- Phase 1: Neuter Detected function
    local success = FindAndNeuterDetected()
    
    if success then
        BypassInstalled = true
    end
    
    return success
end

--------------------------------------------------------------------------------
-- SECTION 6: Recurring Scan (catches late-loading Adonis)
--------------------------------------------------------------------------------

local scanLog = {}

local function scanPrint(msg)
    table.insert(scanLog, msg)
    if #scanLog > 100 then table.remove(scanLog, 1) end
    print(msg)
    -- Flush to file so Magnus can read from the Pi
    pcall(function()
        writefile("scripts/novus_scan.txt", table.concat(scanLog, "\n"))
    end)
end

task.spawn(function()
    while true do
        task.wait(8)
        if not DetectedNeutered then
            scanPrint(string.format("[%s] Scanning...", os.date("%H:%M:%S")))
            
            -- Temporarily redirect prints inside FindAndNeuterDetected to our logger
            local oldPrint = print
            print = scanPrint
            pcall(FindAndNeuterDetected)
            print = oldPrint
        end
    end
end)

--------------------------------------------------------------------------------
-- Auto-install and diagnostics
--------------------------------------------------------------------------------

task.wait(5) -- Let Adonis load first
local result = InstallBypass()

-- Build diagnostic log
local diagLines = {}
local function log(...) 
    local msg = table.concat({...}, "\t")
    table.insert(diagLines, msg)
    print(msg)
end

log("========================================")
log("[Novus] Anti-Detection Diagnostics")
log("========================================")
log(string.format("[Novus] Executor: %s", identifyexecutor and pcall(identifyexecutor) and identifyexecutor() or "Unknown"))
log(string.format("[Novus] Thread Identity: %d", pcall(getthreadidentity) and getthreadidentity() or -1))
log(string.format("[Novus] hiddenprops API: %s", CAPS.hasHiddenProps and "YES" or "NO"))
log(string.format("[Novus] GC access: %s", CAPS.hasGC and "YES" or "NO"))
log(string.format("[Novus] Detected neutered: %s", result and "YES" or "NO  (will retry every 8s)"))
log(string.format("[Novus] WalkSpeed safe: %s", CAPS.hasHiddenProps and "YES (hidden)" or "NO (Changed event)"))
log("========================================")
log("[Novus] Ready. Load your script now.")
log("========================================")

-- Dump to file on share so Magnus can read it
pcall(function()
    writefile("scripts/novus_diag.txt", table.concat(diagLines, "\n"))
end)

-- Expose globally so the main script can use safe setters
getgenv().NovusBypass = {
    Install = InstallBypass,
    SetWalkSpeed = setWalkSpeedSafe,
    SetJumpPower = setJumpPowerSafe,
    IsActive = function() return DetectedNeutered end,
    WriteProperty = function(instance, property, value)
        if CAPS.hasHiddenProps then
            return pcall(sethiddenproperty, instance, property, value)
        end
        instance[property] = value
    end,
}

return getgenv().NovusBypass
end)() -- end bypass scope

-- Novus Combat Hub

---------------------------------------------------------------------
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local Workspace   = game:GetService("Workspace")
local CoreGui     = game:GetService("CoreGui")
local GuiService  = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

---------------------------------------------------------------------

-- Linoria UI — Novus Combat Hub
-- Linoria UI Library — Novus Combat Hub
-- Replaces dollarware with proper keybinds, configs, textboxes, and themes

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Novus Combat Hub',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Combat   = Window:AddTab('Combat'),
    Movement = Window:AddTab('Movement'),
    Visuals  = Window:AddTab('Visuals'),
    Settings = Window:AddTab('Settings'),
}

-- FPS / ping watermark
local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60
game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    Library:SetWatermark(('Novus | %d fps | %d ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library:SetWatermarkVisibility(true)
Library.KeybindFrame.Visible = true

-- Cleanup tracker — all connections and objects registered here
-- Persists in getgenv for reload support
if getgenv()._NovusCleanup then
    pcall(getgenv()._NovusCleanup)
    getgenv()._NovusCleanup = nil
end

local Cleanup = { connections = {}, objects = {}, drawings = {} }

function Cleanup:Track(conn) table.insert(self.connections, conn); return conn end
function Cleanup:TrackObj(obj) table.insert(self.objects, obj); return obj end
function Cleanup:TrackDraw(d) table.insert(self.drawings, d); return d end

function Cleanup:DoCleanup()
    -- Disconnect all tracked connections
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    -- Destroy all tracked objects
    for _, obj in ipairs(self.objects) do
        pcall(function() obj:Destroy() end)
    end
    -- Remove all drawings
    for _, d in ipairs(self.drawings) do
        pcall(function() d:Remove() end)
    end
    -- Clear tables
    self.connections = {}
    self.objects = {}
    self.drawings = {}
    -- Unload ESP
    pcall(function() Sense.Unload() end)
    -- Reset key configs to prevent stale state
    Config.Aimbot.Enabled = false
    Config.Trigger.Enabled = false
    Config.Hitbox.Enabled = false
end

getgenv()._NovusCleanup = function() Cleanup:DoCleanup() end


local Config = {}

Config.Hitbox = {
    Enabled = false,
    Size    = 20,
}
local DEFAULT_HITBOX_SIZE = Vector3.new(2, 2, 2)

Config.Aimbot = {
    Enabled        = false,
    CameraAim      = false,
    AutoFire       = false,
    LockAim        = true,
    TeamCheck      = false,
    DistanceCheck  = true,
    VisibilityCheck= false,
    Prediction     = false,
    Sensitivity    = 20,
    FOVRadius      = 100,
    DistanceLimit  = 250,
    PriorityList   = {"Closest", "Head", "HumanoidRootPart"},
    PriorityIndex  = 1,
}

Config.Silent = {
    Enabled        = false,
    CameraAim      = false,
    AutoFire       = false,
    LockAim        = true,
    TeamCheck      = false,
    DistanceCheck  = true,
    VisibilityCheck= false,
    Prediction     = false,
    HitChance      = 100,
    FOVRadius      = 100,
    DistanceLimit  = 250,
    PriorityList   = {"Closest", "Head", "HumanoidRootPart", "Random"},
    PriorityIndex  = 1,
}

Config.Trigger = {
    Enabled        = false,
    AlwaysOn       = false,
    HoldMouse      = false,
    TeamCheck      = false,
    DistanceCheck  = true,
    VisibilityCheck= false,
    Prediction     = false,
    Delay          = 0.15,
    FireRate       = 100,
    FOVRadius      = 25,
    DistanceLimit  = 250,
    PriorityList   = {"Closest", "Head", "HumanoidRootPart", "Random"},
    PriorityIndex  = 1,
}

Config.Movement = {
    WalkSpeed   = 16,
    JumpPower   = 50,
    ClickTP     = false,
}

Config.Prediction = {
    ProjectileSpeed   = 1000,
    Gravity           = 0,
    GravityCorrection = 0,
}

Config.AimVisuals = {
    ShowAimbotFOV  = true,
    ShowSilentFOV  = true,
    ShowTriggerFOV = true,
    AimbotColor    = {R = 120, G = 170, B = 255},
    SilentColor    = {R = 255, G = 170, B = 120},
    TriggerColor   = {R = 120, G = 255, B = 170},
    Thickness      = 1.5,
    Filled         = false,
    Sides          = 40,
}

---------------------------------------------------------------------
local Sense = loadstring(game:HttpGet("https://sirius.menu/sense"))()
Sense.teamSettings.enemy.enabled        = true
Sense.teamSettings.enemy.box            = true
Sense.teamSettings.enemy.boxColor[1]    = Color3.fromRGB(255, 0, 0)
Sense.teamSettings.enemy.healthBar      = true
Sense.teamSettings.enemy.name           = true
Sense.teamSettings.enemy.distance       = false
Sense.teamSettings.enemy.tracer         = false
Sense.teamSettings.enemy.chams          = false

Sense.teamSettings.friendly.enabled     = false
Sense.teamSettings.friendly.box         = true
Sense.teamSettings.friendly.boxColor[1] = Color3.fromRGB(0, 255, 0)
Sense.teamSettings.friendly.healthBar   = true
Sense.teamSettings.friendly.name        = true
Sense.teamSettings.friendly.distance    = false
Sense.teamSettings.friendly.tracer      = false
Sense.teamSettings.friendly.chams       = false

local VisualsGui = Instance.new("ScreenGui")
VisualsGui.Name = "NovusVisuals"
VisualsGui.IgnoreGuiInset = true
VisualsGui.ResetOnSpawn = false
VisualsGui.Parent = CoreGui
Cleanup:TrackObj(VisualsGui)

---------------------------------------------------------------------
local NovusBypass = getgenv().NovusBypass or {}

local function applyWalkSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if NovusBypass.SetWalkSpeed then
        NovusBypass.SetWalkSpeed(Config.Movement.WalkSpeed)
    else
        hum.WalkSpeed = Config.Movement.WalkSpeed
    end
end

local function applyJumpPower()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if NovusBypass.SetJumpPower then
        NovusBypass.SetJumpPower(Config.Movement.JumpPower)
    else
        hum.JumpPower = Config.Movement.JumpPower
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    applyWalkSpeed()
    applyJumpPower()
end)

---------------------------------------------------------------------
local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
WallCheckParams.IgnoreWater = true

local function Raycast(origin, direction, ignoreList)
    WallCheckParams.FilterDescendantsInstances = ignoreList
    return Workspace:Raycast(origin, direction, WallCheckParams)
end

local function InEnemyTeam(enabled, plr)
    if not enabled then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return LocalPlayer.Team ~= plr.Team
end

local function WithinReach(enabled, distance, limit)
    if not enabled then return true end
    return distance <= limit
end

local function ObjectOccluded(enabled, origin, targetPos, character)
    if not enabled then return false end
    local result = Raycast(origin, targetPos - origin, {character, LocalPlayer.Character})
    return result ~= nil
end

local function SolveTrajectory(origin, velocity, time, gravityMag, correction)
    gravityMag = gravityMag or Config.Prediction.Gravity
    correction = correction or Config.Prediction.GravityCorrection
    local g = Vector3.new(0, -gravityMag, 0)
    return origin + velocity * time + (-g) * time * time / (2 * math.max(correction, 0.01))
end

local function GetClosest(enabled,
    teamCheck, visibilityCheck, distanceCheck,
    distanceLimit, fovRadius, priority, bodyParts,
    predictionEnabled)

    if not enabled then return nil end

    local cameraPos = Camera.CFrame.Position
    local closestHit, closestMag = nil, fovRadius
    local mousePos = UIS:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local char = plr.Character
        if not char then continue end
        if not InEnemyTeam(teamCheck, plr) then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local function checkPart(part)
            if not part then return end
            local pos = part.Position
            local distance = (pos - cameraPos).Magnitude
            if not WithinReach(distanceCheck, distance, distanceLimit) then return end

            if predictionEnabled and Config.Prediction.ProjectileSpeed > 0 then
                local travelTime = distance / Config.Prediction.ProjectileSpeed
                pos = SolveTrajectory(pos, part.AssemblyLinearVelocity, travelTime, Config.Prediction.Gravity, Config.Prediction.GravityCorrection)
            end

            local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
            if not onScreen then return end
            if ObjectOccluded(visibilityCheck, cameraPos, pos, char) then return end

            local screen2d = Vector2.new(screenPos.X, screenPos.Y)
            local mag = (screen2d - mousePos).Magnitude
            if mag < closestMag then
                closestMag = mag
                closestHit = {plr, char, part, screen2d}
            end
        end

        if priority == "Random" then
            local partName = bodyParts[math.random(#bodyParts)]
            checkPart(char:FindFirstChild(partName))
        elseif priority ~= "Closest" then
            checkPart(char:FindFirstChild(priority))
        else
            for _, partName in ipairs(bodyParts) do
                checkPart(char:FindFirstChild(partName))
            end
        end
    end

    return closestHit
end

---------------------------------------------------------------------
local function GetRelation(plr)
    if plr == LocalPlayer then return nil end
    if LocalPlayer.Team and plr.Team then
        if plr.Team == LocalPlayer.Team or plr.TeamColor == LocalPlayer.TeamColor then
            return "friendly"
        else
            return "enemy"
        end
    end
    return "enemy"
end

local function RainbowColor(offset)
    offset = offset or 0
    local t = (tick() * 0.2 + offset) % 1
    return Color3.fromHSV(t, 1, 1)
end

---------------------------------------------------------------------
local SkeletonConfig = {
    EnemyEnabled    = false,
    FriendlyEnabled = false,
    EnemyColor      = Color3.fromRGB(0, 255, 255),
    FriendlyColor   = Color3.fromRGB(0, 255, 0),
    EnemyRainbow    = false,
    FriendlyRainbow = false,
    Thickness       = 1.5,
    Connection      = nil,
    Lines           = {},
}

local function DestroySkeletonLinesFor(plr)
    local lines = SkeletonConfig.Lines[plr]
    if lines then
        for _, l in ipairs(lines) do l:Remove() end
        SkeletonConfig.Lines[plr] = nil
    end
end

local function DisableSkeletonLoop()
    if SkeletonConfig.Connection then
        SkeletonConfig.Connection:Disconnect()
        SkeletonConfig.Connection = nil
    end
    for _, lines in pairs(SkeletonConfig.Lines) do
        for _, l in ipairs(lines) do l:Remove() end
    end
    SkeletonConfig.Lines = {}
end

local function EnsureSkeletonLoop()
    if not (SkeletonConfig.EnemyEnabled or SkeletonConfig.FriendlyEnabled) then
        DisableSkeletonLoop()
        return
    end
    if SkeletonConfig.Connection then return end

    SkeletonConfig.Connection = RunService.RenderStepped:Connect(function()
        for plr in pairs(SkeletonConfig.Lines) do
            if not Players:FindFirstChild(plr.Name) then
                DestroySkeletonLinesFor(plr)
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end

            local relation = GetRelation(plr)
            local wantEnemy    = relation == "enemy"    and SkeletonConfig.EnemyEnabled
            local wantFriendly = relation == "friendly" and SkeletonConfig.FriendlyEnabled
            if not (wantEnemy or wantFriendly) then
                DestroySkeletonLinesFor(plr)
                continue
            end

            local char = plr.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not (char and hrp and hum and hum.Health > 0) then
                DestroySkeletonLinesFor(plr)
                continue
            end

            local lines = SkeletonConfig.Lines[plr]
            if not lines then
                lines = {}
                for i = 1, 15 do
                    local ln = Drawing.new("Line")
                    ln.Visible = false
                    ln.Thickness = SkeletonConfig.Thickness
                    ln.Transparency = 0
                    table.insert(lines, ln)
                end
                SkeletonConfig.Lines[plr] = lines
            end

            local function getPos(partName)
                local part = char:FindFirstChild(partName)
                if not part then return nil end
                local p, onScreen = Camera:WorldToViewportPoint(part.Position)
                if not onScreen then return nil end
                return Vector2.new(p.X, p.Y)
            end

            local points = {
                head       = getPos("Head"),
                upperTorso = getPos("UpperTorso") or getPos("Torso"),
                lowerTorso = getPos("LowerTorso") or getPos("Torso"),
                leftArm    = getPos("LeftHand") or getPos("LeftLowerArm") or getPos("Left Arm"),
                rightArm   = getPos("RightHand") or getPos("RightLowerArm") or getPos("Right Arm"),
                leftLeg    = getPos("LeftFoot") or getPos("LeftLowerLeg") or getPos("Left Leg"),
                rightLeg   = getPos("RightFoot") or getPos("RightLowerLeg") or getPos("Right Leg"),
            }

            local color
            if relation == "enemy" then
                color = SkeletonConfig.EnemyRainbow and RainbowColor(0.1) or SkeletonConfig.EnemyColor
            else
                color = SkeletonConfig.FriendlyRainbow and RainbowColor(0.2) or SkeletonConfig.FriendlyColor
            end

            local idx = 1
            local function drawBone(a, b)
                local ln = lines[idx]
                if a and b and ln then
                    ln.Visible = true
                    ln.Color = color
                    ln.Thickness = SkeletonConfig.Thickness
                    ln.From = a
                    ln.To = b
                elseif ln then
                    ln.Visible = false
                end
                idx = idx + 1
            end

            drawBone(points.head,       points.upperTorso)
            drawBone(points.upperTorso, points.lowerTorso)
            drawBone(points.upperTorso, points.leftArm)
            drawBone(points.upperTorso, points.rightArm)
            drawBone(points.lowerTorso, points.leftLeg)
            drawBone(points.lowerTorso, points.rightLeg)

            for i = idx, #lines do
                lines[i].Visible = false
            end
        end
    end)
end

---------------------------------------------------------------------
local Box3DConfig = {
    Enabled      = false,
    Color        = Color3.fromRGB(255, 255, 255),
    Transparency = 0.25,
    Thickness    = 1.0,
    TeamCheck    = true,
}

local Box3D_Lines = {}
local Box3D_Quads = {}

local function Box3D_Clear()
    for _, l in ipairs(Box3D_Lines) do l:Remove() end
    for _, q in ipairs(Box3D_Quads) do q:Remove() end
    Box3D_Lines = {}
    Box3D_Quads = {}
end

local function Box3D_NewLine()
    local line = Drawing.new("Line")
    line.Visible = false
    return line
end

local function Box3D_NewQuad()
    local quad = Drawing.new("Quad")
    quad.Visible = false
    quad.Filled = true
    return quad
end

local function Box3D_GetCorners(obj)
    local cf = obj.CFrame
    local size = obj.Size / 2
    local corners = {}
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                table.insert(corners, (cf * CFrame.new(size * Vector3.new(x, y, z))).Position)
            end
        end
    end
    return corners
end

local function Box3D_DrawQuad(a, b, c, d)
    local sa, va = Camera:WorldToViewportPoint(a)
    local sb, vb = Camera:WorldToViewportPoint(b)
    local sc, vc = Camera:WorldToViewportPoint(c)
    local sd, vd = Camera:WorldToViewportPoint(d)
    if not (va or vb or vc or vd) then return end

    local qa = Box3D_NewQuad()
    qa.Color = Box3DConfig.Color
    qa.Transparency = 1 - Box3DConfig.Transparency
    qa.PointA = Vector2.new(sa.X, sa.Y)
    qa.PointB = Vector2.new(sb.X, sb.Y)
    qa.PointC = Vector2.new(sc.X, sc.Y)
    qa.PointD = Vector2.new(sd.X, sd.Y)
    qa.Visible = true
    table.insert(Box3D_Quads, qa)
end

local function Box3D_DrawLine(p0, p1)
    local s0, v0 = Camera:WorldToViewportPoint(p0)
    local s1, v1 = Camera:WorldToViewportPoint(p1)
    if not (v0 or v1) then return end

    local l = Box3D_NewLine()
    l.Color = Box3DConfig.Color
    l.Thickness = Box3DConfig.Thickness
    l.Transparency = 1 - Box3DConfig.Transparency
    l.From = Vector2.new(s0.X, s0.Y)
    l.To   = Vector2.new(s1.X, s1.Y)
    l.Visible = true
    table.insert(Box3D_Lines, l)
end

local function Box3D_IsEnemy(plr)
    if plr == LocalPlayer then return false end
    if not Box3DConfig.TeamCheck then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return plr.Team ~= LocalPlayer.Team
end

RunService.RenderStepped:Connect(function()
    if not Box3DConfig.Enabled then
        if #Box3D_Lines > 0 or #Box3D_Quads > 0 then
            Box3D_Clear()
        end
        return
    end

    Box3D_Clear()

    for _, plr in ipairs(Players:GetPlayers()) do
        if Box3D_IsEnemy(plr) and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local fake = { CFrame = hrp.CFrame * CFrame.new(0, -0.5, 0), Size = Vector3.new(3, 5, 3) }
                local corners = Box3D_GetCorners(fake)

                -- bottom
                Box3D_DrawLine(corners[1], corners[2])
                Box3D_DrawLine(corners[2], corners[6])
                Box3D_DrawLine(corners[6], corners[5])
                Box3D_DrawLine(corners[5], corners[1])
                Box3D_DrawQuad(corners[1], corners[2], corners[6], corners[5])

                -- sides
                Box3D_DrawLine(corners[1], corners[3])
                Box3D_DrawLine(corners[2], corners[4])
                Box3D_DrawLine(corners[6], corners[8])
                Box3D_DrawLine(corners[5], corners[7])

                Box3D_DrawQuad(corners[2], corners[4], corners[8], corners[6])
                Box3D_DrawQuad(corners[1], corners[2], corners[4], corners[3])
                Box3D_DrawQuad(corners[1], corners[5], corners[7], corners[3])
                Box3D_DrawQuad(corners[5], corners[7], corners[8], corners[6])

                -- top
                Box3D_DrawLine(corners[3], corners[4])
                Box3D_DrawLine(corners[4], corners[8])
                Box3D_DrawLine(corners[8], corners[7])
                Box3D_DrawLine(corners[7], corners[3])
                Box3D_DrawQuad(corners[3], corners[4], corners[8], corners[7])
            end
        end
    end
end)

---------------------------------------------------------------------
local ChamsConfig = {
    EnemyEnabled        = false,
    FriendlyEnabled     = false,
    EnemyFillColor      = Color3.fromRGB(255, 0, 0),
    EnemyOutlineColor   = Color3.fromRGB(255, 255, 255),
    FriendlyFillColor   = Color3.fromRGB(0, 255, 0),
    FriendlyOutlineColor= Color3.fromRGB(255, 255, 255),
    FillOpacity         = 60,
    OutlineOpacity      = 0,
}

local ChamInstances = {}

local function UpdateChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local relation = GetRelation(plr)
        local wantEnemy    = relation == "enemy"    and ChamsConfig.EnemyEnabled
        local wantFriendly = relation == "friendly" and ChamsConfig.FriendlyEnabled

        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not (char and hum and hum.Health > 0 and (wantEnemy or wantFriendly)) then
            local h = ChamInstances[plr]
            if h then
                h:Destroy()
                ChamInstances[plr] = nil
            end
            continue
        end

        local highlight = ChamInstances[plr]
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "NovusCham"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = VisualsGui
            ChamInstances[plr] = highlight
        end

        highlight.Adornee = char
        if relation == "enemy" then
            highlight.FillColor = ChamsConfig.EnemyFillColor
            highlight.OutlineColor = ChamsConfig.EnemyOutlineColor
        else
            highlight.FillColor = ChamsConfig.FriendlyFillColor
            highlight.OutlineColor = ChamsConfig.FriendlyOutlineColor
        end
        highlight.FillTransparency = 1 - (ChamsConfig.FillOpacity / 100)
        highlight.OutlineTransparency = 1 - (ChamsConfig.OutlineOpacity / 100)
        highlight.Enabled = true
    end

    for plr, h in pairs(ChamInstances) do
        if not Players:FindFirstChild(plr.Name) or not plr.Character then
            h:Destroy()
            ChamInstances[plr] = nil
        end
    end
end

RunService.RenderStepped:Connect(UpdateChams)

---------------------------------------------------------------------
local ArrowConfig = {
    Enabled   = false,
    TeamCheck = true,
    Size      = 18,
    Radius    = 220,
    Thickness = 2,
    Color     = Color3.fromRGB(255, 255, 255),
}

local ArrowInstances = {}

local function GetScreenCenter()
    local size = Camera.ViewportSize
    return Vector2.new(size.X / 2, size.Y / 2)
end

RunService.RenderStepped:Connect(function()
    if not ArrowConfig.Enabled then
        for _, tri in pairs(ArrowInstances) do
            tri.Visible = false
        end
        return
    end

    local center = GetScreenCenter()
    local viewport = Camera.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local relation = GetRelation(plr)
        if ArrowConfig.TeamCheck and relation ~= "enemy" then
            local t = ArrowInstances[plr]
            if t then
                t.Visible = false
            end
            continue
        end

        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not (char and hrp and hum and hum.Health > 0) then
            local t = ArrowInstances[plr]
            if t then
                t:Remove()
                ArrowInstances[plr] = nil
            end
            continue
        end

        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        local screenPos = Vector2.new(pos.X, pos.Y)

        local tri = ArrowInstances[plr]
        if not tri then
            tri = Drawing.new("Triangle")
            tri.Filled = true
            tri.Thickness = ArrowConfig.Thickness
            tri.Transparency = 0
            ArrowInstances[plr] = tri
        end

        if onScreen and pos.Z > 0 and screenPos.X >= 0 and screenPos.X <= viewport.X and screenPos.Y >= 0 and screenPos.Y <= viewport.Y then
            tri.Visible = false
        else
            local dir = (screenPos - center)
            if dir.Magnitude == 0 then dir = Vector2.new(0, -1) end
            dir = dir.Unit
            local baseDir = Vector2.new(-dir.Y, dir.X)
            local tip = center + dir * ArrowConfig.Radius
            local baseHalf = ArrowConfig.Size / 2

            tri.PointA = tip
            tri.PointB = tip - dir * ArrowConfig.Size + baseDir * baseHalf
            tri.PointC = tip - dir * ArrowConfig.Size - baseDir * baseHalf
            tri.Color = ArrowConfig.Color
            tri.Thickness = ArrowConfig.Thickness
            tri.Visible = true
        end
    end

    for plr, tri in pairs(ArrowInstances) do
        if not Players:FindFirstChild(plr.Name) then
            tri:Remove()
            ArrowInstances[plr] = nil
        end
    end
end)

---------------------------------------------------------------------
local NameTagConfig = {
    Enabled      = false,
    ShowDistance = true,
    UseDisplay   = true,
}

local NameTagInstances = {}

local function GetOrCreateNameTag(plr, char)
    local head = char:FindFirstChild("Head")
    if not head then return nil end

    local gui = NameTagInstances[plr]
    if not gui then
        gui = Instance.new("BillboardGui")
        gui.Name = "NovusNameTag"
        gui.Size = UDim2.new(0, 200, 0, 40)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 500
        gui.Adornee = head

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0.5
        label.TextScaled = true
        label.Parent = gui

        gui.Parent = VisualsGui
        NameTagInstances[plr] = gui
    else
        gui.Adornee = head
    end

    return gui
end

RunService.RenderStepped:Connect(function()
    for plr, gui in pairs(NameTagInstances) do
        if not Players:FindFirstChild(plr.Name) or not plr.Character or not plr.Character:FindFirstChild("Head") or not NameTagConfig.Enabled then
            gui.Enabled = false
        end
    end

    if not NameTagConfig.Enabled then return end

    local localChar = LocalPlayer.Character
    local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")
        if not (char and hum and hum.Health > 0 and head) then
            local gui = NameTagInstances[plr]
            if gui then gui.Enabled = false end
            continue
        end

        local gui = GetOrCreateNameTag(plr, char)
        local label = gui and gui:FindFirstChild("Text")
        if not (gui and label) then
            continue
        end

        gui.Enabled = true

        local baseName
        if NameTagConfig.UseDisplay and plr.DisplayName and plr.DisplayName ~= "" then
            if plr.DisplayName ~= plr.Name then
                baseName = plr.Name .. " (@" .. plr.DisplayName .. ")"
            else
                baseName = plr.Name
            end
        else
            baseName = plr.Name
        end

        local text = baseName
        if NameTagConfig.ShowDistance and localHRP then
            local dist = (head.Position - localHRP.Position).Magnitude
            text = string.format("%s [%dm]", text, math.floor(dist + 0.5))
        end

        label.Text = text

        local relation = GetRelation(plr)
        if relation == "friendly" then
            label.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            label.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
end)

---------------------------------------------------------------------
local RadarConfig = { Enabled = false }

local RadarPlayer = LocalPlayer

local LerpColorModule = loadstring(game:HttpGet("https://pastebin.com/raw/wRnsJeid"))()
local HealthBarLerp = LerpColorModule:Lerp(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))

local function NewCircle(Transparency, Color, Radius, Filled, Thickness)
    local c = Drawing.new("Circle")
    c.Transparency = Transparency
    c.Color = Color
    c.Visible = false
    c.Thickness = Thickness
    c.Position = Vector2.new(0, 0)
    c.Radius = Radius
    c.NumSides = math.clamp(Radius * 55 / 100, 10, 75)
    c.Filled = Filled
    return c
end

local RadarInfo = {
    Position = Vector2.new(200, 200),
    Radius = 100,
    Scale = 1,
    MaxDistance = 1000,
    DistanceTransparency = 0,
    RadarBack = Color3.fromRGB(10, 10, 10),
    RadarBorder = Color3.fromRGB(75, 75, 75),
    LocalPlayerDot = Color3.fromRGB(255, 255, 255),
    PlayerDot = Color3.fromRGB(60, 170, 255),
    Team = Color3.fromRGB(0, 255, 0),
    Enemy = Color3.fromRGB(255, 0, 0),
    Health_Color = true,
    Team_Check = true,
}

local RadarBackground = NewCircle(0.1, RadarInfo.RadarBack, RadarInfo.Radius, true, 1)
local RadarBorder = NewCircle(0.25, RadarInfo.RadarBorder, RadarInfo.Radius, false, 3)
RadarBackground.Visible = false
RadarBorder.Visible = false
RadarBackground.Position = RadarInfo.Position
RadarBorder.Position = RadarInfo.Position

local function GetRelative(pos)
    local char = RadarPlayer.Character
    if char and char.PrimaryPart then
        local pmpart = char.PrimaryPart
        local camerapos = Vector3.new(Camera.CFrame.Position.X, pmpart.Position.Y, Camera.CFrame.Position.Z)
        local newcf = CFrame.new(pmpart.Position, camerapos)
        local r = newcf:PointToObjectSpace(pos)
        return r.X, r.Z
    end
    return 0, 0
end

local function PlaceDot(plr)
    local PlayerDot = NewCircle(0, RadarInfo.PlayerDot, 3, true, 1)

    local function Update()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not RadarConfig.Enabled then
                PlayerDot.Visible = false
                return
            end

            local char = plr.Character
            if char and char:FindFirstChildOfClass("Humanoid") and char.PrimaryPart and char:FindFirstChildOfClass("Humanoid").Health > 0 then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local scale = RadarInfo.Scale
                local relx, rely = GetRelative(char.PrimaryPart.Position)
                local newpos = RadarInfo.Position - Vector2.new(relx * scale, rely * scale)

                local dist3d = 0
                local localChar = RadarPlayer.Character
                local localRoot = localChar and localChar.PrimaryPart
                if localRoot then
                    dist3d = (char.PrimaryPart.Position - localRoot.Position).Magnitude
                    if RadarInfo.MaxDistance > 0 and dist3d > RadarInfo.MaxDistance then
                        PlayerDot.Visible = false
                        return
                    end
                end

                if (newpos - RadarInfo.Position).Magnitude < RadarInfo.Radius - 2 then
                    PlayerDot.Radius = 3
                    PlayerDot.Position = newpos
                    PlayerDot.Visible = true
                else
                    local dist = (RadarInfo.Position - newpos).Magnitude
                    local calc = (RadarInfo.Position - newpos).Unit * (dist - RadarInfo.Radius)
                    local inside = Vector2.new(newpos.X + calc.X, newpos.Y + calc.Y)
                    PlayerDot.Radius = 2
                    PlayerDot.Position = inside
                    PlayerDot.Visible = true
                end

                if RadarInfo.Team_Check then
                    if plr.TeamColor == RadarPlayer.TeamColor then
                        PlayerDot.Color = RadarInfo.Team
                    else
                        PlayerDot.Color = RadarInfo.Enemy
                    end
                else
                    PlayerDot.Color = RadarInfo.PlayerDot
                end

                if RadarInfo.Health_Color then
                    PlayerDot.Color = HealthBarLerp(hum.Health / hum.MaxHealth)
                end

                if RadarInfo.DistanceTransparency > 0 and RadarInfo.MaxDistance > 0 then
                    local t = math.clamp(dist3d / RadarInfo.MaxDistance, 0, 1)
                    PlayerDot.Transparency = t * RadarInfo.DistanceTransparency
                else
                    PlayerDot.Transparency = 0
                end
            else
                PlayerDot.Visible = false
                if not Players:FindFirstChild(plr.Name) then
                    PlayerDot:Remove()
                    if conn then conn:Disconnect() end
                end
            end
        end)
    end

    coroutine.wrap(Update)()
end

for _, v in pairs(Players:GetPlayers()) do
    if v ~= RadarPlayer then
        PlaceDot(v)
    end
end

local function NewLocalDot()
    local d = Drawing.new("Triangle")
    d.Visible = false
    d.Thickness = 1
    d.Filled = true
    d.Color = RadarInfo.LocalPlayerDot
    d.PointA = RadarInfo.Position + Vector2.new(0, -6)
    d.PointB = RadarInfo.Position + Vector2.new(-3, 6)
    d.PointC = RadarInfo.Position + Vector2.new(3, 6)
    return d
end

local LocalPlayerDot = NewLocalDot()

Players.PlayerAdded:Connect(function(v)
    if v ~= RadarPlayer then
        PlaceDot(v)
    end
    if LocalPlayerDot then LocalPlayerDot:Remove() end
    LocalPlayerDot = NewLocalDot()
end)

coroutine.wrap(function()
    RunService.RenderStepped:Connect(function()
        if RadarConfig.Enabled then
            RadarBackground.Visible = true
            RadarBorder.Visible = true
            RadarBackground.Position = RadarInfo.Position
            RadarBorder.Position = RadarInfo.Position
            RadarBackground.Radius = RadarInfo.Radius
            RadarBorder.Radius = RadarInfo.Radius

            if LocalPlayerDot then
                LocalPlayerDot.Visible = true
                LocalPlayerDot.Color = RadarInfo.LocalPlayerDot
                LocalPlayerDot.PointA = RadarInfo.Position + Vector2.new(0, -6)
                LocalPlayerDot.PointB = RadarInfo.Position + Vector2.new(-3, 6)
                LocalPlayerDot.PointC = RadarInfo.Position + Vector2.new(3, 6)
            end
        else
            RadarBackground.Visible = false
            RadarBorder.Visible = false
            if LocalPlayerDot then
                LocalPlayerDot.Visible = false
            end
        end
    end)
end)()

-- Radar dragging + hover
local inset = GuiService:GetGuiInset()
local radarDragging = false
local radarOffset = Vector2.new(0, 0)

UIS.InputBegan:Connect(function(input)
    if not RadarConfig.Enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
        if (mousePos - RadarInfo.Position).Magnitude < RadarInfo.Radius then
            radarOffset = RadarInfo.Position - Vector2.new(Mouse.X, Mouse.Y)
            radarDragging = true
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        radarDragging = false
    end
end)

coroutine.wrap(function()
    local hoverDot = NewCircle(1, Color3.fromRGB(255, 255, 255), 3, true, 1)
    RunService.RenderStepped:Connect(function()
        if not RadarConfig.Enabled then
            hoverDot.Visible = false
            return
        end

        local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
        if (mousePos - RadarInfo.Position).Magnitude < RadarInfo.Radius then
            hoverDot.Position = mousePos
            hoverDot.Visible = true
        else
            hoverDot.Visible = false
        end

        if radarDragging then
            RadarInfo.Position = Vector2.new(Mouse.X, Mouse.Y) + radarOffset
        end
    end)
end)()

---------------------------------------------------------------------
local Terrain = Workspace.Terrain

local AimViewerConfig = {
    Enabled = false,
    Beams   = {},
}

local AimViewerColours = {
	At   = ColorSequence.new(Color3.new(1, 0, 0)),
	Away = ColorSequence.new(Color3.new(0, 1, 0)),
}

local function AimViewer_IsBeamHit(beam, mousePos)
    if not beam or not beam.Attachment0 or not beam.Attachment1 then return end

    local character = LocalPlayer.Character
    local origin = beam.Attachment0.WorldPosition
    local direction = mousePos - origin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { character, Workspace.CurrentCamera }

    local result = Workspace:Raycast(origin, direction * 2, raycastParams)
    if not result then
        beam.Color = AimViewerColours.Away
        beam.Attachment1.WorldPosition = mousePos
        beam.Enabled = AimViewerConfig.Enabled
        return
    end

    if character then
        local hitOwnChar = result.Instance:IsDescendantOf(character)
        beam.Color = hitOwnChar and AimViewerColours.At or AimViewerColours.Away
    end

    beam.Attachment1.WorldPosition = result.Position
    beam.Enabled = AimViewerConfig.Enabled
end

local function AimViewer_CreateBeam(character)
    if AimViewerConfig.Beams[character] then
        return AimViewerConfig.Beams[character]
    end

    local head = character:FindFirstChild("Head")
    if not head then return nil end

    local faceAttachment = head:FindFirstChild("FaceCenterAttachment")
    if not faceAttachment then return nil end

    local beam = Instance.new("Beam")
    beam.Attachment0 = faceAttachment
    beam.Enabled = false
    beam.Width0 = 0.1
    beam.Width1 = 0.1
    beam.Parent = character

    AimViewerConfig.Beams[character] = beam
    return beam
end

local function AimViewer_UpdateBeamEnabled()
    for character, beam in pairs(AimViewerConfig.Beams) do
        if beam and beam.Parent then
            local hasGun = character:FindFirstChild("GunScript", true) ~= nil
            beam.Enabled = AimViewerConfig.Enabled and hasGun
        end
    end
end

local function AimViewer_OnCharacter(character)
    if not character then return end

    local bodyEffects = character:FindFirstChild("BodyEffects")
    local mousePosVal = bodyEffects and bodyEffects:FindFirstChild("MousePos")
    if not mousePosVal then
        -- try later if components aren't ready yet
        task.spawn(function()
            local be = character:WaitForChild("BodyEffects", 5)
            if not be then return end
            local mp = be:WaitForChild("MousePos", 5)
            if not mp then return end
            AimViewer_OnCharacter(character)
        end)
        return
    end

    local beam = AimViewer_CreateBeam(character)
    if not beam then return end

    local attachment = Instance.new("Attachment")
    attachment.Parent = Terrain
    beam.Attachment1 = attachment

    -- initial update
    AimViewer_IsBeamHit(beam, mousePosVal.Value)

    mousePosVal.Changed:Connect(function()
        if not AimViewerConfig.Enabled then return end
        AimViewer_IsBeamHit(beam, mousePosVal.Value)
    end)

    character.DescendantAdded:Connect(function(desc)
        if desc.Name == "GunScript" then
            AimViewer_UpdateBeamEnabled()
        end
    end)

    character.DescendantRemoving:Connect(function(desc)
        if desc.Name == "GunScript" then
            AimViewer_UpdateBeamEnabled()
        end
    end)

    AimViewer_UpdateBeamEnabled()
end

local function AimViewer_OnPlayer(plr)
    if plr == LocalPlayer then return end

    if plr.Character then
        AimViewer_OnCharacter(plr.Character)
    end

    plr.CharacterAdded:Connect(function(char)
        AimViewer_OnCharacter(char)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    AimViewer_OnPlayer(plr)
end

Players.PlayerAdded:Connect(AimViewer_OnPlayer)

---------------------------------------------------------------------
local AimbotBodyParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
local TriggerBodyParts = AimbotBodyParts
local TriggerBusy  = false

local function ColorTableToColor3(t, default)
    if type(t) == "table" and t.R and t.G and t.B then
        return Color3.fromRGB(t.R, t.G, t.B)
    end
    return default or Color3.new(1, 1, 1)
end

local AimbotFOVCircle = Drawing.new("Circle")
AimbotFOVCircle.Visible = false

local SilentFOVCircle = Drawing.new("Circle")
SilentFOVCircle.Visible = false

local TriggerFOVCircle = Drawing.new("Circle")
TriggerFOVCircle.Visible = false

local function AimAt(hitbox, sensitivity)
    if not hitbox then return end
    local mouseLoc = UIS:GetMouseLocation()
    local dx = (hitbox[4].X - mouseLoc.X) * sensitivity
    local dy = (hitbox[4].Y - mouseLoc.Y) * sensitivity
    if mousemoverel then
        mousemoverel(dx, dy)
    end
end

local function CameraAim(targetPart, sensitivity)
    if not targetPart then return end
    local targetPos = targetPart.Position
    -- Apply prediction
    if Config.Aimbot.Prediction then
        local distance = (targetPos - Camera.CFrame.Position).Magnitude
        local travelTime = distance / math.max(Config.Prediction.ProjectileSpeed, 1)
        targetPos = SolveTrajectory(targetPos, targetPart.AssemblyLinearVelocity, travelTime, Config.Prediction.Gravity, Config.Prediction.GravityCorrection)
    end
    local camPos = Camera.CFrame.Position
    local targetDir = (targetPos - camPos).Unit
    local currentDir = Camera.CFrame.LookVector
    local smoothDir = currentDir:Lerp(targetDir, math.clamp(sensitivity, 0.01, 1))
    Camera.CFrame = CFrame.lookAt(camPos, camPos + smoothDir * 10)
end

---------------------------------------------------------------------
-- SILENT AIM: Disabled. Needs different approach — Raycast hook tanks FPS.
-- Will use per-remote FireServer hook instead (only fires on weapon use).
---------------------------------------------------------------------
local SilentTarget = nil
---------------------------------------------------------------------

---------------------------------------------------------------------
local function resetAllHitboxes()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = DEFAULT_HITBOX_SIZE
                hrp.Transparency = 0.9
                hrp.BrickColor = BrickColor.new("Really black")
                hrp.Material = Enum.Material.Neon
                hrp.CanCollide = true
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Config.Hitbox.Enabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = plr.Character.HumanoidRootPart
            hrp.Size = Vector3.new(Config.Hitbox.Size, Config.Hitbox.Size, Config.Hitbox.Size)
            hrp.Transparency = 0.7
            hrp.BrickColor = BrickColor.new("Really black")
            hrp.Material = Enum.Material.Neon
            hrp.CanCollide = false
        end
    end
end)

---------------------------------------------------------------------
-- Input handled by Linoria keybinds now

RunService.RenderStepped:Connect(function()
    local mousePos = UIS:GetMouseLocation()
    if Config.Aimbot.Enabled and Config.Aimbot.FOVRadius > 0 and Config.AimVisuals.ShowAimbotFOV then
        AimbotFOVCircle.Position = mousePos
        AimbotFOVCircle.Radius = Config.Aimbot.FOVRadius
        AimbotFOVCircle.Color = ColorTableToColor3(Config.AimVisuals.AimbotColor, Color3.fromRGB(120, 170, 255))
        AimbotFOVCircle.Thickness = Config.AimVisuals.Thickness
        AimbotFOVCircle.Filled = Config.AimVisuals.Filled
        AimbotFOVCircle.NumSides = Config.AimVisuals.Sides
        AimbotFOVCircle.Visible = true
    else
        AimbotFOVCircle.Visible = false
    end

    if Config.Silent.Enabled and Config.Silent.FOVRadius > 0 and Config.AimVisuals.ShowSilentFOV then
        SilentFOVCircle.Position = mousePos
        SilentFOVCircle.Radius = Config.Silent.FOVRadius
        SilentFOVCircle.Color = ColorTableToColor3(Config.AimVisuals.SilentColor, Color3.fromRGB(255, 170, 120))
        SilentFOVCircle.Thickness = Config.AimVisuals.Thickness
        SilentFOVCircle.Filled = Config.AimVisuals.Filled
        SilentFOVCircle.NumSides = Config.AimVisuals.Sides
        SilentFOVCircle.Visible = true
    else
        SilentFOVCircle.Visible = false
    end

    if Config.Trigger.Enabled and Config.Trigger.FOVRadius > 0 and Config.AimVisuals.ShowTriggerFOV then
        TriggerFOVCircle.Position = mousePos
        TriggerFOVCircle.Radius = Config.Trigger.FOVRadius
        TriggerFOVCircle.Color = ColorTableToColor3(Config.AimVisuals.TriggerColor, Color3.fromRGB(120, 255, 170))
        TriggerFOVCircle.Thickness = Config.AimVisuals.Thickness
        TriggerFOVCircle.Filled = Config.AimVisuals.Filled
        TriggerFOVCircle.NumSides = Config.AimVisuals.Sides
        TriggerFOVCircle.Visible = true
    else
        TriggerFOVCircle.Visible = false
    end

    local keyState = Options.AimbotKey:GetState()
    local aimbotActive = Config.Aimbot.Enabled and keyState
    if aimbotActive then
        local hit = nil
        
        -- Lock aim: reuse last target if still valid
        if Config.Aimbot.LockAim and _lockedTarget then
            local lt = _lockedTarget
            local plr, char, part = lt[1], lt[2], lt[3]
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if plr and plr.Parent and char and char.Parent and part and part.Parent and hum and hum.Health > 0 then
                if not Config.Aimbot.TeamCheck or InEnemyTeam(true, plr) then
                    if not Config.Aimbot.DistanceCheck or WithinReach(true, (part.Position - Camera.CFrame.Position).Magnitude, Config.Aimbot.DistanceLimit) then
                        local targetPos = part.Position
                        -- Apply prediction for lock aim
                        if Config.Aimbot.Prediction and Config.Prediction.ProjectileSpeed > 0 then
                            local dist = (targetPos - Camera.CFrame.Position).Magnitude
                            local travelTime = dist / Config.Prediction.ProjectileSpeed
                            targetPos = SolveTrajectory(targetPos, part.AssemblyLinearVelocity, travelTime, Config.Prediction.Gravity, Config.Prediction.GravityCorrection)
                        end
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
                        if onScreen then
                            local mousePos = UIS:GetMouseLocation()
                            local mag = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if not Config.Aimbot.VisibilityCheck or not ObjectOccluded(true, Camera.CFrame.Position, part.Position, char) then
                                hit = {plr, char, part, Vector2.new(screenPos.X, screenPos.Y)}
                            end
                        end
                    end
                end
            end
            if not hit then _lockedTarget = nil end
        end
        
        -- No locked target — find new one
        if not hit then
            hit = GetClosest(true,
                Config.Aimbot.TeamCheck,
                Config.Aimbot.VisibilityCheck,
                Config.Aimbot.DistanceCheck,
                Config.Aimbot.DistanceLimit,
                Config.Aimbot.FOVRadius,
                Config.Aimbot.PriorityList[Config.Aimbot.PriorityIndex],
                AimbotBodyParts,
                Config.Aimbot.Prediction
            )
            if hit and Config.Aimbot.LockAim then
                _lockedTarget = hit
            end
        end
        if hit then
            if Config.Aimbot.CameraAim then
                CameraAim(hit[3], Config.Aimbot.Sensitivity / 100)
                -- Auto-fire after camera updates (wait one render frame)
                if Config.Aimbot.Sensitivity >= 100 and Config.Aimbot.AutoFire and mouse1press and mouse1release then
                    RunService.RenderStepped:Wait()
                    local now = tick()
                    if not _autoFireLast or (now - _autoFireLast) >= (Config.Trigger.FireRate / 1000) then
                        _autoFireLast = now
                        mouse1press()
                        task.wait(0.01)
                        mouse1release()
                    end
                end
            else
                AimAt(hit, Config.Aimbot.Sensitivity / 100)
            end
        end
    end
    -- Clear lock when aimbot deactivates
    if not aimbotActive then
        _lockedTarget = nil
    end

    local trigKeyState = Options.TriggerKey:GetState()
    local triggerActive = Config.Trigger.Enabled and trigKeyState
    if not triggerActive or TriggerBusy then return end

    local triggerHit = GetClosest(true,
        Config.Trigger.TeamCheck,
        Config.Trigger.VisibilityCheck,
        Config.Trigger.DistanceCheck,
        Config.Trigger.DistanceLimit,
        Config.Trigger.FOVRadius,
        Config.Trigger.PriorityList[Config.Trigger.PriorityIndex],
        TriggerBodyParts,
        Config.Trigger.Prediction
    )

    if triggerHit then
        TriggerBusy = true
        task.spawn(function()
            task.wait(Config.Trigger.Delay)
            if mouse1press and mouse1release then
                mouse1press()
                if Config.Trigger.HoldMouse then
                    while Config.Trigger.Enabled and Options.TriggerKey:GetState() do
                        local again = GetClosest(true,
                            Config.Trigger.TeamCheck,
                            Config.Trigger.VisibilityCheck,
                            Config.Trigger.DistanceCheck,
                            Config.Trigger.DistanceLimit,
                            Config.Trigger.FOVRadius,
                            Config.Trigger.PriorityList[Config.Trigger.PriorityIndex],
                            TriggerBodyParts,
                            Config.Trigger.Prediction
                        )
                        if not again then break end
                        task.wait(math.max(Config.Trigger.FireRate / 1000, 0.01))
                    end
                end
                mouse1release()
            end
            task.wait(math.max(Config.Trigger.FireRate / 1000, 0.01))
            TriggerBusy = false
        end)
    end
end)

---------------------------------------------------------------------
local teleporting = false
local function getHumanoidRootPart()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function teleportToPosition(pos)
    if teleporting then return end
    local hrp = getHumanoidRootPart()
    if not hrp then return end

    teleporting = true
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.delay(0.1, function()
        teleporting = false
    end)
end

Mouse.Button1Down:Connect(function()
    if not Config.Movement.ClickTP then return end
    if not Options.ClickTPKey:GetState() then return end
    local target = Mouse.Target
    if target and target:IsDescendantOf(Workspace) then
        teleportToPosition(Mouse.Hit.p)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    teleporting = false
end)

---------------------------------------------------------------------
local CONFIG_FOLDER = "NovusCombatHub"
local DEFAULT_CONFIG_FILE = "_default.txt"

local ConfigControls = {}

local function RegToggle(toggle, tbl, key)
	table.insert(ConfigControls, { type = "toggle", c = toggle, t = tbl, k = key })
end
local function RegSlider(slider, tbl, key)
	table.insert(ConfigControls, { type = "slider", c = slider, t = tbl, k = key })
end
local function RegPicker(picker, tbl, key)
	table.insert(ConfigControls, { type = "picker", c = picker, t = tbl, k = key })
end

local function ApplyConfigToControls()
	for _, reg in ipairs(ConfigControls) do
		local ok, err = pcall(function()
			if reg.type == "toggle" then
				if reg.t[reg.k] then
					reg.c:enable()
				else
					reg.c:disable()
				end
			elseif reg.type == "slider" then
				reg.c:setValue(reg.t[reg.k])
			elseif reg.type == "picker" then
				reg.c:setColor(reg.t[reg.k])
			end
		end)
		if not ok then end
	end
end

local function Color3ToArray(c)
	if type(c) == "table" and c.R then
		return { c.R / 255, c.G / 255, c.B / 255 }
	elseif typeof(c) == "Color3" then
		return { c.R, c.G, c.B }
	end
	return { 1, 1, 1 }
end

local function Color3FromArray(a)
	if type(a) == "table" and #a == 3 then
		return Color3.new(a[1], a[2], a[3])
	end
	return Color3.new(1, 1, 1)
end

local function AimbotColorFromArray(a)
	if type(a) == "table" and #a == 3 then
		return { R = math.floor(a[1] * 255 + 0.5), G = math.floor(a[2] * 255 + 0.5), B = math.floor(a[3] * 255 + 0.5) }
	end
	return { R = 255, G = 255, B = 255 }
end

local function SerializeSettings()
	return {
		version = 1,
		Hitbox = {
			Enabled = Config.Hitbox.Enabled,
			Size = Config.Hitbox.Size,
		},
		Aimbot = {
			Enabled = Config.Aimbot.Enabled,
			AlwaysOn = Config.Aimbot.AlwaysOn,
			TeamCheck = Config.Aimbot.TeamCheck,
			DistanceCheck = Config.Aimbot.DistanceCheck,
			VisibilityCheck = Config.Aimbot.VisibilityCheck,
			Prediction = Config.Aimbot.Prediction,
			Sensitivity = Config.Aimbot.Sensitivity,
			FOVRadius = Config.Aimbot.FOVRadius,
			DistanceLimit = Config.Aimbot.DistanceLimit,
		},
		Silent = {
			Enabled = Config.Silent.Enabled,
			TeamCheck = Config.Silent.TeamCheck,
			DistanceCheck = Config.Silent.DistanceCheck,
			VisibilityCheck = Config.Silent.VisibilityCheck,
			Prediction = Config.Silent.Prediction,
			HitChance = Config.Silent.HitChance,
			FOVRadius = Config.Silent.FOVRadius,
			DistanceLimit = Config.Silent.DistanceLimit,
		},
		Trigger = {
			Enabled = Config.Trigger.Enabled,
			AlwaysOn = Config.Trigger.AlwaysOn,
			HoldMouse = Config.Trigger.HoldMouse,
			TeamCheck = Config.Trigger.TeamCheck,
			DistanceCheck = Config.Trigger.DistanceCheck,
			VisibilityCheck = Config.Trigger.VisibilityCheck,
			Prediction = Config.Trigger.Prediction,
			Delay = Config.Trigger.Delay,
			FOVRadius = Config.Trigger.FOVRadius,
			DistanceLimit = Config.Trigger.DistanceLimit,
		},
		Movement = {
			WalkSpeed = Config.Movement.WalkSpeed,
			JumpPower = Config.Movement.JumpPower,
			ClickTP = Config.Movement.ClickTP,
		},
		Prediction = {
			ProjectileSpeed = Config.Prediction.ProjectileSpeed,
			Gravity = Config.Prediction.Gravity,
			GravityCorrection = Config.Prediction.GravityCorrection,
		},
		AimVisuals = {
			ShowAimbotFOV = Config.AimVisuals.ShowAimbotFOV,
			ShowSilentFOV = Config.AimVisuals.ShowSilentFOV,
			ShowTriggerFOV = Config.AimVisuals.ShowTriggerFOV,
			AimbotColor = Color3ToArray(Config.AimVisuals.AimbotColor),
			SilentColor = Color3ToArray(Config.AimVisuals.SilentColor),
			TriggerColor = Color3ToArray(Config.AimVisuals.TriggerColor),
			Thickness = Config.AimVisuals.Thickness,
			Filled = Config.AimVisuals.Filled,
			Sides = Config.AimVisuals.Sides,
		},
		Skeleton = {
			EnemyEnabled = SkeletonConfig.EnemyEnabled,
			FriendlyEnabled = SkeletonConfig.FriendlyEnabled,
			EnemyColor = { SkeletonConfig.EnemyColor.R, SkeletonConfig.EnemyColor.G, SkeletonConfig.EnemyColor.B },
			FriendlyColor = { SkeletonConfig.FriendlyColor.R, SkeletonConfig.FriendlyColor.G, SkeletonConfig.FriendlyColor.B },
			EnemyRainbow = SkeletonConfig.EnemyRainbow,
			FriendlyRainbow = SkeletonConfig.FriendlyRainbow,
			Thickness = SkeletonConfig.Thickness,
		},
		Box3D = {
			Enabled = Box3DConfig.Enabled,
			Color = { Box3DConfig.Color.R, Box3DConfig.Color.G, Box3DConfig.Color.B },
			Transparency = Box3DConfig.Transparency,
			Thickness = Box3DConfig.Thickness,
			TeamCheck = Box3DConfig.TeamCheck,
		},
		Chams = {
			EnemyEnabled = ChamsConfig.EnemyEnabled,
			FriendlyEnabled = ChamsConfig.FriendlyEnabled,
			EnemyFillColor = { ChamsConfig.EnemyFillColor.R, ChamsConfig.EnemyFillColor.G, ChamsConfig.EnemyFillColor.B },
			EnemyOutlineColor = { ChamsConfig.EnemyOutlineColor.R, ChamsConfig.EnemyOutlineColor.G, ChamsConfig.EnemyOutlineColor.B },
			FriendlyFillColor = { ChamsConfig.FriendlyFillColor.R, ChamsConfig.FriendlyFillColor.G, ChamsConfig.FriendlyFillColor.B },
			FriendlyOutlineColor = { ChamsConfig.FriendlyOutlineColor.R, ChamsConfig.FriendlyOutlineColor.G, ChamsConfig.FriendlyOutlineColor.B },
			FillOpacity = ChamsConfig.FillOpacity,
			OutlineOpacity = ChamsConfig.OutlineOpacity,
		},
		Arrow = {
			Enabled = ArrowConfig.Enabled,
			TeamCheck = ArrowConfig.TeamCheck,
			Size = ArrowConfig.Size,
			Radius = ArrowConfig.Radius,
			Thickness = ArrowConfig.Thickness,
			Color = { ArrowConfig.Color.R, ArrowConfig.Color.G, ArrowConfig.Color.B },
		},
		NameTag = {
			Enabled = NameTagConfig.Enabled,
			ShowDistance = NameTagConfig.ShowDistance,
			UseDisplay = NameTagConfig.UseDisplay,
		},
		Radar = {
			Enabled = RadarConfig.Enabled,
			Position = { RadarInfo.Position.X, RadarInfo.Position.Y },
			Radius = RadarInfo.Radius,
			Scale = RadarInfo.Scale,
			MaxDistance = RadarInfo.MaxDistance,
			DistanceTransparency = RadarInfo.DistanceTransparency,
			TeamCheck = RadarInfo.Team_Check,
			HealthColor = RadarInfo.Health_Color,
		},
		AimViewer = {
			Enabled = AimViewerConfig.Enabled,
		},
	}
end

local function DeserializeSettings(data)
	local function safeSet(tbl, key, val)
		if tbl and val ~= nil then tbl[key] = val end
	end

	local function copyTable(src, dst, keys)
		for _, k in ipairs(keys) do
			if src[k] ~= nil then dst[k] = src[k] end
		end
	end

	local v = data

	if v.Hitbox then
		Config.Hitbox.Enabled = v.Hitbox.Enabled or Config.Hitbox.Enabled
		Config.Hitbox.Size = v.Hitbox.Size or Config.Hitbox.Size
	end

	if v.Aimbot then
		copyTable(v.Aimbot, Config.Aimbot, { "Enabled", "AlwaysOn", "TeamCheck", "DistanceCheck", "VisibilityCheck", "Prediction", "Sensitivity", "FOVRadius", "DistanceLimit" })
	end

	if v.Silent then
		copyTable(v.Silent, Config.Silent, { "Enabled", "TeamCheck", "DistanceCheck", "VisibilityCheck", "Prediction", "HitChance", "FOVRadius", "DistanceLimit" })
	end

	if v.Trigger then
		copyTable(v.Trigger, Config.Trigger, { "Enabled", "AlwaysOn", "HoldMouse", "TeamCheck", "DistanceCheck", "VisibilityCheck", "Prediction", "Delay", "FOVRadius", "DistanceLimit" })
	end

	if v.Movement then
		copyTable(v.Movement, Config.Movement, { "WalkSpeed", "JumpPower", "ClickTP" })
	end

	if v.Prediction then
		copyTable(v.Prediction, Config.Prediction, { "ProjectileSpeed", "Gravity", "GravityCorrection" })
	end

	if v.AimVisuals then
		copyTable(v.AimVisuals, Config.AimVisuals, { "ShowAimbotFOV", "ShowSilentFOV", "ShowTriggerFOV", "Thickness", "Filled", "Sides" })
		if v.AimVisuals.AimbotColor then Config.AimVisuals.AimbotColor = AimbotColorFromArray(v.AimVisuals.AimbotColor) end
		if v.AimVisuals.SilentColor then Config.AimVisuals.SilentColor = AimbotColorFromArray(v.AimVisuals.SilentColor) end
		if v.AimVisuals.TriggerColor then Config.AimVisuals.TriggerColor = AimbotColorFromArray(v.AimVisuals.TriggerColor) end
	end

	if v.Skeleton then
		copyTable(v.Skeleton, SkeletonConfig, { "EnemyEnabled", "FriendlyEnabled", "EnemyRainbow", "FriendlyRainbow", "Thickness" })
		if v.Skeleton.EnemyColor then SkeletonConfig.EnemyColor = Color3FromArray(v.Skeleton.EnemyColor) end
		if v.Skeleton.FriendlyColor then SkeletonConfig.FriendlyColor = Color3FromArray(v.Skeleton.FriendlyColor) end
	end

	if v.Box3D then
		copyTable(v.Box3D, Box3DConfig, { "Enabled", "Transparency", "Thickness", "TeamCheck" })
		if v.Box3D.Color then Box3DConfig.Color = Color3FromArray(v.Box3D.Color) end
	end

	if v.Chams then
		copyTable(v.Chams, ChamsConfig, { "EnemyEnabled", "FriendlyEnabled", "FillOpacity", "OutlineOpacity" })
		if v.Chams.EnemyFillColor then ChamsConfig.EnemyFillColor = Color3FromArray(v.Chams.EnemyFillColor) end
		if v.Chams.EnemyOutlineColor then ChamsConfig.EnemyOutlineColor = Color3FromArray(v.Chams.EnemyOutlineColor) end
		if v.Chams.FriendlyFillColor then ChamsConfig.FriendlyFillColor = Color3FromArray(v.Chams.FriendlyFillColor) end
		if v.Chams.FriendlyOutlineColor then ChamsConfig.FriendlyOutlineColor = Color3FromArray(v.Chams.FriendlyOutlineColor) end
	end

	if v.Arrow then
		copyTable(v.Arrow, ArrowConfig, { "Enabled", "TeamCheck", "Size", "Radius", "Thickness" })
		if v.Arrow.Color then ArrowConfig.Color = Color3FromArray(v.Arrow.Color) end
	end

	if v.NameTag then
		copyTable(v.NameTag, NameTagConfig, { "Enabled", "ShowDistance", "UseDisplay" })
	end

	if v.Radar then
		RadarConfig.Enabled = v.Radar.Enabled or RadarConfig.Enabled
		copyTable(v.Radar, RadarInfo, { "Radius", "Scale", "MaxDistance", "DistanceTransparency" })
		if v.Radar.TeamCheck ~= nil then RadarInfo.Team_Check = v.Radar.TeamCheck end
		if v.Radar.HealthColor ~= nil then RadarInfo.Health_Color = v.Radar.HealthColor end
		if v.Radar.Position and #v.Radar.Position == 2 then
			RadarInfo.Position = Vector2.new(v.Radar.Position[1], v.Radar.Position[2])
		end
	end

	if v.AimViewer then
		AimViewerConfig.Enabled = v.AimViewer.Enabled or AimViewerConfig.Enabled
	end

	applyWalkSpeed()
	applyJumpPower()
	ApplyConfigToControls()
end

local function GetConfigPath(name)
	return CONFIG_FOLDER .. "/" .. name .. ".json"
end

local function SaveConfig(name)
	if not isfolder(CONFIG_FOLDER) then
		makefolder(CONFIG_FOLDER)
	end

	local data = SerializeSettings()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then
		ui.notify({
			title = "Config",
			message = "Failed to encode config.",
			duration = 3,
		})
		return false
	end

	writefile(GetConfigPath(name), encoded)
	ui.notify({
		title = "Config",
		message = "Saved: " .. name,
		duration = 3,
	})
	return true
end

local function LoadConfig(name)
	local path = GetConfigPath(name)
	if not isfile(path) then
		ui.notify({
			title = "Config",
			message = "Config not found: " .. name,
			duration = 3,
		})
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(decoded) ~= "table" then
		ui.notify({
			title = "Config",
			message = "Failed to parse config.",
			duration = 3,
		})
		return false
	end

	DeserializeSettings(decoded)

	ui.notify({
		title = "Config",
		message = "Loaded: " .. name,
		duration = 3,
	})
	return true
end

local function DeleteConfig(name)
	local path = GetConfigPath(name)
	if isfile(path) then
		delfile(path)
		ui.notify({
			title = "Config",
			message = "Deleted: " .. name,
			duration = 3,
		})
	else
		ui.notify({
			title = "Config",
			message = "Config not found: " .. name,
			duration = 3,
		})
	end
end

local function SetDefaultConfig(name)
	if not isfolder(CONFIG_FOLDER) then
		makefolder(CONFIG_FOLDER)
	end
	writefile(CONFIG_FOLDER .. "/" .. DEFAULT_CONFIG_FILE, name)
end

local function ClearDefaultConfig()
	local path = CONFIG_FOLDER .. "/" .. DEFAULT_CONFIG_FILE
	if isfile(path) then
		delfile(path)
	end
end

local function GetDefaultConfig()
	local path = CONFIG_FOLDER .. "/" .. DEFAULT_CONFIG_FILE
	if isfile(path) then
		local name = readfile(path)
		if name and name ~= "" then
			return name
		end
	end
	return nil
end

---------------------------------------------------------------------


-- ============================================================================
-- LINORIA UI WIDGETS
-- ============================================================================

-- ============================================================================
-- COMBAT TAB
-- ============================================================================

-- Hitboxes
do
    local Hitboxes = Tabs.Combat:AddLeftGroupbox('Hitboxes')
    Hitboxes:AddToggle('HitboxEnabled', { Text = 'Enable Hitboxes', Default = Config.Hitbox.Enabled })
    Hitboxes:AddInput('HitboxSize', { Default = tostring(Config.Hitbox.Size), Numeric = true, Finished = true, Text = 'Hitbox Size', Placeholder = tostring(Config.Hitbox.Size) })

    Toggles.HitboxEnabled:OnChanged(function() Config.Hitbox.Enabled = Toggles.HitboxEnabled.Value end)
    Options.HitboxSize:OnChanged(function() Config.Hitbox.Size = tonumber(Options.HitboxSize.Value) end)
end

-- Aimbot
do
    local Aimbot = Tabs.Combat:AddRightGroupbox('Aimbot')
    Aimbot:AddToggle('AimbotEnabled', { Text = 'Aimbot', Default = Config.Aimbot.Enabled })
    Toggles.AimbotEnabled:AddKeyPicker('AimbotKey', { Default = 'None', Mode = 'Hold', SyncToggleState = false, Text = 'Aimbot' })
    local AimDep = Aimbot:AddDependencyBox()
    AimDep:AddToggle('AimbotCameraAim', { Text = 'Camera Aim (snap)', Default = Config.Aimbot.CameraAim })
    AimDep:AddToggle('AimbotLockAim', { Text = 'Lock Aim', Default = Config.Aimbot.LockAim })
    AimDep:AddToggle('AimbotTeamCheck', { Text = 'Team Check', Default = Config.Aimbot.TeamCheck })
    AimDep:AddToggle('AimbotDistCheck', { Text = 'Distance Check', Default = Config.Aimbot.DistanceCheck })
    AimDep:AddToggle('AimbotVisCheck', { Text = 'Visibility Check', Default = Config.Aimbot.VisibilityCheck })
    AimDep:AddToggle('AimbotPred', { Text = 'Prediction', Default = Config.Aimbot.Prediction })
    AimDep:AddInput('AimbotSens', { Default = tostring(Config.Aimbot.Sensitivity), Numeric = true, Finished = true, Text = 'Sensitivity', Placeholder = tostring(Config.Aimbot.Sensitivity) })
    AimDep:AddToggle('AimbotAutoFire', { Text = 'Auto-Fire (100% sens only)', Default = false })
    AimDep:AddInput('AimbotFOV', { Default = tostring(Config.Aimbot.FOVRadius), Numeric = true, Finished = true, Text = 'FOV Radius', Placeholder = tostring(Config.Aimbot.FOVRadius) })
    AimDep:AddInput('AimbotDist', { Default = tostring(Config.Aimbot.DistanceLimit), Numeric = true, Finished = true, Text = 'Distance Limit', Placeholder = tostring(Config.Aimbot.DistanceLimit) })
    AimDep:AddDropdown('AimbotPriority', { Text = 'Priority', Default = 'Closest', Values = {'Closest', 'Head', 'HumanoidRootPart', 'Random'} })

    AimDep:SetupDependencies({{ Toggles.AimbotEnabled, true }})

    local function wireAim()
        local c = Config.Aimbot
        c.Enabled = Toggles.AimbotEnabled.Value
        c.CameraAim = Toggles.AimbotCameraAim.Value
        c.AutoFire = Toggles.AimbotAutoFire.Value
        c.LockAim = Toggles.AimbotLockAim.Value
        c.TeamCheck = Toggles.AimbotTeamCheck.Value
        c.DistanceCheck = Toggles.AimbotDistCheck.Value
        c.VisibilityCheck = Toggles.AimbotVisCheck.Value
        c.Prediction = Toggles.AimbotPred.Value
        c.Sensitivity = tonumber(Options.AimbotSens.Value)
        c.FOVRadius = tonumber(Options.AimbotFOV.Value)
        c.DistanceLimit = tonumber(Options.AimbotDist.Value)
        c.PriorityIndex = table.find({'Closest', 'Head', 'HumanoidRootPart', 'Random'}, Options.AimbotPriority.Value) or 1
        c.PriorityList = {'Closest', 'Head', 'HumanoidRootPart', 'Random'}
    end
    for _, ev in ipairs({Toggles.AimbotEnabled, Toggles.AimbotCameraAim, Toggles.AimbotAutoFire, Toggles.AimbotLockAim, Toggles.AimbotTeamCheck, Toggles.AimbotDistCheck, Toggles.AimbotVisCheck, Toggles.AimbotPred}) do ev:OnChanged(wireAim) end
    for _, ev in ipairs({Options.AimbotSens, Options.AimbotFOV, Options.AimbotDist, Options.AimbotPriority}) do ev:OnChanged(wireAim) end
end

-- Trigger Bot
do
    local Trigger = Tabs.Combat:AddLeftGroupbox('Trigger Bot')
    Trigger:AddToggle('TriggerEnabled', { Text = 'Trigger Bot', Default = Config.Trigger.Enabled })
    Toggles.TriggerEnabled:AddKeyPicker('TriggerKey', { Default = 'None', Mode = 'Hold', SyncToggleState = false, Text = 'Trigger Bot' })
    local TrigDep = Trigger:AddDependencyBox()
    TrigDep:AddToggle('TriggerTeamCheck', { Text = 'Team Check', Default = Config.Trigger.TeamCheck })
    TrigDep:AddToggle('TriggerHoldClick', { Text = 'Hold Click', Default = Config.Trigger.HoldMouse })
    TrigDep:AddToggle('TriggerDistCheck', { Text = 'Distance Check', Default = Config.Trigger.DistanceCheck })
    TrigDep:AddToggle('TriggerVisCheck', { Text = 'Visibility Check', Default = Config.Trigger.VisibilityCheck })
    TrigDep:AddToggle('TriggerPred', { Text = 'Prediction', Default = Config.Trigger.Prediction })
    TrigDep:AddInput('TriggerDelay', { Default = tostring(Config.Trigger.Delay * 1000), Numeric = true, Finished = true, Text = 'Delay', Placeholder = tostring(Config.Trigger.Delay * 1000) })
    TrigDep:AddInput('TriggerFireRate', { Default = tostring(Config.Trigger.FireRate), Numeric = true, Finished = true, Text = 'Fire Rate (ms)', Placeholder = tostring(Config.Trigger.FireRate) })
    TrigDep:AddInput('TriggerFOV', { Default = tostring(Config.Trigger.FOVRadius), Numeric = true, Finished = true, Text = 'FOV Radius', Placeholder = tostring(Config.Trigger.FOVRadius) })
    TrigDep:AddInput('TriggerDist', { Default = tostring(Config.Trigger.DistanceLimit), Numeric = true, Finished = true, Text = 'Distance Limit', Placeholder = tostring(Config.Trigger.DistanceLimit) })
    TrigDep:AddDropdown('TriggerPriority', { Text = 'Priority', Default = 'Closest', Values = {'Closest', 'Head', 'HumanoidRootPart', 'Random'} })

    TrigDep:SetupDependencies({{ Toggles.TriggerEnabled, true }})

    local function wireTrig()
        local c = Config.Trigger
        c.Enabled = Toggles.TriggerEnabled.Value
        c.HoldMouse = Toggles.TriggerHoldClick.Value
        c.TeamCheck = Toggles.TriggerTeamCheck.Value
        c.DistanceCheck = Toggles.TriggerDistCheck.Value
        c.VisibilityCheck = Toggles.TriggerVisCheck.Value
        c.Prediction = Toggles.TriggerPred.Value
        c.Delay = tonumber(Options.TriggerDelay.Value) / 1000
        c.FireRate = tonumber(Options.TriggerFireRate.Value)
        c.FOVRadius = tonumber(Options.TriggerFOV.Value)
        c.DistanceLimit = tonumber(Options.TriggerDist.Value)
        c.PriorityIndex = table.find({'Closest', 'Head', 'HumanoidRootPart', 'Random'}, Options.TriggerPriority.Value) or 1
        c.PriorityList = {'Closest', 'Head', 'HumanoidRootPart', 'Random'}
    end
    for _, ev in ipairs({Toggles.TriggerEnabled, Toggles.TriggerHoldClick, Toggles.TriggerTeamCheck, Toggles.TriggerDistCheck, Toggles.TriggerVisCheck, Toggles.TriggerPred}) do ev:OnChanged(wireTrig) end
    for _, ev in ipairs({Options.TriggerDelay, Options.TriggerFireRate, Options.TriggerFOV, Options.TriggerDist, Options.TriggerPriority}) do ev:OnChanged(wireTrig) end
end

-- Prediction settings
do
    local Pred = Tabs.Combat:AddRightGroupbox('Prediction')
    Pred:AddInput('PredSpeed', { Default = tostring(Config.Prediction.ProjectileSpeed), Numeric = true, Finished = true, Text = 'Projectile Speed', Placeholder = tostring(Config.Prediction.ProjectileSpeed) })
    Pred:AddInput('PredGrav', { Default = tostring(Config.Prediction.Gravity), Numeric = true, Finished = true, Text = 'Gravity', Placeholder = tostring(Config.Prediction.Gravity) })

    Options.PredSpeed:OnChanged(function() Config.Prediction.ProjectileSpeed = tonumber(Options.PredSpeed.Value) end)
    Options.PredGrav:OnChanged(function() Config.Prediction.Gravity = tonumber(Options.PredGrav.Value) / 100 end)
end

-- ============================================================================
-- MOVEMENT TAB
-- ============================================================================

do
    local Move = Tabs.Movement:AddLeftGroupbox('Movement')
    Move:AddInput('WalkSpeed', { Default = tostring(Config.Movement.WalkSpeed), Numeric = true, Finished = true, Text = 'WalkSpeed', Placeholder = tostring(Config.Movement.WalkSpeed) })
    Move:AddInput('JumpPower', { Default = tostring(Config.Movement.JumpPower), Numeric = true, Finished = true, Text = 'JumpPower', Placeholder = tostring(Config.Movement.JumpPower) })
    Move:AddToggle('ClickTP', { Text = 'Click Teleport', Default = Config.Movement.ClickTP })
    Toggles.ClickTP:AddKeyPicker('ClickTPKey', { Default = 'None', Mode = 'Hold', SyncToggleState = false, Text = 'ClickTP' })

    Options.WalkSpeed:OnChanged(function()
        Config.Movement.WalkSpeed = tonumber(Options.WalkSpeed.Value)
        applyWalkSpeed()
    end)
    Options.JumpPower:OnChanged(function()
        Config.Movement.JumpPower = tonumber(Options.JumpPower.Value)
        applyJumpPower()
    end)
    Toggles.ClickTP:OnChanged(function() Config.Movement.ClickTP = Toggles.ClickTP.Value end)
end

-- ============================================================================
-- VISUALS TAB
-- ============================================================================

-- ESP (Enemy)
do
    local EnemyESP = Tabs.Visuals:AddLeftGroupbox('Enemy ESP')
    EnemyESP:AddToggle('ESPEnemyEnabled', { Text = 'Enabled', Default = Sense.teamSettings.enemy.enabled })
    local EspEnDep = EnemyESP:AddDependencyBox()
    EspEnDep:AddToggle('ESPEnemyBox', { Text = 'Box', Default = Sense.teamSettings.enemy.box })
    EspEnDep:AddToggle('ESPEnemyHealth', { Text = 'Health Bar', Default = Sense.teamSettings.enemy.healthBar })
    EspEnDep:AddToggle('ESPEnemyName', { Text = 'Name', Default = Sense.teamSettings.enemy.name })
    EspEnDep:AddToggle('ESPEnemyDist', { Text = 'Distance', Default = Sense.teamSettings.enemy.distance })
    EspEnDep:AddToggle('ESPEnemyTracer', { Text = 'Tracer', Default = Sense.teamSettings.enemy.tracer })
    EspEnDep:AddToggle('ESPEnemyChams', { Text = 'Chams', Default = Sense.teamSettings.enemy.chams })
    EspEnDep:AddLabel('Box Color'):AddColorPicker('ESPEnemyColor', { Default = Sense.teamSettings.enemy.boxColor[1] })
    EspEnDep:SetupDependencies({{ Toggles.ESPEnemyEnabled, true }})

    local function wireEnemyESP()
        local s = Sense.teamSettings.enemy
        s.enabled = Toggles.ESPEnemyEnabled.Value
        s.box = Toggles.ESPEnemyBox.Value
        s.healthBar = Toggles.ESPEnemyHealth.Value
        s.name = Toggles.ESPEnemyName.Value
        s.distance = Toggles.ESPEnemyDist.Value
        s.tracer = Toggles.ESPEnemyTracer.Value
        s.chams = Toggles.ESPEnemyChams.Value
        s.boxColor[1] = Options.ESPEnemyColor.Value
    end
    for _, ev in ipairs({Toggles.ESPEnemyEnabled, Toggles.ESPEnemyBox, Toggles.ESPEnemyHealth, Toggles.ESPEnemyName, Toggles.ESPEnemyDist, Toggles.ESPEnemyTracer, Toggles.ESPEnemyChams}) do ev:OnChanged(wireEnemyESP) end
    Options.ESPEnemyColor:OnChanged(wireEnemyESP)
end

-- ESP (Friendly)
do
    local FriendESP = Tabs.Visuals:AddRightGroupbox('Friendly ESP')
    FriendESP:AddToggle('ESPFriendEnabled', { Text = 'Enabled', Default = Sense.teamSettings.friendly.enabled })
    local EspFrDep = FriendESP:AddDependencyBox()
    EspFrDep:AddToggle('ESPFriendBox', { Text = 'Box', Default = Sense.teamSettings.friendly.box })
    EspFrDep:AddToggle('ESPFriendHealth', { Text = 'Health Bar', Default = Sense.teamSettings.friendly.healthBar })
    EspFrDep:AddToggle('ESPFriendName', { Text = 'Name', Default = Sense.teamSettings.friendly.name })
    EspFrDep:AddToggle('ESPFriendDist', { Text = 'Distance', Default = Sense.teamSettings.friendly.distance })
    EspFrDep:AddToggle('ESPFriendTracer', { Text = 'Tracer', Default = Sense.teamSettings.friendly.tracer })
    EspFrDep:AddToggle('ESPFriendChams', { Text = 'Chams', Default = Sense.teamSettings.friendly.chams })
    EspFrDep:AddLabel('Box Color'):AddColorPicker('ESPFriendColor', { Default = Sense.teamSettings.friendly.boxColor[1] })
    EspFrDep:SetupDependencies({{ Toggles.ESPFriendEnabled, true }})

    local function wireFriendESP()
        local s = Sense.teamSettings.friendly
        s.enabled = Toggles.ESPFriendEnabled.Value
        s.box = Toggles.ESPFriendBox.Value
        s.healthBar = Toggles.ESPFriendHealth.Value
        s.name = Toggles.ESPFriendName.Value
        s.distance = Toggles.ESPFriendDist.Value
        s.tracer = Toggles.ESPFriendTracer.Value
        s.chams = Toggles.ESPFriendChams.Value
        s.boxColor[1] = Options.ESPFriendColor.Value
    end
    for _, ev in ipairs({Toggles.ESPFriendEnabled, Toggles.ESPFriendBox, Toggles.ESPFriendHealth, Toggles.ESPFriendName, Toggles.ESPFriendDist, Toggles.ESPFriendTracer, Toggles.ESPFriendChams}) do ev:OnChanged(wireFriendESP) end
    Options.ESPFriendColor:OnChanged(wireFriendESP)
end

-- FOV Circles
do
    local FOV = Tabs.Visuals:AddRightGroupbox('FOV Circles')
    FOV:AddToggle('FOVAimbot', { Text = 'Show Aimbot FOV', Default = Config.AimVisuals.ShowAimbotFOV })
    FOV:AddToggle('FOVSilent', { Text = 'Show Silent FOV', Default = Config.AimVisuals.ShowSilentFOV })
    FOV:AddToggle('FOVTrigger', { Text = 'Show Trigger FOV', Default = Config.AimVisuals.ShowTriggerFOV })
    FOV:AddToggle('FOVFilled', { Text = 'Filled Circles', Default = Config.AimVisuals.Filled })
    FOV:AddInput('FOVThickness', { Default = tostring(Config.AimVisuals.Thickness), Numeric = true, Finished = true, Text = 'Thickness', Placeholder = tostring(Config.AimVisuals.Thickness) })
    FOV:AddInput('FOVSides', { Default = tostring(Config.AimVisuals.Sides), Numeric = true, Finished = true, Text = 'Sides', Placeholder = tostring(Config.AimVisuals.Sides) })
    FOV:AddLabel('Aimbot Color'):AddColorPicker('FOVAimbotColor', { Default = Color3.fromRGB(Config.AimVisuals.AimbotColor.R, Config.AimVisuals.AimbotColor.G, Config.AimVisuals.AimbotColor.B) })
    FOV:AddLabel('Silent Color'):AddColorPicker('FOVSilentColor', { Default = Color3.fromRGB(Config.AimVisuals.SilentColor.R, Config.AimVisuals.SilentColor.G, Config.AimVisuals.SilentColor.B) })
    FOV:AddLabel('Trigger Color'):AddColorPicker('FOVTriggerColor', { Default = Color3.fromRGB(Config.AimVisuals.TriggerColor.R, Config.AimVisuals.TriggerColor.G, Config.AimVisuals.TriggerColor.B) })

    local function wireFOV()
        Config.AimVisuals.ShowAimbotFOV = Toggles.FOVAimbot.Value
        Config.AimVisuals.ShowSilentFOV = Toggles.FOVSilent.Value
        Config.AimVisuals.ShowTriggerFOV = Toggles.FOVTrigger.Value
        Config.AimVisuals.Filled = Toggles.FOVFilled.Value
        Config.AimVisuals.Thickness = tonumber(Options.FOVThickness.Value)
        Config.AimVisuals.Sides = tonumber(Options.FOVSides.Value)
        local ac = Options.FOVAimbotColor.Value; Config.AimVisuals.AimbotColor = {R = ac.R*255, G = ac.G*255, B = ac.B*255}
        local sc = Options.FOVSilentColor.Value; Config.AimVisuals.SilentColor = {R = sc.R*255, G = sc.G*255, B = sc.B*255}
        local tc = Options.FOVTriggerColor.Value; Config.AimVisuals.TriggerColor = {R = tc.R*255, G = tc.G*255, B = tc.B*255}
    end
    for _, ev in ipairs({Toggles.FOVAimbot, Toggles.FOVSilent, Toggles.FOVTrigger, Toggles.FOVFilled, Options.FOVThickness, Options.FOVSides, Options.FOVAimbotColor, Options.FOVSilentColor, Options.FOVTriggerColor}) do ev:OnChanged(wireFOV) end
end

-- Off-screen Arrows
do
    local Arrows = Tabs.Visuals:AddLeftGroupbox('Off-screen Arrows')
    Arrows:AddToggle('ArrowsEnabled', { Text = 'Enabled', Default = ArrowConfig.Enabled })
    local ArrDep = Arrows:AddDependencyBox()
    ArrDep:AddToggle('ArrowsTeamCheck', { Text = 'Team Check', Default = ArrowConfig.TeamCheck })
    ArrDep:AddInput('ArrowsSize', { Default = tostring(ArrowConfig.Size), Numeric = true, Finished = true, Text = 'Size', Placeholder = tostring(ArrowConfig.Size) })
    ArrDep:AddInput('ArrowsRadius', { Default = tostring(ArrowConfig.Radius), Numeric = true, Finished = true, Text = 'Radius', Placeholder = tostring(ArrowConfig.Radius) })
    ArrDep:AddInput('ArrowsThickness', { Default = tostring(ArrowConfig.Thickness), Numeric = true, Finished = true, Text = 'Thickness', Placeholder = tostring(ArrowConfig.Thickness) })
    ArrDep:AddLabel('Color'):AddColorPicker('ArrowsColor', { Default = ArrowConfig.Color })
    ArrDep:SetupDependencies({{ Toggles.ArrowsEnabled, true }})

    local function wireArrow()
        ArrowConfig.Enabled = Toggles.ArrowsEnabled.Value
        ArrowConfig.TeamCheck = Toggles.ArrowsTeamCheck.Value
        ArrowConfig.Size = tonumber(Options.ArrowsSize.Value)
        ArrowConfig.Radius = tonumber(Options.ArrowsRadius.Value)
        ArrowConfig.Thickness = tonumber(Options.ArrowsThickness.Value)
        ArrowConfig.Color = Options.ArrowsColor.Value
    end
    for _, ev in ipairs({Toggles.ArrowsEnabled, Toggles.ArrowsTeamCheck, Options.ArrowsSize, Options.ArrowsRadius, Options.ArrowsThickness, Options.ArrowsColor}) do ev:OnChanged(wireArrow) end
end

-- Radar
do
    local Radar = Tabs.Visuals:AddLeftGroupbox('Radar')
    Radar:AddToggle('RadarEnabled', { Text = 'Radar Enabled', Default = RadarConfig.Enabled })
    local RadDep = Radar:AddDependencyBox()
    RadDep:AddToggle('RadarTeamCheck', { Text = 'Team Check', Default = RadarInfo.Team_Check })
    RadDep:AddToggle('RadarHealthColor', { Text = 'Health Color', Default = RadarInfo.Health_Color })
    RadDep:AddInput('RadarRadius', { Default = tostring(RadarInfo.Radius), Numeric = true, Finished = true, Text = 'Radar Size', Placeholder = tostring(RadarInfo.Radius) })
    RadDep:AddInput('RadarScale', { Default = tostring(RadarInfo.Scale), Numeric = true, Finished = true, Text = 'Scale', Placeholder = tostring(RadarInfo.Scale) })
    RadDep:AddInput('RadarMaxDist', { Default = tostring(RadarInfo.MaxDistance), Numeric = true, Finished = true, Text = 'Max Distance', Placeholder = tostring(RadarInfo.MaxDistance) })
    RadDep:SetupDependencies({{ Toggles.RadarEnabled, true }})

    local function wireRadar()
        RadarConfig.Enabled = Toggles.RadarEnabled.Value
        RadarInfo.Team_Check = Toggles.RadarTeamCheck.Value
        RadarInfo.Health_Color = Toggles.RadarHealthColor.Value
        RadarInfo.Radius = tonumber(Options.RadarRadius.Value)
        RadarInfo.Scale = tonumber(Options.RadarScale.Value)
        RadarInfo.MaxDistance = tonumber(Options.RadarMaxDist.Value)
    end
    for _, ev in ipairs({Toggles.RadarEnabled, Toggles.RadarTeamCheck, Toggles.RadarHealthColor, Options.RadarRadius, Options.RadarScale, Options.RadarMaxDist}) do ev:OnChanged(wireRadar) end
end

-- ============================================================================
-- SETTINGS TAB (Theme, Config, Keybind — all built-in via addons)
-- ============================================================================

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('NovusHub')
SaveManager:SetFolder('NovusHub/' .. tostring(game.PlaceId))

-- Config section on the right
SaveManager:BuildConfigSection(Tabs.Settings)

-- Theme section on the left
ThemeManager:ApplyToTab(Tabs.Settings)

-- Menu keybind
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })
MenuGroup:AddButton('Unload / Reload', function()
    -- Show feedback before cleanup
    Library:Notify('Unloading... cleanup in progress', 2)
    
    -- Destroy all ESP overlays (Highlights, BillboardGuis, etc.)
    if VisualsGui and VisualsGui.Parent then
        for _, child in ipairs(VisualsGui:GetChildren()) do
            pcall(function() child:Destroy() end)
        end
    end
    
    -- Disconnect key tracked connections
    if SkeletonConfig.Connection then
        pcall(function() SkeletonConfig.Connection:Disconnect() end)
        SkeletonConfig.Connection = nil
    end
    
    -- Clear skeleton/box3D/arrow/radar drawing tables
    for plr, lines in pairs(SkeletonConfig.Lines) do
        for _, l in ipairs(lines) do pcall(function() l:Remove() end) end
    end
    SkeletonConfig.Lines = {}
    for _, l in ipairs(Box3D_Lines) do pcall(function() l:Remove() end) end
    Box3D_Lines = {}
    for _, q in ipairs(Box3D_Quads) do pcall(function() q:Remove() end) end
    Box3D_Quads = {}
    for _, tri in pairs(ArrowInstances) do pcall(function() tri:Remove() end) end
    ArrowInstances = {}
    
    -- Unload Sense ESP
    pcall(function() Sense.Unload() end)
    
    -- Reset combat toggles
    Config.Aimbot.Enabled = false
    Config.Trigger.Enabled = false
    Config.Hitbox.Enabled = false
    ArrowConfig.Enabled = false
    RadarConfig.Enabled = false
    
    -- Unload Linoria window
    Library:Unload()
    Library:Notify('Cleanup complete — re-inject to reload', 5)
end)
Library.ToggleKeybind = Options.MenuKeybind

-- Load auto config
SaveManager:LoadAutoloadConfig()

-- Cleanup
Library:OnUnload(function()
    Library.Unloaded = true
end)


Sense.Load()