local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local UIS = S.UIS
local GuiService = S.GuiService
local LocalPlayer = S.LocalPlayer
local Mouse = S.Mouse

local module = {}
local dots, conns = {}, {}
local conn, playerAddedConn, hoverDot
local dragging = false
local dragOffset = Vector2.new(0, 0)
local inset = GuiService:GetGuiInset()
local radarPos = Vector2.new(200, 200)

local bg, border, localDot

local HealthLerp = S.LerpColor(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))

local function newCircle(transparency, color, radius, filled, thickness)
	local c = Drawing.new("Circle")
	c.Transparency = transparency
	c.Color = color
	c.Visible = false
	c.Thickness = thickness
	c.Position = Vector2.new(0, 0)
	c.Radius = radius
	c.NumSides = math.clamp(radius * 55 / 100, 10, 75)
	c.Filled = filled
	return c
end

local function getRelative(pos)
	local char = LocalPlayer.Character
	if char and char.PrimaryPart then
		local pmpart = char.PrimaryPart
		local camerapos = Vector3.new(Camera.CFrame.Position.X, pmpart.Position.Y, Camera.CFrame.Position.Z)
		local newcf = CFrame.new(pmpart.Position, camerapos)
		local r = newcf:PointToObjectSpace(pos)
		return r.X, r.Z
	end
	return 0, 0
end

local function updateRadarVisuals(radius)
	if bg then
		bg.Position = radarPos
		bg.Radius = radius
		bg.Visible = Toggles.RadarEnabled.Value
		border.Position = radarPos
		border.Radius = radius
		border.Visible = Toggles.RadarEnabled.Value
		if localDot then
			localDot.Visible = Toggles.RadarEnabled.Value
			localDot.Color = Color3.fromRGB(255, 255, 255)
			localDot.PointA = radarPos + Vector2.new(0, -6)
			localDot.PointB = radarPos + Vector2.new(-3, 6)
			localDot.PointC = radarPos + Vector2.new(3, 6)
		end
	end
end

local function placeDot(plr)
	local dot = newCircle(0, Color3.fromRGB(60, 170, 255), 3, true, 1)

	local dotConn = RunService.RenderStepped:Connect(function()
		if not Toggles.RadarEnabled.Value then
			dot.Visible = false
			return
		end

		local char = plr.Character
		if char and char:FindFirstChildOfClass("Humanoid") and char.PrimaryPart
			and char:FindFirstChildOfClass("Humanoid").Health > 0 then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local scale = Options.RadarScale.Value
			local relx, rely = getRelative(char.PrimaryPart.Position)
			local newpos = radarPos - Vector2.new(relx * scale, rely * scale)

			local dist3d = 0
			local localChar = LocalPlayer.Character
			local localRoot = localChar and localChar.PrimaryPart
			local maxDist = Options.RadarMaxDistance.Value
			if localRoot then
				dist3d = (char.PrimaryPart.Position - localRoot.Position).Magnitude
				if maxDist > 0 and dist3d > maxDist then
					dot.Visible = false
					return
				end
			end

			local radius = Options.RadarRadius.Value
			if (newpos - radarPos).Magnitude < radius - 2 then
				dot.Radius = 3
				dot.Position = newpos
				dot.Visible = true
			else
				local dist = (radarPos - newpos).Magnitude
				local calc = (radarPos - newpos).Unit * (dist - radius)
				local inside = Vector2.new(newpos.X + calc.X, newpos.Y + calc.Y)
				dot.Radius = 2
				dot.Position = inside
				dot.Visible = true
			end

			if Toggles.RadarTeamCheck.Value then
				if plr.TeamColor == LocalPlayer.TeamColor then
					dot.Color = Color3.fromRGB(0, 255, 0)
				else
					dot.Color = Color3.fromRGB(255, 0, 0)
				end
			else
				dot.Color = Color3.fromRGB(60, 170, 255)
			end

			if Toggles.RadarHealthColor.Value then
				dot.Color = HealthLerp(hum.Health / hum.MaxHealth)
			end

			local fade = Options.RadarDistanceTransparency.Value / 100
			if fade > 0 and maxDist > 0 then
				local t = math.clamp(dist3d / maxDist, 0, 1)
				dot.Transparency = t * fade
			else
				dot.Transparency = 0
			end
		else
			dot.Visible = false
			if not Players:FindFirstChild(plr.Name) then
				dot:Remove()
				dotConn:Disconnect()
			end
		end
	end)

	table.insert(conns, dotConn)
	table.insert(dots, dot)
end

function module.stop()
	if conn then conn:Disconnect() conn = nil end
	if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn = nil end
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	for _, d in ipairs(dots) do d:Remove() end
	dots = {}
	if bg then bg:Remove() bg = nil end
	if border then border:Remove() border = nil end
	if localDot then localDot:Remove() localDot = nil end
	if hoverDot then hoverDot:Remove() hoverDot = nil end
end

function module.start()
	if conn then return end

	bg = newCircle(0.1, Color3.fromRGB(10, 10, 10), 100, true, 1)
	border = newCircle(0.25, Color3.fromRGB(75, 75, 75), 100, false, 3)

	localDot = Drawing.new("Triangle")
	localDot.Visible = false
	localDot.Thickness = 1
	localDot.Filled = true
	localDot.Color = Color3.fromRGB(255, 255, 255)

	conn = RunService.RenderStepped:Connect(function()
		updateRadarVisuals(Options.RadarRadius.Value)
	end)

	for _, v in pairs(Players:GetPlayers()) do
		if v ~= LocalPlayer then
			placeDot(v)
		end
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(v)
		if v ~= LocalPlayer then
			placeDot(v)
		end
	end)

	hoverDot = newCircle(1, Color3.fromRGB(255, 255, 255), 3, true, 1)

	local hoverConn = RunService.RenderStepped:Connect(function()
		if not Toggles.RadarEnabled.Value then
			hoverDot.Visible = false
			return
		end
		local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
		if (mousePos - radarPos).Magnitude < Options.RadarRadius.Value then
			hoverDot.Position = mousePos
			hoverDot.Visible = true
		else
			hoverDot.Visible = false
		end
		if dragging then
			radarPos = Vector2.new(Mouse.X, Mouse.Y) + dragOffset
		end
	end)
	table.insert(conns, hoverConn)

	local dragConn = UIS.InputBegan:Connect(function(input)
		if not Toggles.RadarEnabled.Value then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
			if (mousePos - radarPos).Magnitude < Options.RadarRadius.Value then
				dragOffset = radarPos - Vector2.new(Mouse.X, Mouse.Y)
				dragging = true
			end
		end
	end)
	table.insert(conns, dragConn)

	local endConn = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	table.insert(conns, endConn)
end

return module
