require "CDCLastHope/CDCState"

-- journal line items keyed by quest, then stage; stages without an entry show nothing; an entry can be a string or a list of strings
-- lines = active objectives, completed = finished-quest entries
CDC.QuestStatus = {}
local QS = CDC.QuestStatus

QS.order = { "first", "tri", "junkie" }

-- @region quests:names
-- shown in "Quest started"; falls back to the key
QS.names = {
  first = "Zombie Meat",
  tri = "Triple Sample",
  junkie = "The Overdose Victim",
}

function QS.name(key)
  return QS.names[key] or tostring(key)
end

QS.lines = {
  first = {
    [0] = "Contact the CDC to accept the zombie meat job.",
    [1] = "Get some zombie meat and then call the CDC.",
  },
  tri = {
    [1] = {
      "Get a zombie brain using a saw or axe.",
      "Get a soil sample from the northward turn of Route 163 that is due east of the crossroads with 31W.",
      "Get a sample of Velvet from a police evidence lockup. The police captain's desk at the Rosewood PD certainly has some (right click menu).",
      "Find a microscope in a clinic, hospital, or lab.",
    },
    [2] = "Set up the microscope near the radio and contact CDC to run comparison on the three samples."
  },
  junkie = {
    [1] =
    "Go to the Muldraugh police department and retrieve the corpse from one of the body lockers in the morgue in the basement. Bring a knife, and a saw or axe, to take muscle and brain samples.",
    [2] =
    "Perform a microscopic analysis on the sample while on the radio with the CDC, and transmit the contents of the medical examiner's notes."
  },
  march = {
    -- STUB: march ridge scientist quest
  }
}

QS.completed = {
  first = {
    [100] =
    "Analyzed a hunk of zombie meat for the CDC, establishing that the Z strain originated in the Knox Event zone, and has an oddly high diversity at origin.",
  },
  tri = {
    [100] =
    "Helped the CDC compare samples of Velvet, the military chemical spill, and a zombie brain, thus establishing that the Z strain has *two* common ancestors in the Knox Event zone."
  },
  junkie = {
    [100] =
    "Recovered the medical examiner's notes and some biosamples from a Velvet overdose victim, giving us valuable insight into the chemical origin of the Z strain.",
  }
}

local function collect(st, map)
  local out = {}
  for _, key in ipairs(QS.order) do
    local line = (map[key] or {})[CDC.State.quest(st, key)]
    if type(line) == "table" then
      for _, l in ipairs(line) do table.insert(out, l) end
    elseif line then
      table.insert(out, line)
    end
  end
  return out
end

function QS.current(st)
  return collect(st, QS.lines)
end

function QS.done(st)
  return collect(st, QS.completed)
end
