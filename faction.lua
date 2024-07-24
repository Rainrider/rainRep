local _, ns = ...

local factionTypes = {}

function ns:GetFactionValues(factionId)
	local factionType = factionTypes[factionId]
	local name, low, value, high, level, isParagon, hasPendingReward

	if nil ~= factionType then
		name, low, value, high, level, isParagon, hasPendingReward = self['Get'..factionType](self, factionId)
		factionType = isParagon and 'Paragon' or factionType
	else
		if _G.C_Reputation.IsMajorFaction(factionId) then
			name, low, value, high, level, isParagon, hasPendingReward = self:GetMajorFaction(factionId)
			factionType = isParagon and 'Paragon' or 'MajorFaction'
		else
			name, low, value, high, level, isParagon, hasPendingReward = self:GetFriendship(factionId)

			if nil ~= name then
				factionType = isParagon and 'Paragon' or 'Friendship'
			else
				name, low, value, high, level, isParagon, hasPendingReward = self:GetReputation(factionId)
				factionType = isParagon and 'Paragon' or 'Reputation'
			end
		end
	end

	factionTypes[factionId] = factionType

	return name, low, value, high, level, isParagon, hasPendingReward
end

function ns.GetFriendship(_, factionId)
	local friendship = _G.C_GossipInfo.GetFriendshipReputation(factionId)
	local name, low, value, high, level, isParagon = nil, nil, nil, nil, nil, nil

	if friendship and friendship.friendshipFactionID == factionId then
		name = friendship.name
		low = friendship.reactionThreshold
		value = friendship.standing
		high = friendship.nextThreshold or value
		level = _G.C_Reputation.GetFactionDataByID(factionId).reaction
		isParagon = false
	end

	return name, low, value, high, level, isParagon
end

function ns:GetMajorFaction(factionId)
	if _G.C_MajorFactions.HasMaximumRenown(factionId) then
		return self:GetParagon(factionId)
	end

	local name, low, value, high, level, isParagon = nil, nil, nil, nil, nil, nil
	local renown = _G.C_MajorFactions.GetMajorFactionData(factionId)

	if renown and renown.name then
		name = renown.name
		low = 0
		value = renown.renownReputationEarned
		high = renown.renownLevelThreshold
		level = 9
		isParagon = false
	end

	return name, low, value, high, level, isParagon
end

function ns.GetParagon(_, factionId)
	local name, low, level, isParagon = nil, nil, nil, nil
	local value, high, _, hasPendingReward = _G.C_Reputation.GetFactionParagonInfo(factionId)

	if nil ~= value then
		name = _G.C_Reputation.GetFactionDataByID(factionId).name
		low = 0
		level = 9
		value = value % high
		isParagon = true
	end

	return name, low, value, high, level, isParagon, hasPendingReward
end

function ns:GetReputation(factionId)
	if _G.C_Reputation.IsFactionParagon(factionId) then
		return self:GetParagon(factionId)
	end

	local isParagon = nil
	local faction = _G.C_Reputation.GetFactionDataByID(factionId)
	local name, level = faction.name, faction.reaction
	local low, high, value = faction.currentReactionThreshold, faction.nextReactionThreshold, faction.currentStanding

	if nil ~= name then
		isParagon = false
	end

	return name, low, value, high, level, isParagon
end