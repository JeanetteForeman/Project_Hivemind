-- GASLIGHT Gemini Handler
-- Ryan/tile127
-- Handles communication with the Google Gemini API using HttpService Secrets.

local GeminiHandler = {}
GeminiHandler.__index = GeminiHandler

local HttpService = game:GetService("HttpService")

local Config
local Logger
local apiKeySecret: Secret? = nil
local apiEndpoint = ""

local function log(level, message) if Logger then Logger:log(level, "[GeminiHandler] " .. message) end end

-- local function _makeGeminiRequest(payloadTable: table, requestContext: string, manualJsonInsert: string?): (boolean, any)
local function _makeGeminiRequest(payloadTable: table, requestContext: string): (boolean, any)
	if not apiKeySecret then
		log("ERROR", "Request ("..requestContext..") failed: API key Secret object not available.")
		return false, "Gemini API key Secret not configured or fetch failed."
	end
	if not apiEndpoint or apiEndpoint == "" then
		log("ERROR", "Request ("..requestContext..") failed: API endpoint not configured.")
		return false, "Gemini API endpoint not configured."
	end

	local body = ""
	local encodeSuccess, encodedBodyOrError = pcall(function() return HttpService:JSONEncode(payloadTable) end)
	if not encodeSuccess then
		log("ERROR", "JSONEncode failed for "..requestContext..": " .. tostring(encodedBodyOrError))
		return false, "JSONEncode failed: " .. tostring(encodedBodyOrError)
	end
	body = encodedBodyOrError

	if Config.LogGeminiPayloads then
		log("GEMINI_DEBUG", string.format("Request Payload (%s) [Final Body]:\n%s", requestContext, body)) -- Log final body after insertion
	else
		log("DEBUG", string.format("Sending Request (%s) to Gemini...", requestContext))
	end

	local requestUrl = ""
	local constructSuccess, constructError = pcall(function()
		local urlPrefix = apiEndpoint .. "?key="
		requestUrl = apiKeySecret:AddPrefix(urlPrefix)
	end)
	if not constructSuccess then
		log("ERROR", "Failed to construct Gemini URL with Secret:AddPrefix: " .. tostring(constructError))
		return false, "Failed to construct Gemini URL with Secret: " .. tostring(constructError)
	end

	local success, result
	local function attemptRequest()
		success, result = pcall(function()
			return HttpService:RequestAsync({
				Url = requestUrl,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json", },
				Body = body
			})
		end)
	end
	attemptRequest()

	if not success then
		log("ERROR", string.format("Gemini request pcall error (%s): %s", requestContext, tostring(result)))
		return false, "pcall error: " .. tostring(result)
	end

	if Config.LogGeminiPayloads then
		log("GEMINI_DEBUG", string.format("Response (%s) - HTTP %d:\nBody: %s", requestContext, result.StatusCode, result.Body))
	else
		log("DEBUG", string.format("Response (%s) - HTTP %d received. Body Length: %d", requestContext, result.StatusCode, #result.Body))
	end

	if not result.Success then
		log("ERROR", string.format("Gemini request HTTP error (%s) (%d): %s", requestContext, result.StatusCode, result.Body))
		return false, string.format("HTTP %d: %s", result.StatusCode, result.Body)
	end
	
	--print(result)
	local decodedSuccess, decodedResult = pcall(function() return HttpService:JSONDecode(result.Body) end)
	if not decodedSuccess then
		log("ERROR", string.format("Gemini JSON decode error (%s): %s", requestContext, tostring(decodedResult)))
		return false, "JSON Decode Error: " .. tostring(decodedResult)
	end

	if decodedResult and decodedResult.candidates and #decodedResult.candidates > 0 then
		local candidate = decodedResult.candidates[1]
		if not candidate or not candidate.content or not candidate.content.parts or #candidate.content.parts == 0 then
			log("ERROR", "Gemini response candidate format error ("..requestContext.."). Missing content/parts OR model blocked content")
			return false, "Gemini response format error: Missing content/parts."
		end
		local rawText = candidate.content.parts[1].text
		local groundingMetadata = candidate.groundingMetadata
		local jsonSuccess, structuredData = pcall(function() if string.sub(rawText, 1, 1) == "{" and string.sub(rawText, -1) == "}" or string.sub(rawText, 1, 1) == "[" and string.sub(rawText, -1) == "]" then return HttpService:JSONDecode(rawText) else return nil end end)

		if jsonSuccess and structuredData and structuredData.message ~= nil then
			log("DEBUG", "Parsed structured Gemini response ("..requestContext.."). Message: ".. (structuredData.message or ""):sub(1,50) .. ", Actions: " .. tostring(#(structuredData.actions or {})))
			return true, { message = structuredData.message or "", inner_thoughts = structuredData.inner_thoughts or "", actions = structuredData.actions or {}, groundingMetadata = groundingMetadata }
		else
			log("DEBUG", "Parsed plain text Gemini response ("..requestContext.."). Text Length: ".. #rawText)
			return true, { text = rawText, groundingMetadata = groundingMetadata }
		end
	elseif decodedResult.error then
		local errorMsg = decodedResult.error.message or HttpService:JSONEncode(decodedResult.error)
		log("ERROR", "Gemini API Error ("..requestContext.."): " .. errorMsg);
		return false, "Gemini API Error: " .. errorMsg
	else
		log("ERROR", "Gemini response format error ("..requestContext.."): No candidates found. Body: " .. result.Body);
		return false, "Gemini response format error: No candidates."
	end
end

function GeminiHandler.init(config: table, loggerModule: table): typeof(GeminiHandler)
	local self = setmetatable({}, GeminiHandler)
	self.Config = config; self.Logger = loggerModule; Config = config; Logger = loggerModule; apiEndpoint = Config.GeminiAPIEndpoint

	local secretName = Config.GeminiApiKeySecretName
	if not secretName or secretName == "" then
		log("ERROR", "GeminiApiKeySecretName is not configured in GaslightConfig. Gemini features disabled.")
		apiKeySecret = nil
	else
		local success, fetchedSecret = pcall(function() return HttpService:GetSecret(secretName) end)
		if success and fetchedSecret then
			apiKeySecret = fetchedSecret
			log("INFO", string.format("Successfully fetched Gemini API Key Secret object ('%s') from HttpService.", secretName))
		else
			apiKeySecret = nil
			log("ERROR", string.format("Failed to fetch Gemini API Key Secret ('%s') from HttpService. Gemini features disabled. Error: %s", secretName, tostring(fetchedSecret)))
		end
	end

	return self
end

function GeminiHandler:requestConversationResponse(botId: string, systemPrompt: string, playerProfiles: table, chatHistory: {table}, newMessage: string): (boolean, any)
	log("INFO", string.format("Requesting Gemini CONVERSATION response for BotID: %s", botId))
	local contents = {}
	local profileString = ""
	local profileCount = 0
	for userId, profile in pairs(playerProfiles) do
		profileCount += 1
		profileString ..= string.format("\n- %s (UserId: %d): %s", profile.username or "Unknown", userId, profile.profileSummary or profile.description or "No summary.")
	end
	if profileCount == 0 then profileString = " None in range." end
	local systemInstructionText = systemPrompt .. "\n\nCURRENT PLAYER PROFILES IN RANGE:" .. profileString .. "\n\nCHAT HISTORY (Direct = Player was nearby, Overheard = Player was further away):\n"
	local systemInstruction = { role = "user", parts = {{text = systemInstructionText}}	}
	table.insert(contents, systemInstruction)
	local maxHistory = 30
	local historyCount = 0
	for i = math.max(1, #chatHistory - maxHistory + 1), #chatHistory do
		local entry = chatHistory[i]
		local role = entry.role
		local content = entry.content or ""
		local proximity = entry.proximity or "Direct"
		local source = entry.source or "AI"
		local formattedContent = content
		if role == "user" then formattedContent = string.format("%s (%s): %s", source, proximity, content) end
		table.insert(contents, { role = role, parts = {{text = formattedContent}} })
		historyCount += 1
	end
	log("DEBUG", string.format("Added %d/%d chat history entries to Gemini prompt.", historyCount, #chatHistory))
	local payloadTable = {
		contents = contents,
		generationConfig = { temperature = 0.7, topP = 1.0, topK = 40, responseMimeType = "application/json" },
		safetySettings = { { category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_MEDIUM_AND_ABOVE"}, { category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_MEDIUM_AND_ABOVE"}, { category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_MEDIUM_AND_ABOVE"}, { category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_MEDIUM_AND_ABOVE"} }
	}
	return _makeGeminiRequest(payloadTable, "Conversation", nil)
end

function GeminiHandler:requestGroundedPlayerProfile(playerData: table): (boolean, any)
	local username = playerData.username or "UnknownUser"
	log("INFO", "Requesting Gemini GROUNDED player profile for: " .. username)
	local dataToSend = table.clone(playerData)
	dataToSend.fetchErrors = nil
	if dataToSend.favoriteGames and #dataToSend.favoriteGames > 10 then dataToSend.favoriteGames = {table.unpack(dataToSend.favoriteGames, 1, 10)} end
	if dataToSend.createdGames and #dataToSend.createdGames > 10 then dataToSend.createdGames = {table.unpack(dataToSend.createdGames, 1, 10)} end
	if dataToSend.badges and #dataToSend.badges > 15 then dataToSend.badges = {table.unpack(dataToSend.badges, 1, 15)} end
	if dataToSend.groups and #dataToSend.groups > 10 then dataToSend.groups = {table.unpack(dataToSend.groups, 1, 10)} end
	local prompt = string.format( "Analyze the following detailed Roblox player data for user '%s'.  Synthesize all available information (both the provided data below and information you may already know) into a comprehensive player profile summary. Focus on potential interests, notable creations/achievements, community involvement, and possible player archetype. Do not invent information (you can speculate). Dont put anything in the analysis that would violate roblox rules. Format the output as plain text.\n\nPROVIDED PLAYER DATA:\n%s", username, HttpService:JSONEncode(dataToSend) )

	local payloadTable = {
		contents = {{ role = "user", parts = {{text = prompt}} }},
		generationConfig = { temperature = 0.5 },
		safetySettings = {
			{ category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_MEDIUM_AND_ABOVE"},
			{ category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_MEDIUM_AND_ABOVE"},
			{ category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_MEDIUM_AND_ABOVE"},
			{ category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_MEDIUM_AND_ABOVE"}
		}
	}
	return _makeGeminiRequest(payloadTable, "ProfileAnalysis")
end

return GeminiHandler