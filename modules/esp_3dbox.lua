local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local LocalPlayer = S.LocalPlayer

local module = {}
local boxLines = {}
local boxQuads = {}
local conn

local function newLine()
	local l = Drawing.new("Line")
	l.Visible = false
	return l
end

local function newQuad()
	local q = Drawing.new("Quad")
	q.Visible = false
	q.Filled = true
	return q
end

local function clearAll()
	for _, l in ipairs(boxLines) do l:Remove() end
	for _, q in ipairs(boxQuads) do q:Remove() end
	boxLines = {}
	boxQuads = {}
end

local function getCorners(cf, size)
	local half = size / 2
	local corners = {}
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				table.insert(corners, (cf * CFrame.new(half * Vector3.new(x, y, z))).Position)
			end
		end
	end
	return corners
end

local function drawQuad(a, b, c, d, color, transparency)
	local sa, va = Camera:WorldToViewportPoint(a)
	local sb, vb = Camera:WorldToViewportPoint(b)
	local sc, vc = Camera:WorldToViewportPoint(c)
	local sd, vd = Camera:WorldToViewportPoint(d)
	if not (va or vb or vc or vd) then return end
	local q = newQuad()
	q.Color = color
	q.Transparency = 1 - transparency
	q.PointA = Vector2.new(sa.X, sa.Y)
	q.PointB = Vector2.new(sb.X, sb.Y)
	q.PointC = Vector2.new(sc.X, sc.Y)
	q.PointD = Vector2.new(sd.X, sd.Y)
	q.Visible = true
	table.insert(boxQuads, q)
end

local function drawLine(p0, p1, color, transparency, thickness)
	local s0, v0 = Camera:WorldToViewportPoint(p0)
	local s1, v1 = Camera:WorldToViewportPoint(p1)
	if not (v0 or v1) then return end
	local l = newLine()
	l.Color = color
	l.Thickness = thickness
	l.Transparency = 1 - transparency
	l.From = Vector2.new(s0.X, s0.Y)
	l.To = Vector2.new(s1.X, s1.Y)
	l.Visible = true
	table.insert(boxLines, l)
end

local function isEnemy(plr, teamCheck)
	if plr == LocalPlayer then return false end
	if not teamCheck then return true end
	if not LocalPlayer.Team or not plr.Team then return true end
	return plr.Team ~= LocalPlayer.Team
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	clearAll()
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.Box3DEnabled.Value then
			if #boxLines > 0 or #boxQuads > 0 then
				clearAll()
			end
			return
		end

		clearAll()

		local color = Options.Box3DColor.Value
		local transparency = Options.Box3DOpacity.Value / 100
		local thickness = Options.Box3DThickness.Value
		local teamCheck = Toggles.Box3DTeamCheck.Value

		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemy(plr, teamCheck) and plr.Character then
				local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local fake = {
						CFrame = hrp.CFrame * CFrame.new(0, -0.5, 0),
						Size = Vector3.new(3, 5, 3)
					}
					local c = getCorners(fake.CFrame, fake.Size)

					drawLine(c[1], c[2], color, transparency, thickness)
					drawLine(c[2], c[6], color, transparency, thickness)
					drawLine(c[6], c[5], color, transparency, thickness)
					drawLine(c[5], c[1], color, transparency, thickness)
					drawQuad(c[1], c[2], c[6], c[5], color, transparency)

					drawLine(c[1], c[3], color, transparency, thickness)
					drawLine(c[2], c[4], color, transparency, thickness)
					drawLine(c[6], c[8], color, transparency, thickness)
					drawLine(c[5], c[7], color, transparency, thickness)

					drawQuad(c[2], c[4], c[8], c[6], color, transparency)
					drawQuad(c[1], c[2], c[4], c[3], color, transparency)
					drawQuad(c[1], c[5], c[7], c[3], color, transparency)
					drawQuad(c[5], c[7], c[8], c[6], color, transparency)

					drawLine(c[3], c[4], color, transparency, thickness)
					drawLine(c[4], c[8], color, transparency, thickness)
					drawLine(c[8], c[7], color, transparency, thickness)
					drawLine(c[7], c[3], color, transparency, thickness)
					drawQuad(c[3], c[4], c[8], c[7], color, transparency)
				end
			end
		end
	end)
end

return module
