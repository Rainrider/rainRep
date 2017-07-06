local addon, ns = ...	-- load the namespace
local L = ns.L			-- load the localization table
local locale = _G.GetLocale()

local OUTPUT = "%s%+d|r %s (%d) %s" -- color, change, faction, reps, suffix
local REWARD_ATLAS = "ParagonReputation_Bag"

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
local CollapseFactionHeader = _G.CollapseFactionHeader
local ExpandFactionHeader = _G.ExpandFactionHeader
local GetFactionInfo = _G.GetFactionInfo
local GetFactionInfoByID = _G.GetFactionInfoByID
local GetFactionParagonInfo = _G.C_Reputation.GetFactionParagonInfo
local GetNumFactions = _G.GetNumFactions
local GetFriendshipReputation = _G.GetFriendshipReputation

local GUILD = _G.GUILD
local GUILD_FACTION_ID = 1168

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
standingColors[9] = {r = 0, g = 0.5, b = 0.9} -- fake paragon standing

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
    label = _G.REPUTATION,
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

local collapsed, scanning = {}
local function ScanFactions(event)
	if scanning then return end
	scanning = true
	local i, limit = 1, GetNumFactions()
	while i <= limit do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed, hasRep, _, _, id = GetFactionInfo(i)

		if isCollapsed then
			collapsed[#collapsed + 1] = i
			ExpandFactionHeader(i)
			limit = GetNumFactions()
		end

		if not isHeader or isHeader and hasRep then
			factionIDs[name] = id
			Debug("|cff00ff00Added|r", name, id)
		else
			Debug("|cffff0000Skipped|r", name, id, isCollapsed and "(collapsed)" or "(not collapsed)")
		end

		i = i + 1
	end

	if #collapsed > 0 then
		for i = #collapsed, 1, -1 do
			CollapseFactionHeader(collapsed[i])
		end
	end

	factionIDs[GUILD] = GUILD_FACTION_ID -- Just always add the damn guild
	scanning = nil
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
	if not id then
		ScanFactions()
		id = factionIDs[name]
		if not id then return end
	end
	Debug("Reporting", id, name, change)

	local standing, low, suffix, _ = 9, 0, "" -- defaults for paragon factions
	local value, high, _, hasRewardPending = GetFactionParagonInfo(id)
	if value then
		value = value % high
		if hasRewardPending then
			suffix = format("|A:%s:0:0:0:0|a", REWARD_ATLAS)
		end
	else
		_, _, standing, low, high, value = GetFactionInfoByID(id)
	end

	local reps, color
	if change > 0 then
		reps = ceil((high - value) / change)
		color = greenColor
	else
		reps = ceil((value - low) / -change)
		color = redColor
	end

	local text = format(OUTPUT, color, change, GetStandingColoredName(standing, name), reps, suffix)
	dataobj.text = text;
	print(text)

	return true
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
	elseif (msg == "factions") then
		PrintSortedFactions(factionIDs)
	else
		print(format("%s: %s:%s|r %s", coloredAddonName, redColor, L["Unknown command"], msg))
	end
end

local function ShowTooltip(tt)
	local list = db.instanceGainList
	tt:SetText(_G.COMBAT_TEXT_SHOW_REPUTATION_TEXT)
	tt:AddLine(" ")
	if not next(list) then
		tt:AddLine(_G.NONE)
		tt:AddLine(" ")
	else
		local sortedInstances = SortKeys(list)
		for i = 1, #sortedInstances do
			local instance = sortedInstances[i]
			local data = list[instance]
			if next(data) then
				tt:AddLine(instance)
				local sortedFactions = SortKeys(data)
				for j = 1, #sortedFactions do
					local faction = sortedFactions[j]
					local value = data[faction]
					local _, _, standing = GetFactionInfoByID(factionIDs[faction])
					local color = standingColors[standing]
					local lr, lg, lb = color.r, color.g, color.b
					local rr, rg, rb
					if value > 0 then
						rr, rg, rb = 0, 1, 0
					else
						rr, rg, rb = 1, 0, 0
					end
					tt:AddDoubleLine("   "..faction, value, lr, lg, lb, rr, rg, rb)
				end
				tt:AddLine(" ")
			end
		end
		tt:AddLine(format("|cff0099cc%s:|r |cffffffff%s|r", L["Alt-Click"], _G.RESET))
	end

	tt:AddLine(format("|cff0099cc%s:|r |cffffffff%s|r", L["Click"], _G.BINDING_NAME_TOGGLECHARACTER2))
end

local function OnClick()
	if _G.IsAltKeyDown() then
		wipe(db.instanceGainList)
	else
		_G.ToggleCharacter("ReputationFrame")
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
		db = setmetatable(_G.rainRepDB, { __index = function(t, k)
			rawset(t, k, defaultDB[k])
			return t[k]
		end})

		-- data broker
		dataobj.OnTooltipShow = ShowTooltip
		dataobj.OnClick = OnClick

		-- events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UPDATE_FACTION")

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
		self:UnregisterEvent(event)
		self:RegisterEvent("PLAYER_GUILD_UPDATE")
	end
end

function rainRep:PLAYER_GUILD_UPDATE(event)
	local name = _G.GetGuildInfo("player")
	if (name and not factionIDs[name]) then
		factionIDs[name] = GUILD_FACTION_ID
		factionIDs[GUILD] = GUILD_FACTION_ID
		Debug("|cff00ff00Added|r", name, GUILD_FACTION_ID)
		self:UnregisterEvent(event)
	end
end

_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", function(_, _, msg)
	local filter = false
	for pattern, data in pairs(matchData) do
		local matches = {match(msg, pattern)}
		if #matches > 0 then
			local faction = matches[data.name]
			local value = matches[data.value]
			local standing = matches[data.standing]
			if standing then
				print(format("%s - %s"), faction, standing) -- TODO: coloring, paragon
				filter = true
			elseif value then
				value = value * (data.mult or 1)
				filter = ReportFaction(faction, value)
				UpdateInstanceGain(faction, value) -- TODO: base on instance or session?
			end
			break
		end
	end

	return filter
end)
