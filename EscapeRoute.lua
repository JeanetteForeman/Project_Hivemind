local clickPart = script.Parent  -- the part with the ClickDetector
local clickDetector = clickPart.Button:WaitForChild("ClickDetector")

-- The model to make invisible
local targetModel = workspace.Escape:WaitForChild("Cover")  -- or whatever your model is named

local helicopter = workspace.Escape:WaitForChild("Helicopter")


-- Function to make all parts inside the model invisible and non-collidable
local function hideModel(model)
	for _, descendant in pairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		end
	end
end

local function showModel(model)
	for _, descendant in pairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0  -- Make it visible
			descendant.CanCollide = true  -- Enable collisions
		end
	end
end

-- On click
clickDetector.MouseClick:Connect(function(player)
	print(player.Name .. " clicked to escape!")
	hideModel(targetModel)
	
	clickPart.Button.Transparency = 1
	clickPart.Button.CanCollide = false
	clickDetector.MaxActivationDistance = 0 
	
	helicopter:SetPrimaryPartCFrame(CFrame.new(448.657, 169.878, -1362.119) * 
		CFrame.Angles(0, 0, math.rad(90))
	)
end)
