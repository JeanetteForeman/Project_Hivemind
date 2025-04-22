-- GASLIGHT Core
-- Ryan/tile127
-- Central hub for the GASLIGHT framework. Manages AI bots, state, and interactions.

local Core = {}
Core.__index = Core

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ChatService = game:GetService("Chat")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")

local Config
local Logger
local FirebaseHandler
local GeminiHandler
local ActionHandler

local TypingStatusEvent: RemoteEvent
local UIDataEvent: RemoteEvent
local PlayerChattedEvent: RemoteEvent

local bots = {}
local playerProfiles = {}
local playerTypingStatus = {}
local serverStartTime = 0
local isInitialized = false
local serverId = ""

type BotState = { id: string, model: Model, config: table, activeParticipants: {[number]: Player}, chatHistory: {{role: string, content: string, source: string?, proximity: string?}}, proximityChecker: any?, isWaitingForResponse: boolean, lastInteractionTime: number }
type PlayerProfile = { userId: number, username: string, profileState: "None" | "Fetching" | "Analyzing" | "Ready" | "Error", fetchedData: table?, profileReport: string?, lastUpdated: number }

local checkParticipantsTypingStatus
local triggerGeminiRequest

function Core:_displayBotMessage(botId: string, message: string)
	local botState = bots[botId]
	if not botState or not botState.model or not botState.model.Parent then Logger:log("WARN", "Cannot display message for bot "..botId..", model invalid."); return end
	local head = botState.model:FindFirstChild("Head")
	if head then
		local success, err = pcall(function() ChatService:Chat(head, message, Enum.ChatColor.White) end)
		if success then Logger:log("DEBUG", "Displayed bot message via ChatService:Chat for bot "..botId)
		else Logger:log("ERROR", string.format("Error displaying bot message for %s: %s", botId, tostring(err))) end
	else Logger:log("WARN", "Cannot display message, bot "..botId.." has no Head part: " .. botState.model.Name) end
end

function Core:_sendSystemEventToClients(eventMessage: string, players: {Player}?)
	if not Config.EnableClientDebugUI or not UIDataEvent then return end
	local payload = {dataType = "SystemEvent", message = "[" .. DateTime.now():FormatUniversalTime("HH:mm:ss", "en-us") .. "] " .. eventMessage}
	if players then
		local playerList = {}
		if typeof(players) == "table" then
			local isDictionary = false; for k, v in pairs(players) do if typeof(k) == "number" and v:IsA("Player") then else isDictionary=true; break; end end
			if isDictionary then for _, player in pairs(players) do if player:IsA("Player") then table.insert(playerList, player) end end
			else playerList = players end
		else Logger:log("WARN", "_sendSystemEventToClients received non-table 'players' argument."); return end
		for _, player in ipairs(playerList) do if player and player.Parent then local s,e=pcall(function() UIDataEvent:FireClient(player, payload) end) if not s then Logger:log("WARN", "Error FireClient SystemEvent: "..tostring(e)) end end end
	else
		local s,e=pcall(function() UIDataEvent:FireAllClients(payload) end) if not s then Logger:log("WARN", "Error FireAllClients SystemEvent: "..tostring(e)) end
	end
end

function Core:_sendInnerThoughtsToClients(thoughts: string, players: {[number]: Player})
	if not Config.EnableClientDebugUI or not UIDataEvent or thoughts == "" then return end
	local payload = {dataType = "InnerThoughts", thoughts = thoughts}
	local count = 0; for _, player in pairs(players) do if player and player.Parent then local s,e=pcall(function() UIDataEvent:FireClient(player, payload) end) if not s then Logger:log("WARN", "Error FireClient InnerThoughts: "..tostring(e)) else count+=1 end end end
end

function Core:_sendProfileReportToClient(player: Player, report: string)
	if not Config.EnableClientDebugUI or not UIDataEvent or not player or not player.Parent then return end
	Logger:log("DEBUG", string.format("Sending profile report for %s to client UI.", player.Name))
	local payload = {dataType = "ProfileReport", report = report}
	local s,e=pcall(function() UIDataEvent:FireClient(player, payload) end) if not s then Logger:log("WARN", "Error FireClient ProfileReport: "..tostring(e)) end
end


function Core.init(configModule: table): typeof(Core)
	if isInitialized then warn("[GASLIGHT_Core] Already initialized."); return Core end
	local self = setmetatable({}, Core)
	Config = configModule

	local actualJobId = game.JobId
	if actualJobId == nil or actualJobId == "" then
		warn("[GASLIGHT_Core] game.JobId is empty/nil. Generating fallback Server ID for Studio/testing.")
		serverId = "STUDIO_0"
	else serverId = actualJobId end
	print("[GASLIGHT_Core] Determined Server ID:", serverId)

	local LoggerModule = require(script.Parent:WaitForChild("GaslightLogger"))
	local FirebaseHandlerModule = require(script.Parent:WaitForChild("FirebaseHandler"))
	local GeminiHandlerModule = require(script.Parent:WaitForChild("GeminiHandler"))
	local ActionHandlerModule = require(script.Parent:WaitForChild("ActionHandler"))

	FirebaseHandler = FirebaseHandlerModule.init(Config)
	if not FirebaseHandler then error("[GASLIGHT_Core] CRITICAL: Failed to initialize FirebaseHandler.") end

	Logger = LoggerModule.init(Config, FirebaseHandler, serverId)
	if not Logger then error("[GASLIGHT_Core] CRITICAL: Failed to initialize Logger.") end
	FirebaseHandler:setLogger(Logger)

	GeminiHandler = GeminiHandlerModule.init(Config, Logger)
	ActionHandler = ActionHandlerModule.init(Config, Logger, self)

	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventFolder then error("[GASLIGHT_Core] 'RemoteEvents' folder not found in ReplicatedStorage! Framework cannot function.") end

	TypingStatusEvent = remoteEventFolder:FindFirstChild("TypingStatusEvent")
	UIDataEvent = remoteEventFolder:FindFirstChild("UIDataEvent")
	PlayerChattedEvent = remoteEventFolder:FindFirstChild("PlayerChattedEvent")

	if not TypingStatusEvent then warn("[GASLIGHT_Core] 'TypingStatusEvent' not found!") end
	if not UIDataEvent then warn("[GASLIGHT_Core] 'UIDataEvent' not found!") end
	if not PlayerChattedEvent then warn("[GASLIGHT_Core] 'PlayerChattedEvent' not found! Chat input will not work.") end

	serverStartTime = os.time()
	bots = {}; playerProfiles = {}; playerTypingStatus = {}

	if Config.FirebaseEnabled then
		task.spawn(function()
			local players = Players:GetPlayers()
			local playerIds = {}
			for _, p in ipairs(players) do table.insert(playerIds, p.UserId) end
			Logger:log("DEBUG", "Logging initial server data to Firebase...")
			local success, err = FirebaseHandler:logInitialServerData(serverId, playerIds, "")
			if not success then Logger:log("WARN", "Failed to log initial server data via FirebaseHandler: " .. tostring(err))
			else Logger:log("INFO", "Initial server data logged successfully.") end
		end)
	end

	Players.PlayerAdded:Connect(function(player) self:_handleNewPlayer(player) end)
	Players.PlayerRemoving:Connect(function(player) self:_handlePlayerRemoving(player) end)

	if TypingStatusEvent then TypingStatusEvent.OnServerEvent:Connect(function(player, ...) self:_onTypingStatusReceived(player, ...) end)
	else Logger:log("ERROR", "Cannot listen for TypingStatusEvent - Event not found.") end

	if PlayerChattedEvent then PlayerChattedEvent.OnServerEvent:Connect(function(player, ...) self:_onPlayerChattedEvent(player, ...) end)
	else Logger:log("ERROR", "Cannot listen for PlayerChattedEvent - Event not found. Chat will not be processed.") end

	game:BindToClose(function() self:_onServerShutdown(); task.wait(2) end)

	for _, player in ipairs(Players:GetPlayers()) do task.spawn(function() self:_handleNewPlayer(player) end) end

	isInitialized = true
	Logger:log("INFO", "GASLIGHT_Core initialized successfully.")
	return self
end

function Core:registerBot(botModel: Model, botConfigOverrides: table?): string
	local botId = HttpService:GenerateGUID(false)
	local botConfig = table.clone(Config.DefaultBotSettings)
	if botConfigOverrides then for key, value in pairs(botConfigOverrides) do botConfig[key] = value end end

	local botState: BotState = {
		id = botId, model = botModel, config = botConfig,
		activeParticipants = {}, chatHistory = {}, isWaitingForResponse = false,
		lastInteractionTime = os.time(), proximityChecker = nil,
	}

	CollectionService:AddTag(botModel, "GASLIGHT_Bot")
	botModel:SetAttribute("GASLIGHT_BotId", botId)
	bots[botId] = botState
	Logger:log("INFO", string.format("Registered Bot: %s (ID: %s) with Radius: %.1f", botModel.Name, botId, botConfig.ActivationRadius))

	if botConfig.ListenMode == "Proximity" then self:_setupProximityDetection(botState) end

	if botConfig.InitialGreeting and botConfig.InitialGreeting ~= "" then
		task.delay(1, function()
			if bots[botId] then
				Logger:log("DEBUG", string.format("Bot %s saying initial greeting.", botId))
				self:_displayBotMessage(botId, botConfig.InitialGreeting)
				table.insert(botState.chatHistory, { role = "model", content = botConfig.InitialGreeting, source="AI", proximity="Direct" })
			end
		end)
	end
	return botId
end

function Core:unregisterBot(botId: string)
	local botState = bots[botId]
	if not botState then Logger:log("WARN", "Attempted to unregister non-existent bot ID: "..botId); return end
	Logger:log("INFO", string.format("Unregistering Bot: %s (ID: %s)", botState.model.Name, botId))
	if botState.proximityChecker then if typeof(botState.proximityChecker) == "RBXScriptConnection" then botState.proximityChecker:Disconnect() end; botState.proximityChecker = nil end
	if botState.model and botState.model.Parent then CollectionService:RemoveTag(botState.model, "GASLIGHT_Bot"); botState.model:SetAttribute("GASLIGHT_BotId", nil) end
	bots[botId] = nil
end

function Core:_getBotStateFromModel(model: Model): BotState?
	local botId = model:GetAttribute("GASLIGHT_BotId")
	if botId and typeof(botId) == "string" then return bots[botId] end
	return nil
end

function Core:getBotParticipants(botModel: Model): {Player}?
	local botState = self:_getBotStateFromModel(botModel)
	if botState then local participants = {}; for _, player in pairs(botState.activeParticipants) do table.insert(participants, player) end; return participants end
	return nil
end

function Core:_handleNewPlayer(player: Player)
	
	Logger:log("INFO", string.format("Player Added: %s (UserId: %d)", player.Name, player.UserId))

	playerTypingStatus[player.UserId] = { isTyping = false, hasFocus = false, lastTypedTime = 0, lastChatTime = 0, }
	playerProfiles[player.UserId] = { userId = player.UserId, username = player.Name, profileState = "None", fetchedData = nil, profileReport = nil, lastUpdated = os.time() }

	if Config.FirebaseEnabled and Config.PlayerProfilingEnabled then
		playerProfiles[player.UserId].profileState = "Fetching"
		Logger:log("INFO", "Requesting profile data for player: " .. player.Name)
		self:_sendSystemEventToClients("Fetching profile data for " .. player.Name .. "...", {player})

		task.spawn(function()
			local successFetch, resultFetch = FirebaseHandler:requestPlayerProfile({player.UserId})
			if not playerProfiles[player.UserId] then Logger:log("DEBUG", "Player "..player.Name.." left during profile fetch."); return end

			if successFetch and resultFetch and resultFetch.profiles and resultFetch.profiles[tostring(player.UserId)] then
				local richProfileData = resultFetch.profiles[tostring(player.UserId)]
				local fetchErrors = richProfileData.fetchErrors or {}
				if #fetchErrors > 0 then Logger:log("WARN", string.format("Partial profile data fetched for %s. Errors: %s", player.Name, table.concat(fetchErrors, ", "))) end

				playerProfiles[player.UserId].fetchedData = richProfileData
				playerProfiles[player.UserId].lastUpdated = os.time()
				playerProfiles[player.UserId].profileState = "Analyzing"
				self:_sendSystemEventToClients("Profile data fetched. Analyzing for " .. player.Name .. "...", {player})
				Logger:log("INFO", "Rich profile data fetched for " .. player.Name .. ". Requesting Gemini analysis.")

				local geminiSuccess, geminiResult = GeminiHandler:requestGroundedPlayerProfile(richProfileData)
				if not playerProfiles[player.UserId] then Logger:log("DEBUG", "Player "..player.Name.." left during profile analysis."); return end

				if geminiSuccess and geminiResult and geminiResult.text then
					local generatedReport = geminiResult.text
					playerProfiles[player.UserId].profileReport = generatedReport
					playerProfiles[player.UserId].profileState = "Ready"
					playerProfiles[player.UserId].lastUpdated = os.time()
					Logger:log("INFO", "Gemini profile analysis complete for: " .. player.Name)
					self:_sendSystemEventToClients("Profile analysis complete for " .. player.Name, {player})
					self:_sendProfileReportToClient(player, generatedReport)

					task.spawn(function()
						Logger:log("DEBUG", "Storing fetched data and generated report to Firebase for " .. player.Name)
						local storeSuccess, storeErr = FirebaseHandler:storeProfileData(player.UserId, richProfileData, generatedReport)
						if not storeSuccess then Logger:log("WARN", string.format("Failed to store profile data for %s in Firebase: %s", player.Name, tostring(storeErr)))
						else Logger:log("DEBUG", "Successfully stored profile data for " .. player.Name) end
					end)

					if geminiResult.groundingMetadata then Logger:log("GEMINI_DEBUG", "Gemini profile grounding metadata for " .. player.Name .. ": " .. HttpService:JSONEncode(geminiResult.groundingMetadata)) end

				else
					Logger:log("WARN", string.format("Failed Gemini profile analysis for %s: %s", player.Name, tostring(geminiResult)))
					playerProfiles[player.UserId].profileState = "Error"
					playerProfiles[player.UserId].profileReport = "Error during analysis."
					self:_sendSystemEventToClients("Profile analysis failed for " .. player.Name, {player})
					self:_sendProfileReportToClient(player, "Error: Analysis failed.")

					task.spawn(function()
						Logger:log("DEBUG", "Storing only fetched profile data (analysis failed) to Firebase for " .. player.Name)
						local storeSuccess, storeErr = FirebaseHandler:storeProfileData(player.UserId, richProfileData, nil)
						if not storeSuccess then Logger:log("WARN", string.format("Failed to store fetched profile data (post-analysis-error) for %s in Firebase: %s", player.Name, tostring(storeErr))) end
					end)
				end
			else
				Logger:log("WARN", string.format("Failed to fetch profile data for %s from Firebase: %s", player.Name, tostring(resultFetch)))
				if playerProfiles[player.UserId] then
					playerProfiles[player.UserId].profileState = "Error"
					playerProfiles[player.UserId].profileReport = "Error fetching data."
					self:_sendSystemEventToClients("Failed to load profile data for " .. player.Name, {player})
					self:_sendProfileReportToClient(player, "Error: Failed to fetch data.")
				end
			end
		end)
	else
		Logger:log("INFO", "Player profiling disabled for " .. player.Name)
	end
	task.delay(0.5, function() self:_checkAllBotsProximityForPlayer(player) end)
end

function Core:_handlePlayerRemoving(player: Player)
	Logger:log("INFO", string.format("Player Removing: %s (UserId: %d)", player.Name, player.UserId))
	for botId, botState in pairs(bots) do if botState.activeParticipants[player.UserId] then self:_onProximityExit(player, botId) end end
	playerProfiles[player.UserId] = nil
	playerTypingStatus[player.UserId] = nil
	Logger:log("DEBUG", "Cleaned up state for removed player: " .. player.Name)
end

function Core:_setupProximityDetection(botState: BotState)
	if not botState.model or not botState.model:FindFirstChild("HumanoidRootPart") then Logger:log("WARN", "Cannot setup proximity for bot without HumanoidRootPart: " .. botState.model.Name); return end
	local botRoot = botState.model.HumanoidRootPart
	local radiusSq = botState.config.ActivationRadius * botState.config.ActivationRadius
	Logger:log("DEBUG", string.format("Setting up proximity checker for Bot %s (Radius: %.1f)", botState.id, botState.config.ActivationRadius))
	botState.proximityChecker = RunService.Heartbeat:Connect(function()
		if not bots[botState.id] or not botState.model or not botState.model.Parent or not botRoot or not botRoot.Parent then
			if botState.proximityChecker then botState.proximityChecker:Disconnect(); botState.proximityChecker = nil end
			return
		end
		local currentPos = botRoot.Position
		for _, player in ipairs(Players:GetPlayers()) do
			local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if playerRoot and playerRoot.Parent then
				local diffVector = playerRoot.Position - currentPos
				local distanceSq = diffVector.X*diffVector.X + diffVector.Y*diffVector.Y + diffVector.Z*diffVector.Z
				local isInside = distanceSq <= radiusSq
				if isInside and not botState.activeParticipants[player.UserId] then self:_onProximityEnter(player, botState.id)
				elseif not isInside and botState.activeParticipants[player.UserId] then self:_onProximityExit(player, botState.id) end
			elseif botState.activeParticipants[player.UserId] then self:_onProximityExit(player, botState.id) end
		end
	end)
end

function Core:_checkAllBotsProximityForPlayer(player: Player)
	Logger:log("DEBUG", "Checking proximity for player " .. player.Name .. " against all bots.")
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then Logger:log("DEBUG", "Player " .. player.Name .. " has no HumanoidRootPart, skipping proximity check."); return end
	for botId, botState in pairs(bots) do
		if botState.config.ListenMode == "Proximity" and botState.model and botState.model:FindFirstChild("HumanoidRootPart") then
			local botRoot = botState.model.HumanoidRootPart
			local radiusSq = botState.config.ActivationRadius * botState.config.ActivationRadius
			local distanceSq = (playerRoot.Position - botRoot.Position).MagnitudeSqr
			local isInside = distanceSq <= radiusSq
			if isInside and not botState.activeParticipants[player.UserId] then self:_onProximityEnter(player, botId)
			elseif not isInside and botState.activeParticipants[player.UserId] then self:_onProximityExit(player, botId) end
		end
	end
end

function Core:_onProximityEnter(player: Player, botId: string)
	local botState = bots[botId]
	if not botState or botState.activeParticipants[player.UserId] then return end
	Logger:log("INFO", string.format("Player %s ENTERED proximity of Bot %s", player.Name, botState.model.Name))
	botState.activeParticipants[player.UserId] = player
	checkParticipantsTypingStatus(botId)
end

function Core:_onProximityExit(player: Player, botId: string)
	local botState = bots[botId]
	if not botState or not botState.activeParticipants[player.UserId] then return end
	Logger:log("INFO", string.format("Player %s EXITED proximity of Bot %s", player.Name, botState.model.Name))
	botState.activeParticipants[player.UserId] = nil
	checkParticipantsTypingStatus(botId)
end

function Core:_onPlayerChattedEvent(player: Player, message: string)
	if not player or not player:IsA("Player") or typeof(message) ~= "string" or message == "" then
		Logger:log("WARN", "Received invalid PlayerChattedEvent.")
		return
	end
	Logger:log("INFO", string.format("Player %s chatted (via Event): '%s'", player.Name, message))
	if playerTypingStatus[player.UserId] then playerTypingStatus[player.UserId].lastChatTime = os.time()
	else Logger:log("WARN", "Could not find typing status for player "..player.Name.." to update lastChatTime.") end
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	for botId, botState in pairs(bots) do
		local inProximity = false
		local botRoot = botState.model and botState.model:FindFirstChild("HumanoidRootPart")
		if playerRoot and botRoot and botState.config.ListenMode == "Proximity" then
			local radiusSq = botState.config.ActivationRadius * botState.config.ActivationRadius
			local distanceSq = (playerRoot.Position - botRoot.Position).Magnitude
			distanceSq = distanceSq * distanceSq

			inProximity = distanceSq <= radiusSq
		elseif botState.activeParticipants[player.UserId] then
			inProximity = true
			Logger:log("DEBUG", string.format("Player %s is an active participant for Bot %s, treating chat as Direct.", player.Name, botId))
		end

		local proximityLabel = inProximity and "Direct" or "Overheard"
		local chatEntry = { role = "user", content = message, source = player.Name, proximity = proximityLabel, }
		table.insert(botState.chatHistory, chatEntry)
		Logger:log("DEBUG", string.format("Chat logged for BotID %s: (%s) %s: %s", botState.id, proximityLabel, player.Name, message:sub(1,50)))

		if inProximity then
			Logger:log("DEBUG", string.format("Chat was Direct for Bot %s. Checking typing status...", botId))
			botState.lastInteractionTime = os.time()
			task.spawn(checkParticipantsTypingStatus, botState.id)
		end
	end
end

function Core:_onTypingStatusReceived(player: Player, isTyping: boolean, hasFocus: boolean)
	if not Config.TypingCheckEnabled then return end
	local userId = player.UserId
	if not playerTypingStatus[userId] then Logger:log("WARN", "Received typing status for unknown player: " .. userId); return end

	local status = playerTypingStatus[userId]
	local changed = status.isTyping ~= isTyping or status.hasFocus ~= hasFocus
	status.isTyping = isTyping; status.hasFocus = hasFocus
	if isTyping or hasFocus then status.lastTypedTime = os.time() end

	if changed then
		for botId, botState in pairs(bots) do
			if botState.activeParticipants[userId] then
				checkParticipantsTypingStatus(botId)
			end
		end
	end
end

function checkParticipantsTypingStatus(botId: string): boolean
	local botState = bots[botId]
	if not botState then Logger:log("WARN", "checkParticipantsTypingStatus called for non-existent bot: "..botId); return false end
	if botState.isWaitingForResponse then Logger:log("DEBUG", "checkParticipantsTypingStatus skipped for Bot "..botId..": Already waiting for response."); return false end

	local participants = botState.activeParticipants
	local participantCount = 0; for _, _ in pairs(participants) do participantCount += 1 end
	if participantCount == 0 then return false end

	if not Config.TypingCheckEnabled then
		Logger:log("DEBUG", "Typing check disabled. Triggering Gemini for Bot "..botId)
		triggerGeminiRequest(botId); return true
	end

	local allIdle = true
	local currentTime = os.time()
	for userId, player in pairs(participants) do
		local status = playerTypingStatus[userId]
		if not status then Logger:log("WARN", "Missing typing status for participant: " .. userId); allIdle = false; break end
		if status.isTyping then Logger:log("DEBUG", "Bot "..botId.." waiting: Player "..userId.." is typing."); allIdle = false; break end
		if status.hasFocus and (currentTime - status.lastTypedTime < Config.TypingIdleMediumSeconds) then Logger:log("DEBUG", "Bot "..botId.." waiting: Player "..userId.." has focus and typed recently."); allIdle = false; break end
		if not status.hasFocus and (currentTime - status.lastTypedTime < Config.TypingIdleShortSeconds) then Logger:log("DEBUG", "Bot "..botId.." waiting: Player "..userId.." lost focus but typed very recently."); allIdle = false; break end
	end

	if allIdle then
		Logger:log("DEBUG", "All participants idle for BotID: " .. botId .. ". Triggering Gemini.")
		triggerGeminiRequest(botId); return true
	else
		Logger:log("DEBUG", "Participants not idle for BotID: " .. botId .. ". Waiting.")
		return false
	end
end

function triggerGeminiRequest(botId: string)
	local botState = bots[botId]
	if not botState then Logger:log("WARN", "triggerGeminiRequest aborted: Bot "..botId.." not found."); return end
	if botState.isWaitingForResponse then Logger:log("WARN", "triggerGeminiRequest aborted: Bot "..botId.." already waiting."); return end
	if #botState.chatHistory == 0 then Logger:log("WARN", "triggerGeminiRequest aborted: Bot "..botId.." has no chat history."); return end
	if botState.chatHistory[#botState.chatHistory].role == "model" then Logger:log("DEBUG", "triggerGeminiRequest skipped: Bot "..botId.." last message was from model."); return end

	botState.isWaitingForResponse = true
	Logger:log("INFO", "Preparing Gemini CONVERSATION request for BotID: " .. botId)

	local profilesToSend = {}
	local participantNames = {}
	for userId, player in pairs(botState.activeParticipants) do
		local profileInfo = playerProfiles[userId]
		if profileInfo and profileInfo.profileState == "Ready" and profileInfo.profileReport then profilesToSend[userId] = { userId = userId, username = player.Name, profileSummary = profileInfo.profileReport }
		elseif profileInfo and profileInfo.fetchedData then profilesToSend[userId] = { userId = userId, username = player.Name, description = profileInfo.fetchedData.description or "N/A" }
		else profilesToSend[userId] = { userId = userId, username = player.Name, profileSummary = "Profile not available." } end
		table.insert(participantNames, player.Name)
	end
	Logger:log("DEBUG", "Gathered profiles for participants: " .. table.concat(participantNames, ", "))

	local lastMessageContent = ""
	local lastUserMessageEntry = nil
	for i = #botState.chatHistory, 1, -1 do if botState.chatHistory[i].role == "user" then lastUserMessageEntry = botState.chatHistory[i]; break; end end
	if lastUserMessageEntry then lastMessageContent = lastUserMessageEntry.content else Logger:log("WARN", "Could not find last user message for Bot "..botId); end

	local systemPrompt = botState.config.SystemPrompt or Config.DefaultBotSettings.SystemPrompt
	local historyToSend = botState.chatHistory

	Logger:log("INFO", "Sending CONVERSATION request to Gemini for BotID: " .. botId)
	Core:_sendSystemEventToClients("AI is thinking...", botState.activeParticipants)

	task.spawn(function()
		local success, response = GeminiHandler:requestConversationResponse(botId, systemPrompt, profilesToSend, historyToSend, lastMessageContent)
		if not bots[botId] then Logger:log("DEBUG","Bot "..botId.." unregistered while waiting for Gemini response."); return end
		if success and response then Core:_handleGeminiResponse(botId, response)
		else Core:_handleGeminiError(botId, tostring(response)) end
		if bots[botId] then bots[botId].isWaitingForResponse = false; checkParticipantsTypingStatus(botId) end
	end)
end

function Core:_handleGeminiResponse(botId: string, response: {message: string?, inner_thoughts: string?, actions: {any}?, text: string?, groundingMetadata: any?})
	local botState = bots[botId]
	if not botState then return end

	local message = response.message or ""
	local thoughts = response.inner_thoughts or ""
	local actions = response.actions or {}

	if message ~= "" then
		Logger:log("INFO", string.format("Gemini CONVO response for BotID %s: '%s'", botId, message:sub(1,100)))
		Logger:log("DEBUG", string.format("Gemini thoughts: '%s'", thoughts:sub(1,100)))
		if #actions > 0 then Logger:log("DEBUG", "Gemini actions: " .. HttpService:JSONEncode(actions)) end

		self:_displayBotMessage(botId, message)
		table.insert(botState.chatHistory, { role = "model", content = message, source="AI", proximity="Direct" })
		botState.lastInteractionTime = os.time()

		if thoughts ~= "" and Config.EnableClientDebugUI then self:_sendInnerThoughtsToClients(thoughts, botState.activeParticipants) end
		self:_sendSystemEventToClients("AI response received.", botState.activeParticipants)

		if actions and #actions > 0 then
			task.delay(0.1, function()
				if bots[botId] then
					Logger:log("DEBUG", string.format("Executing %d action(s) for Bot %s", #actions, botId))
					if typeof(actions[1]) == "table" then
						for _, actionData in ipairs(actions) do
							if typeof(actionData) == "table" and #actionData > 0 then ActionHandler:executeAction(botState.model, botId, actionData)
							else Logger:log("WARN", "Invalid action format in Gemini response (inner array): " .. HttpService:JSONEncode(actionData)) end
						end
					elseif typeof(actions[1]) == "string" then
						ActionHandler:executeAction(botState.model, botId, actions)
					else Logger:log("WARN", "Unrecognized action format in Gemini response: " .. HttpService:JSONEncode(actions)) end
				end
			end)
		end
	else
		Logger:log("WARN", "Received Gemini response without 'message' field for BotID " .. botId .. ". Text: " .. (response.text or "N/A"))
	end
end

function Core:_handleGeminiError(botId: string, errorMsg: string)
	local botState = bots[botId]
	Logger:log("ERROR", string.format("Gemini request failed for BotID %s: %s", botId, errorMsg))
	if botState then
		--local errorMessage = "Sorry, I encountered an error thinking about that."
		local errorMessage = "..."
		self:_displayBotMessage(botId, errorMessage)
		self:_sendSystemEventToClients("AI Error: " .. errorMsg:sub(1,100), botState.activeParticipants)
		botState.lastInteractionTime = os.time()
	end
end

function Core:_handleFirebaseError(context: string, errorMsg: string)
	Logger:log("ERROR", string.format("Firebase Error (%s): %s", context, errorMsg))
	self:_sendSystemEventToClients(string.format("Firebase Error (%s)", context), nil)
end

function Core:_onServerShutdown()
	if not isInitialized then return end
	Logger:log("INFO", "Server shutdown sequence initiated.")
	if Config.FirebaseEnabled and Logger and FirebaseHandler then
		Logger:log("INFO", "Attempting to mark server shutdown in Firebase.")
		local finalLogs = Logger:getBufferedLogs()
		local success, err = FirebaseHandler:markServerShutdown(serverId, finalLogs)
		if not success then warn("[GASLIGHT_Core] Failed to mark server shutdown in Firebase:", err)
		else Logger:log("INFO", "Successfully marked server shutdown in Firebase.") end
	end
	isInitialized = false
end

return Core