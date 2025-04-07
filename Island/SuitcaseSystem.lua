-- ServerScriptService.SuitcaseSystem.luau
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local HOLD_DURATION = 1 -- Seconds player needs to hold E
local PROMPT_DISTANCE = 6 -- Distance at which the prompt appears

-- Make sure SuitcaseDrops folder exists
if not ReplicatedStorage:FindFirstChild("SuitcaseDrops") then
	warn("SuitcaseDrops folder not in ReplicatedStorage")
end

-- Function to find a suitable part for the proximity prompt
local function findSuitablePart(suitcase)
	-- Try primary part first
	if suitcase.PrimaryPart then
		return suitcase.PrimaryPart
	end

	-- Look for any BasePart
	local allParts = {}
	for _, child in ipairs(suitcase:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(allParts, child)
		end
	end

	-- Return the first part found or nil
	return allParts[1]
end

-- Function to create a prompt for a suitcase
local function setupSuitcasePrompt(suitcase)
	-- Check if the suitcase already has a prompt
	if suitcase:FindFirstChild("SuitcasePrompt") then
		return
	end

	-- Find a part to attach the prompt to
	local attachPart = findSuitablePart(suitcase)
	if not attachPart then
		warn("Suitcase has no BaseParts to attach prompt to:", suitcase:GetFullName())
		return
	end

	-- Create the proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SuitcasePrompt"
	prompt.ActionText = "Open Suitcase"
	prompt.ObjectText = "Suitcase"
	prompt.HoldDuration = HOLD_DURATION
	prompt.RequiresLineOfSight = true
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = attachPart

	-- Setup the triggered event
	prompt.Triggered:Connect(function(player)
		handleSuitcaseOpen(suitcase, player)
	end)
end

-- Function to get the position of a model
local function getModelPosition(model)
	-- Try using PrimaryPart
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end

	-- Try using center of all parts
	local allParts = {}
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(allParts, child)
		end
	end

	if #allParts > 0 then
		-- Calculate center of all parts
		local center = Vector3.new(0, 0, 0)
		for _, part in ipairs(allParts) do
			center = center + part.Position
		end
		return center / #allParts
	end

	-- Fallback
	return Vector3.new(0, 0, 0)
end

-- Function to handle the suitcase opening
function handleSuitcaseOpen(suitcase, player)
	-- Get the drop value
	local dropValue = suitcase:FindFirstChild("Drop")
	if not dropValue or not dropValue:IsA("StringValue") then
		warn("Suitcase has no valid Drop StringValue")
		return
	end

	local toolName = dropValue.Value
	local toolTemplate = ReplicatedStorage.SuitcaseDrops:FindFirstChild(toolName)

	if not toolTemplate then
		warn("Tool not found in ReplicatedStorage.SuitcaseDrops: " .. toolName)
		return
	end

	-- Get position before removing suitcase
	local position = getModelPosition(suitcase)

	-- Clone the tool
	local tool = toolTemplate:Clone()

	-- Position the tool at the drop location
	local handle = tool:FindFirstChild("Handle")
	
	if handle and handle:IsA("BasePart") then
		tool.Parent = workspace
		handle.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
		handle.CanCollide = true
		handle.Anchored = false
	else
		tool.Parent = workspace
		if tool:IsA("Model") and tool.PrimaryPart then
			tool:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 0.5, 0)))
		end
	end

	-- Play sound effect (server-side only)
	local openSound = Instance.new("Sound")
	openSound.SoundId = "rbxassetid://3479742892" -- Replace with appropriate sound ID
	openSound.Volume = 0.8
	openSound.Parent = workspace
	openSound:Play()
	game:GetService("Debris"):AddItem(openSound, 3)

	-- Remove the suitcase
	suitcase:Destroy()
end

-- Setup all existing suitcases
for _, suitcase in pairs(CollectionService:GetTagged("Suitcase")) do
	setupSuitcasePrompt(suitcase)
end

-- Setup for any new suitcases added
CollectionService:GetInstanceAddedSignal("Suitcase"):Connect(setupSuitcasePrompt)