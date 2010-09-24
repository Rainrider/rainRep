local debug = true

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
					local standingText = _G["FACTION_STANDING_LABEL"..standingID]
					local message = "You are now "..standingText.." with "..self:GetStandingColor(standingID)..name.."|r."
					DEFAULT_CHAT_FRAME:AddMessage(message)
				end
				
				local nextStanding, remaining, sign
				local message = "|cffff7831rainRep:|r "
				
				if (diff > 0) then -- reputation gain
					remaining = barMax - barValue
					sign = "+"
					
					if (standingID < standingMaxID) then
						nextStanding = self:GetStandingColor(standingID + 1).._G["FACTION_STANDING_LABEL"..standingID + 1].."|r"
					else
						nextStanding = " the end of "..self:GetStandingColor(standingMaxID).._G["FACTION_STANDING_LEVEL"..standingMaxID].."|r."
					end
				else -- reputaion loss
					remaining = barValue - barMin
					sign = "-"
					
					if (standingID > standingMinID) then
						nextStanding = self:GetStandingColor(standingID - 1).._G["FACTION_STANDING_LABEL"..standingID - 1].."|r"
					else
						nextStanding = " the beginning of "..self:GetStandingColor(standingMinID).._G["FACTION_STANDING_LEVEL"..standingMinID].."|r."
					end
				end
				
				-- calculate repetitions
				local change = math.abs(diff)
				local repetitions = math.ceil(remaining / change)
				message = message..self:GetStandingColor(standingID)..name.."|r "..sign..change..". "..repetitions.." repetitions until "..nextStanding.."."
				
				-- rainRep: RepName +15. 150 repetitions until nextstanding
				DEFAULT_CHAT_FRAME:AddMessage(message)
				
				factionVars[name].standing = standingID
				factionVars[name].value = barValue
			end
		end
	end
end

function rainRep:GetStandingColor(standingID)
	local color = FACTION_BAR_COLORS[standingID]
	return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

function rainRep.Command(str, editbox)
	if (str == "factions") then
		local i = 0
		for k, v in pairs(factionVars) do
			DEFAULT_CHAT_FRAME:AddMessage("key: "..k)
			i = i + 1
		end
		print("|cffff7831rainRep: ".."Number of factions: "..i)
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff7831rainRep: ".."Unknown command: "..str)
	end
end

function rainRep:Debug(...)
	local str = tostring(...)
	if (debug) then
		print("|cffff7831rainRep debug:|r "..str)
	end
end