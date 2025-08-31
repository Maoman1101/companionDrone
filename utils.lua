-- utils.lua by binbinhfr, v1.0.17 
-- modified for use by Maoman

-- To use debug_active, you must define debug_status to 1 or nil in the control.lua before require("utils")
-- also define debug_file to where you want the debug file to go and debug_mod_name to the raw name of the mod.

local author1 = "binbinhfr"
local author2 = "binbin"
local author3 = "maoman"

colors = {
	white = {r = 1, g = 1, b = 1},
	black = {r = 0, g = 0, b = 0},
	darkgrey = {r = 0.25, g = 0.25, b = 0.25},
	grey = {r = 0.5, g = 0.5, b = 0.5},
	lightgrey = {r = 0.75, g = 0.75, b = 0.75},

	red = {r = 1, g = 0, b = 0},
	darkred = {r = 0.5, g = 0, b = 0},
	lightred = {r = 1, g = 0.5, b = 0.5},
	green = {r = 0, g = 1, b = 0},
	darkgreen = {r = 0, g = 0.5, b = 0},
	lightgreen = {r = 0.5, g = 1, b = 0.5},
	blue = {r = 0, g = 0, b = 1},
	darkblue = {r = 0, g = 0, b = 0.5},
	lightblue = {r = 0.5, g = 0.5, b = 1},

	orange = {r = 1, g = 0.55, b = 0.1},
	yellow = {r = 1, g = 1, b = 0},
	pink = {r = 1, g = 0, b = 1},
	purple = {r = 0.6, g = 0.1, b = 0.6},
	brown = {r = 0.6, g = 0.4, b = 0.1},
}

anticolors = {
	white = colors.black,
	black = colors.white,
	darkgrey = colors.white,
	grey = colors.black,
	lightgrey = colors.black,

	red = colors.green,
	darkred = colors.darkgreen,
	lightred = colors.lightgreen,
	green = colors.red,
	darkgreen = colors.darkred,
	lightgreen = colors.lightred,
	blue = colors.orange,
	darkblue = colors.brown,
	lightblue = colors.yellow,
    
	orange = colors.blue,
	yellow = colors.purple,
	pink = colors.lightgreen,
	purple = colors.yellow,
	brown = colors.darkblue,
}

lightcolors = {
	white = colors.lightgrey,
	grey = colors.darkgrey,
	lightgrey = colors.grey,

	red = colors.lightred,
	green = colors.lightgreen,
	blue = colors.lightblue,
	yellow = colors.orange,
	pink = colors.purple,
}

local function truncate_decimal(number, length)
    local mult = 10 ^ length
    number = math.floor((number*mult)/mult)
    return number
end

local function parse_hex(input)
    if not input or type(input) ~= "string" or not input:match("^#%x%x%x%x%x%x(%x%x)?$") then return end 
    -- verify input is a string that starts with # and has either 6 or 8 hex characters
    -- or just always use hexcolors.<color> 
    local r = string.sub(input, 2, 3)
    local g = string.sub(input, 4, 5)
    local b = string.sub(input, 6, 7)
    local a = string.sub(input, 8, 9)
    r = tonumber(r, 16) / 255
    g = tonumber(g, 16) / 255
    b = tonumber(b, 16) / 255
    if a ~= "" then a = tonumber(a, 16) / 255 end
    r = truncate_decimal(r, 3)
    g = truncate_decimal(g, 3)
    b = truncate_decimal(b, 3)
    if a ~= "" then a = truncate_decimal(a, 3) end
    if a == "" then a = 1.0 end -- if alpha is undefined, default to fully opaque
    return r, g, b, a
end

-- Shamelessly stolen from https://rentry.co/rentry-text-colors (you can actually see the colors there)
hexcolors = {
    black = "#000000",
    silver = "#c0c0c0",
    grey = "#808080",
	gray = "#808080",
    white = "#ffffff",
    maroon = "#800000",
    red = "#ff0000",
    purple = "#800080",
    fuchsia = "#ff00ff",
    forest = "#008000",
    green = "#00ff00",
    olive = "#808000",
    yellow = "#ffff00",
    navy = "#000080",
    blue = "#0000ff",
    teal = "#008080",
    aqua = "#00ccff",
    magenta = "#ff00ff",
    cyan = "#00ffff",
    aliceblue = "#f0f8ff",
    antiquewhite = "#faebd7",
    aquamarine = "#7fffd4",
    azure = "#f0ffff",
    beige = "#f5f5dc",
    bisque = "#ffe4c4",
    blanchedalmond = "#ffebcd",
    blueviolet = "#8a2be2",
    brown = "#a52a2a",
    burlywood = "#deb887",
    cadetblue = "#5f9ea0",
    chartreuse = "#7fff00",
    chocolate = "#d2691e",
    coral = "#ff7f50",
    cornflowerblue = "#6495ed",
    cornsilk = "#fff8dc",
    crimson = "#dc143c",
    darkblue = "#00008b",
    darkcyan = "#008b8b",
    darkgoldenrod = "#b8860b",
    darkgray = "#a9a9a9",
    darkgreen = "#006400",
    darkgrey = "#a9a9a9",
    darkkhaki = "#bdb76b",
    darkmagenta = "#8b008b",
    darkolivegreen = "#556b2f",
    darkorange = "#ff8c00",
    darkorchid = "#9932cc",
    darkred = "#8b0000",
    darksalmon = "#e9967a",
    darkseagreen = "#8fbc8f",
    darkslateblue = "#483d8b",
    darkslategray = "#2f4f4f",
    darkslategrey = "#2f4f4f",
    darkturquoise = "#00ced1",
    darkviolet = "#9400d3",
    deeppink = "#ff1493",
    deepskyblue = "#00bfff",
    dimgray = "#696969",
    dimgrey = "#696969",
    dodgerblue = "#1e90ff",
    firebrick = "#b22222",
    floralwhite = "#fffaf0",
    forestgreen = "#228b22",
    gainsboro = "#dcdcdc",
    ghostwhite = "#f8f8ff",
    gold = "#ffd700",
    goldenrod = "#daa520",
    honeydew = "#f0fff0",
    hotpink = "#ff69b4",
    indianred = "#cd5c5c",
    indigo = "#4b0082",
    ivory = "#fffff0",
    khaki = "#f0e68c",
    lavender = "#e6e6fa",
    lavenderblush = "#fff0f5",
    lawngreen = "#7cfc00",
    lemonchiffon = "#fffacd",
    lightblue = "#add8e6",
    lightcoral = "#f08080",
    lightcyan = "#e0ffff",
    lightgoldenrodyellow = "#fafad2",
    lightgray = "#d3d3d3",
    lightgreen = "#90ee90",
    lightgrey = "#d3d3d3",
    lightpink = "#ffb6c1",
    lightsalmon = "#ffa07a",
    lightseagreen = "#20b2aa",
    lightskyblue = "#87cefa",
    lightslategray = "#778899",
    lightslategrey = "#778899",
    lightsteelblue = "#b0c4de",
    lightyellow = "#ffffe0",
    lime = "#adff2f",
    linen = "#faf0e6",
    mediumaquamarine = "#66cdaa",
    mediumblue = "#0000cd",
    mediumorchid = "#ba55d3",
    mediumpurple = "#9370db",
    mediumseagreen = "#3cb371",
    mediumslateblue = "#7b68ee",
    mediumspringgreen = "#00fa9a",
    mediumturquoise = "#48d1cc",
    mediumvioletred = "#c71585",
    midnightblue = "#191970",
    mintcream = "#f5fffa",
    mistyrose = "#ffe4e1",
    moccasin = "#ffe4b5",
    navajowhite = "#ffdead",
    oldlace = "#fdf5e6",
    olivedrab = "#6b8e23",
    orange = "#ffa500",
    orangered = "#ff4500",
    orchid = "#da70d6",
    palegoldenrod = "#eee8aa",
    palegreen = "#98fb98",
    paleturquoise = "#afeeee",
    palevioletred = "#db7093",
    papayawhip = "#ffefd5",
    peachpuff = "#ffdab9",
    peru = "#cd853f",
    pink = "#ffc0cb",
    plum = "#dda0dd",
    powderblue = "#b0e0e6",
    rebeccapurple = "#663399",
    rosybrown = "#bc8f8f",
    royalblue = "#4169e1",
    saddlebrown = "#8b4513",
    salmon = "#fa8072",
    sandybrown = "#f4a460",
    seagreen = "#2e8b57",
    seashell = "#fff5ee",
    sienna = "#a0522d",
    skyblue = "#87ceeb",
    slateblue = "#6a5acd",
    slategray = "#708090",
    slategrey = "#708090",
    snow = "#fffafa",
    springgreen = "#00ff7f",
    steelblue = "#4682b4",
    tancolor = "#d2b48c", -- "tan" is a lua keyword
    thistle = "#d8bfd8",
    tomato = "#ff6347",
    turquoise = "#40e0d0",
    violet = "#ee82ee",
    wheat = "#f5deb3",
    whitesmoke = "#f5f5f5",
    yellowgreen = "#9acd32"
}

--------------------------------------------------------------------------------------
function read_version(v)
	local v1, v2, v3 = string.match(v, "(%d+).(%d+).(%d+)")
	debug_print( "version cut = ", v1,v2,v3)
end

--------------------------------------------------------------------------------------
function compare_versions(v1,v2)
	local v1a, v1b, v1c = string.match(v1, "(%d+).(%d+).(%d+)")
	local v2a, v2b, v2c = string.match(v2, "(%d+).(%d+).(%d+)")
	
	v1a = tonumber(v1a)
	v1b = tonumber(v1b)
	v1c = tonumber(v1c)
	v2a = tonumber(v2a)
	v2b = tonumber(v2b)
	v2c = tonumber(v2c)
	
	if v1a > v2a then
		return 1
	elseif v1a < v2a then
		return -1
	elseif v1b > v2b then
		return 1
	elseif v1b < v2b then
		return -1
	elseif v1c > v2c then
		return 1
	elseif v1c < v2c then
		return -1
	else
		return 0
	end
end

--------------------------------------------------------------------------------------
function older_version(v1,v2)
	local v1a, v1b, v1c = string.match(v1, "(%d+).(%d+).(%d+)")
	local v2a, v2b, v2c = string.match(v2, "(%d+).(%d+).(%d+)")
	local ret
	
	v1a = tonumber(v1a)
	v1b = tonumber(v1b)
	v1c = tonumber(v1c)
	v2a = tonumber(v2a)
	v2b = tonumber(v2b)
	v2c = tonumber(v2c)
	
	if v1a > v2a then
		ret = false
	elseif v1a < v2a then
		ret = true
	elseif v1b > v2b then
		ret = false
	elseif v1b < v2b then
		ret = true
	elseif v1c < v2c then
		ret = true
	else
		ret = false
	end
	
	debug_print( "older_version ", v1, "<", v2, "=", ret )
	
	return(ret)
end

--------------------------------------------------------------------------------------

function debug_active(...)
	-- can be called everywhere, except in on_load where game is not existing
	if not debug_status or not debug_file or not debug_mod_name then return end
	local s = ""
	
	for i, v in ipairs({...}) do
		s = s .. tostring(v)
	end

	if s == "RESET" or debug_do_reset == true then
		game.remove_path(debug_file)
		debug_do_reset = false
	elseif s == "CLEAR" then
		for _, player in pairs(game.players) do
			if player.connected then player.clear_console() end
		end
	end

	s = debug_mod_name .. "(" .. game.tick .. "): " .. s
	game.write_file( debug_file, s .. "\n", true )
	
	for _, player in pairs(game.players) do
		if player.connected then player.print(s) end
	end
end

if debug_status == 1 then debug_print = debug_active else debug_print = function() end end

--------------------------------------------------------------------------------------
function message_all(s)
	for _, player in pairs(game.players) do
		if player.connected then
			player.print(s)
		end
	end
end

--------------------------------------------------------------------------------------
function message_force(force, s)
	for _, player in pairs(force.players) do
		if player.connected then
			player.print(s)
		end
	end
end

--------------------------------------------------------------------------------------
function square_area( origin, radius )
	return {
		{x=origin.x - radius, y=origin.y - radius},
		{x=origin.x + radius, y=origin.y + radius}
	}
end

--------------------------------------------------------------------------------------
function distance( pos1, pos2 )
	local dx = pos2.x - pos1.x
	local dy = pos2.y - pos1.y
	return( math.sqrt(dx*dx+dy*dy) )
end

--------------------------------------------------------------------------------------
function distance_square( pos1, pos2 )
	return( math.max(math.abs(pos2.x - pos1.x),math.abs(pos2.y - pos1.y)) )
end

--------------------------------------------------------------------------------------
function pos_offset( pos, offset )
	return { x=pos.x + offset.x, y=pos.y + offset.y }
end

--------------------------------------------------------------------------------------
function surface_area(surf)
	local x1, y1, x2, y2 = 0,0,0,0
	
	for chunk in surf.get_chunks() do
		if chunk.x < x1 then
			x1 = chunk.x
		elseif chunk.x > x2 then
			x2 = chunk.x
		end
		if chunk.y < y1 then
			y1 = chunk.y
		elseif chunk.y > y2 then
			y2 = chunk.y
		end
	end
	
	return( {{x1*32-8,y1*32-8},{x2*32+40,y2*32+40}} )
end

--------------------------------------------------------------------------------------
function iif( cond, val1, val2 )
	if cond then
		return val1
	else
		return val2
	end
end

--------------------------------------------------------------------------------------
function concat_lists(list1, list2)
	-- add list2 into list1 , do not avoid duplicates...
	for i, obj in pairs(list2) do
		table.insert(list1,obj)
	end
end

--------------------------------------------------------------------------------------
function add_list(list, obj)
	-- to avoid duplicates...
	for i, obj2 in pairs(list) do
		if obj2 == obj then
			return(false)
		end
	end
	table.insert(list,obj)
	return(true)
end

--------------------------------------------------------------------------------------
function del_list(list, obj)
	for i, obj2 in pairs(list) do
		if obj2 == obj then
			table.remove( list, i )
			return(true)
		end
	end
	return(false)
end

--------------------------------------------------------------------------------------
function in_list(list, obj)
	for k, obj2 in pairs(list) do
		if obj2 == obj then
			return(k)
		end
	end
	return(nil)
end

--------------------------------------------------------------------------------------
function size_list(list)
	local n = 0
	for i in pairs(list) do
		n = n + 1
	end
	return(n)
end

------------------------------------------------------------------------------------
function is_dev(player)
	local name = string.lower(player.name)
	return(name == author1 or name == author2 or name == author3)
end

--------------------------------------------------------------------------------------
function dupli_proto( type, name1, name2 )
	--Deep copies a prototype of type "type" named "name1" and names the new prototype "name2"
	if data.raw[type][name1] then 
		local proto = table.deepcopy(data.raw[type][name1])
		proto.name = name2
		if proto.minable and proto.minable.result then proto.minable.result = name2	end
		if proto.place_result then proto.place_result = name2 end
		if proto.take_result then proto.take_result = name2	end
		if proto.result then proto.result = name2 end
		return(proto)
	else
		error("prototype unknown " .. name1 )
		return(nil)
	end
end

--------------------------------------------------------------------------------------
function debug_guis( guip, indent )
	if guip == nil then return end
	debug_print( indent .. string.rep("....",indent) .. " " .. guip.name )
	indent = indent+1
	for k, gui in pairs(guip.children_names) do
		debug_guis( guip[gui], indent )
	end
end

--------------------------------------------------------------------------------------
function extract_monolith(filename, x, y, w, h)
	return {
		type = "monolith",

		top_monolith_border = 0,
		right_monolith_border = 0,
		bottom_monolith_border = 0,
		left_monolith_border = 0,

		monolith_image = {
			filename = filename,
			priority = "extra-high-no-scale",
			width = w,
			height = h,
			x = x,
			y = y,
		},
	}
end

