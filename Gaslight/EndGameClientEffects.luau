-- GASLIGHT End game client effects
-- Ryan/tile127
-- Does the end game effects that trigger the GASLIGHT AI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FADE_TIME = 1.5
local SOUND_PATH = "EndGameStartSound"

local eventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local effectsEvent = eventsFolder:WaitForChild("EndGameEffectsEvent") :: RemoteEvent
local sound = SoundService:FindFirstChild(SOUND_PATH)

local screenGui = PlayerGui:FindFirstChild("EndGameEffectsGui")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EndGameEffectsGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 1001
	screenGui.IgnoreGuiInset = true

	local blackFrame = Instance.new("Frame")
	blackFrame.Name = "BlackoutFrame"
	blackFrame.Size = UDim2.new(1, 0, 1, 0)
	blackFrame.Position = UDim2.new(0, 0, 0, 0)
	blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackFrame.BorderSizePixel = 0
	blackFrame.BackgroundTransparency = 1.0
	blackFrame.Visible = false
	blackFrame.Parent = screenGui

	screenGui.Parent = PlayerGui
	--print("[EndGameClient] Effects GUI created.")
end

local blackoutFrame = screenGui:WaitForChild("BlackoutFrame")

effectsEvent.OnClientEvent:Connect(function(action: string)
	if action == "Start" then
		--print("[EndGameClient] Received Start command.")
		blackoutFrame.BackgroundTransparency = 1.0
		blackoutFrame.Visible = true

		local fadeInTween = TweenService:Create(blackoutFrame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.0 })
		fadeInTween:Play()

		if sound then
			sound:Play()
			--print("[EndGameClient] Playing sound: " .. sound.Name)
		else
			warn("[EndGameClient] EndGameSound not found at path: " .. SOUND_PATH)
		end

	elseif action == "End" then
		--print("[EndGameClient] Received End command.")
		local fadeOutTween = TweenService:Create(blackoutFrame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1.0 })
		fadeOutTween:Play()

		-- task.delay(FADE_TIME, function()
		--    if sound and sound.IsPlaying then sound:Stop() end
		--    blackoutFrame.Visible = false
		-- end)
		fadeOutTween.Completed:Once(function()
			blackoutFrame.Visible = false
			if sound and sound.IsPlaying then sound:Stop() end
		end)


	else
		warn("[EndGameClient] Received unknown action:", action)
	end
end)