local _, ns = ...

local L = {
	["more to"] = "more to",
	["repetitions"] = "repetitions",
	["Reputation changes in"] = "Reputation changes in",
	["the end of"] = "the end of",
	["the beginning of"] = "the beginning of",
	["Database reset."] = "Database reset.",
	["Stopped debugging."] = "Stopped debugging.",
	["Started debugging."] = "Started debugging.",
	["Unknown command:"] = "Unknown command:",
	["No reputation changes."] = "No reputation changes.",
}
local locale = GetLocale()

if locale == "deDE" then
	L["more to"] = "noch bis"
	L["repetitions"] = "Wiederholungen"
	L["Reputation changes in"] = "Rufänderung in"
	L["the end of"] = "zum Anfang von"
	L["the beginning of"] = "zum Ende von"
	L["Database reset."] = "Datenbank zurückgesetzt."
	L["Stopped debugging."] = "Debuggen angehalten."
	L["Started debugging."] = "Debuggen gestartet."
	L["Unknown command:"] = "Unbekannter Befehl:"
	L["No reputation changes."] = "Keine Rufänderungen."
end

ns.L = L