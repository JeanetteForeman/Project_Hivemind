-- GASLIGHT Logger
-- Ryan/tile127
-- Handles buffering and sending logs to Firebase.

local Logger = {}
Logger.__index = Logger

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config
local LOG_LEVELS = { GEMINI_DEBUG = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

local function _formatLog(level: string, message: string): string
	return string.format("[%s] %s: %s", level:upper(), DateTime.now():ToIsoDate(), message)
end


function Logger:_flushLogsInternal(forceShutdown: boolean)
	if (self.isShuttingDown and not forceShutdown) or not self.Config or not self.Config.FirebaseEnabled or not self.FirebaseHandler then
		if not self.isShuttingDown and self.flushTimerActive then
			local selfRef = self
			task.delay(self.Config.LogBatchIntervalSeconds, function() selfRef:_flushLogsInternal(false) end)
		end
		return
	end

	if forceShutdown and not self.isShuttingDown then
		self.isShuttingDown = true
		self.flushTimerActive = false
		local logLevelNum = LOG_LEVELS.INFO
		local configLevelNum = LOG_LEVELS[self.Config.LogLevel:upper()] or LOG_LEVELS.INFO
		if logLevelNum >= configLevelNum then
			local shutdownMsg = _formatLog("INFO", "Server shutting down. Sending final log batch.")
			table.insert(self.logBuffer, shutdownMsg)
			if RunService:IsStudio() then print("[GASLIGHT] " .. shutdownMsg) end
		end
	end

	if #self.logBuffer == 0 then
		if not self.isShuttingDown and self.flushTimerActive then
			local selfRef = self
			task.delay(self.Config.LogBatchIntervalSeconds, function() selfRef:_flushLogsInternal(false) end)
		end
		return
	end

	local logsToSend = table.concat(self.logBuffer, "\n")
	table.clear(self.logBuffer)

	local success, err

	-- print("[GASLIGHT_Logger] Flushing logs to Firebase. Forced:", forceShutdown)

	if forceShutdown then
		success, err = self.FirebaseHandler:markServerShutdown(self.serverId, logsToSend)
	else
		success, err = self.FirebaseHandler:updateServerLog(self.serverId, logsToSend)
	end

	if not success then
		warn(string.format("[GASLIGHT_Logger] Failed to send logs to Firebase for ServerID %s: %s", self.serverId or "N/A", tostring(err)))
	end

	if not self.isShuttingDown and self.flushTimerActive then
		local selfRef = self
		task.delay(self.Config.LogBatchIntervalSeconds, function() selfRef:_flushLogsInternal(false) end)
	end
end


function Logger.init(config: table, firebaseHandlerInstance: table, serverId_in: string): typeof(Logger)
	local self = setmetatable({}, Logger)
	self.Config = config
	self.FirebaseHandler = firebaseHandlerInstance

	self.logBuffer = {}
	self.serverId = serverId_in
	self.isShuttingDown = false
	self.flushTimerActive = false

	if self.Config.FirebaseEnabled then
		self:log("INFO", string.format("Logger Initializing... ServerId: %s", self.serverId))
		if self.Config.LogBatchIntervalSeconds > 0 then
			self.flushTimerActive = true
			local selfRef = self
			task.delay(self.Config.LogBatchIntervalSeconds, function() selfRef:_flushLogsInternal(false) end)
			self:log("DEBUG", string.format("Log flush timer started (%d seconds).", self.Config.LogBatchIntervalSeconds))
		else
			self:log("INFO", "Log flush timer disabled (Interval <= 0).")
		end
	else
		self:log("WARN", "Firebase logging is disabled in config.")
	end

	return self
end

function Logger:log(level: string, message: string)
	if self.isShuttingDown then return end

	local currentConfig = self.Config
	if not currentConfig then
		warn("[GASLIGHT_Logger:log] CRITICAL: Config not available on Logger instance!")
		print(string.format("[GASLIGHT NoConfig] [%s] %s", level:upper(), message))
		return
	end

	local levelStrUpper = level:upper()
	local logLevelNum = LOG_LEVELS[levelStrUpper]
	if logLevelNum == nil then
		warn(string.format("[GASLIGHT_Logger:log] Invalid log level used: %s. Message: %s", level, message))
		logLevelNum = LOG_LEVELS.INFO
	end

	local configLevelStrUpper = currentConfig.LogLevel:upper()
	local configLevelNum = LOG_LEVELS[configLevelStrUpper]
	if configLevelNum == nil then
		warn(string.format("[GASLIGHT_Logger:log] Invalid Config.LogLevel: %s. Defaulting to INFO.", currentConfig.LogLevel))
		configLevelNum = LOG_LEVELS.INFO
	end

	if logLevelNum >= configLevelNum then
		local formattedMessage = _formatLog(levelStrUpper, message)
		table.insert(self.logBuffer, formattedMessage)

		if RunService:IsStudio() then
			if logLevelNum == LOG_LEVELS.ERROR then warn("[GASLIGHT] " .. formattedMessage)
			elseif logLevelNum == LOG_LEVELS.WARN then warn("[GASLIGHT] " .. formattedMessage)
			else print("[GASLIGHT] " .. formattedMessage) end
		end
	end
end

function Logger:flushLogs(isShutdown: boolean)
	self:_flushLogsInternal(isShutdown)
end

function Logger:getBufferedLogs(): string
	return table.concat(self.logBuffer, "\n")
end

return Logger