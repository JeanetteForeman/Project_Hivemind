-- GASLIGHT End Game Monitor
-- Ryan/tile127
-- Handles the end game AI interaction

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local GaslightFolder = ServerScriptService:WaitForChild("Gaslight")
local Core = require(GaslightFolder:WaitForChild("GaslightCore"))

local TRIGGER_EVENT_NAME = "TriggerEndGame"
local EFFECTS_EVENT_NAME = "EndGameEffectsEvent"
local NANOBOT_MODEL_NAME = "NanobotV2"
local PEDESTAL_NAME = "EndGamePedestal"
local TELEPORT_TARGET_NAME = "EndGameTeleportTarget"

local BLACK_SCREEN_WAIT = 2.0
local TELEPORT_WAIT = 0.5
local REVEAL_TWEEN_TIME = 3.0

local isEndGameActive = false
local endGameBotId = nil

local eventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local triggerEvent = eventsFolder:FindFirstChild(TRIGGER_EVENT_NAME)
local effectsEvent = eventsFolder:FindFirstChild(EFFECTS_EVENT_NAME)

if not triggerEvent or not triggerEvent:IsA("BindableEvent") then
	warn("[EndGameManager] Trigger BindableEvent '"..TRIGGER_EVENT_NAME.."' not found in ReplicatedStorage/RemoteEvents!")
	return
end
if not effectsEvent or not effectsEvent:IsA("RemoteEvent") then
	warn("[EndGameManager] Effects RemoteEvent '"..EFFECTS_EVENT_NAME.."' not found in ReplicatedStorage/RemoteEvents!")
	return
end

local function startEndGameSequence()
	--print("[EndGame] Trigger received.")
	if isEndGameActive then
		warn("[EndGame] Sequence triggered but already active.")
		return
	end
	--print("[EndGame] Starting end game sequence...")
	isEndGameActive = true

	if not Core or not Core.init then
		warn("[EndGame] GaslightCore is not available or not initialized. AI bot will not start.")
	end

	--print("[EndGame] Step 1: Triggering black screen and sound for clients.")
	for _, player in ipairs(Players:GetPlayers()) do
		effectsEvent:FireClient(player, "Start")
	end
	task.wait(BLACK_SCREEN_WAIT)

	--print("[EndGame] Step 2: Teleporting players.")
	local teleportTarget = Workspace.ReferenceParts:FindFirstChild(TELEPORT_TARGET_NAME)
	local targetCFrame: CFrame

	if teleportTarget then
		if teleportTarget:IsA("BasePart") then
			targetCFrame = teleportTarget.CFrame * CFrame.new(0, 3, 0)
		elseif teleportTarget:IsA("Model") and teleportTarget.PrimaryPart then
			targetCFrame = teleportTarget.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
		elseif teleportTarget:IsA("CFrameValue") then
			targetCFrame = teleportTarget.Value
		else
			warn("[EndGame] ".. TELEPORT_TARGET_NAME .. " found, but is not a Part, Model with PrimaryPart, or CFrameValue. Using default spawn.") -- Simple warn
			targetCFrame = CFrame.new(0, 10, 0)
		end
	else
		warn("[EndGame] ".. TELEPORT_TARGET_NAME .. " not found! Using default spawn CFrame.")
		targetCFrame = CFrame.new(0, 10, 0)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = targetCFrame
		else
			warn("[EndGame] Could not find HumanoidRootPart for player: " .. player.Name)
		end
	end
	task.wait(TELEPORT_WAIT)

	--print("[EndGame] Step 3: Fading out black screen.")
	for _, player in ipairs(Players:GetPlayers()) do
		effectsEvent:FireClient(player, "End")
	end

	--print("[EndGame] Step 4: Revealing the Nanobot.")
	-- *** Use WaitForChild for the template ***
	local nanobotTemplate = ServerStorage:WaitForChild(NANOBOT_MODEL_NAME, 10)
	local pedestal = Workspace.ReferenceParts:FindFirstChild(PEDESTAL_NAME).EndGamePedestal

	if not nanobotTemplate then
		warn("[EndGame] Nanobot template '"..NANOBOT_MODEL_NAME.."' not found in ServerStorage after waiting!")
		isEndGameActive = false
		return
	end
	if not pedestal or not pedestal:IsA("BasePart") then
		warn("[EndGame] Pedestal part '"..PEDESTAL_NAME.."' not found or not a BasePart in Workspace!")
		isEndGameActive = false
		return
	end

	local nanobotModel = nanobotTemplate:Clone()
	nanobotModel.Name = "EndGameAI_Nanobot"

	local primaryPart = nanobotModel.PrimaryPart
	if not primaryPart then
		warn("[EndGame] Nanobot model '"..NANOBOT_MODEL_NAME.."' does not have a PrimaryPart set!")
		nanobotModel:Destroy()
		isEndGameActive = false
		return
	end
	

	local pedestalTop = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	local endCFrame = CFrame.new(pedestalTop + Vector3.new(0, primaryPart.Size.Y / 2 + 0.1, 0))
	local startCFrame = endCFrame * CFrame.new(0, -15, 0)

	primaryPart.Anchored = true
	nanobotModel:PivotTo(startCFrame)
	nanobotModel.Parent = Workspace

	local tweenInfo = TweenInfo.new(REVEAL_TWEEN_TIME, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	local tween = TweenService:Create(primaryPart, tweenInfo, { CFrame = endCFrame })

	tween:Play()
	--print("[EndGame] Nanobot reveal tween started.")
	tween.Completed:Wait()
	--print("[EndGame] Nanobot reveal tween finished.")
	-- primaryPart.Anchored = false

	--print("[EndGame] Step 5: Starting the GASLIGHT AI Bot.")

	if Core and Core.registerBot then
		local botConfigOverrides = {
			-- SystemPrompt = "...",
			InitialGreeting = "Why should I let you off this island?",
			ListenMode = "Proximity",
			ActivationRadius = 10
		}

		local success, botIdOrErr = pcall(function()
			return Core:registerBot(nanobotModel, botConfigOverrides)
		end)

		if success then
			endGameBotId = botIdOrErr
			--print("[EndGame] End game AI bot registered successfully with ID: " .. endGameBotId)
		else
			warn("[EndGame] Failed to register end game AI bot: " .. tostring(botIdOrErr))
		end
	else
		warn("[EndGame] GaslightCore not available. Could not start AI bot.")
	end

	--print("[EndGame] End game sequence complete.")
end

local endGameTriggerPart = game.Workspace:WaitForChild("ReferenceParts"):WaitForChild("EndGameTriggerPoint").EndGameTriggerPoint

endGameTriggerPart.Touched:Connect(function()
	endGameTriggerPart:Destroy()
	startEndGameSequence()
end)

triggerEvent.Event:Connect(startEndGameSequence)

--print("[EndGameManager] Initialized and listening for TriggerEndGame event.")