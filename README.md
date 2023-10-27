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
