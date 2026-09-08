-- Comprehensive parser and serializer for Hyprland windowrules.lua
-- Used by GUIndowRules to provide two-way sync with ~/.config/hypr/windowrules.lua

local json = {}

local function json_escape(s)
  local matches = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t'
  }
  return s:gsub('["\\%z\1-\31]', function(c)
    return matches[c] or string.format('\\u%.4X', string.byte(c))
  end)
end

function json.encode(val)
  local t = type(val)
  if t == "string" then
    return '"' .. json_escape(val) .. '"'
  elseif t == "number" or t == "boolean" then
    return tostring(val)
  elseif t == "table" then
    local is_array = true
    local max_idx = 0
    local count = 0
    for k, v in pairs(val) do
      count = count + 1
      if type(k) == "number" and k > 0 and math.floor(k) == k then
        if k > max_idx then max_idx = k end
      else
        is_array = false
      end
    end
    if is_array and max_idx == count then
      local parts = {}
      for i = 1, max_idx do
        table.insert(parts, json.encode(val[i]))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(val) do
        table.insert(parts, string.format('"%s":%s', json_escape(tostring(k)), json.encode(v)))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local c = f:read("*all")
  f:close()
  return c
end

local function parse_windowrules(path)
  local content = read_file(path)
  local lines = {}
  for line in content:gmatch("([^\r\n]*)\r?\n?") do
    table.insert(lines, line)
  end
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end

  -- Identify where window rules end and layer rules/tail begin
  local last_rule_line = 0
  local layer_start_line = nil
  for i, l in ipairs(lines) do
    if l:find("o%.window") then
      last_rule_line = i
    end
    if not layer_start_line and (l:find("hl%.layer_rule") or l:find("local blur_layers") or l:find("%-%-%s*Layer Rules")) then
      layer_start_line = i
    end
  end

  local tail_start = layer_start_line or (last_rule_line + 1)
  local tail_lines = {}
  if tail_start <= #lines then
    for i = tail_start, #lines do
      table.insert(tail_lines, lines[i])
    end
  end
  local tail = table.concat(tail_lines, "\n")

  -- Collect rules using Lua execution
  local rules = {}
  local o = {}
  local hl = setmetatable({}, { __index = function() return function() end end })

  local function add_rule(arg1, arg2, enabled, line_num)
    local match = arg1
    local effects = arg2 or {}
    if type(arg1) == "string" then match = { class = arg1 } end

    -- Find preceding section comment if any
    local section = nil
    if line_num and line_num > 1 then
      local check = line_num - 1
      while check >= 1 do
        local l = lines[check]:gsub("^%s+", ""):gsub("%s+$", "")
        if l:sub(1, 2) == "--" and not l:find("o%.window") then
          section = l:sub(3):gsub("^%s+", "")
          break
        elseif l == "" then
          check = check - 1
        else
          break
        end
      end
    end

    table.insert(rules, {
      id = "rule_" .. (#rules + 1),
      enabled = enabled,
      match = match,
      effects = effects,
      section = section or ""
    })
  end

  function o.window(arg1, arg2)
    local line_num = debug.getinfo(2, "l").currentline
    add_rule(arg1, arg2, true, line_num)
  end

  local env = { o = o, hl = hl, ipairs = ipairs, pairs = pairs, table = table, string = string, type = type }
  local chunk, err = loadfile(path, "t", env)
  if chunk then
    chunk()
  else
    io.stderr:write("Warning: could not execute " .. path .. ": " .. tostring(err) .. "\n")
  end

  -- Also check for any commented-out rules in the rule section
  -- (e.g. "-- o.window(...)")
  for i = 1, math.min(#lines, tail_start - 1) do
    local l = lines[i]
    local commented_call = l:match("^%s*%-%-%s*(o%.window%s*%b().*)")
    if commented_call then
      local mock_env = {
        o = {
          window = function(arg1, arg2)
            add_rule(arg1, arg2, false, i)
          end
        }
      }
      local mock_chunk = load(commented_call, "commented_rule", "t", mock_env)
      if mock_chunk then mock_chunk() end
    end
  end

  return {
    rules = rules,
    tail = tail
  }
end

local cmd = arg[1]
local filepath = arg[2] or os.getenv("HOME") .. "/.config/hypr/windowrules.lua"

if cmd == "read" then
  local res = parse_windowrules(filepath)
  print(json.encode(res))
else
  io.stderr:write("Usage: lua parser.lua read [path]\n")
  os.exit(1)
end
