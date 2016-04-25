local _, ns = ...

local L = {
	["Unknown command:"] = "Unknown command:",
	["No reputation changes."] = "No reputation changes.",
}
local locale = _G.GetLocale()

if locale == "deDE" then
	L["Unknown command:"] = "Unbekannter Befehl:"
	L["No reputation changes."] = "Keine Rufänderungen."
end

ns.L = L
