**DCSS pillar dancing script by gmarks**

Automates pillar dancing. Essentially, the user chooses a pillar (or rather, a tile within a pillar), and the script auatomatically finds a shortest path around that pillar. It then automatically walks the user around the pillar as long as the user is able to walk away from all onscreen monsters until the user is at full HP and MP. As the script is certainly nowhere near a finished state, I have included a "manual" mode in which you can see where the pillar dance plans to take you next and "step" through the pillar dance.

To use, you have to put the contents of the `pillardance.lua` script in your crawl RC file, inside a pair of curly braces {}, like:

\<rest of rc file\>

{

\<contents of pillardance.lua\>

}

You have to macro a few keys to Lua functions. To macro the key K to the luafunction funcName, you would
put the following line in your crawl RC file:
macros += M K ===funcName

The functions that need to be mapped to keys are:

****inputPillar**** -- This is the "find pillar" function. When called, it will prompt the user to choose a tile of the
pillar that they want to use for pillar dancing. The function will then find the best path around the pillar and
save it, and show the tiles of that best path by excluding them.

****dancePillar**** -- This is the actual "dance pillar" function. When called, if the user is standing on one of the path
tiles, a pillar dance will be initiated. If auto mode is enabled, pillar dancing will automatically happen until

1. Both directions the user can walk take the user either closer to an enemy or adjacent to an enemy, or 
2. There are fast/ranged/magic-using enemies on screen, or 
3. The user is at full HP and MP, or 
4. It has been 500 turns since the dance began (this is to protect against the possibility the user has no regen near enemies or is a DD or
something). If auto mode is disabled, pillar dancing won't start automatically. Note that when manually pillar
dancing, above conditions 1 and 2 still cause the pillar dance to end.

If you are going to use manual mode, you will need to also map:

****doStep**** -- If we just started dancing or if we need to switch direction, this will just exclude the next tile we
plan to dance onto and return. Otherwise, this will move onto the calculated "next" tile that is currently
excluded, un-exclude it, and exclude the next tile we plan to dance onto. NOTE: You can end the manual dance by pressing the button bound to dancePillar. 

If you want to dynamically switch between auto and manual mode, map:

****invertAuto**** -- Switches between auto and manual mode.

And to "kill" the pillar, which has the benefit of removing the exclusion tiles around the pillar, map ****killPillar****.

Note: Doing stupid things could have unintended consequences; if you call functions or do things when this script
doesn't expect you to, bad things can and will happen. A good example is manually moving while in the middle of a
pillar dance, and then trying to keep dancing. Don't do this.

Feel free to give feedback/possible changes for the script by opening an issue or a PR.