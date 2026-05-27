local S = _G.Parvus2.Shared
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local Mouse = S.Mouse
local Workspace = S.Workspace

local module = {}
local teleporting = false
local conn, charConn, mouseConn

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

local function applyWalkSpeed()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = Options.MovementWalkSpeed.Value end
end

local function applyJumpPower()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = Options.MovementJumpPower.Value end
end

function module.stop()
	if conn then conn:Disconnect() conn = nil end
	if charConn then charConn:Disconnect() charConn = nil end
	if mouseConn then mouseConn:Disconnect() mouseConn = nil end
	teleporting = false
end

function module.start()
	if charConn then return end

	conn = RunService.RenderStepped:Connect(function()
		applyWalkSpeed()
		applyJumpPower()
	end)

	charConn = LocalPlayer.CharacterAdded:Connect(function()
		applyWalkSpeed()
		applyJumpPower()
		teleporting = false
	end)

	mouseConn = Mouse.Button1Down:Connect(function()
		if not Toggles.MovementClickTP.Value then return end
		local target = Mouse.Target
		if target and target:IsDescendantOf(Workspace) then
			teleportToPosition(Mouse.Hit.p)
		end
	end)
end

return module
