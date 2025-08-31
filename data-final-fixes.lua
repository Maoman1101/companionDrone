local util = require("__core__/lualib/util")

local function replace_shadows(node, replacement)
    if type(node) ~= "table" then return end
    if node.draw_as_shadow == true then
        for k in pairs(node) do node[k] = nil end
        for k, v in pairs(replacement) do node[k] = v end
        return
    end
    for _, v in pairs(node) do
        if type(v) == "table" then replace_shadows(v, replacement) end
    end
end

local companion = data.raw["spider-vehicle"] and data.raw["spider-vehicle"]["companion"]
if companion and companion.graphics_set then
    local SHADOW = {
        filename = "__companion-drones-mjlfix__/sprites/shadow.png",
        width = 256, height = 256,
        shift = util.by_pixel(-9, 4),
        scale = 0.15,
        draw_as_shadow = true,
    }
    replace_shadows(companion.graphics_set, SHADOW)
end