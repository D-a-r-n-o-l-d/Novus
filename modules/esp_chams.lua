local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local VisualsGui = S.VisualsGui

local module = {}
local chams = {}
local conn

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, h in pairs(chams) do
		h:Destroy()
	end
	chams = {}
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local relation = S.GetRelation(plr)
			local wantEnemy = relation == "enemy" and Toggles.ChamsEnemyEnabled.Value
			local wantFriendly = relation == "friendly" and Toggles.ChamsFriendlyEnabled.Value

			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and hum and hum.Health > 0 and (wantEnemy or wantFriendly)) then
				if chams[plr] then
					chams[plr]:Destroy()
					chams[plr] = nil
				end
				continue
			end

			local highlight = chams[plr]
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "Parvus2Cham"
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = VisualsGui
				chams[plr] = highlight
			end

			highlight.Adornee = char
			if relation == "enemy" then
				highlight.FillColor = Options.ChamsEnemyFillColor.Value
				highlight.OutlineColor = Options.ChamsEnemyOutlineColor.Value
			else
				highlight.FillColor = Options.ChamsFriendlyFillColor.Value
				highlight.OutlineColor = Options.ChamsFriendlyOutlineColor.Value
			end
			highlight.FillTransparency = 1 - (Options.ChamsFillOpacity.Value / 100)
			highlight.OutlineTransparency = 1 - (Options.ChamsOutlineOpacity.Value / 100)
			highlight.Enabled = true
		end

		for plr, h in pairs(chams) do
			if not Players:FindFirstChild(plr.Name) or not plr.Character then
				h:Destroy()
				chams[plr] = nil
			end
		end
	end)
end

return module
