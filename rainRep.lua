local debug = true

local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCrainRep:|r "

local factionVars = {}

local standingMaxID = 8
local standingMinID = 1

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
		--factionsSV = factionsSV or {}
		
		-- events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
end

function rainRep:PLAYER_ENTERING_WORLD() -- TODO: sometimes the reps are not available at this. PLAYER_ALIVE is the next event on the list but it sucks
	-- scan factions and put them in factionVars
	self:ScanFactions()
	
	-- register events
	self:RegisterEvent("UPDATE_FACTION")
end

function rainRep:UPDATE_FACTION()
	self:Report()
end

function rainRep:ScanFactions()
	for i = 1, GetNumFactions() do
		local name, _, standingID, _, _, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(i)
		
		if (not isHeader or hasRep) then
			factionVars[name] = {}
			factionVars[name].standing = standingID
			factionVars[name].value = barValue
		end
	end
	self:Debug("Scanning factions done.")
end

function rainRep:Report()
	for i = 1, GetNumFactions() do
		local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(i) -- TODO: handle hasRep = header with rep info (i.e. Alliance Vanguard)
		
		if ((not isHeader or hasRep) and factionVars[name]) then
			local diff = barValue - factionVars[name].value
			
			if (diff ~= 0) then
				if (standingID ~= factionVars[name].standing) then
					local standingText = _G["FACTION_STANDING_LABEL" .. standingID]
					local message = "You are now " .. standingText .. " with " .. self:GetStandingColoredName(standingID, name) .. "."
					self:Print(message)
				end
				
				local nextStanding, remaining, sign, changeColor
				
				if (diff > 0) then -- reputation gain
					remaining = barMax - barValue
					sign = "+"
					changeColor = greenColor
					
					if (standingID < standingMaxID) then
						nextStanding = self:GetStandingColoredName(standingID + 1, _G["FACTION_STANDING_LABEL" .. standingID + 1])
					else
						nextStanding = " the end of " .. self:GetStandingColoredName(standingMaxID, _G["FACTION_STANDING_LEVEL" .. standingMaxID])
					end
				else -- reputaion loss
					remaining = barValue - barMin
					sign = "-"
					changeColor = redColor
					
					if (standingID > standingMinID) then
						nextStanding = self:GetStandingColoredName(standingID - 1, _G["FACTION_STANDING_LABEL" .. standingID - 1])
					else
						nextStanding = " the beginning of " .. self:GetStandingColoredName(standingMinID, _G["FACTION_STANDING_LEVEL" .. standingMinID])
					end
				end
				
				
				
				-- calculate repetitions
				local change = math.abs(diff)
				local repetitions = math.ceil(remaining / change)
				
				-- rainRep: RepName +15. 150 (10 repetitions) until nextstanding
				local message = self:GetStandingColoredName(standingID, name).. " " .. changeColor .. sign .. change .. "|r. ".. remaining .. " (" .. repetitions .. " repetitions) until " .. nextStanding .. "."
				self:Print(message)
				
				factionVars[name].standing = standingID
				factionVars[name].value = barValue
			end
		end
	end
end

function rainRep:GetStandingColoredName(standingID, name)
	local color = FACTION_BAR_COLORS[standingID]
	return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
end

function rainRep.Command(str, editbox)
	if (str == "factions") then
		local i = 0
		for k, v in pairs(factionVars) do
			rainRep:Print("key: " .. k)
			i = i + 1
		end
		rainRep:Print("Number of factions: " .. i)
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
	DEFAULT_CHAT_FRAME:AddMessage(coloredAddonName..str)
end