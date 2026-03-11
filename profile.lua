--[[
This file is a part of the "profile.lua" library.

MIT License

Copyright (c) 2015 2dengine LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local clock = os.clock

local profile = {}
local _labeled, _defined, _tcalled, _telapsed, _ncalls, _internal =
  {}, {}, {}, {}, {}, {}

-- cache table lookups locally for performance
local getinfo = debug.getinfo
local type, tostring, pairs, ipairs = type, tostring, pairs, ipairs

function profile.setclock(f)
  clock = f or love.timer.getTime
end

function profile.hooker(event)
  local info = getinfo(2, "fnS")
  local f = info.func
  if _internal[f] or info.what ~= "Lua" then return end

  local tc, te, nc = _tcalled, _telapsed, _ncalls

  if event == "call" then
    tc[f] = clock()
    if not _defined[f] then
      _defined[f] = info.short_src .. ":" .. info.linedefined
      nc[f], te[f] = 0, 0
      if info.name then _labeled[f] = info.name end
    end
  else -- "return" or "tail call"
    local t0 = tc[f]
    if t0 then
      te[f] = te[f] + (clock() - t0)
      tc[f] = nil
      nc[f] = (nc[f] or 0) + 1
    end
  end
end

function profile.start()
  if rawget(_G, 'jit') then
    jit.off(); jit.flush()
  end
  debug.sethook(profile.hooker, "cr")
end

function profile.stop()
  debug.sethook()
  local tc, te = _tcalled, _telapsed
  for f, t0 in pairs(tc) do
    te[f] = te[f] + (clock() - t0)
    tc[f] = nil
  end
end

--- Resets all collected data.
function profile.reset()
  for f in pairs(_ncalls) do
    _ncalls[f] = 0
  end
  for f in pairs(_telapsed) do
    _telapsed[f] = 0
  end
  for f in pairs(_tcalled) do
    _tcalled[f] = nil
  end
  collectgarbage('collect')
end

--- This is an internal function.
-- @tparam function a First function
-- @tparam function b Second function
-- @treturn boolean True if "a" should rank higher than "b"
function profile.comp(a, b)
  local dt = _telapsed[b] - _telapsed[a]
  if dt == 0 then
    return _ncalls[b] < _ncalls[a]
  end
  return dt < 0
end

--- Generates a report of functions that have been called since the profile was started.
-- Returns the report as a numeric table of rows containing the rank, function label, number of calls, total execution time and source code line number.
-- @tparam[opt] number limit Maximum number of rows
-- @treturn table Table of rows
function profile.query(limit)
  local t = {}
  for f, n in pairs(_ncalls) do
    if n > 0 then
      t[#t + 1] = f
    end
  end
  table.sort(t, profile.comp)
  if limit then
    while #t > limit do
      table.remove(t)
    end
  end
  for i, f in ipairs(t) do
    local dt = 0
    if _tcalled[f] then
      dt = clock() - _tcalled[f]
    end
    t[i] = { i, _labeled[f] or '?', _ncalls[f], _telapsed[f] + dt, _defined[f] }
  end
  return t
end

local cols = { 3, 29, 11, 24, 32 }

--- Generates a text report of functions that have been called since the profile was started.
-- Returns the report as a string that can be printed to the console.
-- @tparam[opt] number limit Maximum number of rows
-- @treturn string Text-based profiling report
function profile.report(n)
  local out = {}
  local report = profile.query(n)
  for i, row in ipairs(report) do
    for j = 1, 5 do
      local s = row[j]
      local l2 = cols[j]
      s = tostring(s)
      local l1 = s:len()
      if l1 < l2 then
        s = s..(' '):rep(l2-l1)
      elseif l1 > l2 then
        s = s:sub(l1 - l2 + 1, l1)
      end
      row[j] = s
    end
    out[i] = table.concat(row, ' | ')
  end

  local row = " +-----+-------------------------------+-------------+--------------------------+----------------------------------+ \n"
  local col = " | #   | Function                      | Calls       | Time                     | Code                             | \n"
  local sz = row..col..row
  if #out > 0 then
    sz = sz..' | '..table.concat(out, ' | \n | ')..' | \n'
  end
  return '\n'..sz..row
end

return profile