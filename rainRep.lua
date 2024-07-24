local addon, ns = ...	-- load the namespace
local L = ns.L			-- load the localization table
local locale = _G.GetLocale()

local OUTPUT = "%s%+d|r %s (%d) %s" -- color, change, faction, reps, suffix
local PARAGON_SUFFIX = "|A:ParagonReputation_Bag:0:0:0:0|a"
local WARBAND_SUFFIX = '|A:warbands-icon:0:0:0:0|a'

local ceil = math.ceil
local format = string.format
local match = string.match
local gsub = string.gsub
local strsplit = _G.strsplit
local sort = table.sort
local wipe = _G.table.wipe
local CollapseFactionHeader = _G.C_Reputation.CollapseFactionHeader
local ExpandFactionHeader = _G.C_Reputation.ExpandFactionHeader
local GetFactionDataByIndex = _G.C_Reputation.GetFactionDataByIndex
local GetFactionDataByID = _G.C_Reputation.GetFactionDataByID
local GetNumFactions = _G.C_Reputation.GetNumFactions
local IsAccountWideReputation = _G.C_Reputation.IsAccountWideReputation
local UnitFactionGroup = _G.UnitFactionGroup

local GUILD = _G.GUILD
local GUILD_FACTION_ID = 1168

local matchData = {
	-- global string // match order
	[_G.FRIENDSHIP_STANDING_CHANGED] = {
		enUS = {name = 1, standing = 2}, -- "Your relationship with %s is now %s."
		deDE = {name = 2, standing = 1},
	},
	[_G.FRIENDSHIP_STANDING_CHANGED_ACCOUNT_WIDE] = {
		enUS = {name = 1, standing = 2}, -- "Your Warband's relationship with %s is now %s."
		deDE = {name = 2, standing = 1},
	},
	[_G.FACTION_STANDING_CHANGED] = {
		enUS = {standing = 1, name = 2}, -- "You are now %s with %s."
		deDE = {standing = 2, name = 1},
		ruRU = {standing = 2, name = 1},
		zhCH = {standing = 2, name = 1},
		koKR = {standing = 2, name = 1},
	},
	[_G.FACTION_STANDING_CHANGED_ACCOUNT_WIDE] = {
		enUS = {standing = 1, name = 2}, -- "Your Warband is now %s with %s."
		deDE = {standing = 2, name = 1},
		ruRU = {standing = 2, name = 1},
		zhCH = {standing = 2, name = 1},
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
	[_G.FACTION_STANDING_INCREASED] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d."
	},
	[_G.FACTION_STANDING_INCREASED_ACCOUNT_WIDE] = {
		enUS = {name = 1, value = 2, mult = 1}, --"Your Warband's reputation with %s increased by %d."
	},
	[_G.FACTION_STANDING_INCREASED_ACH_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Your Warband's reputation with %s increased by %d. (+%.1f bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f Refer-A-Friend bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_DOUBLE_BONUS] = {
		enUS = {name = 1, value = 2, mult = 1}, -- "Reputation with %s increased by %d. (+%.1f Refer-A-Friend bonus) (+%.1f bonus)"
	},
	[_G.FACTION_STANDING_INCREASED_GENERIC] = {
		enUS = {name = 1, mult = 1}, -- "Reputation with %s increased."
	},
	[_G.FACTION_STANDING_INCREASED_GENERIC_ACCOUNT_WIDE] = {
		enUS = {name = 1, mult = 1}, -- "Your Warband's reputation with %s increased."
	},
	[_G.FACTION_STANDING_DECREASED] = {
		enUS = {name = 1, value = 2, mult = -1}, -- "Reputation with %s decreased by %d."
	},
	[_G.FACTION_STANDING_DECREASED_ACCOUNT_WIDE] = {
		enUS = {name = 1, value = 2, mult = -1}, -- "Your Warband's reputation with %s decreased by %d."
	},
	[_G.FACTION_STANDING_DECREASED_GENERIC] = {
		enUS = {name = 1, mult = -1}, -- "Reputation with %s decreased."
	},
	[_G.FACTION_STANDING_DECREASED_GENERIC_ACCOUNT_WIDE] = {
		enUS = {name = 1, mult = -1}, -- "Your Warband's reputation with %s decreased."
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

-- get the faction color table
local standingColors = {}
for i = 1, _G.MAX_REPUTATION_REACTION do
	standingColors[i] = _G.FACTION_BAR_COLORS[i]
end
standingColors[_G.MAX_REPUTATION_REACTION + 1] = {r = 0, g = 0.5, b = 0.9} -- fake paragon standing

local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCrainRep|r"

local db
local defaultDB = {
	instanceGainList = {},
}

local factionIDs = {}
local currentInstanceName = _G.WORLD

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
		local faction = GetFactionDataByID(id)
		print(format("%s: %s", GetStandingColoredName(faction.reaction, name), tbl[name]))
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

local factionGroup, collapsed, allegiance, scanning, _ = {}, {}, nil, nil, nil
local function ScanFactions(event)
	if scanning then return end

	scanning = true
	_, allegiance = UnitFactionGroup("player")
	local i, limit = 1, GetNumFactions()
	local isInFactionGroup = false
	while i <= limit do
		local faction = GetFactionDataByIndex(i)
		local isHeader, isCollapsed =  faction.isHeader, faction.isCollapsed
		local name, id = faction.name, faction.factionID

		if isHeader and name == allegiance then
			isInFactionGroup = true
		elseif isHeader and isInFactionGroup then
			isInFactionGroup = false
		end

		-- GetNumFactions counts expanded factions only
		if isCollapsed then
			collapsed[#collapsed + 1] = i
			ExpandFactionHeader(i)
			limit = GetNumFactions()
		end

		if not isHeader or faction.isHeaderWithRep then
			factionIDs[name] = id
			Debug("|cff00ff00Added|r", name, id)

			-- handle cases like 'Your reputation with the Alliance has increased by 75'
			if isInFactionGroup then
				local _, _, value = ns:GetFactionValues(id)
				factionGroup[name] = value
				Debug(allegiance, name, value)
			end
		else
			Debug("|cffff0000Skipped|r", name, id, isCollapsed and "(" or  "(not " .. "collapsed)")
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

local function UpdateInstanceInfo()
	currentInstanceName = _G.IsInInstance() and _G.GetInstanceInfo() or _G.WORLD
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

local function ReportNumbers(name, change, standing, low, high, value, suffix)
	Debug("Reporting", name, change)
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
end

local function ReportFactionGroup()
	for name, oldValue in next, factionGroup do
		local id = factionIDs[name]
		local _, low, value, high, standing = ns:GetFactionValues(id)
		local change = value - oldValue
		if change ~= 0 then
			ReportNumbers(name, change, standing, low, high, value, '')
			factionGroup[name] = value
		else
			Debug(allegiance, name, 'not changed', oldValue, value)
		end
	end
end

local function ReportFaction(name, change)
	if name == allegiance then
		_G.C_Timer.After(2, ReportFactionGroup)
		return true
	end

	local id = factionIDs[name]
	if not id then
		_G.C_Timer.After(2, ScanFactions)
		_G.C_Timer.After(3, function() return ReportFaction(name, change) end)
		return true
	end

	local _, low, value, high, standing, _, hasPendingAward = ns:GetFactionValues(id)
	local suffix = hasPendingAward and PARAGON_SUFFIX or ''
	
	if IsAccountWideReputation(id) then
		suffix = suffix .. WARBAND_SUFFIX
	end

	ReportNumbers(name, change, standing, low, high, value, suffix)
	return true
end

local function Command(msg)
	local command, change, factionName = strsplit(' ', msg, 3)
	if (command == "report") then
		ReportInstanceGain()
	elseif (command == "reset") then
		wipe(db.instanceGainList)
	elseif (command == "db") then
		PrintTable(db)
	elseif (command == "scan") then
		ScanFactions("scan")
	elseif (command == "factions") then
		PrintSortedFactions(factionIDs)
	elseif (command == "group") then
		ReportFactionGroup()
	elseif command == 'test' then
		ReportFaction(factionName, tonumber(change))
	else
		print(format("%s: %s:%s|r %s", coloredAddonName, redColor, L["Unknown command"], command))
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
					local standing = GetFactionDataByID(factionIDs[faction]).reaction
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

		self:UnregisterEvent("ADDON_LOADED")
	end
end

function rainRep:PLAYER_ENTERING_WORLD(event)
	ScanFactions(event)
	UpdateInstanceInfo()
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function rainRep:ZONE_CHANGED_NEW_AREA()
	UpdateInstanceInfo()
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
