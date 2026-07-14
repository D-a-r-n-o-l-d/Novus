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
