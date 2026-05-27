local S = _G.Parvus2.Shared
local T = _G.Parvus2.Targeting
local RunService = S.RunService
local UIS = S.UIS

local module = {}
local conn

local bodyParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.AimbotEnabled.Value
		if not enabled then return end

		local alwaysOn = Toggles.AimbotAlwaysOn.Value
		if not (alwaysOn or S.RMBHeld) then return end

		local hit = T.GetClosest(true,
			Toggles.AimbotTeamCheck.Value,
			Toggles.AimbotVisibilityCheck.Value,
			Toggles.AimbotDistanceCheck.Value,
			Options.AimbotDistanceLimit.Value,
			Options.AimbotFOV.Value,
			Options.AimbotPriority.Value,
			bodyParts,
			Toggles.AimbotPrediction.Value,
			Options.PredictionProjectileSpeed.Value,
			Options.PredictionGravity.Value,
			Options.PredictionGravityCorrection.Value
		)

		if not hit then return end

		local mouseLoc = UIS:GetMouseLocation()
		local sensitivity = Options.AimbotSensitivity.Value / 100
		local dx = (hit[4].X - mouseLoc.X) * sensitivity
		local dy = (hit[4].Y - mouseLoc.Y) * sensitivity
		S.mousemoverel(dx, dy)
	end)
end

return module
