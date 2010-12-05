local _, ns = ...	-- load the namespace
local L = ns.L		-- load the localization table

local debug = false

local standingMaxID = 8
local standingMinID = 1
local updateCounter = 0
local numFactions = 0

local format = string.format
local abs = math.abs
local ceil = math.ceil
local GetFactionInfo = GetFactionInfo
local GetNumFactions = GetNumFactions

local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCrainRep:|r "

local factionList = {}
local defaultDB = {
	prevLoc = "world",
	currLoc = "world",
	prevName = "",
	currName = "",
	playerWasDead = false,
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

function rainRep:ADDON_LOADED(event, name)
	if (name == self:GetName()) then
		-- set slash commands
		SLASH_rainRep1 = "/rrep"
		SLASH_rainRep2 = "/rainrep"
		SlashCmdList[name] = self.Command
	
		-- set saved variables
		rainRepDB = rainRepDB or defaultDB
		rainRepDB = setmetatable(rainRepDB, metaPrint)
		rainRepDB.instanceGainList = setmetatable(rainRepDB.instanceGainList, metaPrint)
		
		-- events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UPDATE_FACTION")
		-- does unregestering ADDON_LOADED get us something?
	end
end


function rainRep:PLAYER_ENTERING_WORLD()
	local name, locType = GetInstanceInfo()
	
	rainRepDB.prevLoc = rainRepDB.currLoc
	rainRepDB.prevName = rainRepDB.currName
	rainRepDB.currName = name
	
	if locType == "raid" or locType == "party" then
		rainRepDB.currLoc = "instance"
	else
		rainRepDB.currLoc = "world"
	end
	
	self:ReportInstanceGain(rainRepDB.prevName)
	
	-- wipe instanceGainList in case the player did a spirit rezz after an instance and then entered a new one
	if (rainRepDB.currLoc == "instance" and rainRepDB.prevLoc == "world" and not rainRepDB.playerWasDead) then
		self:Debug("instanceGainList wiped upon entering a dungeon.")
		table.wipe(rainRepDB.instanceGainList)
		rainRepDB.playerWasDead = false
	-- wipe instanceGainList if we join a new dungeon from the current dungeon
	elseif (rainRepDB.currLoc == "instance" and rainRepDB.prevLoc == "instance" and prevName ~= currName) then
		self:Debug("instanceGainList wiped upon entering a dungeon from a dungeon.")
		table.wipe(rainRepDB.instanceGainList)
	end
end

-- NOTES: UPDATE_FACTION fires 3 times after login and twice after reloadui. Reps are available from the 2nd fire after login and the 1st after reloadui.
function rainRep:UPDATE_FACTION()
	if (updateCounter < 3) then
		updateCounter = updateCounter + 1
	end

	if (updateCounter > 2) then
		self:Report()
	elseif (updateCounter == 2) then
		self:ScanFactions()
	end
end

-- we need the headers too in order to catch new factions in Report()
function rainRep:ScanFactions()
	for i = 1, GetNumFactions() do
		local name, _, standingID, _, _, barValue = GetFactionInfo(i)

		numFactions = numFactions + 1
		factionList[name] = {}
		factionList[name].standing = standingID
		factionList[name].value = barValue
	end
	self:Debug("Scanning factions done.")
end

function rainRep:Report()
	for i = 1, GetNumFactions() do
		local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(i)
		
		if ((not isHeader or hasRep) and factionList[name]) then
			local diff = barValue - factionList[name].value
			
			if (diff ~= 0) then
				if (rainRepDB.currLoc == "instance") then
					self:InstanceGain(name, diff)
				end
			
				if (standingID ~= factionList[name].standing) then
					local standingText = _G["FACTION_STANDING_LABEL" .. standingID]
					local message = format(_G["FACTION_STANDING_CHANGED"], standingText, self:GetStandingColoredName(standingID, name))
					self:Print(message)
				end
				
				local nextStanding, remaining, changeColor
				
				if (diff > 0) then -- reputation gain
					remaining = barMax - barValue
					changeColor = greenColor
					
					if (standingID < standingMaxID) then
						nextStanding = self:GetStandingColoredName(standingID + 1, _G["FACTION_STANDING_LABEL" .. standingID + 1])
					else
						nextStanding = L["the end of"] .. " " .. self:GetStandingColoredName(standingMaxID, _G["FACTION_STANDING_LABEL" .. standingMaxID])
					end
				else -- reputaion loss
					remaining = barValue - barMin
					changeColor = redColor
					
					if (standingID > standingMinID) then
						nextStanding = self:GetStandingColoredName(standingID - 1, _G["FACTION_STANDING_LABEL" .. standingID - 1])
					else
						nextStanding = L["the beginning of"] .. " " .. self:GetStandingColoredName(standingMinID, _G["FACTION_STANDING_LABEL" .. standingMinID])
					end
				end
				
				-- calculate repetitions
				local change = abs(diff)
				local repetitions = ceil(remaining / change)
				
				-- TODO: 	3 table look-ups for message (2 in L, 1 in _G)
				--			2-3 table look-ups for nextStanding (1 in L, 2 in _G)
				--			and 2 more if we get a new standing (both in _G)
				--			best case: 5 look-ups, worst case: 8 per single rep change
				-- +15 RepName. 150 more to nextstanding (10 repetitions)
				local message = format("%s%+d|r %s. %s%d|r %s %s (%d %s)", changeColor, diff, self:GetStandingColoredName(standingID, name), changeColor, remaining, L["more to"], nextStanding, repetitions, L["repetitions"])
				self:Print(message)
				
				factionList[name].standing = standingID
				factionList[name].value = barValue
			end
		end
	end
	
	if (GetNumFactions() > numFactions) then
		self:Debug("New faction encountered.")
		self:ScanFactions()
	end
end

function rainRep:GetStandingColoredName(standingID, name)
	local color = FACTION_BAR_COLORS[standingID]
	return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
end

function rainRep:InstanceGain(repName, diff)
	local match = false
	for k, v in pairs(rainRepDB.instanceGainList) do
		if (k == repName) then
			rainRepDB.instanceGainList[k] = v + diff
			match = true
			break -- exit the loop since we have a match
		end
	end
	
	if (not match) then
		rainRepDB.instanceGainList[repName] = diff
	end
end

-- not UnitIsDeadOrGhost("player") to not wipe instanceGainList if we corpse run into an instance again
function rainRep:ReportInstanceGain(instanceName)
	local playerDead = UnitIsDeadOrGhost("player")
	
	if (rainRepDB.currLoc == "world" and rainRepDB.prevLoc == "instance" and playerDead == 1) then
		self:Debug("Player is dead. No report, no table wipe")
		rainRepDB.playerWasDead = true
	elseif (rainRepDB.prevLoc == "instance" and not playerDead) then
		self:Print(coloredAddonName .. L["Reputation changes in"] .. " " .. instanceName .. ":")
		self:Print(rainRepDB.instanceGainList)
		--wipe(rainRepDB.instanceGainList)
	end
end

function rainRep.Command(str, editbox)
	if (str == "report") then
		rainRep:Print(rainRepDB.instanceGainList)
	elseif (str == "db") then
		rainRep:Print(rainRepDB)
	elseif (str == "reset") then
		table.wipe(rainRepDB.instanceGainList)
		rainRepDB = defaultDB
		rainRepDB = setmetatable(rainRepDB, metaPrint)
		rainRepDB.instanceGainList = setmetatable(rainRepDB.instanceGainList, metaPrint)
		rainRep:Print(coloredAddonName .. L["Database reset."])
	elseif (str == "debug") then
		if (debug) then
			debug = false
			rainRep:Print(coloredAddonName .. L["Stopped debugging."])
		else
			debug = true
			rainRep:Print(coloredAddonName .. L["Started debugging."])
		end
	else
		rainRep:Print(redColor .. L["Unknown command:"] .."|r " .. str)
	end
end

function rainRep:Debug(...)
	if (debug) then
		print(coloredAddonName .. redColor .. "debug:|r ", ...)
	end
end

function rainRep:Print(...)
	local str = tostring(...)
	DEFAULT_CHAT_FRAME:AddMessage(str)
end