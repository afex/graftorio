local script_data = {
  networks = {}
}

local defs = {
  max_distance = false,
  ignores = {}
}

gauges.power_production_input = prometheus.gauge("factorio_power_production_input", "power produced", {"force", "name", "network", "surface"})
gauges.power_production_output = prometheus.gauge("factorio_power_production_output", "power consumed", {"force", "name", "network", "surface"})

local function max_distance()
  if not defs.max_distance then
    defs.max_distance = game.max_electric_pole_connection_distance
  end

  return defs.max_distance
end

local function rescan_worlds()
  local networks = script_data.networks
  for _, surface in pairs(game.surfaces) do
    local ents = surface.find_entities_filtered({type = "electric-pole"})
    for _, entity in pairs(ents) do
      if not networks[entity.electric_network_id] or not networks[entity.electric_network_id].valid then
        new_entity_entry(entity)
      end
    end
  end
end

local function new_entity_entry(entity)
  script_data.networks[entity.electric_network_id] = {entity = entity, prev = {input = {}, output = {}}}
end

local on_build = function(event)
  local entity = event.entity or event.created_entity
  if entity and entity.type == "electric-pole" then
    if not script_data.networks[entity.electric_network_id] then
      new_entity_entry(entity)
    end
  end
end

local on_destroy = function(event)
  local entity = event.entity
  if entity.type == "electric-pole" then
    local pos = entity.position
    local max = max_distance()
    local area = {{pos.x - max, pos.y - max}, {pos.x + max, pos.y + max}}
    local surface = entity.surface
    local current_idx = entity.electric_network_id
    -- Make sure to create the new network ids before collecting new info
    entity.disconnect_neighbour()
    local finds = surface.find_entities_filtered({type = "electric-pole", area = area})
    for _, new_entity in pairs(finds) do
      if new_entity ~= entity then
        if new_entity.electric_network_id == current_idx or not script_data.networks[new_entity.electric_network_id] then
          new_entity_entry(entity)
        end
      end
    end
  end
end

local lib = {
  on_load = function()
    script_data = global.power_data or script_data
    if global.power_data == nil then
      global.power_data = script_data
    end
  end,
  on_init = function()
    global.power_data = global.power_data or script_data
  end,
  on_configuration_changed = function(event)
    -- Basicly only when first added or version changed
    -- Power network is added in .10
    if event.mod_changes.graftorio.new_version == "1.0.10" then
      -- scan worlds
      rescan_worlds()
    end
  end,
  on_nth_tick = {
    [600] = function(event)
      local gauges = gauges
      for idx, network in pairs(script_data.networks) do
        local entity = network.entity
        if entity and entity.valid and entity.electric_network_id == idx then
          local prevs = network.prev
          local force_name = entity.force.name
          local surface_name = entity.surface.name
          for name, n in pairs(entity.electric_network_statistics.input_counts) do
            local p = (n - (prevs.input[name] or 0)) / 600
            gauges.power_production_input:set(p, {force_name, name, idx, surface_name})
            prevs.input[name] = n
          end
          for name, n in pairs(entity.electric_network_statistics.output_counts) do
            local p = (n - (prevs.output[name] or 0)) / 600
            gauges.power_production_output:set(p, {force_name, name, idx, surface_name})
            prevs.output[name] = n
          end
        elseif entity and entity.valid and entity.electric_network_id ~= idx then
          -- assume this network has been merged with some other so unset
          script_data.networks[idx] = nil
        elseif entity and not entity.valid then
          -- Invalid  entity remove anyhow
          script_data.networks[idx] = nil
        end
      end
    end
  },
  events = {
    [defines.events.on_built_entity] = on_build,
    [defines.events.on_robot_built_entity] = on_build,
    [defines.events.script_raised_built] = on_build,
    [defines.events.on_player_mined_entity] = on_destroy,
    [defines.events.on_robot_mined_entity] = on_destroy,
    [defines.events.on_entity_died] = on_destroy,
    [defines.events.script_raised_destroy] = on_destroy
  },
  rescan_worlds = rescan_worlds
}

return lib
