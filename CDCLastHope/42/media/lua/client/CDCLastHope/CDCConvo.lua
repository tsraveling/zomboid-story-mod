if isServer() then return end
require "CDCLastHope/CDCSkald"
require "CDCLastHope/skald/index"

-- drives one Skald conversation. view receives:
--   line(kind, who, text)   kind: player | cdc | radio | other | narration
--   options(opts)           opts: { {text, available} }
--   waiting()               content shown, wait for continue()
--   working(key, duration, progress)  radio job running; call jobDone() / jobInterrupted()
--   ended(reason)           exit | end | error | interrupted
CDC.Convo = {}
CDC.Convo.__index = CDC.Convo
local C = CDC.Convo

C.ENTRY = "cdc.ska"

local SPEAKERS = { cdc = "CDC", radio = "Radio" }

local function chunks(t)
    return table.concat(t or {})
end

function C.new(player, radio, view)
    local o = setmetatable({}, C)
    o.host = { player = player, radio = radio }
    o.view = view
    o.rt = SkaldRuntime.new(CDCSkaldCodex, {
        load_module = function(path) return CDCSkaldModules[path] end,
        warn = function(msg, line) CDC.log("skald warn: " .. tostring(msg) .. " @" .. tostring(line)) end,
    })
    return o
end

-- jump: optional "tag" or "module.ska:tag" to start at (debug)
function C:begin(jump)
    local module, tag = C.ENTRY, jump
    if jump and jump:find(":") then module, tag = jump:match("^(.-):(.*)$") end
    local ok, err = self.rt:load(module)
    if not ok then return self:advance(err) end
    if tag then return self:advance(self.rt:start_at(tag)) end
    self:advance(self.rt:start())
end

function C:continue()
    if self.state ~= "content" then return end
    self:advance(self.rt:act(0))
end

-- i: 1-based index into the last options list; nil continues past a group with nothing available
function C:choose(i)
    if self.state ~= "options" then return end
    local opt = i and self.opts[i]
    if opt then
        if not opt.available then return end
        local first = self.host.player:getDescriptor():getForename()
        self.view:line("player", first, opt.text)
    end
    self:advance(self.rt:act((i or 1) - 1))
end

function C:query(res)
    local f = CDC.Skald.queries[res.method]
    if not f then
        CDC.log("skald: no query handler for " .. tostring(res.method))
        return nil
    end
    local ok, v = pcall(f, self.host, unpack(res.args))
    if not ok then CDC.log("skald: query " .. res.method .. " failed: " .. tostring(v)); return nil end
    return v
end

function C:post(res)
    local f = CDC.Skald.posts[res.method]
    if not f then CDC.log("skald: no post handler for " .. tostring(res.method)); return end
    local ok, err = pcall(f, self.host, unpack(res.args))
    if not ok then CDC.log("skald: post " .. res.method .. " failed: " .. tostring(err)) end
end

-- runs the engine until it needs the player or a job
function C:advance(res)
    self.state = nil
    while true do
        local t = res.type
        if t == "query" then
            res = self.rt:answer(self:query(res))
        elseif t == "post" and res.method == "do_job" then
            return self:startJob(res.args[1], res.args[2])
        elseif t == "post" then
            self:post(res)
            res = self.rt:act(0)
        elseif t == "notification" or t == "go" then
            res = self.rt:act(0)
        elseif t == "content" then
            local who = res.attribution or ""
            local kind = who == "" and "narration" or (SPEAKERS[who] and who or "other")
            self.view:line(kind, SPEAKERS[who] or who, chunks(res.text))
            self.state = "content"
            return self.view:waiting()
        elseif t == "options" then
            self.opts = {}
            for _, o in ipairs(res.options) do
                table.insert(self.opts, { text = chunks(o.text), available = o.available })
            end
            self.state = "options"
            return self.view:options(self.opts)
        elseif t == "error" then
            CDC.log("skald error line " .. tostring(res.line) .. ": " .. tostring(res.message))
            self.state = "ended"
            return self.view:ended("error")
        else
            self.state = "ended"
            return self.view:ended(t)
        end
    end
end

-- first call registers the job; a finished job continues immediately
function C:startJob(key, hours)
    local job = CDC.State.job(CDC.State.get(), key)
    if not job then
        job = { duration = hours, progress = 0 }
        CDC.Client.applyOps(self.host.player, { { type = "job", key = key, duration = job.duration, progress = 0 } })
    elseif job.progress >= job.duration then
        return self:advance(self.rt:act(0))
    end
    self.state = "job"
    self.jobKey = key
    self.view:working(key, job.duration, job.progress)
end

function C:jobDone()
    if self.state ~= "job" then return end
    self:advance(self.rt:act(0))
end

function C:jobInterrupted()
    if self.state ~= "job" then return end
    self.state = "ended"
    self.view:line("narration", "", "Transmission interrupted.")
    self.view:ended("interrupted")
end
