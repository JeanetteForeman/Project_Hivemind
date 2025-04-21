-- get all buttons and sort them in ascending order
local buttons = script.Parent.Buttons:GetChildren()
table.sort(buttons, function(a, b) return a.Name < b.Name end)

local clickTimestamps = {}
local clickWindow = 3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local openDoorEvent = ReplicatedStorage.RemoteEvents:WaitForChild("OpenDoor")

local puzzle = script.Parent
local doorRef = puzzle:FindFirstChild("LinkedDoor")

local function onButtonClicked(button)
	-- get current time and store the time clicked for given button
	local currentTime = tick()
	clickTimestamps[button] = currentTime
	
	-- check if all buttons were clicked within the time window
	for _, btn in pairs(buttons) do
		-- if a button wasn't clicked or if it was clicked but outside of the clickWindow
		if not clickTimestamps[btn] or (currentTime - clickTimestamps[btn] > clickWindow) then
			return
		end
	end
	
	print("Puzzle solved!")
	script.Parent.Solved.Value = true
	clickTimestamps = {}
	wait(5)
	
	if doorRef and doorRef.Value then
		openDoorEvent:FireServer(doorRef.Value)
	end
	
	script.Parent.Solved.Value = false
end

-- connect each button to the function
for _, button in pairs(buttons) do
	local clickDetector = button.Head2:FindFirstChild("ClickDetector") 
	if clickDetector then
		clickDetector.MouseClick:Connect(function()
			onButtonClicked(button)
		end)
	end
end