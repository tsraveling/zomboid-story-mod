-- skald.lua: pure-Lua runtime for compiled Skald narratives.
-- Consumes the tables produced by `skalder --compile lua`. Lua 5.1 (Kahlua)
-- through 5.4 and LuaJIT. No dependencies.

local Skald = {}
Skald.VERSION = "0.1.0"
Skald.FORMAT_VERSION = 1

-- SECTION: Shims

local unpack = unpack or table.unpack -- luacheck: ignore
local floor = math.floor
local huge = math.huge

local function is_integer(n)
  return type(n) == "number" and n == floor(n) and n > -huge and n < huge
end

-- SECTION: Error codes (mirror include/skald.h)

Skald.ERROR = {
  UNKNOWN = 0,
  EOF = 1,
  EMPTY_MODULE = 2,
  MODULE_TAG_NOT_FOUND = 3,
  CHOICE_OUT_OF_BOUNDS = 4,
  CHOICE_UNAVAILABLE = 5,
  EXPECTED_ANSWER = 6,
  RESOLUTION_QUEUE_EMPTY = 7,
  TYPE_MISMATCH = 8,
  UNEXPECTED_NULL = 9,
  VAR_UNDEFINED = 10,
  UNEXPECTED_ACT = 11,
  LOADING_MODULE = 12,
  NO_GLOBAL = 13,
  OUT_OF_BOUNDS = 14,
  START_EMPTY_BLOCK = 15,
}
local E = Skald.ERROR

local function err(code, message, line)
  return { type = "error", code = code, message = message, line = line or 0 }
end

-- SECTION: Typed values
-- Internal values are tagged tables {t="str"|"int"|"float"|"bool", v=...},
-- the same shape the compiler emits for literals.

-- codex/declaration type names to value tags
local TAG_FOR_TYPE = { string = "str", bool = "bool", int = "int", float = "float" }
local TYPE_FOR_TAG = { str = "string", bool = "bool", int = "int", float = "float" }
local ZERO = { str = "", int = 0, float = 0.0, bool = false }

local function tv(t, v)
  return { t = t, v = v }
end

local function copy_tv(x)
  return { t = x.t, v = x.v }
end

local function truthy(x)
  if x.t == "str" then
    return #x.v > 0
  elseif x.t == "bool" then
    return x.v
  end
  return x.v ~= 0
end

-- ordering key; bools order as 0/1 like C++
local function ord(x)
  if x.t == "bool" then
    return x.v and 1 or 0
  end
  return x.v
end

-- mismatched types compare false, as in the C++ engine
local function compare(a, b, cmp)
  if a.t ~= b.t then
    return false
  end
  if cmp == "eq" then
    return a.v == b.v
  elseif cmp == "ne" then
    return a.v ~= b.v
  end
  local x, y = ord(a), ord(b)
  if cmp == "gt" then
    return x > y
  elseif cmp == "lt" then
    return x < y
  elseif cmp == "ge" then
    return x >= y
  elseif cmp == "le" then
    return x <= y
  end
  return false
end

local function fmt_float(v, precision)
  if v ~= v then
    return "nan"
  elseif v == huge then
    return "inf"
  elseif v == -huge then
    return "-inf"
  end
  local s = string.format("%." .. precision .. "g", v)
  if not s:find("[%.eEn]") then
    s = s .. ".0"
  end
  return s
end

-- value as it appears inside narrative text
local function display(x)
  if x.t == "str" then
    return x.v
  elseif x.t == "bool" then
    return x.v and "true" or "false"
  elseif x.t == "int" then
    return string.format("%d", x.v)
  end
  return fmt_float(x.v, 14)
end

-- value as a Lua literal; matches the compiler's emitter and skalder transcripts
local function lua_literal(x)
  if x.t == "str" then
    local s = x.v:gsub("[%c\\\"\127]", function(c)
      if c == "\\" then return "\\\\" end
      if c == "\"" then return "\\\"" end
      if c == "\n" then return "\\n" end
      if c == "\r" then return "\\r" end
      if c == "\t" then return "\\t" end
      return string.format("\\%03d", c:byte())
    end)
    return "\"" .. s .. "\""
  elseif x.t == "bool" then
    return x.v and "true" or "false"
  elseif x.t == "int" then
    return string.format("%d", x.v)
  end
  if x.v ~= x.v then return "(0/0)" end
  if x.v == huge then return "math.huge" end
  if x.v == -huge then return "-math.huge" end
  return fmt_float(x.v, 9)
end
Skald.lua_literal = lua_literal

-- plain Lua value to typed, given a target tag (or nil to infer)
local function coerce(v, tag)
  local lt = type(v)
  if tag == nil then
    if lt == "boolean" then return tv("bool", v) end
    if lt == "string" then return tv("str", v) end
    if lt == "number" then return tv(is_integer(v) and "int" or "float", v) end
    return nil, "unsupported Lua type " .. lt
  end
  if tag == "str" then
    if lt ~= "string" then return nil, "expected string, got " .. lt end
    return tv("str", v)
  elseif tag == "bool" then
    if lt ~= "boolean" then return nil, "expected bool, got " .. lt end
    return tv("bool", v)
  elseif tag == "int" then
    if lt ~= "number" then return nil, "expected int, got " .. lt end
    if not is_integer(v) then return nil, "expected int, got non-integer " .. tostring(v) end
    return tv("int", v)
  elseif tag == "float" then
    if lt ~= "number" then return nil, "expected float, got " .. lt end
    return tv("float", v)
  end
  return nil, "unknown type " .. tostring(tag)
end

-- SECTION: Call collection
-- Every `call` RValue reachable from a node, in source order. These become
-- queries the host must answer before the node runs.

local collect_cond

local function collect_rv(rv, out)
  if type(rv) ~= "table" or rv.t ~= "call" then
    return
  end
  for i = 1, #rv.args do
    collect_rv(rv.args[i], out)
  end
  out[#out + 1] = rv
end

collect_cond = function(cond, out)
  if not cond then
    return
  end
  for i = 1, #cond.items do
    local item = cond.items[i]
    if item.t == "group" then
      collect_cond(item.cond, out)
    else
      collect_rv(item.a, out)
      if item.b then
        collect_rv(item.b, out)
      end
    end
  end
end

local function collect_text(text, out)
  for i = 1, #text.parts do
    local p = text.parts[i]
    if type(p) == "table" then
      if p.t == "insert" then
        collect_rv(p.rv, out)
      elseif p.t == "tern" then
        collect_rv(p.check, out)
        for j = 1, #p.options do
          collect_rv(p.options[j][1], out)
          collect_rv(p.options[j][2], out)
        end
      end
    end
  end
end

local function collect_member(mem, out)
  collect_cond(mem.cond, out)
  local b = mem.body
  if b.t == "beat" then
    collect_text(b.text, out)
  elseif b.t == "mutation" then
    if b.rv then
      collect_rv(b.rv, out)
    end
  elseif b.t == "call" then
    for i = 1, #b.args do
      collect_rv(b.args[i], out)
    end
  end
end

local function collect_choices(cg, out)
  for i = 1, #cg.choices do
    local c = cg.choices[i]
    collect_cond(c.cond, out)
    collect_text(c.text, out)
  end
end

-- SECTION: Loading helpers

local function check_format(tbl, what)
  if type(tbl) ~= "table" then
    error("Skald: " .. what .. " is not a table", 3)
  end
  if tbl.format_version ~= Skald.FORMAT_VERSION then
    error(string.format("Skald: %s has format_version %s, runtime supports %d", what,
      tostring(tbl.format_version), Skald.FORMAT_VERSION), 3)
  end
end

-- host.load_module for stock Lua: "chapter1/a.ska" -> dofile(dir.."/chapter1/a.lua")
function Skald.dofile_loader(dir)
  return function(path)
    local lua_path = (path:gsub("%.ska$", ".lua"))
    return dofile(dir .. "/" .. lua_path)
  end
end

-- Static checks on a compiled module against its codex. Returns a list of
-- {message=, line=}. Empty list means clean.
function Skald.validate(codex, module)
  local out = {}
  local function add(msg, line)
    out[#out + 1] = { message = msg, line = line or 0 }
  end
  if type(module) ~= "table" then
    add("module is not a table")
    return out
  end
  if module.format_version ~= Skald.FORMAT_VERSION then
    add("module format_version " .. tostring(module.format_version) .. " unsupported")
    return out
  end
  if codex and codex.format_version ~= Skald.FORMAT_VERSION then
    add("codex format_version " .. tostring(codex.format_version) .. " unsupported")
  end
  local tags, known_modules, methods = {}, {}, {}
  for i = 1, #module.blocks do
    tags[module.blocks[i].tag] = true
  end
  if codex then
    for i = 1, #(codex.modules or {}) do
      known_modules[codex.modules[i]] = true
    end
    for i = 1, #(codex.methods or {}) do
      methods[codex.methods[i].name] = true
    end
  end

  local check_member
  local function check_rv(rv, line)
    if type(rv) == "table" and rv.t == "call" then
      if codex and not methods[rv.method] then
        add("unknown method: " .. rv.method, rv.line or line)
      end
      for i = 1, #rv.args do
        check_rv(rv.args[i], line)
      end
    end
  end
  local function check_calls(node, line)
    local calls = {}
    if node.body then
      collect_member(node, calls)
    elseif node.t == "choices" then
      collect_choices(node, calls)
    elseif node.cond then
      collect_cond(node.cond, calls)
    end
    for i = 1, #calls do
      check_rv(calls[i], line)
    end
  end
  check_member = function(mem)
    check_calls(mem, mem.line)
    local b = mem.body
    if b.t == "move" and not tags[b.target] then
      add("move target not found: " .. b.target, mem.line)
    elseif b.t == "go" and codex and not known_modules[b.module] then
      add("GO target not in codex: " .. b.module, mem.line)
    elseif b.t == "call" and codex and not methods[b.method] then
      add("unknown method: " .. b.method, mem.line)
    end
  end
  local function check_bm(bm)
    if bm.t == "choices" then
      check_calls(bm, bm.line)
      for i = 1, #bm.choices do
        for j = 1, #bm.choices[i].members do
          check_member(bm.choices[i].members[j])
        end
      end
    else
      check_member(bm)
    end
  end
  for i = 1, #module.blocks do
    local members = module.blocks[i].members
    for j = 1, #members do
      local m = members[j]
      if m.t == "chain" then
        for k = 1, #m.blocks do
          check_calls(m.blocks[k], m.blocks[k].line)
          for l = 1, #m.blocks[k].members do
            check_bm(m.blocks[k].members[l])
          end
        end
      else
        check_bm(m)
      end
    end
  end
  return out
end

-- SECTION: Runtime

local Runtime = {}
Runtime.__index = Runtime

local function new_cursor()
  return {
    block = 1,
    member = 1,
    transition = nil, -- absolute tag queued by a move
    go = nil, -- pending go response
    exit = nil, -- pending exit response
    chain_block = 1,
    chain_member = 1,
    in_chain = false,
    choice = nil, -- 1-based selected choice while stepping its members
    choice_member = 1,
    choice_setup = false,
    queue = {}, -- pending query responses, source order
  }
end

-- host = { load_module = function(path) -> table, warn = function(msg, line) }
function Skald.new(codex, host, opts)
  if type(host) ~= "table" or type(host.load_module) ~= "function" then
    error("Skald.new: host.load_module(path) is required", 2)
  end
  if codex ~= nil then
    check_format(codex, "codex")
  end
  local self = setmetatable({}, Runtime)
  self.codex = codex
  self.host = host
  self.opts = opts or {}
  self.methods = {}
  self.modules = {}
  self.current = nil
  self.cursor = nil
  self.response = nil
  self.warning_list = {}
  self.global = {}
  self.module_state = {}
  self.local_state = {}
  self.cache = {}
  if codex then
    for i = 1, #(codex.methods or {}) do
      self.methods[codex.methods[i].name] = codex.methods[i]
    end
    for i = 1, #(codex.globals or {}) do
      local g = codex.globals[i]
      self.global[g.name] = g.default and copy_tv(g.default) or tv(TAG_FOR_TYPE[g.type], ZERO[TAG_FOR_TYPE[g.type]])
    end
    if codex.skald_version and codex.skald_version ~= Skald.SKALD_VERSION then
      -- informational only; format_version is the real handshake
      self:_warn("codex compiled by skalder " .. tostring(codex.skald_version))
    end
  end
  return self
end

-- skald version this runtime was developed against
Skald.SKALD_VERSION = "0.6.3"

function Runtime:_warn(msg, line)
  self.warning_list[#self.warning_list + 1] = { message = msg, line = line or 0 }
  if self.host.warn then
    self.host.warn(msg, line or 0)
  end
end

function Runtime:warnings()
  return self.warning_list
end

-- Loads (or fetches cached) compiled module for a codex-relative path.
function Runtime:_fetch(path)
  local mod = self.modules[path]
  if mod then
    return mod
  end
  local ok, res = pcall(self.host.load_module, path)
  if not ok then
    return nil, err(E.LOADING_MODULE, "Error loading module " .. path .. ": " .. tostring(res), 0)
  end
  if res == nil then
    return nil, err(E.LOADING_MODULE, "File not found: " .. path, 0)
  end
  check_format(res, "module " .. path)
  -- tag -> block index
  res._index = {}
  for i = 1, #res.blocks do
    res._index[res.blocks[i].tag] = i
  end
  self.modules[path] = res
  return res
end

-- Makes `path` the current module. Returns true, or nil plus an error response.
function Runtime:load(path)
  local mod, e = self:_fetch(path)
  if not mod then
    return nil, e
  end
  self.current = mod
  self.cursor = nil
  self.response = nil
  return true
end

-- SECTION: State

function Runtime:_build_state()
  self.local_state = {}
  local vars = self.current.vars or {}
  for i = 1, #vars do
    local v = vars[i]
    local tag = TAG_FOR_TYPE[v.type]
    local existing = self.module_state[v.name]
    if existing == nil then
      self.module_state[v.name] = v.default and copy_tv(v.default) or tv(tag, ZERO[tag])
    elseif existing.t ~= tag then
      self:_warn("Module var '" .. v.name .. "' redeclared with different type; keeping existing value.", v.line)
    end
  end
end

-- scope maps in lookup order
function Runtime:_scopes()
  return { { "global", self.global }, { "module", self.module_state }, { "local", self.local_state } }
end

function Runtime:_var_get(name)
  local v = self.global[name] or self.module_state[name] or self.local_state[name]
  if v then
    return v
  end
  self:_warn("Getting value for " .. name .. ", and found nothing. Defaulting to `false`.")
  return tv("bool", false)
end

-- returns scope name, or an error response
function Runtime:_var_set(name, val, line)
  local scopes = self:_scopes()
  for i = 1, 3 do
    local scope, map = scopes[i][1], scopes[i][2]
    local cur = map[name]
    if cur then
      if cur.t ~= val.t then
        return err(E.TYPE_MISMATCH, "Tried to set " .. scope .. " var " .. name .. " to " .. display(val), line)
      end
      map[name] = copy_tv(val)
      return scope
    end
  end
  self.local_state[name] = copy_tv(val)
  return "local"
end

function Runtime:_var_toggle(name, line)
  local scopes = self:_scopes()
  for i = 1, 3 do
    local scope, map = scopes[i][1], scopes[i][2]
    local cur = map[name]
    if cur then
      if cur.t ~= "bool" then
        return err(E.TYPE_MISMATCH, "Tried to switch " .. name .. ", but it is not a boolean.", line)
      end
      map[name] = tv("bool", not cur.v)
      return scope
    end
  end
  self:_warn("Tried to switch " .. name .. ", and found nothing. Setting it as a local variable to `false`.", line)
  self.local_state[name] = tv("bool", false)
  return "local"
end

-- toward-zero truncation, matching a C cast
local function trunc(n)
  if n < 0 then
    return -floor(-n)
  end
  return floor(n)
end

function Runtime:_var_add(name, val, sign, line)
  if val.t ~= "int" and val.t ~= "float" then
    return err(E.TYPE_MISMATCH, "Tried to add non-numeric value " .. display(val) .. " to " .. name .. ".", line)
  end
  local arg = val.v
  if not sign then
    arg = -arg
  end
  local scopes = self:_scopes()
  for i = 1, 3 do
    local scope, map = scopes[i][1], scopes[i][2]
    local cur = map[name]
    if cur then
      if cur.t == "int" then
        map[name] = tv("int", cur.v + trunc(arg))
        return scope
      elseif cur.t == "float" then
        map[name] = tv("float", cur.v + arg)
        return scope
      end
      return err(E.TYPE_MISMATCH, "Tried to add to " .. scope .. " var " .. name .. ", but it is not numeric.", line)
    end
  end
  return err(E.VAR_UNDEFINED, "Tried to add to undefined var " .. name .. ".", line)
end

-- Public: globals only, mirroring Engine::get / Engine::set.
function Runtime:get(name)
  local v = self.global[name]
  if not v then
    return nil, err(E.VAR_UNDEFINED, "Tried to get undefined global var " .. name .. ".", 0)
  end
  return v.v, TYPE_FOR_TAG[v.t]
end

function Runtime:set(name, value)
  local cur = self.global[name]
  if not cur then
    return err(E.VAR_UNDEFINED, "Tried to set undefined global var " .. name .. ".", 0)
  end
  local val, why = coerce(value, cur.t)
  if not val then
    return err(E.TYPE_MISMATCH, "Tried to set global var " .. name .. " to " .. tostring(value) .. ", but the type does not match (" .. why .. ").", 0)
  end
  self.global[name] = val
  return nil
end

-- Applies a @testbed from the current module. Call after load, before start.
function Runtime:apply_testbed(name)
  if not self.current then
    return err(E.LOADING_MODULE, "No module loaded.", 0)
  end
  local bed
  for i = 1, #(self.current.testbeds or {}) do
    if self.current.testbeds[i].name == name then
      bed = self.current.testbeds[i]
      break
    end
  end
  if not bed then
    return err(E.VAR_UNDEFINED, "Unknown testbed: " .. name, 0)
  end
  local decl_type = {}
  for i = 1, #(self.current.vars or {}) do
    decl_type[self.current.vars[i].name] = TAG_FOR_TYPE[self.current.vars[i].type]
  end
  for i = 1, #bed.sets do
    local s = bed.sets[i]
    local g = self.global[s.var]
    if g then
      if g.t ~= s.value.t then
        return err(E.TYPE_MISMATCH, "Testbed sets global " .. s.var .. " to " .. display(s.value) .. ", but the type does not match.", s.line)
      end
      self.global[s.var] = copy_tv(s.value)
    else
      if decl_type[s.var] and decl_type[s.var] ~= s.value.t then
        return err(E.TYPE_MISMATCH, "Testbed sets " .. s.var .. " to " .. display(s.value) .. ", but the type does not match.", s.line)
      end
      self.module_state[s.var] = copy_tv(s.value)
    end
  end
  return nil
end

-- SECTION: Resolution

function Runtime:_call_key(method, args)
  local parts = { method }
  for i = 1, #args do
    parts[#parts + 1] = lua_literal(args[i])
  end
  return table.concat(parts, "|")
end

-- resolves a call RValue's args; returns typed args plus key, or error
function Runtime:_resolve_call(rv)
  local args = {}
  for i = 1, #rv.args do
    args[i] = self:_resolve(rv.args[i])
  end
  local def = self.methods[rv.method]
  if def then
    if #def.args ~= #args then
      return nil, nil, err(E.TYPE_MISMATCH, string.format("Method %s expects %d argument(s), got %d.", rv.method, #def.args, #args), rv.line)
    end
    for i = 1, #args do
      local want = TAG_FOR_TYPE[def.args[i].type]
      if args[i].t ~= want then
        return nil, nil, err(E.TYPE_MISMATCH, string.format("Method %s argument %d (%s) expects %s, got %s.", rv.method, i, def.args[i].name, def.args[i].type, TYPE_FOR_TAG[args[i].t]), rv.line)
      end
    end
  elseif self.codex then
    self:_warn("Unknown method: " .. rv.method, rv.line)
  end
  return args, self:_call_key(rv.method, args)
end

function Runtime:_resolve(rv)
  if rv.t == "var" then
    return self:_var_get(rv.name)
  elseif rv.t == "call" then
    local args, key = self:_resolve_call(rv)
    if not args then
      return tv("bool", false)
    end
    local hit = self.cache[key]
    if hit then
      return hit
    end
    self:_warn("Tried to resolve query key " .. key .. " and got nothing; defaulting to `false`.", rv.line)
    return tv("bool", false)
  end
  return rv
end

function Runtime:_atom(atom)
  local a = self:_resolve(atom.a)
  if atom.cmp == "truthy" then
    return truthy(a)
  elseif atom.cmp == "not_truthy" then
    return not truthy(a)
  end
  return compare(a, self:_resolve(atom.b), atom.cmp)
end

-- nil condition passes
function Runtime:_cond(cond)
  if not cond then
    return true
  end
  local is_or = cond.type == "or"
  for i = 1, #cond.items do
    local item = cond.items[i]
    local r
    if item.t == "group" then
      r = self:_cond(item.cond)
    else
      r = self:_atom(item)
    end
    if r and is_or then
      return true
    end
    if not r and not is_or then
      return false
    end
  end
  return not is_or
end

function Runtime:_tern(p)
  local check = self:_resolve(p.check)
  if p.truthy then
    local opt = p.options[truthy(check) and 1 or 2]
    return display(self:_resolve(opt[2]))
  end
  for i = 1, #p.options do
    if compare(check, self:_resolve(p.options[i][1]), "eq") then
      return display(self:_resolve(p.options[i][2]))
    end
  end
  return ""
end

-- one chunk per text part
function Runtime:_text(text)
  local chunks = {}
  for i = 1, #text.parts do
    local p = text.parts[i]
    if type(p) == "string" then
      chunks[i] = p
    elseif p.t == "insert" then
      chunks[i] = display(self:_resolve(p.rv))
    elseif p.t == "tern" then
      chunks[i] = self:_tern(p)
    else
      chunks[i] = ""
    end
  end
  return chunks
end

-- SECTION: Query queue

local function plain_args(args)
  local vals, types = {}, {}
  for i = 1, #args do
    vals[i] = args[i].v
    types[i] = TYPE_FOR_TAG[args[i].t]
  end
  return vals, types
end

-- builds query responses for a list of call RValues; returns error response on bad args
function Runtime:_queue_calls(calls)
  for i = 1, #calls do
    local rv = calls[i]
    local args, key, e = self:_resolve_call(rv)
    if not args then
      return e
    end
    local vals, types = plain_args(args)
    self.cursor.queue[#self.cursor.queue + 1] = {
      type = "query", method = rv.method, args = vals, arg_types = types, key = key, line = rv.line or 0,
    }
  end
  return nil
end

function Runtime:_setup_bm(bm)
  local calls = {}
  if bm.t == "choices" then
    collect_choices(bm, calls)
  else
    collect_member(bm, calls)
  end
  return self:_queue_calls(calls)
end

function Runtime:_setup_mbm(mbm)
  local c = self.cursor
  c.chain_block, c.chain_member, c.in_chain = 1, 1, false
  if mbm.t == "chain" then
    local calls = {}
    collect_cond(mbm.blocks[1].cond, calls)
    return self:_queue_calls(calls)
  end
  return self:_setup_bm(mbm)
end

-- SECTION: Members

function Runtime:_do_member(mem)
  if mem.cond and not self:_cond(mem.cond) then
    return nil
  end
  local b = mem.body
  local c = self.cursor
  if b.t == "beat" then
    return { type = "content", attribution = b.attribution or "", text = self:_text(b.text), line = mem.line or 0 }
  elseif b.t == "move" then
    c.transition = b.target
    return nil
  elseif b.t == "call" then
    local args, _, e = self:_resolve_call(b)
    if not args then
      return e
    end
    local vals, types = plain_args(args)
    return { type = "post", method = b.method, args = vals, arg_types = types, line = mem.line or 0 }
  elseif b.t == "mutation" then
    local rv = b.rv and self:_resolve(b.rv) or nil
    local res
    if b.op == "set" then
      res = self:_var_set(b.lvalue, rv, mem.line)
    elseif b.op == "add" then
      res = self:_var_add(b.lvalue, rv, true, mem.line)
    elseif b.op == "sub" then
      res = self:_var_add(b.lvalue, rv, false, mem.line)
    else
      res = self:_var_toggle(b.lvalue, mem.line)
    end
    if type(res) == "table" then
      return res
    end
    return {
      type = "notification", var = b.lvalue, op = b.op, scope = res,
      value = rv and rv.v or nil, value_type = rv and TYPE_FOR_TAG[rv.t] or nil, line = mem.line or 0,
    }
  elseif b.t == "go" then
    c.go = { type = "go", module = b.module, start_in = b.start_in or "", line = mem.line or 0 }
    return c.go
  elseif b.t == "exit" then
    local v = b.arg
    c.exit = { type = "exit", value = v and v.v or nil, value_type = v and TYPE_FOR_TAG[v.t] or nil, line = mem.line or 0 }
    return c.exit
  end
  return err(E.UNKNOWN, "Unknown member body: " .. tostring(b.t), mem.line)
end

function Runtime:_options(cg)
  local opts = {}
  for i = 1, #cg.choices do
    local ch = cg.choices[i]
    opts[i] = { text = self:_text(ch.text), available = self:_cond(ch.cond) }
  end
  return { type = "options", options = opts, line = cg.line or 0 }
end

-- runs the block member under the cursor; response, or nil to advance
function Runtime:_run_bm(bm)
  local c = self.cursor
  if bm.t ~= "choices" then
    return self:_do_member(bm)
  end
  if not c.choice then
    return self:_options(bm)
  end
  local choice = bm.choices[c.choice]
  if c.choice_member > #choice.members then
    c.choice, c.choice_member, c.choice_setup = nil, 1, false
    return nil
  end
  local mem = choice.members[c.choice_member]
  if not c.choice_setup then
    c.choice_setup = true
    local e = self:_queue_calls((function()
      local calls = {}
      collect_member(mem, calls)
      return calls
    end)())
    if e then
      return e
    end
    if #c.queue > 0 then
      return c.queue[1]
    end
  end
  c.choice_member = c.choice_member + 1
  c.choice_setup = false
  return self:_do_member(mem)
end

-- SECTION: Cursor movement

function Runtime:_block()
  return self.current.blocks[self.cursor.block]
end

function Runtime:_mbm()
  return self:_block().members[self.cursor.member]
end

-- current Member or ChoiceGroup, descending into an entered chain
function Runtime:_bm()
  local mbm = self:_mbm()
  if mbm.t == "chain" then
    if not self.cursor.in_chain then
      return nil
    end
    return mbm.blocks[self.cursor.chain_block].members[self.cursor.chain_member]
  end
  return mbm
end

-- steps to the next member; nil or error response
function Runtime:_advance(from_line)
  local c = self.cursor
  if c.transition then
    local idx = self.current._index[c.transition]
    if not idx then
      return err(E.MODULE_TAG_NOT_FOUND, "Module tag not found: " .. c.transition, from_line)
    end
    c.block = idx
    c.member = 0 -- above the top, so the increment below lands on member 1
    c.in_chain, c.chain_block, c.chain_member = false, 1, 1
    c.choice, c.choice_member, c.choice_setup = nil, 1, false
    c.transition = nil
  end

  if c.member >= 1 and c.in_chain then
    local cb = self:_mbm().blocks[c.chain_block]
    c.chain_member = c.chain_member + 1
    if c.chain_member <= #cb.members then
      return self:_setup_bm(cb.members[c.chain_member])
    end
    c.in_chain, c.chain_block, c.chain_member = false, 1, 1
  end

  c.member = c.member + 1
  local block = self:_block()
  while c.member > #block.members do
    c.block = c.block + 1
    c.member = 1
    if c.block > #self.current.blocks then
      return err(E.EOF, "Unexpectedly reached the end of the file", from_line)
    end
    block = self:_block()
  end
  return self:_setup_mbm(block.members[c.member])
end

-- SECTION: Step loop

function Runtime:_next()
  local c = self.cursor
  for _ = 1, 50 do
    if c.exit then
      return c.exit
    end
    if c.go then
      return c.go
    end
    if #c.queue > 0 then
      return c.queue[1]
    end

    local mbm = self:_mbm()
    local bm, e
    if mbm.t == "chain" then
      if c.in_chain then
        bm = mbm.blocks[c.chain_block].members[c.chain_member]
      else
        local cb = mbm.blocks[c.chain_block]
        if self:_cond(cb.cond) then
          if #cb.members == 0 then
            e = self:_advance()
          else
            c.in_chain = true
            e = self:_setup_bm(cb.members[1])
          end
        else
          c.chain_block = c.chain_block + 1
          if c.chain_block > #mbm.blocks then
            c.chain_block = 1
            e = self:_advance()
          else
            local calls = {}
            collect_cond(mbm.blocks[c.chain_block].cond, calls)
            e = self:_queue_calls(calls)
          end
        end
      end
    else
      bm = mbm
    end
    if e then
      return e
    end

    if bm then
      local resp = self:_run_bm(bm)
      if resp then
        return resp
      end
      e = self:_advance()
      if e then
        return e
      end
    end
  end
  return err(E.UNKNOWN, "Module was caught in an infinite loop; bailed out at 50 iterations.", 0)
end

function Runtime:_finish(resp)
  self.response = resp
  return resp
end

-- SECTION: Entry

function Runtime:_enter(block_index)
  self.cursor = new_cursor()
  self.cache = self.cache or {}
  self:_build_state()
  self.cursor.block = block_index
  local block = self:_block()
  if #block.members == 0 then
    return self:_finish(err(E.START_EMPTY_BLOCK, "You cannot enter into an empty block!", block.line))
  end
  local e = self:_setup_mbm(block.members[1])
  if e then
    return self:_finish(e)
  end
  return self:_finish(self:_next())
end

function Runtime:start()
  if not self.current then
    error("Skald: start() before load()", 2)
  end
  if #self.current.blocks < 1 then
    return self:_finish(err(E.EMPTY_MODULE, "No blocks were found in the current module!", 0))
  end
  return self:_enter(1)
end

function Runtime:start_at(tag)
  if not self.current then
    error("Skald: start_at() before load()", 2)
  end
  local idx = self.current._index[tag]
  if not idx then
    return self:_finish(err(E.MODULE_TAG_NOT_FOUND, "No block was found for tag: " .. tag, 0))
  end
  return self:_enter(idx)
end

function Runtime:get_current()
  return self.response
end

-- SECTION: Input

function Runtime:_do_go()
  local g = self.cursor.go
  local mod, e = self:_fetch(g.module)
  if not mod then
    return self:_finish(e)
  end
  self.current = mod
  if g.start_in and g.start_in ~= "" then
    return self:start_at(g.start_in)
  end
  return self:start()
end

-- Continue (any index) after content, notification, post or go; pick an
-- option (0-based) after options. Terminal responses repeat themselves.
function Runtime:act(index)
  index = index or 0
  local resp = self.response
  if not resp then
    error("Skald: act() before start()", 2)
  end
  local t = resp.type
  if t == "end" or t == "error" then
    return resp
  elseif t == "exit" then
    return self:_finish({ type = "end", reason = "Module EXIT." })
  elseif t == "go" then
    return self:_do_go()
  elseif t == "query" then
    return err(E.UNEXPECTED_ACT, "Received act() while a query is pending; call answer() instead.", resp.line)
  end

  local c = self.cursor
  local bm = self:_bm()
  if bm and bm.t == "choices" then
    if c.choice then
      -- stepping through a chosen option's members; nothing to select
      return self:_finish(self:_next())
    end
    local n = #bm.choices
    if index < 0 or index >= n then
      return self:_finish(err(E.CHOICE_OUT_OF_BOUNDS,
        "You picked choice " .. index .. ", but there are only " .. n .. " choices available!", bm.line))
    end
    local any = false
    for i = 1, n do
      if self:_cond(bm.choices[i].cond) then
        any = true
        break
      end
    end
    if any then
      local choice = bm.choices[index + 1]
      if not self:_cond(choice.cond) then
        return self:_finish(err(E.CHOICE_UNAVAILABLE, "You picked choice " .. index .. ", but it is unavailable.", choice.line))
      end
      c.choice, c.choice_member, c.choice_setup = index + 1, 1, false
      return self:_finish(self:_next())
    end
    -- no option available: fall through and continue past the group
  end

  local e = self:_advance(resp.line)
  if e then
    return self:_finish(e)
  end
  return self:_finish(self:_next())
end

-- Answers the pending query. nil clears any cached value for that call.
function Runtime:answer(value)
  local c = self.cursor
  if not c or #c.queue == 0 then
    return err(E.RESOLUTION_QUEUE_EMPTY, "Received an answer, but the resolution queue is empty!", 0)
  end
  local q = table.remove(c.queue, 1)
  if value == nil then
    self.cache[q.key] = nil
  else
    local def = self.methods[q.method]
    local tag = def and TAG_FOR_TYPE[def.ret] or nil
    local val = coerce(value, tag)
    if not val then
      -- keep whatever the host gave us rather than fail the story
      val = coerce(value)
      if not val then
        return err(E.TYPE_MISMATCH, "Cannot store answer of Lua type " .. type(value), q.line)
      end
    end
    self.cache[q.key] = val
  end
  return self:_finish(self:_next())
end

-- SECTION: Bookmarks

local function deep_copy(x)
  if type(x) ~= "table" then
    return x
  end
  local out = {}
  for k, v in pairs(x) do
    out[k] = deep_copy(v)
  end
  return out
end

-- Plain-table snapshot of everything needed to resume. Safe to serialize.
function Runtime:bookmark()
  if not self.current or not self.cursor then
    error("Skald: bookmark() before start()", 2)
  end
  return {
    skald_lua = Skald.VERSION,
    module = self.current.path,
    cursor = deep_copy(self.cursor),
    global = deep_copy(self.global),
    module_state = deep_copy(self.module_state),
    local_state = deep_copy(self.local_state),
    cache = deep_copy(self.cache),
    response = deep_copy(self.response),
  }
end

-- Rebuilds state from a bookmark and returns the response that was current.
function Runtime:restore(bm)
  local mod, e = self:_fetch(bm.module)
  if not mod then
    return self:_finish(e)
  end
  self.current = mod
  self.cursor = deep_copy(bm.cursor)
  self.global = deep_copy(bm.global)
  self.module_state = deep_copy(bm.module_state)
  self.local_state = deep_copy(bm.local_state)
  self.cache = deep_copy(bm.cache)
  self.response = deep_copy(bm.response)
  return self.response
end

SkaldRuntime = Skald
