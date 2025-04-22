-- GASLIGHT ChatMonitor
-- Ryan/tile127
-- Monitors player chat input state and notifies the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer


local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local TypingStatusEvent = remoteEventFolder:WaitForChild("TypingStatusEvent")
local PlayerChattedEvent = remoteEventFolder:WaitForChild("PlayerChattedEvent")


local TYPING_CHECK_ENABLED = true
local IDLE_SHORT_S = 1.5


local hasFocus = false
local isTyping = false
local lastTypedTime = 0
local lastSentStatus = { isTyping = false, hasFocus = false }
local focusedChatTextBox: TextBox? = nil
local changedConnection: RBXScriptConnection? = nil
local messageReceivedConnection: RBXScriptConnection? = nil
local focusedConnection: RBXScriptConnection? = nil
local focusReleasedConnection: RBXScriptConnection? = nil



local function sendStatusUpdate(context: string)
	if not TYPING_CHECK_ENABLED or not TypingStatusEvent then return end
	local currentStatus = { isTyping = isTyping, hasFocus = hasFocus }
	if currentStatus.isTyping ~= lastSentStatus.isTyping or currentStatus.hasFocus ~= lastSentStatus.hasFocus then
		local success, err = pcall(function() TypingStatusEvent:FireServer(isTyping, hasFocus) end)
		if not success then warn("[ChatMonitor] Error firing TypingStatusEvent:", err) end
		lastSentStatus = currentStatus
	end
end


local function connectChangedEvent(textbox: TextBox?)
	if changedConnection then changedConnection:Disconnect(); changedConnection = nil end
	if not textbox then return end
	-- print("[ChatMonitor] Attempting to connect Changed event...")
	changedConnection = textbox.Changed:Connect(function(property)
		if property == "Text" and hasFocus then
			isTyping = true
			lastTypedTime = os.time()
			sendStatusUpdate("TextChanged")
			task.delay(IDLE_SHORT_S, function()
				if hasFocus and os.time() - lastTypedTime >= IDLE_SHORT_S then
					if isTyping then
						isTyping = false
						sendStatusUpdate("IdleTimer")
					end
				end
			end)
		end
	end)
	-- print("[ChatMonitor] Connected Changed event.")
end

local function isLikelyChatInput(textbox: TextBox?): boolean
	if not textbox then return false end

	local textChatDefaultInput = textbox:FindFirstAncestor("TextChatDefaultInput")
	if textChatDefaultInput then return true end

	return false
end


if TYPING_CHECK_ENABLED then
	--print("[ChatMonitor] Initializing")

	if TextChatService then
		messageReceivedConnection = TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
			if message.Status == Enum.TextChatMessageStatus.Success and message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
				if PlayerChattedEvent then
					local success, err = pcall(function() PlayerChattedEvent:FireServer(message.Text) end)
					if not success then warn("[ChatMonitor] Error firing PlayerChattedEvent:", err) end
				else warn("[ChatMonitor] Cannot fire PlayerChattedEvent - RemoteEvent not found.") end
			end
		end)
		--print("[ChatMonitor] Connected MessageReceived listener.")
	else
		warn("[ChatMonitor] TextChatService not available! Cannot detect sent messages reliably.")
	end

	focusedConnection = UserInputService.TextBoxFocused:Connect(function(textbox: TextBox)
		if isLikelyChatInput(textbox) then
			-- print("[ChatMonitor] Likely chat input focused.") -- Debug
			hasFocus = true
			isTyping = false
			lastTypedTime = os.time()
			focusedChatTextBox = textbox
			connectChangedEvent(textbox)
			sendStatusUpdate("FocusGained")
			-- else
			-- print("[ChatMonitor] Focused textbox is not likely chat input:", textbox:GetFullName())
		end
	end)
	--print("[ChatMonitor] Connected TextBoxFocused listener.")

	focusReleasedConnection = UserInputService.TextBoxFocusReleased:Connect(function(textbox: TextBox)
		if textbox == focusedChatTextBox then
			hasFocus = false
			isTyping = false
			if changedConnection then changedConnection:Disconnect(); changedConnection = nil end
			focusedChatTextBox = nil
			sendStatusUpdate("FocusReleased")
		end
	end)
	--print("[ChatMonitor] Connected TextBoxFocusReleased listener.")

else
	--print("[GASLIGHT_ChatMonitor] Typing check disabled.")
end