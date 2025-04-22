-- GASLIGHT Action Handler
-- Ryan/tile127
-- Executes actions requested by the AI.

local ActionHandler = {}
ActionHandler.__index = ActionHandler

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Config
local Logger
local Core
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local actionScriptsFolder = nil
local loadedActionScripts = {}

local function log(level, message) if Logger then Logger:log(level, "[ActionHandler] " .. message) end end

local function getPlayerCharacter(playerNameOrUserId: string | number): Model?
	local player = nil
	if typeof(playerNameOrUserId) == "number" then
		player = Players:GetPlayerByUserId(playerNameOrUserId)
	elseif typeof(playerNameOrUserId) == "string" then
		player = Players:FindFirstChild(playerNameOrUserId)
	end
	return player and player.Character
end

function ActionHandler.init(config: table, loggerModule: table, coreModule: table): typeof(ActionHandler)
	local self = setmetatable({}, ActionHandler)
	self.Config = config
	self.Logger = loggerModule; Logger = loggerModule
	self.Core = coreModule
	Config = config
	Core = coreModule

	actionScriptsFolder = Config.ActionScriptsFolder
	if actionScriptsFolder then
		log("INFO", "Initialized. Custom ActionScriptsFolder specified: " .. actionScriptsFolder:GetFullName())
	else
		log("INFO", "Initialized. No custom ActionScriptsFolder specified. Using built-in actions only.")
	end
	return self
end

function ActionHandler:executeAction(botModel: Model, botId: string, actionData: {any})
	if not actionData or #actionData == 0 then
		log("WARN", "executeAction called with empty actionData for BotID: " .. botId)
		return
	end

	local actionName = string.upper(tostring(actionData[1]))
	local parameters = {}
	for i = 2, #actionData do table.insert(parameters, actionData[i]) end

	log("INFO", string.format("BotID %s requesting Action: '%s' with %d parameters: %s", botId, actionName, #parameters, HttpService:JSONEncode(parameters)))

	local actionFunc = nil

	if actionScriptsFolder then
		local moduleName = actionName
		local success, actionModule = pcall(function()
			if loadedActionScripts[moduleName] then return loadedActionScripts[moduleName] end
			local module = actionScriptsFolder:FindFirstChild(moduleName)
			if module and module:IsA("ModuleScript") then
				local requiredModule = require(module)
				if typeof(requiredModule) == "function" then
					loadedActionScripts[moduleName] = requiredModule
					return requiredModule
				else
					log("WARN", string.format("Custom action module '%s' did not return a function.", moduleName)) return nil
				end
			end; return nil
		end)
		if success and actionModule then
			actionFunc = actionModule
			log("DEBUG", "Found custom action function for: " .. actionName)
		elseif not success then
			log("ERROR", string.format("Error requiring custom action module '%s': %s", moduleName, tostring(actionModule)))
		end
	end

	if not actionFunc then
		local internalFuncName = "_action_" .. actionName
		if self[internalFuncName] and typeof(self[internalFuncName]) == "function" then
			actionFunc = self[internalFuncName]
			log("DEBUG", "Found built-in action function for: " .. actionName)
		end
	end

	if actionFunc then
		log("DEBUG", string.format("Executing action '%s' for BotID %s...", actionName, botId))
		local execSuccess, execError = pcall(function()
			actionFunc(self, botModel, parameters, Core, Logger) -- Pass Logger directly
		end)
		if execSuccess then
			log("INFO", string.format("Action '%s' executed successfully for BotID: %s", actionName, botId))
		else
			log("ERROR", string.format("Error executing action '%s' for BotID %s: %s", actionName, botId, tostring(execError)))
		end
	else
		log("WARN", string.format("Action '%s' requested by BotID %s is not defined.", actionName, botId))
	end
end

function ActionHandler:_action_KILL(botModel: Model, parameters: {any}, core, logger: table)
	local logFn = function(lvl, msg) logger:log(lvl, "[Action:KILL] "..msg) end
	if #parameters < 1 then logFn("WARN", "Requires a target player name or UserID."); return end
	local target = parameters[1]
	local character = getPlayerCharacter(target)
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		task.wait(2.5)
		if humanoid then logFn("INFO", string.format("Executing on %s", target)); humanoid.Health = 0
		else logFn("WARN", string.format("Target '%s' has no Humanoid.", target)) end
	else logFn("WARN", string.format("Target '%s' not found or has no character.", target)) end
end

function ActionHandler:_action_SELFDESTRUCT(botModel: Model, parameters: {any}, core, logger: table)
	local logFn = function(lvl, msg) logger:log(lvl, "[Action:SELFDESTRUCT] "..msg) end
	local delay = (parameters and #parameters >= 1 and tonumber(parameters[1])) or 0.5
	logFn("INFO", string.format("Executing SELFDESTRUCT on bot %s after %.1f seconds.", botModel.Name, delay))

	task.delay(delay, function()
		if botModel and botModel.Parent then
			local botId = botModel:GetAttribute("GASLIGHT_BotId")
			local explosionPos = botModel:GetPivot().Position

			local explosion = Instance.new("Explosion", Workspace)
			explosion.Position = explosionPos
			explosion.BlastRadius = 25; explosion.BlastPressure = 100000; explosion.DestroyJointRadiusPercent = 0.5

			botModel:Destroy()

			if core and botId then
				logFn("DEBUG", "Unregistering self-destructed bot: " .. botId)
				local success, err = pcall(function() core:unregisterBot(botId) end)
				if not success then logFn("WARN", "Failed to unregister bot during self-destruct: " .. tostring(err)) end
			end

			logFn("INFO", "Self-destruct triggered win condition. Teleporting players.")
			self:_action_TELEPORT_WINNER(nil, {}, core, logger)

		end
	end)
end

function ActionHandler:_action_TELEPORT_WINNER(botModel: Model?, parameters: {any}, core, logger: table)
	local logFn = function(lvl, msg) logger:log(lvl, "[Action:TELEPORT_WINNER] "..msg) end
	local targetLocationPart = Workspace.ReferenceParts:FindFirstChild("WinTeleportTarget")

	if not targetLocationPart then
		logFn("ERROR", "WinTeleportTarget part not found in Workspace!")
		return
	end

	local targetCFrame: CFrame
	if targetLocationPart:IsA("BasePart") then
		targetCFrame = targetLocationPart.CFrame * CFrame.new(0, 3, 0)
	elseif targetLocationPart:IsA("Model") and targetLocationPart.PrimaryPart then
		targetCFrame = targetLocationPart.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
	elseif targetLocationPart:IsA("CFrameValue") then
		targetCFrame = targetLocationPart.Value
	else
		logFn("ERROR", "WinTeleportTarget is not a Part, Model with PrimaryPart, or CFrameValue!")
		return
	end

	local playersToTeleport = {}
	if #parameters >= 1 then
		local target = parameters[1]
		local player = nil
		if typeof(target) == "number" then player = Players:GetPlayerByUserId(target)
		elseif typeof(target) == "string" then player = Players:FindFirstChild(target) end
		if player then table.insert(playersToTeleport, player)
		else logFn("WARN", "Target player '" .. tostring(target) .. "' not found for teleport.") end
	else
		logFn("INFO", "Teleporting all players to win location.")
		task.wait(2.5)
		playersToTeleport = Players:GetPlayers()
	end

	for _, player in ipairs(playersToTeleport) do
		local char = player.Character
		local humanoidRootPart = char and char:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			logFn("DEBUG", "Teleporting player: " .. player.Name)
			humanoidRootPart.CFrame = targetCFrame
		else
			logFn("WARN", "Cannot teleport player " .. player.Name .. ": Character or HumanoidRootPart not found.")
		end
	end
	logFn("INFO", "Finished teleporting players to win location.")
end

function ActionHandler:_action_RUN_AWAY(botModel: Model, parameters: {any}, core, logger: table)
	local logFn = function(lvl, msg) logger:log(lvl, "[Action:RUN_AWAY] "..msg) end
	logFn("INFO", string.format("Executing for bot %s.", botModel.Name))
	local humanoid = botModel:FindFirstChildOfClass("Humanoid")
	local rootPart = botModel:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart then
		local nearestPlayerDist = math.huge
		local runDirection = Vector3.new(math.random()-0.5, 0, math.random()-0.5).Unit
		local participants = core and core:getBotParticipants(botModel)
		if participants then
			for _, player in ipairs(participants) do
				local char = player.Character
				local pRoot = char and char:FindFirstChild("HumanoidRootPart")
				if pRoot then
					local dist = (rootPart.Position - pRoot.Position).Magnitude
					if dist < nearestPlayerDist then
						nearestPlayerDist = dist
						runDirection = (rootPart.Position - pRoot.Position).Unit
					end
				end
			end
			logFn("DEBUG", "Determined run direction based on participants.")
		else
			logFn("DEBUG", "No participants found, running in random direction.")
		end

		local speedMultiplier = (parameters and #parameters >= 1 and tonumber(parameters[1])) or 1.5
		local originalSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = originalSpeed * speedMultiplier
		local targetPos = rootPart.Position + runDirection * 50
		humanoid:MoveTo(targetPos)
		logFn("DEBUG", string.format("Moving bot towards %s with speed %.1f", tostring(targetPos), humanoid.WalkSpeed))

		task.delay(4, function()
			if humanoid and humanoid.Parent then humanoid.WalkSpeed = originalSpeed; logFn("DEBUG", "Restored bot speed.") end
		end)
	else logFn("WARN", "Action failed: Bot missing Humanoid or HumanoidRootPart.") end
end

function ActionHandler:_action_WAIT(botModel: Model, parameters: {any}, core, logger: table)
	local logFn = function(lvl, msg) logger:log(lvl, "[Action:WAIT] "..msg) end
	local duration = (parameters and #parameters >= 1 and tonumber(parameters[1])) or 1.0
	logFn("INFO", string.format("Executing WAIT action for %.1f seconds.", duration))
end

return ActionHandler