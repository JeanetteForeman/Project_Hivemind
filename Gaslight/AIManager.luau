-- GASLIGHT AI Monitor
-- Ryan/tile127
-- Entry point and manager script for the GASLIGHT framework in this place.

local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")


local GaslightFolder = ServerScriptService:WaitForChild("Gaslight")
local Config = require(GaslightFolder:WaitForChild("GaslightConfig"))
local Core = require(GaslightFolder:WaitForChild("GaslightCore"))



local coreSuccess, coreErr = pcall(function() Core.init(Config) end)
if not coreSuccess then
	warn("[AIManager] CRITICAL: Failed to initialize GaslightCore:", coreErr)
	return
end


local function registerExistingBots()
	--print("[AIManager] Searching for existing AI bots...")
	local count = 0
	local taggedBots = CollectionService:GetTagged("AIBotModel")
	for _, botModel in ipairs(taggedBots) do
		if botModel:IsA("Model") then
			local overrides = {}
			local persona = botModel:GetAttribute("PersonaPrompt"); if persona then overrides.SystemPrompt = persona end
			local radius = botModel:GetAttribute("ActivationRadius"); if radius then overrides.ActivationRadius = radius end
			local greeting = botModel:GetAttribute("InitialGreeting"); if greeting ~= nil then overrides.InitialGreeting = greeting end
			local listenMode = botModel:GetAttribute("ListenMode"); if listenMode then overrides.ListenMode = listenMode end

			local success, botIdOrErr = pcall(function() return Core:registerBot(botModel, overrides) end)
			if success then
				count += 1
				--print(string.format("[AIManager] Initiated registration for bot %s (ID: %s)", botModel.Name, botIdOrErr))
			else
				warn(string.format("[AIManager] Failed to initiate registration for bot %s: %s", botModel.Name, tostring(botIdOrErr)))
			end
		else
			warn("[AIManager] Item tagged 'AIBotModel' is not a Model:", botModel:GetFullName())
		end
	end
	--print(string.format("[AIManager] Finished initiating registration for %d existing AI bots.", count))
end

task.wait(2)
local regSuccess, regErr = pcall(registerExistingBots)
if not regSuccess then warn("[AIManager] Error during bot registration search: " .. tostring(regErr)) end

--print("[GASLIGHT_AIManager] Setup Complete.")