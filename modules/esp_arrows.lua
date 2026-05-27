local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local LocalPlayer = S.LocalPlayer

local module = {}
local arrows = {}
local conn

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, tri in pairs(arrows) do
		tri:Remove()
	end
	arrows = {}
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.ArrowEnabled.Value then
			for _, tri in pairs(arrows) do
				tri.Visible = false
			end
			return
		end

		local center = S.GetScreenCenter()
		local viewport = Camera.ViewportSize
		local teamCheck = Toggles.ArrowTeamCheck.Value
		local size = Options.ArrowSize.Value
		local radius = Options.ArrowRadius.Value
		local thickness = Options.ArrowThickness.Value
		local color = Options.ArrowColor.Value

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local relation = S.GetRelation(plr)
			if teamCheck and relation ~= "enemy" then
				if arrows[plr] then
					arrows[plr].Visible = false
				end
				continue
			end

			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and hrp and hum and hum.Health > 0) then
				if arrows[plr] then
					arrows[plr]:Remove()
					arrows[plr] = nil
				end
				continue
			end

			local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
			local screenPos = Vector2.new(pos.X, pos.Y)

			local tri = arrows[plr]
			if not tri then
				tri = Drawing.new("Triangle")
				tri.Filled = true
				tri.Thickness = thickness
				tri.Transparency = 0
				arrows[plr] = tri
			end

			if onScreen and pos.Z > 0
				and screenPos.X >= 0 and screenPos.X <= viewport.X
				and screenPos.Y >= 0 and screenPos.Y <= viewport.Y then
				tri.Visible = false
			else
				local dir = screenPos - center
				if dir.Magnitude == 0 then dir = Vector2.new(0, -1) end
				dir = dir.Unit
				local baseDir = Vector2.new(-dir.Y, dir.X)
				local tip = center + dir * radius
				local baseHalf = size / 2

				tri.PointA = tip
				tri.PointB = tip - dir * size + baseDir * baseHalf
				tri.PointC = tip - dir * size - baseDir * baseHalf
				tri.Color = color
				tri.Thickness = thickness
				tri.Visible = true
			end
		end

		for plr, tri in pairs(arrows) do
			if not Players:FindFirstChild(plr.Name) then
				tri:Remove()
				arrows[plr] = nil
			end
		end
	end)
end

return module
