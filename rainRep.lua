local addon, ns = ...	-- load the namespace
local L = ns.L			-- load the localization table

local standingMaxID = 8
local standingMinID = 1

local format = string.format
local abs = math.abs
local ceil = math.ceil
local GetFactionInfo = GetFactionInfo
local GetNumFactions = GetNumFactions
local GetFriendshipReputation = GetFriendshipReputation

-- get the standing text table
local standingText = {}
for i = standingMinID, standingMaxID do
	standingText[i] = _G["FACTION_STANDING_LABEL" .. i]
end

-- get the faction color table
local standingColor = {}
for i = standingMinID, standingMaxID do
	standingColor[i] = FACTION_BAR_COLORS[i]
end

local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCrainRep:|r "

local factionList = {}
local db
local defaultDB = {
	prevLoc = "world",
	currLoc = "world",
	prevName = "",
	currName = "",
	playerWasDead = false,
	debug = false,
	instanceGainList = {},
}
local metaPrint = {
	__tostring = function(tbl)
		local str = ""
		if (not next(tbl)) then -- "if (not next(tbl))" should tell whether the table is empty
			return L["No reputation changes."]
		end
		for k, v in pairs(tbl) do
			str = str .. k .. ": " .. tostring(v) .. "\n"
		end

		return str
	end,
}

local rainRep = CreateFrame("Frame", "rainRep", UIParent)
rainRep:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
rainRep:RegisterEvent("ADDON_LOADED")

local Debug
if AdiDebug then
	Debug = AdiDebug:Embed(rainRep, "rainRep")
else
	Debug = function() end
end

function rainRep:ADDON_LOADED(event, name)
	if (name == addon) then
		-- set slash commands
		SLASH_rainRep1 = "/rrep"
		SLASH_rainRep2 = "/rainrep"
		SlashCmdList[name] = self.Command

		-- set saved variables
		rainRepDB = rainRepDB or defaultDB
		db = setmetatable(rainRepDB, metaPrint)
		db.instanceGainList = setmetatable(db.instanceGainList, metaPrint)

		-- events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UPDATE_FACTION")
		self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")

		self:UnregisterEvent("ADDON_LOADED")
	end
end

function rainRep:PLAYER_ENTERING_WORLD()
	local name, locType = GetInstanceInfo()

	db.prevLoc = db.currLoc
	db.prevName = db.currName
	db.currName = name

	if locType == "raid" or locType == "party" then
		db.currLoc = "instance"
	else
		db.currLoc = "world"
	end

	self:ReportInstanceGain(db.prevName)

	-- TODO: playerWasDead does not always get set to false
	-- wipe instanceGainList in case the player did a spirit rezz after an instance and then entered a new one
	if (db.currLoc == "instance" and db.prevLoc == "world" and not db.playerWasDead) then
		Debug("instanceGainList wiped upon entering a dungeon.")
		table.wipe(db.instanceGainList)
		db.playerWasDead = false
	-- wipe instanceGainList if we join a new dungeon from the current dungeon
	elseif (db.currLoc == "instance" and db.prevLoc == "instance" and prevName ~= currName) then
		Debug("instanceGainList wiped upon entering a dungeon from a dungeon.")
		table.wipe(db.instanceGainList)
	end
end

function rainRep:UPDATE_FACTION(event)
	if (GetNumFactions() > 0) then
		self:ScanFactions(event)
		self:UnregisterEvent("UPDATE_FACTION")
		-- when we have the factions info we still don't have the player's guild name (it just says "Guild" for both header and faction bar)
		-- Guild name becomes available at PLAYER_GUILD_UPDATE (PGU)
		-- so we have to rescan the factions to get the proper name at PGU _IF_ the player is in a guild
		-- The guild rep bar is the second faction in the reputation ui if the player is in a guild
		if (GetFactionInfo(2) == _G["GUILD"]) then
			self:RegisterEvent("PLAYER_GUILD_UPDATE")
		end
	end
end

function rainRep:PLAYER_GUILD_UPDATE(event)
	if (GetGuildInfo("player")) then
		self:ScanFactions(event)
		self:UnregisterEvent("PLAYER_GUILD_UPDATE")
	end
end

function rainRep:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message)
	self:Report(event)
end

function rainRep:ScanFactions(event)
	for i = 1, GetNumFactions() do
		local name, _, standingID, _, _, barValue, _, _, isHeader, _, hasRep, _, _, id = GetFactionInfo(i)
		local _, _, _, _, _, _, reaction = GetFriendshipReputation(id)

		if (not isHeader or isHeader and hasRep) then
			factionList[name] = {}
			factionList[name].value = barValue
			factionList[name].standing = reaction or standingID
			Debug("|cff00ff00Added|r", name, barValue, reaction, standingID)
		else
			Debug("|cffff0000Skipped|r", name)
		end
	end

	Debug("Scanning factions done at", event)
end

function rainRep:Report(event)
	for i = 1, GetNumFactions() do
		local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep, _, _, id = GetFactionInfo(i)
		local _, _, _, _, _, _, reaction, threshold, nextThreshold = GetFriendshipReputation(id)

		if (not reaction and factionList[name]) then
			local diff = barValue - factionList[name].value

			if (diff ~= 0) then
				if (rainRepDB.currLoc == "instance") then
					self:InstanceGain(name, diff)
				end

				if (standingID ~= factionList[name].standing) then
					local message = format(_G["FACTION_STANDING_CHANGED"], standingText[standingID], self:GetStandingColoredName(standingID, name))
					self:Print(message)
				end

				local nextStanding, remaining, changeColor

				if (diff > 0) then -- reputation gain
					remaining = barMax - barValue
					changeColor = greenColor

					if (standingID < standingMaxID) then
						nextStanding = self:GetStandingColoredName(standingID + 1, standingText[standingID + 1])
					else
						nextStanding = format("%s %s", L["the end of"], self:GetStandingColoredName(standingMaxID, standingText[standingMaxID]))
					end
				else -- reputaion loss
					remaining = barValue - barMin
					changeColor = redColor

					if (standingID > standingMinID) then
						nextStanding = self:GetStandingColoredName(standingID - 1, standingText[standingID - 1])
					else
						nextStanding = format("%s %s", L["the beginning of"], self:GetStandingColoredName(standingMinID, standingText[standingMinID]))
					end
				end

				-- calculate repetitions
				local repetitions = ceil(remaining / abs(diff))

				-- TODO: message should go into L
				-- +15 RepName. 150 more to nextstanding (10 repetitions)
				local message = format("%s%+d|r %s. %s%d|r %s %s (%d %s)", changeColor, diff, self:GetStandingColoredName(standingID, name), changeColor, remaining, L["more to"], nextStanding, repetitions, L["repetitions"])
				self:Print(message)

				factionList[name].standing = standingID
				factionList[name].value = barValue
			end
		end

		if (reaction and factionList[name]) then
			local diff = barValue - factionList[name].value

			if (diff ~= 0) then
				if (reaction ~= factionList[name].standing) then
					self:Print(format(_G["FRIENDSHIP_STANDING_CHANGED"], name, reaction))
					factionList[name].standing = reaction
				end

				local remaining, changeColor

				if (diff > 0) then
					-- nextThreshold is nil when friendship is maxed out (5 X 8400 = 42000 but max is 42999)
					nextThreshold = nextThreshold or 42999
					remaining = nextThreshold - barValue
					changeColor = greenColor
				else
					remaining = barValue - threshold
					changeColor = redColor
				end

				local repetitions = ceil(remaining / abs(diff))
				self:Print(format("%+d %s. %s%d|r (%d %s)", diff, name, changeColor, remaining, repetitions, L["repetitions"]))
				factionList[name].value = barValue
			end
		end
	end

	if (not factionList[name] and (not isHeader or isHeader and hasRep)) then
		Debug("New faction encountered:", name)
		self:ScanFactions(event)
	end
end

function rainRep:GetStandingColoredName(standingID, name)
	local color = standingColor[standingID]
	return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
end

function rainRep:InstanceGain(repName, diff)
	local match = false
	for k, v in pairs(db.instanceGainList) do
		if (k == repName) then
			db.instanceGainList[k] = v + diff
			match = true
			break -- exit the loop since we have a match
		end
	end

	if (not match) then
		db.instanceGainList[repName] = diff
	end
end

-- not UnitIsDeadOrGhost("player") to not wipe instanceGainList if we corpse run into an instance again
function rainRep:ReportInstanceGain(instanceName)
	local playerDead = UnitIsDeadOrGhost("player")

	if (db.currLoc == "world" and db.prevLoc == "instance" and playerDead) then
		Debug("Player is dead. No report, no table wipe.")
		db.playerWasDead = true
	elseif (db.prevLoc == "instance" and not playerDead) then
		self:Print(coloredAddonName, L["Reputation changes in"], instanceName .. ":")
		self:Print(db.instanceGainList)
		--wipe(db.instanceGainList)
	end
end

function rainRep.Command(str, editbox)
	if (str == "report") then
		rainRep:Print(db.instanceGainList)
	elseif (str == "db") then
		rainRep:Print(db)
	elseif (str == "reset") then
		table.wipe(db.instanceGainList)
		rainRepDB = defaultDB
		db = setmetatable(rainRepDB, metaPrint)
		db.instanceGainList = setmetatable(db.instanceGainList, metaPrint)
		rainRep:Print(coloredAddonName, L["Database reset."])
	elseif (str == "scan") then
		rainRep:ScanFactions("scan")
	else
		rainRep:Print(coloredAddonName, redColor .. L["Unknown command:"] .."|r", str)
	end
end

function rainRep:Print(...)
	local str = tostring(...)
	DEFAULT_CHAT_FRAME:AddMessage(str)
end