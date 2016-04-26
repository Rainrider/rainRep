local addon, ns = ...	-- load the namespace
local L = ns.L			-- load the localization table
local locale = _G.GetLocale()

local standingMaxID = 8
local standingMinID = 1

local _G = _G
local abs = math.abs
local ceil = math.ceil
local format = string.format
local match = string.match
local gsub = string.gsub
local strlower = _G.strlower
local sort = table.sort
local wipe = table.wipe
local GetFactionInfo = _G.GetFactionInfo
local GetFactionInfoByID = _G.GetFactionInfoByID
local GetNumFactions = _G.GetNumFactions
local GetFriendshipReputation = _G.GetFriendshipReputation

local matchData = {
	-- global string // match order
	[_G.FRIENDSHIP_STANDING_CHANGED] = {
		enUS = {name = 1, standing = 2}, -- "Your relationship with %s is now %s."
		deDE = {name = 2, standing = 1},
	},
	[_G.FACTION_STANDING_CHANGED] = {
		enUS = {standing = 1, name = 2}, -- "You are now %s with %s."
		deDE = {standing = 2, name = 1},
		ruRU = {standing = 2, name = 1},
		zhCH = {standing = 2, name = 1},
		koKR = {standing = 2, name = 1},
	},
	[_G.FACTION_STANDING_CHANGED_GUILD] = {
		enUS = {standing = 1}, -- "You are now %s with your guild."
	},
	[_G.FACTION_STANDING_CHANGED_GUILDNAME] = {
		enUS = {standing = 1, name = 2}, -- "You are now %s with %s."
		deDE = {standing = 2, name = 1},
		ruRU = {standing = 2, name = 1},
		zhCH = {standing = 2, name = 1},
		koKR = {standing = 2, name = 1},
	},
	[_G.FACTION_STANDING_INCREASED_DOUBLE_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f Refer-A-Friend bonus) (+%.1f bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f Refer-A-Friend bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_ACH_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f bonus)"
	},
	[_G.FACTION_STANDING_INCREASED] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d."
	},
	[_G.FACTION_STANDING_INCREASED_GENERIC] = {
		enUS = {name = 1, mult = 1}, -- "Reputation with %s increased."
	},
	[_G.FACTION_STANDING_DECREASED] = {
		enUS = {name = 1, value = 2, mult = -1}, -- "Reputation with %s decreased by %d."
	},
	[_G.FACTION_STANDING_DECREASED_GENERIC] = {
		enUS = {name = 1, mult = -1}, -- "Reputation with %s decreased."
	},
}

local function ConvertToPattern(pattern)
	-- substitute all format specifier with \1
	pattern = gsub(pattern, "(%%%d?$?%d*%.?%d?[dsf])", "\1") -- %s : %d : %2$s : %1$03d : +%.1f : %2$10.4f
	-- escape the magic characters ( ) . % + - * ? [ ] by prepending %
	pattern = gsub(pattern, "[%(%)%.%%%+%-%*%?%[%]]", "%%%1")
	-- substitute \1 with the matcher
	pattern = gsub(pattern, "\1", "(.-)")
	return pattern
end

do
	local patternData = {}

	for gs, data in pairs(matchData) do
		local pattern = ConvertToPattern(gs)
		patternData[pattern] = data[locale or "enUS"]
	end

	matchData = patternData
end

-- get the standing text table
local standingTexts = {}
for i = standingMinID, standingMaxID do
	standingTexts[i] = _G.GetText("FACTION_STANDING_LABEL" .. i, _G.UnitSex("player"))
end

-- get the faction color table
local standingColors = {}
for i = standingMinID, standingMaxID do
	standingColors[i] = _G.FACTION_BAR_COLORS[i]
end

local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCrainRep|r"

local db
local defaultDB = {
	instanceGainList = {},
}

local factionIDs = {}
local isInInstance = false
local currentInstanceName = _G.WORLD
-----------------------
-- Utility Functions --
-----------------------
local Debug = function() end
if _G.AdiDebug then
	Debug = _G.AdiDebug:Embed({}, addon)
end

local dataobj = _G.LibStub("LibDataBroker-1.1"):NewDataObject("Broker_rainRep", {
    type = "data source",
    label = coloredAddonName,
})

local function GetStandingColoredName(standingID, name)
	local color = standingColors[standingID]
	return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
end

local function SortKeys(tbl)
	local sortedKeys = {}
	for k in pairs(tbl) do
		sortedKeys[#sortedKeys + 1] = k;
	end
	sort(sortedKeys)
	return sortedKeys
end

local function PrintSortedFactions(tbl)
	local sortedKeys = SortKeys(tbl)
	for i = 1, #sortedKeys do
		local name = sortedKeys[i]
		local id = factionIDs[name]
		local _, _, standing = GetFactionInfoByID(id)
		print(format("%s: %s", GetStandingColoredName(standing, name), tbl[name]))
	end
end

local function PrintTable(tbl)
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			PrintTable(v)
		else
			print(format("%s: %s", k, tostring(v)))
		end
	end
end

local function ScanFactions(event)
	for i = 1, GetNumFactions() do
		local name, _, _, _, _, _, _, _, isHeader, _, hasRep, _, _, id = GetFactionInfo(i)

		if (not isHeader or isHeader and hasRep) then
			factionIDs[name] = id
			Debug("|cff00ff00Added|r", name, id)
		else
			Debug("|cffff0000Skipped|r", name, id)
		end
	end

	Debug("Scanning factions done at", event)
end

local function UpdateInstanceGain(faction, value)
	local instance = currentInstanceName
	db.instanceGainList[instance] = db.instanceGainList[instance] or {}
	db.instanceGainList[instance][faction] = (db.instanceGainList[instance][faction] or 0) + value
end

local function ReportInstanceGain()
	local list = db.instanceGainList
	if not next(list) then
		return print(format("%s: %s", coloredAddonName, L["No reputation changes."]))
	end

	local sortedInstances = SortKeys(list)
	for i = 1, #sortedInstances do
		local name = sortedInstances[i]
		print(format("%s%s|r", yellowColor, name))
		local instance = list[name]
		PrintSortedFactions(instance)
	end
end

local function ReportFaction(name, change)
	local id = factionIDs[name]
	if not id then return ScanFactions() end
	local _, _, standing, low, high, value = GetFactionInfoByID(id)
	local reps
	local color
	if change > 0 then
		reps = ceil((high - value) / change)
		color = greenColor
	else
		reps = ceil((value - low) / abs(change))
		color = redColor
	end

	local text = format("%s%+d|r %s (%d)", color, change, GetStandingColoredName(standing, name), reps)
	dataobj.text = text;
	print(text)
end

local function Command(msg)
	msg = strlower(msg)
	if (msg == "report") then
		ReportInstanceGain()
	elseif (msg == "reset") then
		wipe(db.instanceGainList)
	elseif (msg == "db") then
		PrintTable(db)
	elseif (msg == "scan") then
		ScanFactions("scan")
	else
		print(format("%s: %s%s|r %s", coloredAddonName, redColor, L["Unknown command:"], msg))
	end
end

local rainRep = _G.CreateFrame("Frame", "rainRep")
rainRep:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
rainRep:RegisterEvent("ADDON_LOADED")

function rainRep:ADDON_LOADED(_, name)
	if (name == addon) then
		-- set slash commands
		_G.SLASH_rainRep1 = "/rrep"
		_G.SLASH_rainRep2 = "/rainrep"
		_G.SlashCmdList[name] = Command

		-- set saved variables
		_G.rainRepDB = _G.rainRepDB or {}
		db = setmetatable(_G.rainRepDB, { __index = defaultDB })

		-- events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UPDATE_FACTION")
		self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")

		self:UnregisterEvent("ADDON_LOADED")
	end
end

function rainRep:PLAYER_ENTERING_WORLD()
	isInInstance = _G.IsInInstance()
	currentInstanceName = isInInstance and _G.GetInstanceInfo() or _G.WORLD
end

function rainRep:UPDATE_FACTION(event)
	if (GetNumFactions() > 2) then
		ScanFactions(event)
		self:UnregisterEvent("UPDATE_FACTION")
		-- The real guild name becomes available at PLAYER_GUILD_UPDATE
		-- The guild rep bar is the second faction in the reputation ui if the player is in a guild
		if (GetFactionInfo(2) == _G.GUILD) then
			self:RegisterEvent("PLAYER_GUILD_UPDATE")
		end
	end
end

function rainRep:PLAYER_GUILD_UPDATE()
	local name = _G.GetGuildInfo("player")
	if (name) then
		factionIDs[_G.GUILD] = nil
		factionIDs[name] = 1168
		Debug("cff00ff00Added|r", name, 1168)
		self:UnregisterEvent("PLAYER_GUILD_UPDATE")
	end
end

function rainRep:CHAT_MSG_COMBAT_FACTION_CHANGE(_, msg) -- args: event, message
	local matches
	for pattern, data in pairs(matchData) do
		matches = {match(msg, pattern)}
		if #matches > 0 then
			local faction = matches[data.name]
			local value = matches[data.value]
			local standing = matches[data.standing]
			if standing then
				print(format("%s - %s"), faction, standing) -- TODO: coloring
			elseif value then
				value = value * (data.mult or 1)
				ReportFaction(faction, value)
			end
			break
		end
	end
end
