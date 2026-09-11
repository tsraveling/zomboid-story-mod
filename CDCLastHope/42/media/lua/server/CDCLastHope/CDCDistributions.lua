require "CDCLastHope/CDCStoryLoader"

local function inject()
    for _, s in ipairs(CDC.story.world.spawns or {}) do
        for _, name in ipairs(s.lists or {}) do
            local list = ProceduralDistributions.list[name]
            if list and list.items then
                table.insert(list.items, s.item)
                table.insert(list.items, s.chance or 1)
            else
                CDC.log("WARN: spawn list '" .. tostring(name) .. "' not found")
            end
        end
    end
end

Events.OnPreDistributionMerge.Add(inject)
