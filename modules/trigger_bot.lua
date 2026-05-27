local S = _G.Parvus2.Shared
local T = _G.Parvus2.Targeting
local RunService = S.RunService

local module = {}
local conn
local busy = false

local bodyParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	busy = false
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.TriggerEnabled.Value
		if not enabled then return end

		local alwaysOn = Toggles.TriggerAlwaysOn.Value
		if not (alwaysOn or S.RMBHeld) then return end

		if busy then return end

		local hit = T.GetClosest(true,
			Toggles.TriggerTeamCheck.Value,
			Toggles.TriggerVisibilityCheck.Value,
			Toggles.TriggerDistanceCheck.Value,
			Options.TriggerDistanceLimit.Value,
			Options.TriggerFOV.Value,
			Options.TriggerPriority.Value,
			bodyParts,
			Toggles.TriggerPrediction.Value,
			Options.PredictionProjectileSpeed.Value,
			Options.PredictionGravity.Value,
			Options.PredictionGravityCorrection.Value
		)

		if not hit then return end

		busy = true
		local delay = Options.TriggerDelay.Value / 1000
		task.spawn(function()
			task.wait(delay)
			if not enabled then
				busy = false
				return
			end
			S.mouse1press()
			if Toggles.TriggerHoldMouse.Value then
				while enabled and (alwaysOn or S.RMBHeld) do
					local again = T.GetClosest(true,
						Toggles.TriggerTeamCheck.Value,
						Toggles.TriggerVisibilityCheck.Value,
						Toggles.TriggerDistanceCheck.Value,
						Options.TriggerDistanceLimit.Value,
						Options.TriggerFOV.Value,
						Options.TriggerPriority.Value,
						bodyParts,
						Toggles.TriggerPrediction.Value,
						Options.PredictionProjectileSpeed.Value,
						Options.PredictionGravity.Value,
						Options.PredictionGravityCorrection.Value
					)
					if not again then break end
					RunService.RenderStepped:Wait()
				end
			end
			S.mouse1release()
			busy = false
		end)
	end)
end

return module
