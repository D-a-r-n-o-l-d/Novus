local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local VisualsGui = S.VisualsGui

local module = {}
local tags = {}
local conn

local function getOrCreate(plr, char)
	local head = char:FindFirstChild("Head")
	if not head then return nil end

	local gui = tags[plr]
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Parvus2NameTag"
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
		tags[plr] = gui
	else
		gui.Adornee = head
	end

	return gui
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, gui in pairs(tags) do
		gui.Enabled = false
	end
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.NameTagEnabled.Value

		for plr, gui in pairs(tags) do
			if not Players:FindFirstChild(plr.Name)
				or not plr.Character
				or not plr.Character:FindFirstChild("Head")
				or not enabled then
				gui.Enabled = false
			end
		end

		if not enabled then return end

		local localChar = LocalPlayer.Character
		local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local head = char and char:FindFirstChild("Head")
			if not (char and hum and hum.Health > 0 and head) then
				if tags[plr] then tags[plr].Enabled = false end
				continue
			end

			local gui = getOrCreate(plr, char)
			local label = gui and gui:FindFirstChild("Text")
			if not (gui and label) then continue end

			gui.Enabled = true

			local baseName
			if Toggles.NameTagUseDisplay.Value and plr.DisplayName and plr.DisplayName ~= "" then
				if plr.DisplayName ~= plr.Name then
					baseName = plr.Name .. " (@" .. plr.DisplayName .. ")"
				else
					baseName = plr.Name
				end
			else
				baseName = plr.Name
			end

			local text = baseName
			if Toggles.NameTagShowDistance.Value and localHRP then
				local dist = (head.Position - localHRP.Position).Magnitude
				text = string.format("%s [%dm]", text, math.floor(dist + 0.5))
			end

			label.Text = text

			local relation = S.GetRelation(plr)
			if relation == "friendly" then
				label.TextColor3 = Color3.fromRGB(0, 255, 0)
			else
				label.TextColor3 = Color3.fromRGB(255, 80, 80)
			end
		end
	end)
end

return module
