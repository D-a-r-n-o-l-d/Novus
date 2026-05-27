local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer

local module = {}
local conn

local DEFAULT_SIZE = Vector3.new(2, 2, 2)

local function resetAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Size = DEFAULT_SIZE
				hrp.Transparency = 0.9
				hrp.BrickColor = BrickColor.new("Really black")
				hrp.Material = Enum.Material.Neon
				hrp.CanCollide = true
			end
		end
	end
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	resetAll()
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.HitboxEnabled.Value then return end

		local size = Vector3.new(Options.HitboxSize.Value, Options.HitboxSize.Value, Options.HitboxSize.Value)

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = plr.Character.HumanoidRootPart
				hrp.Size = size
				hrp.Transparency = 0.7
				hrp.BrickColor = BrickColor.new("Really black")
				hrp.Material = Enum.Material.Neon
				hrp.CanCollide = false
			end
		end
	end)
end

return module
