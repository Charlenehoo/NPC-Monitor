--
-- log.lua (GMod adaptation)
--
-- Original Copyright (c) 2016 rxi
-- Adapted for Garry's Mod by Assistant
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log    = { _version = "0.2.0" }

log.usecolor = true
log.outfile  = nil -- Relative to "garrysmod/data/" (e.g., "logs/mylog.txt")
log.level    = "trace"

local modes  = {
    { name = "trace", color = Color(50, 150, 255) }, -- blue-ish
    { name = "debug", color = Color(0, 200, 200) },  -- cyan
    { name = "info",  color = Color(50, 200, 50) },  -- green
    { name = "warn",  color = Color(255, 200, 0) },  -- yellow
    { name = "error", color = Color(255, 80, 80) },  -- red
    { name = "fatal", color = Color(200, 50, 200) }, -- purple
}

local levels = {}
for i, v in ipairs(modes) do
    levels[v.name] = i
end

local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end

local _tostring = tostring

local tostring = function(...)
    local t = {}
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if type(x) == "number" then
            x = round(x, .01)
        end
        t[#t + 1] = _tostring(x)
    end
    return table.concat(t, " ")
end

for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    log[x.name] = function(...)
        -- Return early if we're below the log level
        if i < levels[log.level] then
            return
        end

        local msg = tostring(...)
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline

        -- Build the console message (time only with seconds)
        local con_msg = string.format("[%-6s%s] %s: %s",
            nameupper,
            os.date("%H:%M:%S"),
            lineinfo,
            msg)

        -- Output to console with optional color
        if log.usecolor then
            MsgC(x.color, con_msg, "\n")
        else
            Msg(con_msg, "\n")
        end

        -- Output to log file (full date and time)
        if log.outfile then
            local str = string.format("[%-6s%s] %s: %s\n",
                nameupper,
                os.date(),
                lineinfo,
                msg)
            file.Append(log.outfile, str)
        end
    end
end

return log
