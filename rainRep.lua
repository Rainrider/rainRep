local debug = true

local standingMaxID = 8
local standingMinID = 1
local updateCounter = 0
local numFactions = 0

local format = string.format
local abs = math.abs
local ceil = math.ceil
local GetFactionInfo = GetFactionInfo

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
		rainRep:Debug("meta print")
		local str = ""
		if (not next(tbl)) then -- "if (not next(tbl))" should tell whether the table is empty
			return "Table is empty"
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
		self:Debug("instanceGainList wiped upon entering a dungeon")
		table.wipe(rainRepDB.instanceGainList)
		rainRepDB.playerWasDead = false
	end
	
	-- wipe instanceGainList if we join a new dungeon from the current dungeon
	if (rainRepDB.currLoc == "instance" and rainRepDB.prevLoc == "instance" and prevName ~= currName) then
		self:Debug("instanceGainList wiped upon entering a dungeon")
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
		local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(i) -- TODO: handle hasRep = header with rep info (i.e. Alliance Vanguard)
		
		if ((not isHeader or hasRep) and factionList[name]) then
			local diff = barValue - factionList[name].value
			
			if (diff ~= 0) then
				if (rainRepDB.currLoc == "instance") then
					self:InstanceGain(name, diff)
				end
			
				if (standingID ~= factionList[name].standing) then
					local standingText = _G["FACTION_STANDING_LABEL" .. standingID]
					local message = "You are now " .. standingText .. " with " .. self:GetStandingColoredName(standingID, name) .. "."
					self:Print(message)
				end
				
				local nextStanding, remaining, changeColor
				
				if (diff > 0) then -- reputation gain
					remaining = barMax - barValue
					changeColor = greenColor
					
					if (standingID < standingMaxID) then
						nextStanding = self:GetStandingColoredName(standingID + 1, _G["FACTION_STANDING_LABEL" .. standingID + 1])
					else
						nextStanding = "the end of " .. self:GetStandingColoredName(standingMaxID, _G["FACTION_STANDING_LABEL" .. standingMaxID])
					end
				else -- reputaion loss
					remaining = barValue - barMin
					changeColor = redColor
					
					if (standingID > standingMinID) then
						nextStanding = self:GetStandingColoredName(standingID - 1, _G["FACTION_STANDING_LABEL" .. standingID - 1])
					else
						nextStanding = "the beginning of " .. self:GetStandingColoredName(standingMinID, _G["FACTION_STANDING_LABEL" .. standingMinID])
					end
				end
				
				
				
				-- calculate repetitions
				local change = abs(diff)
				local repetitions = ceil(remaining / change)
				
				-- RepName +15. 150 more to nextstanding (10 repetitions)
				local message = format("%s%+d|r %s. %d more to %s (%d repetitions)", changeColor, diff, self:GetStandingColoredName(standingID, name), remaining, nextStanding, repetitions)
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
		self:Print(coloredAddonName .. "Reputation changes in " .. instanceName .. ":")
		self:Print(rainRepDB.instanceGainList)
		--wipe(rainRepDB.instanceGainList)
	end
end

function rainRep.Command(str, editbox)
	if (str == "factions") then
		local i = 0
		for k, v in pairs(factionList) do
			rainRep:Print(k)
			i = i + 1
		end
		rainRep:Print("Number of factions: " .. i)
	elseif (str == "report") then
		rainRep:Print(rainRepDB.instanceGainList)
		for k, v in pairs(rainRepDB.instanceGainList) do
			rainRep:Print(k .. ": " .. v)
		end
	elseif (str == "db") then
		rainRep:Print(rainRepDB)
	elseif (str == "reset") then
		table.wipe(rainRepDB.instanceGainList)
		rainRepDB = defaultDB
		rainRep:Print(coloredAddonName .. "Database reset.")
	else
		rainRep:Print(redColor .. "Unknown command:|r " .. str)
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