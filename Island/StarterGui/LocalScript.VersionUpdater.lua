-- Updates the publish # for the version GUI
-- For use only in Alpha stage of game
-- @RyanRodrii (tile127)
-- 02/23/2025

-- CONFIG
local VERSIONGUI_ENABLED = true

-- REFERENCES
local versionLabel = script.Parent
local versionFrame = versionLabel.Parent
local versionGUI = versionFrame.Parent

-- CODE
if VERSIONGUI_ENABLED then
	versionGUI.Enabled = true
	versionFrame.Visible = true
	versionLabel.Text = "Hivemind Island #" .. game.PlaceVersion
else
	versionGUI.Enabled = false
	versionFrame.Visible = false
end

