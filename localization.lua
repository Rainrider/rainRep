local _, ns = ...

local L = {
	["Unknown command:"] = "Unknown command:",
	["No reputation changes."] = "No reputation changes.",
	["|cff0099ccAlt+Click|r to reset"] = "|cff0099ccAlt+Click|r to reset",
}
local locale = _G.GetLocale()

if locale == "deDE" then
	L["Unknown command:"] = "Unbekannter Befehl:"
	L["No reputation changes."] = "Keine Rufänderungen."
	L["|cff0099ccAlt+Click|r to reset"] = "|cff0099ccAlt+Klick|r zum Zurücksetzen."
end

ns.L = L
