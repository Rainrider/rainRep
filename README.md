## Features

- Prints a short colored message to chat with your reputation gain/loss and the remaining repetitions until the next
standing. The amount is either green (gain) or red (loss) and the faction name is colored by its standing:
    - e.g. <span style="color:#00ff00">+25</span> <span style="color:#e6b300">Booty Bay</span> (810)
- Has a DataBroker display showing the total reputation changes by instance
    - A click toggles the reputation pane
    - Alt-Click resets the statistics
- Prints information about total reputation gain/loss in a dungeon after leaving the dungeon <span style="color:red">(NYI)</span>
- Zero configuration

## How it works

**rainRep** builds Lua search patterns from the global strings used in the current game locale. Those patterns are then
used in a message filter to figure out the faction with that the player's reputation changed and, if a match was found,
replace the message with a custom colored one. For this to work, rainRep manages a list of factions the player has
already encountered and maps each faction name to the corresponding faction ID.

## Current Limitations

**rainRep** relies on how the game communicates reputation changes through the chat system. On rare occasions Blizzard
reports certain changes by using the name of the reputation header instead of each individual faction, e.g. the Lunar
Festival quests provide reputation with every Alliance/Horde faction, but the message the client receives is
`"Reputation with Alliance increased by 75."` Funny enough not every Alliance/Horde faction gets the mentioned 75
points, and the Pandaren factions, added with Mists of Pandaria, did not get any points at all. In this case, rainRep
will just show the default message, because it will fail to find a faction named Alliance (or Horde) that is either not
a header in the default UI or is a header but has points.

**rainRep** does not differentiate between friendships and reputations as this is not required for it to function.
However this leads to friendships beeing incorrectly colored, because their standing IDs correspond to a different
reputation standing (standing ID 1 means "Hostile").