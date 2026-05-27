return function(Tabs)
	local cb = Tabs.Combat

	local aimbot = cb:AddLeftGroupbox('Aimbot')
	local aimToggle = aimbot:AddToggle('AimbotEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Legit aimbot with smooth mouse movement',
	})
	aimToggle:AddKeyPicker('AimbotKey', {
		Default = 'Q',
		Mode = 'Toggle',
		Text = 'Aimbot',
		NoUI = false,
	})

	aimbot:AddToggle('AimbotAlwaysOn', {
		Text = 'Always On',
		Default = false,
		Tooltip = 'Aim without holding RMB',
	})

	aimbot:AddToggle('AimbotTeamCheck', {
		Text = 'Team Check',
		Default = false,
	})

	aimbot:AddToggle('AimbotDistanceCheck', {
		Text = 'Distance Check',
		Default = true,
	})

	aimbot:AddToggle('AimbotVisibilityCheck', {
		Text = 'Visibility Check',
		Default = false,
	})

	aimbot:AddToggle('AimbotPrediction', {
		Text = 'Prediction',
		Default = false,
		Tooltip = 'Lead targets based on velocity',
	})

	aimbot:AddSlider('AimbotSensitivity', {
		Text = 'Sensitivity',
		Default = 20,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})

	aimbot:AddSlider('AimbotFOV', {
		Text = 'FOV',
		Default = 100,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Suffix = ' px',
	})

	aimbot:AddSlider('AimbotDistanceLimit', {
		Text = 'Distance Limit',
		Default = 250,
		Min = 25,
		Max = 1000,
		Rounding = 0,
		Suffix = ' studs',
	})

	aimbot:AddDropdown('AimbotPriority', {
		Text = 'Priority',
		Values = {'Closest', 'Head', 'HumanoidRootPart'},
		Default = 'Closest',
		AllowNull = false,
	})

	local trig = cb:AddLeftGroupbox('Trigger Bot')
	local trigToggle = trig:AddToggle('TriggerEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Auto-fire when target enters FOV',
	})
	trigToggle:AddKeyPicker('TriggerKey', {
		Default = 'R',
		Mode = 'Toggle',
		Text = 'Trigger',
		NoUI = false,
	})

	trig:AddToggle('TriggerAlwaysOn', {
		Text = 'Always On',
		Default = false,
	})

	trig:AddToggle('TriggerHoldMouse', {
		Text = 'Hold Mouse',
		Default = false,
	})

	trig:AddToggle('TriggerTeamCheck', {
		Text = 'Team Check',
		Default = false,
	})

	trig:AddToggle('TriggerDistanceCheck', {
		Text = 'Distance Check',
		Default = true,
	})

	trig:AddToggle('TriggerVisibilityCheck', {
		Text = 'Visibility Check',
		Default = false,
	})

	trig:AddToggle('TriggerPrediction', {
		Text = 'Prediction',
		Default = false,
	})

	trig:AddSlider('TriggerDelay', {
		Text = 'Delay',
		Default = 150,
		Min = 0,
		Max = 1000,
		Rounding = 0,
		Suffix = ' ms',
	})

	trig:AddSlider('TriggerFOV', {
		Text = 'FOV',
		Default = 25,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Suffix = ' px',
	})

	trig:AddSlider('TriggerDistanceLimit', {
		Text = 'Distance Limit',
		Default = 250,
		Min = 25,
		Max = 1000,
		Rounding = 0,
		Suffix = ' studs',
	})

	trig:AddDropdown('TriggerPriority', {
		Text = 'Priority',
		Values = {'Closest', 'Head', 'HumanoidRootPart', 'Random'},
		Default = 'Closest',
		AllowNull = false,
	})

	local hitboxGrp = cb:AddRightGroupbox('Hitboxes')
	hitboxGrp:AddToggle('HitboxEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Enlarge enemy hitboxes',
	})
	hitboxGrp:AddSlider('HitboxSize', {
		Text = 'Size',
		Default = 20,
		Min = 5,
		Max = 200,
		Rounding = 0,
		Suffix = ' studs',
	})

	local pred = cb:AddRightGroupbox('Prediction')
	pred:AddSlider('PredictionProjectileSpeed', {
		Text = 'Projectile Speed',
		Default = 1000,
		Min = 100,
		Max = 10000,
		Rounding = 0,
		Suffix = ' studs/s',
	})
	pred:AddSlider('PredictionGravity', {
		Text = 'Gravity',
		Default = 196.2,
		Min = 0,
		Max = 400,
		Rounding = 1,
	})
	pred:AddSlider('PredictionGravityCorrection', {
		Text = 'Gravity Correction',
		Default = 2,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local vb = Tabs.Visuals

	local skel = vb:AddLeftGroupbox('Skeleton ESP')
	local skEnToggle = skel:AddToggle('SkeletonEnemyEnabled', {
		Text = 'Enemy Skeleton',
		Default = false,
	})
	skEnToggle:AddKeyPicker('SkeletonKey', {
		Default = 'K',
		Mode = 'Toggle',
		Text = 'Skeleton',
		NoUI = false,
	})
	skel:AddToggle('SkeletonEnemyRainbow', {
		Text = 'Enemy Rainbow',
		Default = false,
	})
	skel:AddLabel('Enemy Color'):AddColorPicker('SkeletonEnemyColor', {
		Default = Color3.fromRGB(0, 255, 255),
		Title = 'Enemy Skeleton',
	})
	skel:AddToggle('SkeletonFriendlyEnabled', {
		Text = 'Friendly Skeleton',
		Default = false,
	})
	skel:AddToggle('SkeletonFriendlyRainbow', {
		Text = 'Friendly Rainbow',
		Default = false,
	})
	skel:AddLabel('Friendly Color'):AddColorPicker('SkeletonFriendlyColor', {
		Default = Color3.fromRGB(0, 255, 0),
		Title = 'Friendly Skeleton',
	})
	skel:AddSlider('SkeletonThickness', {
		Text = 'Thickness',
		Default = 1.5,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local box3d = vb:AddLeftGroupbox('3D Box ESP')
	local bx3Toggle = box3d:AddToggle('Box3DEnabled', {
		Text = 'Enabled',
		Default = false,
	})
	bx3Toggle:AddKeyPicker('Box3DKey', {
		Default = 'F6',
		Mode = 'Toggle',
		Text = '3D Boxes',
		NoUI = false,
	})
	box3d:AddToggle('Box3DTeamCheck', {
		Text = 'Team Check',
		Default = true,
	})
	box3d:AddLabel('Color'):AddColorPicker('Box3DColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = '3D Box',
	})
	box3d:AddSlider('Box3DOpacity', {
		Text = 'Opacity',
		Default = 25,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	box3d:AddSlider('Box3DThickness', {
		Text = 'Thickness',
		Default = 1,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local fovGrp = vb:AddRightGroupbox('FOV Circles')
	fovGrp:AddToggle('FOVAimbotVisible', {
		Text = 'Show Aimbot FOV',
		Default = true,
	})
	fovGrp:AddToggle('FOVTriggerVisible', {
		Text = 'Show Trigger FOV',
		Default = true,
	})
	fovGrp:AddToggle('FOVFilled', {
		Text = 'Filled Circles',
		Default = false,
	})
	fovGrp:AddSlider('FOVThickness', {
		Text = 'Thickness',
		Default = 1.5,
		Min = 1,
		Max = 10,
		Rounding = 1,
	})
	fovGrp:AddSlider('FOVSides', {
		Text = 'Circle Sides',
		Default = 40,
		Min = 10,
		Max = 100,
		Rounding = 0,
	})
	fovGrp:AddLabel('Aimbot Color'):AddColorPicker('FOVAimbotColor', {
		Default = Color3.fromRGB(120, 170, 255),
		Title = 'Aimbot FOV',
	})
	fovGrp:AddLabel('Trigger Color'):AddColorPicker('FOVTriggerColor', {
		Default = Color3.fromRGB(120, 255, 170),
		Title = 'Trigger FOV',
	})

	local chams = vb:AddLeftGroupbox('Chams')
	local chEnToggle = chams:AddToggle('ChamsEnemyEnabled', {
		Text = 'Enemy Chams',
		Default = false,
	})
	chEnToggle:AddKeyPicker('ChamsKey', {
		Default = 'F5',
		Mode = 'Toggle',
		Text = 'Chams',
		NoUI = false,
	})
	chams:AddLabel('Enemy Fill'):AddColorPicker('ChamsEnemyFillColor', {
		Default = Color3.fromRGB(255, 0, 0),
		Title = 'Enemy Fill',
	})
	chams:AddLabel('Enemy Outline'):AddColorPicker('ChamsEnemyOutlineColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Enemy Outline',
	})
	chams:AddToggle('ChamsFriendlyEnabled', {
		Text = 'Friendly Chams',
		Default = false,
	})
	chams:AddLabel('Friendly Fill'):AddColorPicker('ChamsFriendlyFillColor', {
		Default = Color3.fromRGB(0, 255, 0),
		Title = 'Friendly Fill',
	})
	chams:AddLabel('Friendly Outline'):AddColorPicker('ChamsFriendlyOutlineColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Friendly Outline',
	})
	chams:AddSlider('ChamsFillOpacity', {
		Text = 'Fill Opacity',
		Default = 60,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	chams:AddSlider('ChamsOutlineOpacity', {
		Text = 'Outline Opacity',
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})

	local arrowGrp = vb:AddRightGroupbox('Arrows & Nametags')
	arrowGrp:AddToggle('ArrowEnabled', {
		Text = 'Off-screen Arrows',
		Default = false,
	})
	arrowGrp:AddToggle('ArrowTeamCheck', {
		Text = 'Arrow Team Check',
		Default = true,
	})
	arrowGrp:AddSlider('ArrowSize', {
		Text = 'Arrow Size',
		Default = 18,
		Min = 8,
		Max = 40,
		Rounding = 0,
		Suffix = ' px',
	})
	arrowGrp:AddSlider('ArrowRadius', {
		Text = 'Arrow Radius',
		Default = 220,
		Min = 50,
		Max = 400,
		Rounding = 0,
		Suffix = ' px',
	})
	arrowGrp:AddSlider('ArrowThickness', {
		Text = 'Arrow Thickness',
		Default = 2,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})
	arrowGrp:AddLabel('Color'):AddColorPicker('ArrowColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Arrow',
	})
	arrowGrp:AddDivider()
	arrowGrp:AddToggle('NameTagEnabled', {
		Text = 'Enable Name Tags',
		Default = false,
	})
	arrowGrp:AddToggle('NameTagShowDistance', {
		Text = 'Show Distance',
		Default = true,
	})
	arrowGrp:AddToggle('NameTagUseDisplay', {
		Text = 'Use Display Name',
		Default = true,
	})

	local radarGrp = vb:AddRightGroupbox('Radar & Aim Viewer')
	local radToggle = radarGrp:AddToggle('RadarEnabled', {
		Text = 'Enable Radar',
		Default = false,
	})
	radToggle:AddKeyPicker('RadarKey', {
		Default = 'F4',
		Mode = 'Toggle',
		Text = 'Radar',
		NoUI = false,
	})
	radarGrp:AddToggle('RadarTeamCheck', {
		Text = 'Team Check',
		Default = true,
	})
	radarGrp:AddToggle('RadarHealthColor', {
		Text = 'Health Color',
		Default = true,
	})
	radarGrp:AddSlider('RadarRadius', {
		Text = 'Radius',
		Default = 100,
		Min = 50,
		Max = 400,
		Rounding = 0,
		Suffix = ' px',
	})
	radarGrp:AddSlider('RadarScale', {
		Text = 'Scale',
		Default = 1,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})
	radarGrp:AddSlider('RadarMaxDistance', {
		Text = 'Max Distance',
		Default = 1000,
		Min = 100,
		Max = 2000,
		Rounding = 0,
		Suffix = ' studs',
	})
	radarGrp:AddSlider('RadarDistanceTransparency', {
		Text = 'Distance Fade',
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	radarGrp:AddDivider()
	local avToggle = radarGrp:AddToggle('AimViewerEnabled', {
		Text = 'Enable Aim Viewer',
		Default = false,
	})
	avToggle:AddKeyPicker('AimViewerKey', {
		Default = 'F7',
		Mode = 'Toggle',
		Text = 'Aim Viewer',
		NoUI = false,
	})

	local mb = Tabs.Movement

	local mov = mb:AddLeftGroupbox('Movement')
	mov:AddSlider('MovementWalkSpeed', {
		Text = 'WalkSpeed',
		Default = 16,
		Min = 8,
		Max = 300,
		Rounding = 0,
		Suffix = ' studs/s',
	})
	mov:AddSlider('MovementJumpPower', {
		Text = 'JumpPower',
		Default = 50,
		Min = 25,
		Max = 500,
		Rounding = 0,
	})
	mov:AddToggle('MovementClickTP', {
		Text = 'Click Teleport',
		Default = false,
		Tooltip = 'Left-click to teleport',
	})

	local sb = Tabs.Settings
	local menuGroup = sb:AddLeftGroupbox('Menu')
	menuGroup:AddLabel('Menu key'):AddKeyPicker('MenuKeybind', {
		Default = 'End',
		Mode = 'Toggle',
		Text = 'Menu keybind',
		NoUI = true,
	})
end
