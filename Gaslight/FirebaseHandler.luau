-- GASLIGHT Firebase Handler
-- Ryan/tile127
-- Handles HTTP communication with Firebase Cloud Functions.

local FirebaseHandler = {}
FirebaseHandler.__index = FirebaseHandler

local HttpService = game:GetService("HttpService")

local Config
local Logger = nil
local firebaseFunctionsUrl = nil

local function logMessage(level, message)
	if Logger then
		Logger:log(level, "[FBHandler] " .. message)
	else
		if level == "ERROR" or level == "WARN" then warn(string.format("[FBHandler NoLog] [%s] %s", level, message))
		else print(string.format("[FBHandler NoLog] [%s] %s", level, message)) end
	end
end

local function _makeRequest(endpoint: string, payload: table): (boolean, any)
	if not firebaseFunctionsUrl then
		logMessage("WARN", string.format("Request to %s aborted: Firebase URL not configured.", endpoint))
		return false, "Firebase URL not configured or secret fetch failed."
	end
	if not Config or not Config.FirebaseEnabled then
		return false, "Firebase is disabled in config."
	end

	logMessage("DEBUG", string.format("Sending request to Firebase endpoint: %s", endpoint))
	local url = firebaseFunctionsUrl .. "/" .. endpoint
	local body = ""
	local encodeSuccess, encodedOrErr = pcall(function() return HttpService:JSONEncode(payload) end)
	if not encodeSuccess then
		logMessage("ERROR", string.format("JSONEncode failed for %s request: %s", endpoint, tostring(encodedOrErr)))
		return false, "JSONEncode error: " .. tostring(encodedOrErr)
	end
	body = encodedOrErr

	local success, result

	success, result = pcall(function()
		return HttpService:RequestAsync({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
	end)

	if not success then
		logMessage("ERROR", string.format("Firebase request pcall error to %s: %s", endpoint, tostring(result)))
		return false, "pcall error: " .. tostring(result)
	end

	if not result.Success then
		logMessage("ERROR", string.format("Firebase request HTTP error to %s (%d): %s", endpoint, result.StatusCode, result.Body))
		return false, string.format("HTTP %d: %s", result.StatusCode, result.Body)
	end

	logMessage("DEBUG", string.format("Firebase request to %s successful (HTTP %d). Body: %s", endpoint, result.StatusCode, result.Body:sub(1, 100) .. (#result.Body > 100 and "..." or ""))) -- Log snippet

	local decodedSuccess, decodedResult = pcall(function()
		return HttpService:JSONDecode(result.Body)
	end)

	if not decodedSuccess then
		logMessage("ERROR", string.format("Firebase JSON decode error from %s: %s", endpoint, tostring(decodedResult)))
		return false, "JSON Decode Error: " .. tostring(decodedResult)
	end

	if decodedResult and typeof(decodedResult) == "table" then
		if decodedResult.data then
			logMessage("DEBUG", string.format("Successfully decoded Firebase response from %s (found data key).", endpoint))
			return true, decodedResult.data
		elseif decodedResult.result then
			logMessage("DEBUG", string.format("Successfully decoded Firebase response from %s (found result key).", endpoint))
			return true, decodedResult.result
		elseif decodedResult.success ~= nil then
			logMessage("DEBUG", string.format("Decoded Firebase response from %s (found success key: %s).", endpoint, tostring(decodedResult.success)))
			return decodedResult.success, decodedResult
		else
			logMessage("DEBUG", string.format("Decoded Firebase response from %s (no standard keys like data/result/success found, returning full object).", endpoint))
			return true, decodedResult
		end
	else
		logMessage("WARN", string.format("Firebase response from %s decoded but was not a table: %s", endpoint, tostring(decodedResult)))
		return true, decodedResult
	end
end

function FirebaseHandler.init(config: table): typeof(FirebaseHandler)
	local self = setmetatable({}, FirebaseHandler)
	self.Config = config
	Config = config

	if Config.FirebaseEnabled then
		if Config.FirebaseFunctionsURL and Config.FirebaseFunctionsURL ~= "" then
			firebaseFunctionsUrl = Config.FirebaseFunctionsURL
		else
			firebaseFunctionsUrl = nil
			warn("[FBHandler Init] FirebaseFunctionsURL is missing or empty in GASLIGHT_Config. Firebase features disabled.")
			self.Config.FirebaseEnabled = false
			Config.FirebaseEnabled = false
		end
	else
		firebaseFunctionsUrl = nil
	end

	return self
end

function FirebaseHandler:setLogger(loggerInstance: table)
	Logger = loggerInstance
	self.Logger = loggerInstance
	if firebaseFunctionsUrl then
		logMessage("INFO", "Initialized. Using Firebase Functions URL: " .. firebaseFunctionsUrl)
	else
		logMessage("INFO", "Initialized. Firebase interactions disabled (No URL or Config disabled).")
	end
end

function FirebaseHandler:requestPlayerProfile(playerIds: {number}): (boolean, any)
	logMessage("DEBUG", "Calling requestPlayerProfile for IDs: " .. table.concat(playerIds, ", "))
	return _makeRequest("getPlayerProfile", { data = { playerIds = playerIds } })
end

function FirebaseHandler:storeProfileData(userId: number, fetchedData: table?, generatedReport: string?): (boolean, any)
	logMessage("DEBUG", "Calling storeProfileData for UserId: " .. tostring(userId))
	return _makeRequest("storeProfileData", { data = {
		userId = userId,
		fetchedData = fetchedData,
		generatedReport = generatedReport
	} })
end

function FirebaseHandler:logInitialServerData(serverId: string, playerIds: {number}, initialLog: string): (boolean, any)
	logMessage("DEBUG", "Calling logInitialServerData for ServerId: " .. serverId)
	return _makeRequest("logServerData", { data = {
		serverId = serverId,
		playerIds = playerIds,
		initialLog = initialLog,
		startTime = DateTime.now():ToIsoDate()
	} })
end

function FirebaseHandler:updateServerLog(serverId: string, logBatch: string): (boolean, any)
	return _makeRequest("updateServerLog", { data = { serverId = serverId, logBatch = logBatch } })
end

function FirebaseHandler:markServerShutdown(serverId: string, finalLogBatch: string): (boolean, any)
	logMessage("INFO", "Calling markServerShutdown for ServerId: " .. serverId)
	return _makeRequest("markServerShutdown", { data = { serverId = serverId, finalLogBatch = finalLogBatch } })
end

return FirebaseHandler