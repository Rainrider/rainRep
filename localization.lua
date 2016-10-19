local _, ns = ...

local L = {
	["Unknown command"] = "Unknown command",
	["Click"] = "Click",
	["Alt-Click"] = "Alt-Click",
}

local locale = _G.GetLocale()

if locale == "deDE" then
	L["Unknown command"] = "Unbekannter Befehl"
	L["Click"] = "Klick"
	L["Alt-Click"] = "Alt-Klick"
end

setmetatable(L, {__index = function(_, k)
	return k
end})

ns.L = L
