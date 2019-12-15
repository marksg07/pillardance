-- change this between "false" and "true" to change the default mode.
auto = false

mk = 1
_path = nil
_seqForward = nil
_seqBackward = nil
_seqidx = 0
_dir = true
_pillarDance = false

function invertAuto()
    auto = not auto
    if auto then
        crawl.mpr("Switched into auto mode.")
    else
        crawl.mpr("Switched into manual mode.")
    end
end

function inputPillar()
    local x, y = crawl.get_target()
    killPillar()
    doSearch(x, y)
    travel.set_waypoint(7, 0, 0)
end

function dancePillar()
    if (not auto) and _pillarDance then
        crawl.mpr("Stopping manual dance.")
        stopPillarDance()
        if _nextAction ~= nil then
            -- kill the exclude we set after our last step
            local x, y = getOffset(_nextAction)
            travel.del_exclude(x, y, 0)
        end
        return
    end
    if _path == nil then
        crawl.mpr("No search selected!")
        return
    end
    -- find which tile (if any) of the path we are standing on
    local x, y = travel.waypoint_delta(7)
    local path = _path
    local idx = 0
    for i, xy in ipairs(path) do
        if xy[1] == x and xy[2] == y then
            idx = i
            break
        end
    end
    if idx == 0 then
        crawl.mpr("Please step on one of the excluded tiles.")
        return
    end
    startPillarDance()
    _seqForward = getSeq(path)
    _seqBackward = getSeqBackwards(path)
    _seqidx = idx
    if (not auto) then
        crawl.mpr("Starting manual dance.")
    end
end

do
    local toOff
    function getOffset(cmd)
        toOff = toOff or { CMD_MOVE_UP_LEFT = { -1, -1 },
            CMD_MOVE_UP_RIGHT = { 1, -1 },
            CMD_MOVE_DOWN_LEFT = { -1, 1 },
            CMD_MOVE_DOWN_RIGHT = { 1, 1 },
            CMD_MOVE_UP = { 0, -1 },
            CMD_MOVE_DOWN = { 0, 1 },
            CMD_MOVE_LEFT = { -1, 0 },
            CMD_MOVE_RIGHT = { 1, 0 } }
        return unpack(toOff[cmd])
    end
end


function checkDance()
    -- checks whether we should dance, based on hp, mp, monster positioning, ... and also changes our direction
    -- if necessary (i.e. a monster is blocking our path).
    if not shouldDance() then
        stopPillarDance()
        return false
    end
    assert(_seqForward ~= nil)
    assert(_seqBackward ~= nil)
    assert(_seqidx ~= 0)
    local monsters = getAllMonsters()
    -- fast monsters and ranged monsters + casters are bad for health
    -- TODO allow user to override, could be useful for high-regen users vs. low level fast mons
    for i, mon in ipairs(monsters) do
        if string.find(mon:speed_description(), "fast") then
            crawl.mpr("Fast monster in LOS!")
            stopPillarDance()
            return false
        end
        if #(mon:spells()) ~= 0 or mon:has_known_ranged_attack() then
            crawl.mpr("Spellcaster/ranged/abilityperson in LOS!")
            stopPillarDance()
            return false
        end
        if mon:status("fast") or mon:status("covering ground quickly") then
            crawl.mpr("Hasted/berserked/swifting monster in LOS!")
            stopPillarDance()
            return false
        end
    end

    local xdir, ydir, xndir, yndir
    local x, y = getOffset(getNextAction())
    xdir, ydir = x, y
    -- the below pile of ifs checks whether we should keep going in current direction, switch direction, or stop
    -- altogether. It favors moving away from monsters to moving not away, and will never move towards monsters or
    -- within one tile of a monster.
    if not tileIsBetter(x, y, monsters) then
        _dir = not _dir
        x, y = getOffset(getNextAction())
        xndir, yndir = x, y
        if not tileIsBetter(x, y, monsters) then
            _dir = not _dir
            x, y = xdir, ydir
            if not tileIsGood(x, y, monsters) then
                _dir = not _dir
                x, y = xndir, yndir
                if not tileIsGood(x, y, monsters) then
                    crawl.mpr("No good direction to walk!")
                    stopPillarDance()
                    return false
                end
            end
        end
    end
    return true
end

function getNextAction()
    if _dir then
        return _seqForward[_seqidx]
    else
        return _seqBackward[_seqidx]
    end
end

function doSeqAction()
    local nextAction = getNextAction()
    -- actually performs the action and pushes the sequence pointer in the correct direction.
    if _dir then
        _seqidx = _seqidx + 1
        if _seqidx > #_seqForward then
            _seqidx = 1
        end
    else
        _seqidx = _seqidx - 1
        if _seqidx < 1 then
            _seqidx = #_seqBackward
        end
    end
    local x, y = getOffset(nextAction)
    if not travel.feature_traversable(view.feature_at(x, y)) then
        crawl.mpr("Unexpected blockage of path! Did you close a door or move mid-dance?")
        stopPillarDance()
        return
    end
    crawl.do_commands({ nextAction })
end

max_steps = 500
_stepcount = 0
function shouldDance()
    if (not auto) then
        -- user knows what they want
        return true
    end
    if _stepcount < max_steps then
        _stepcount = _stepcount + 1
        local hp, mhp = you.hp()
        local mp, mmp = you.mp()
        return hp ~= mhp or mp ~= mmp
    end
    crawl.mpr("Hit max number of steps! You might have found an edge case. If you want to continue dancing, press your dance macro again.")
    return false
end

function showPillar()
    if _path == nil then return end
    local x, y = travel.waypoint_delta(7)
	if x == nil then return end
    local pathTiles = {}
    for i, t in ipairs(_path) do
        pathTiles[t] = true
    end
    showTiles(pathTiles, -x, -y)
end

function hidePillar()
    if _path == nil then return end
    local x, y = travel.waypoint_delta(7)
	if x == nil then return end
    local pathTiles = {}
    for i, t in ipairs(_path) do
        pathTiles[t] = true
    end
    hideTiles(pathTiles, -x, -y)
end

function startPillarDance()
    hidePillar()
    _pillarDance = true
    _nextAction = nil
    _stepcount = 0
end

function stopPillarDance()
    showPillar()
    _pillarDance = false
end

function killPillar()
    hidePillar()
    _pillarDance = false
    _path = nil
    _seqForward = nil
    _seqBackward = nil
    _seqidx = nil
    _dir = true
end

_nextAction = nil
function doStep()
    if (not auto) and _pillarDance then
        if not checkDance() then
            -- dance stopped, delete "next step" exclusion and stop dancing
            if _nextAction ~= nil then
                local x, y = getOffset(_nextAction)
                travel.del_exclude(x, y)
            end
            stopPillarDance()
            return
        end
        if _nextAction ~= nil then
            -- if an enemy came into view, our next action may have changed, do nothing and just switch next action
            local confirmNextAction = getNextAction()
            if _nextAction == confirmNextAction then
                doSeqAction()
                -- after the action happens, the "next action" exclude should be under us
                travel.del_exclude(0, 0)
            else
                crawl.mpr("Direction swapped!")
                local x, y = getOffset(_nextAction)
                travel.del_exclude(x, y)
            end
        end
        _nextAction = getNextAction()
        if _nextAction ~= nil then
            local x, y = getOffset(_nextAction)
            travel.set_exclude(x, y, 0)
        end
    end
end

function c_answer_prompt()
    if (not auto) and _pillarDance then
        return true
    end
end

function ready()
    if auto and _pillarDance and checkDance() then
        doSeqAction()
    end
end

function can_walk_towards(m)
    -- it's ok to walk towards: neutral monsters, harmless monsters, and firewood.
    -- this is separate from can_walk_through because if they are in our direct path, we can't walk towards them.
    if not m or m:attitude() > 1 then
        return true
    end
    if m:name() == "butterfly" then
        return true
    end
    if m:is_firewood() then
        if string.find(m:name(), "ballistomycete") then
            return false
        end
        return true
    end
    return false
end

function can_walk_through(m)
    -- we can only walk through, and thus completely ignore, friendly non-stationary non-trapped monsters.
    return not m or (m:attitude() == 4 and not (m:is_stationary() or m:is_constricted() or m:is_caught()))
end

function getAllMonsters()
    local monsters = {}
    local los = you.los()
    for x_off = -los, los do
        for y_off = -los, los do
            if view.cell_see_cell(0, 0, x_off, y_off) then
                local mon = monster.get_monster_at(x_off, y_off)
                if not can_walk_through(mon) then
                    monsters[#monsters + 1] = mon
                end
            end
        end
    end
    return monsters
end

function tileIsGood(x, y, monsters)
    -- a tile is "good" if it does not take us closer to any monsters.
    for i, mon in ipairs(monsters) do
        local newDist = getDist(x, y, mon:x_pos(), mon:y_pos())
        if newDist == 0 then return false end
        if (not can_walk_towards(mon)) and (newDist <= 1
                or (getDist(0, 0, mon:x_pos(), mon:y_pos()) > newDist
                and view.cell_see_cell(x, y, mon:x_pos(), mon:y_pos()))) then
            return false
        end
    end
    return true
end

function tileIsBetter(x, y, monsters)
    -- a tile is "better" if it takes us farther away from all monsters.
    for i, mon in ipairs(monsters) do
        local newDist = getDist(x, y, mon:x_pos(), mon:y_pos())
        if newDist == 0 then return false end
        if (not can_walk_towards(mon)) and (newDist <= 1
                or (getDist(0, 0, mon:x_pos(), mon:y_pos()) >= newDist
                and view.cell_see_cell(x, y, mon:x_pos(), mon:y_pos()))) then
            return false
        end
    end
    return true
end

function doSearch(x, y)
    -- first, get the outline (orthogonally adjacent tiles) of the pillar.
    local pillar = create(x, y)
    if pillar == nil then
        return nil
    end
    local xmin, ymin, xmax, ymax = getBbox(pillar.tiles)
    -- find two distinct tiles on the outline which are on the outline's axis aligned bounding box.
    local x1, y1, x2, y2 = findTwoTilesOnBorder(pillar.tiles, xmin, ymin, xmax, ymax)
    local tileset = getTilesInBox(xmin, ymin, xmax, ymax)
    -- find the shortest path between those two tiles.
    local path = getPath(tileset, x1, y1, x2, y2)
    local next = path[2]
    -- block that path.
    if x1 == xmin then
        mk.put(tileset, x1, next[2], false)
        mk.put(tileset, x1 + 1, next[2], false)
    elseif x1 == xmax then
        mk.put(tileset, x1, next[2], false)
        mk.put(tileset, x1 - 1, next[2], false)
    elseif y1 == ymin then
        mk.put(tileset, next[1], y1, false)
        mk.put(tileset, next[1], y1 + 1, false)
    elseif y1 == ymax then
        mk.put(tileset, next[1], y1, false)
        mk.put(tileset, next[1], y1 - 1, false)
    end
    -- find the shortest path again. This will be forced to be the other path because of the blocked tiles.
    local path2 = getPath(tileset, x1, y1, x2, y2)
    -- flip the second path, concatenate it to the original path. Now we have a full cyclic path around the pillar.
    reverse(path2)
    local prevlen = #path
    for i = 2, (#path2 - 1) do
        path[prevlen + i - 1] = path2[i]
    end
    local pathTiles = {}
    for i, t in ipairs(path) do
        pathTiles[t] = true
    end
    showTiles(pathTiles)
    _path = path
    crawl.mpr("Pillar chosen. Step on one of the excluded tiles and use your pillar dance macro to continue.")
    return path
end

function getSeq(path)
    local seq = {}
    for i, s in ipairs(path) do
        local t = path[(i + 1)]
        if i == #path then
            t = path[1]
        end
        -- this could be a lookup table, but i already wrote it
        local n
        if t[1] == s[1] and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN"
        elseif t[1] == s[1] and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP"
        elseif t[1] == s[1] + 1 and t[2] == s[2] then
            n = "CMD_MOVE_RIGHT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] then
            n = "CMD_MOVE_LEFT"
        elseif t[1] == s[1] + 1 and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN_RIGHT"
        elseif t[1] == s[1] + 1 and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP_RIGHT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN_LEFT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP_LEFT"
        end
        seq[i] = n
    end
    return seq
end

function getSeqBackwards(path)
    local seq = {}
    for i, s in ipairs(path) do
        local t = path[(i - 1)]
        if i == 1 then
            t = path[#path]
        end
        local n
        -- lol
        if t[1] == s[1] and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN"
        elseif t[1] == s[1] and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP"
        elseif t[1] == s[1] + 1 and t[2] == s[2] then
            n = "CMD_MOVE_RIGHT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] then
            n = "CMD_MOVE_LEFT"
        elseif t[1] == s[1] + 1 and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN_RIGHT"
        elseif t[1] == s[1] + 1 and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP_RIGHT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] + 1 then
            n = "CMD_MOVE_DOWN_LEFT"
        elseif t[1] == s[1] - 1 and t[2] == s[2] - 1 then
            n = "CMD_MOVE_UP_LEFT"
        end
        seq[i] = n
    end
    return seq
end


function getTilesInBox(xmin, ymin, xmax, ymax)
    local tiles = {}
    for x = xmin, xmax do
        for y = ymin, ymax do
            mk.put(tiles, x, y, travel.feature_traversable(view.feature_at(x, y)))
        end
    end
    return tiles
end

function create(x, y)
    local pillar = {}
    -- flood fill the wall tiles of the pillar, then get the orthogonally neighboring walkable tiles
    pillar.tiles = getNeighboringFloors(floodFillWalls(x, y))
    return pillar
end

function showTiles(tiles, offx, offy)
    offx = offx or 0
    offy = offy or 0
    for xy, _ in pairs(tiles) do
        local x = xy[1] + offx
        local y = xy[2] + offy
        travel.set_exclude(x, y, 0)
    end
end

function printTiles(tiles)
    -- helper debugging function
    for i, xy in ipairs(tiles) do
        crawl.mpr("(" .. xy[1] .. ", " .. xy[2] .. ")")
    end
end

function hideTiles(tiles, offx, offy)
    offx = offx or 0
    offy = offy or 0
    for xy, _ in pairs(tiles) do
        local x = xy[1] + offx
        local y = xy[2] + offy
        travel.del_exclude(x, y)
    end
end

function extendSet(a, b)
    for k, _ in pairs(b) do
        a[k] = true
    end
end

function has(l, t)
    for k, _ in pairs(l) do
        print(k)
        if k[1] == t[1] and k[2] == t[2] then
            return true
        end
    end
    return false
end

function newTupleSet()
    return {}
end

function floodFillWalls(x, y)
    return floodFillWallsHelper(x, y, {}, { 0 })
end

function floodFillWallsHelper(x, y, used, counter)
    if has(used, { x, y }) or travel.feature_traversable(view.feature_at(x, y)) then
        return {}
    end
    local ffRes = newTupleSet()
    ffRes[{ x, y }] = true
    counter[1] = counter[1] + 1
    if counter[1] >= 1000 then
        crawl.mpr("Pillar too large! Did you select a map border?")
        return nil
    end
    used[{ x, y }] = true
    local n_pos = newTupleSet()
    n_pos[{ 0, 1 }] = true
    n_pos[{ 0, -1 }] = true
    n_pos[{ 1, 0 }] = true
    n_pos[{ -1, 0 }] = true
    for oxoy, _ in pairs(n_pos) do
        local off_x = oxoy[1]
        local off_y = oxoy[2]
        local ff = floodFillWallsHelper(x + off_x, y + off_y, used, counter)
        if ff == nil then
            return nil
        end
        extendSet(ffRes, ff)
    end
    return ffRes
end

function getNeighboringFloors(tiles)
    local neighbors = {}
    local n_pos = newTupleSet()
    n_pos[{ 0, 1 }] = true
    n_pos[{ 0, -1 }] = true
    n_pos[{ 1, 0 }] = true
    n_pos[{ -1, 0 }] = true
    for xy, _ in pairs(tiles) do
        local x, y = unpack(xy)
        for oxoy, _ in pairs(n_pos) do
            local off_x, off_y = unpack(oxoy)
            if travel.feature_traversable(view.feature_at(x + off_x, y + off_y)) then
                neighbors[{ x + off_x, y + off_y }] = true
            end
        end
    end
    return neighbors
end

function getBbox(tiles)
    local xmin = math.huge
    local xmax = -math.huge
    local ymin = math.huge
    local ymax = -math.huge
    for tile, _ in pairs(tiles) do
        local x = tile[1]
        local y = tile[2]
        if x > xmax then
            xmax = x
        end
        if x < xmin then
            xmin = x
        end
        if y > ymax then
            ymax = y
        end
        if y < ymin then
            ymin = y
        end
    end
    return xmin, ymin, xmax, ymax
end

function tilesOneApart(x1, y1, x2, y2)
    return math.abs(x1 - x2) <= 1 and math.abs(y1 - y2) <= 1
end

function findTwoTilesOnBorder(tiles, xmin, ymin, xmax, ymax)
    local t1found = false
    local t1 = nil
    for tile, _ in pairs(tiles) do
        local x = tile[1]
        local y = tile[2]
        if (x == xmin or x == xmax or y == ymin or y == ymax) then
            if t1found then
                if not tilesOneApart(t1[1], t1[2], x, y) then
                    return t1[1], t1[2], x, y
                end
            else
                t1found = true
                t1 = { x, y }
            end
        end
    end
    return nil
end

function getDist(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

function getNeighboring(tileset, x, y)
    local neighbors = {}
    for ox = -1, 1 do
        for oy = -1, 1 do
            if mk.get(tileset, x + ox, y + oy) ~= nil and not (ox == 0 and oy == 0) then
                neighbors[{ x + ox, y + oy }] = true
            end
        end
    end
    return neighbors
end

function getMinTile(nodes, dist)
    local min = math.huge
    local tile
    for _, x, y, __ in mk.tuples(nodes) do
        local cost = mk.get(dist, x, y)
        if cost ~= nil and cost <= min then
            min = cost
            tile = { x, y }
        end
    end
    return tile
end

function getPath(tileset, x1, y1, x2, y2)
    -- we just use dijkstra's to get the shortest path
    local dist = {}
    local nodes = {}
    local prev = {}
    for _, x, y, trav in mk.tuples(tileset) do
        if trav then
            mk.put(dist, x, y, 10000)
            mk.put(nodes, x, y, true)
        end
    end
    mk.put(dist, x1, y1, 0)
    while next(nodes) ~= nil do
        local u = getMinTile(nodes, dist)
        assert(u ~= nil)
        mk.put(nodes, u[1], u[2], nil)
        if u[1] == x2 and u[2] == y2 then
            assert(mk.get(prev, u[1], u[2]) ~= nil)
            return parsePrev(prev, x1, y1, x2, y2)
        end
        for v, _ in pairs(getNeighboring(nodes, u[1], u[2])) do
            local altDist = mk.get(dist, u[1], u[2]) + 1
            if mk.get(dist, v[1], v[2]) == nil or altDist < mk.get(dist, v[1], v[2]) then
                mk.put(dist, v[1], v[2], altDist)
                mk.put(prev, v[1], v[2], u)
            end
        end
    end
end

function parsePrev(prev, x1, y1, x2, y2)
    -- goes backwards along the prev chain to find the tiles in the shortest path
    local path = {}
    local u = { x2, y2 }
    path[1] = u
    while not (u[1] == x1 and u[2] == y1) do
        u = mk.get(prev, u[1], u[2])
        assert(u ~= nil)
        path[#path + 1] = u
    end
    reverse(path)
    return path
end

function reverse(arr)
    local i, j = 1, #arr

    while i < j do
        arr[i], arr[j] = arr[j], arr[i]

        i = i + 1
        j = j - 1
    end
end

local function getMk()
    -- i don't know enough lua to mess around with metatables and do this myself, so i yoinked this from somewhere

    -- simple table adaptor for using multiple keys in a lookup table

    -- cache some global functions/tables for faster access
    local assert = assert
    local select = assert(select)
    local next = assert(next)
    local setmetatable = assert(setmetatable)

    -- sentinel values for the key tree, nil keys, and nan keys
    local KEYS, NIL, NAN = {}, {}, {}


    local M = {}
    local M_meta = { __index = M }


    function M.new()
        return setmetatable({ [KEYS] = {} }, M_meta)
    end

    setmetatable(M, { __call = M.new })


    function M.clear(t)
        for k in next, t do
            t[k] = nil
        end
        return t
    end


    -- local helper function to map a vararg of keys to the real key
    local function get_key(key, ...)
        for i = 1, select('#', ...) do
            if key == nil then break
            end
            local e = select(i, ...)
            if e == nil then
                e = NIL
            elseif e ~= e then -- can only happen for NaNs
                e = NAN
            end
            key = key[e]
        end
        return key
    end


    function M.get(t, ...)
        local key = get_key(t[KEYS], ...)
        if key ~= nil then
            return t[key]
        end
        return nil
    end


    -- local helper function for both put variants below
    local function put(t, idx, val, n, ...)
        for i = 1, n do
            local e = select(i, ...)
            if e == nil then
                e = NIL
            elseif e ~= e then -- can only happen for NaNs
                e = NAN
            end
            local nextidx = idx[e]
            if not nextidx then
                nextidx = {}
                idx[e] = nextidx
            end
            idx = nextidx
        end
        t[idx] = val
    end


    -- returns true if tab can be removed from the parent table
    local function del(t, idx, n, ...)
        if n > 0 then
            local e = ...
            if e == nil then
                e = NIL
            elseif e ~= e then -- can only happen for NaNs
                e = NAN
            end
            local nextidx = idx[e]
            if nextidx and del(t, nextidx, n - 1, select(2, ...)) then
                idx[e] = nil
                return t[idx] == nil and next(idx) == nil
            end
            return false
        else
            t[idx] = nil
            return next(idx) == nil
        end
    end


    function M.put(t, ...)
        local n, keys, val = select('#', ...), t[KEYS], nil
        if n > 0 then
            val = select(n, ...)
            n = n - 1
        end
        if val == nil then
            if keys ~= nil then
                del(t, keys, n, ...)
            end
        else
            if keys == nil then
                keys = {}
                t[KEYS] = keys
            end
            put(t, keys, val, n, ...)
        end
        return t
    end


    -- same as M.put, but value comes first not last
    function M.putv(t, val, ...)
        local keys = t[KEYS]
        if val == nil then
            if keys ~= nil then
                del(t, keys, select('#', ...), ...)
            end
        else
            if keys == nil then
                keys = {}
                t[KEYS] = keys
            end
            put(t, keys, val, select('#', ...), ...)
        end
        return t
    end


    -- iteration is only available with coroutine support
    if coroutine ~= nil then
        local unpack = assert(unpack or table.unpack)
        local pairs = assert(pairs)
        local ipairs = assert(ipairs)
        local co_yield = assert(coroutine.yield)
        local co_wrap = assert(coroutine.wrap)


        -- internal iterator function
        local function iterate(iter, t, key, keystack, n)
            if t[key] ~= nil then
                keystack[n + 1] = t[key]
                co_yield(unpack(keystack, 1, n + 1))
            end
            for k, v in iter(key) do
                if k == NIL then
                    k = nil
                elseif k == NAN then
                    k = 0 / 0
                end
                keystack[n + 1] = k
                iterate(iter, t, v, keystack, n + 1)
            end
            return nil
        end


        -- iterator similar to pairs, but since we have multiple keys ...
        function M.tuples(t, ...)
            local vals, n = { true, ... }, select('#', ...) + 1
            return co_wrap(function()
                local key = get_key(t[KEYS], unpack(vals, 2, n))
                if key ~= nil then
                    return iterate(pairs, t, key, vals, n)
                end
            end)
        end


        function M.ituples(t, ...)
            local vals, n = { ... }, select('#', ...)
            return co_wrap(function()
                local key = get_key(t[KEYS], unpack(vals, 1, n))
                if key ~= nil then
                    return iterate(ipairs, t, key, vals, n)
                end
            end)
        end


        -- Lua 5.2 metamethods for iteration
        M_meta.__pairs = M.tuples
        M_meta.__ipairs = M.ituples
    end

    return M
end

mk = getMk()
