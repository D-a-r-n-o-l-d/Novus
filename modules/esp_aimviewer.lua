local S = _G.Parvus2.Shared
local Players = S.Players
local LocalPlayer = S.LocalPlayer
local Workspace = S.Workspace

local module = {}
local beams = {}
local charConns = {}

local Terrain = Workspace.Terrain

local aimColours = {
	At = ColorSequence.new(Color3.new(1, 0, 0)),
	Away = ColorSequence.new(Color3.new(0, 1, 0)),
}

local function isBeamHit(beam, mousePos)
	if not beam or not beam.Attachment0 or not beam.Attachment1 then return end

	local character = LocalPlayer.Character
	local origin = beam.Attachment0.WorldPosition
	local direction = mousePos - origin

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character, Workspace.CurrentCamera }

	local result = Workspace:Raycast(origin, direction * 2, raycastParams)
	if not result then
		beam.Color = aimColours.Away
		beam.Attachment1.WorldPosition = mousePos
		beam.Enabled = Toggles.AimViewerEnabled.Value
		return
	end

	if character then
		local hitOwnChar = result.Instance:IsDescendantOf(character)
		beam.Color = hitOwnChar and aimColours.At or aimColours.Away
	end

	beam.Attachment1.WorldPosition = result.Position
	beam.Enabled = Toggles.AimViewerEnabled.Value
end

local function createBeam(character)
	if beams[character] then return beams[character] end

	local head = character:FindFirstChild("Head")
	if not head then return nil end

	local faceAttachment = head:FindFirstChild("FaceCenterAttachment")
	if not faceAttachment then return nil end

	local beam = Instance.new("Beam")
	beam.Attachment0 = faceAttachment
	beam.Enabled = false
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.Parent = character

	beams[character] = beam
	return beam
end

local function updateBeamEnabled()
	for character, beam in pairs(beams) do
		if beam and beam.Parent then
			local hasGun = character:FindFirstChild("GunScript", true) ~= nil
			beam.Enabled = Toggles.AimViewerEnabled.Value and hasGun
		end
	end
end

local function onCharacter(character)
	if not character then return end

	local bodyEffects = character:FindFirstChild("BodyEffects")
	local mousePosVal = bodyEffects and bodyEffects:FindFirstChild("MousePos")
	if not mousePosVal then
		task.spawn(function()
			local be = character:WaitForChild("BodyEffects", 5)
			if not be then return end
			local mp = be:WaitForChild("MousePos", 5)
			if not mp then return end
			onCharacter(character)
		end)
		return
	end

	local beam = createBeam(character)
	if not beam then return end

	local attachment = Instance.new("Attachment")
	attachment.Parent = Terrain
	beam.Attachment1 = attachment

	isBeamHit(beam, mousePosVal.Value)

	local conn = mousePosVal.Changed:Connect(function()
		if not Toggles.AimViewerEnabled.Value then return end
		isBeamHit(beam, mousePosVal.Value)
	end)
	if not charConns[character] then charConns[character] = {} end
	table.insert(charConns[character], conn)

	local gunConn = character.DescendantAdded:Connect(function(desc)
		if desc.Name == "GunScript" then
			updateBeamEnabled()
		end
	end)
	table.insert(charConns[character], gunConn)

	local remConn = character.DescendantRemoving:Connect(function(desc)
		if desc.Name == "GunScript" then
			updateBeamEnabled()
		end
	end)
	table.insert(charConns[character], remConn)

	updateBeamEnabled()
end

local function onPlayer(plr)
	if plr == LocalPlayer then return end

	if plr.Character then
		onCharacter(plr.Character)
	end

	plr.CharacterAdded:Connect(function(char)
		onCharacter(char)
	end)
end



local playerAddedConn

function module.start()
	if playerAddedConn then return end

	for _, plr in ipairs(Players:GetPlayers()) do
		onPlayer(plr)
	end
	playerAddedConn = Players.PlayerAdded:Connect(onPlayer)
end

function module.stop()
	for _, beam in pairs(beams) do
		if beam and beam.Parent then
			beam:Destroy()
		end
	end
	beams = {}
	for _, conns in pairs(charConns) do
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
	end
	charConns = {}
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
end

return module
