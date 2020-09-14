local translate = require("scripts/translation")

local script_data = {
  has_checked = false,
  networks = {},
  switches = {}
}

local map = {}

local function new_entity_entry(entity)
  local base = {
    entity_number = entity.unit_number,
    prev = {input = {}, output = {}}
  }
  if script_data.networks[entity.electric_network_id] then
    base.prev = script_data.networks[entity.electric_network_id].prev
  end
  script_data.networks[entity.electric_network_id] = base
  map[entity.unit_number] = entity
end

local function find_entity(unit_number, entity_type)
  if map[unit_number] then
    return map[unit_number]
  end

  for _, surface in pairs(game.surfaces) do
    local ents = surface.find_entities_filtered({type = entity_type})
    for _, entity in pairs(ents) do
      if entity.unit_number == unit_number then
        map[entity.unit_number] = entity
        return entity
      end
    end
  end
end

local function rescan_worlds()
  local networks = script_data.networks
  local invalids = {}
  local remove = {}
  for idx, network in pairs(networks) do
    if network.entity then
      network.entity_number = network.entity.unit_number
      network.entity = nil
    end

    if network.entity_number then
      local assoc = find_entity(network.entity_number, "electric-pole")
      if not assoc then
        invalids[idx] = true
      end
    else
      remove[idx] = true
    end
  end
  for _, surface in pairs(game.surfaces) do
    local ents = surface.find_entities_filtered({type = "electric-pole"})
    for _, entity in pairs(ents) do
      if not networks[entity.electric_network_id] or invalids[entity.electric_network_id] then
        new_entity_entry(entity)
        invalids[entity.electric_network_id] = nil
      end
    end
  end

  if table_size(remove) > 0 then
    for idx, _ in pairs(remove) do
      networks[idx] = nil
    end
  end
end

local function get_ignored_networks_by_switches()
  local ignored = {}
  local max = math.max
  for switch_id, val in pairs(script_data.switches) do
    -- assume old entity
    if val ~= 1 and val and val.valid then
      script_data.switches[val.unit_number] = 1
      script_data.switches[switch_id] = nil
    end
    local switch = find_entity(switch_id, "power-switch")
    if switch.power_switch_state and #switch.neighbours.copper > 1 then
      local network = max(switch.neighbours.copper[1].electric_network_id, switch.neighbours.copper[2].electric_network_id)
      ignored[network] = true
    end
  end
  return ignored
end

local on_build = function(event)
  local entity = event.entity or event.created_entity
  if entity and entity.type == "electric-pole" then
    if not script_data.networks[entity.electric_network_id] then
      new_entity_entry(entity)
    end
  elseif entity and entity.type == "power-switch" then
    script_data.switches[entity.unit_number] = 1
    map[entity.unit_number] = entity
  end
end

local on_destroy = function(event)
  local entity = event.entity
  if entity.type == "electric-pole" then
    local pos = entity.position
    local max = entity.prototype and entity.prototype.max_wire_distance or game.max_electric_pole_connection_distance
    local area = {{pos.x - max, pos.y - max}, {pos.x + max, pos.y + max}}
    local surface = entity.surface
    local networks = script_data.networks
    local current_idx = entity.electric_network_id
    -- Make sure to create the new network ids before collecting new info
    if entity.neighbours.copper then
      entity.disconnect_neighbour()
    end
    local finds = surface.find_entities_filtered({type = "electric-pole", area = area})
    for _, new_entity in pairs(finds) do
      if new_entity ~= entity then
        if new_entity.electric_network_id == current_idx or not networks[new_entity.electric_network_id] then
          new_entity_entry(entity)
        end
      end
    end
  elseif entity.type == "power-switch" then
    script_data.switches[entity.unit_number] = nil
  end
end

local lib = {
  on_load = function()
    script_data = global.power_data or script_data
  end,
  on_init = function()
    global.power_data = global.power_data or script_data
  end,
  on_configuration_changed = function(event)
    if global.power_data == nil then
      global.power_data = script_data
    end

    if global.power_data.switches == nil then
      global.power_data.switches = {}
    end
    -- Basicly only when first added or version changed
    -- Power network is added in .10
    if not script_data.has_checked then
      -- scan worlds
      rescan_worlds()
      script_data.has_checked = true
    end
  end,
  events = {
    [defines.events.on_built_entity] = on_build,
    [defines.events.on_robot_built_entity] = on_build,
    [defines.events.script_raised_built] = on_build,
    [defines.events.on_player_mined_entity] = on_destroy,
    [defines.events.on_robot_mined_entity] = on_destroy,
    [defines.events.on_entity_died] = on_destroy,
    [defines.events.script_raised_destroy] = on_destroy,
    [defines.events.on_selected_entity_changed] = function(event)
      local d = 1
      -- if event.last_entity and #event.last_entity.neighbours.copper == 0 then
      --   local a = 1
      -- end
    end,
    [defines.events.on_tick] = function(event)
      if event.tick % 600 == 240 then
        local gauges = gauges
        local ignored = get_ignored_networks_by_switches()
        gauges.power_production_input =
          renew_gauge(gauges.power_production_input, "factorio_power_production_input", "power produced", {"force", "name", "network", "surface", "localised_name"})
        gauges.power_production_output =
          renew_gauge(gauges.power_production_output, "factorio_power_production_output", "power consumed", {"force", "name", "network", "surface", "localised_name"})

        for idx, network in pairs(script_data.networks) do
          -- reset old style in case it still is old
          if network.entity then
            network.entity_number = network.entity.unit_number
            network.entity = nil
          end
          local entity = find_entity(network.entity_number, "electric-pole")
          if not entity then
            rescan_worlds()
            entity = find_entity(network.entity_number, "electric-pole")
          end
          if entity and entity.valid and not ignored[entity.electric_network_id] and entity.electric_network_id == idx then
            -- local prevs = network.prev
            local force_name = entity.force.name
            local surface_name = entity.surface.name
            for name, n in pairs(entity.electric_network_statistics.input_counts) do
              -- local p = (n - (prevs.input[name] or 0)) / 600
              translate.translate(
                {"entity-name." .. name},
                function(translated)
                  gauges.power_production_input:set(n, {force_name, name, idx, surface_name, translated})
                end
              )
              -- prevs.input[name] = n
            end
            for name, n in pairs(entity.electric_network_statistics.output_counts) do
              translate.translate(
                {"entity-name." .. name},
                function(translated)
                  gauges.power_production_output:set(n, {force_name, name, idx, surface_name, translated})
                end
              )
              -- prevs.output[name] = n
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
    end
  },
  rescan_worlds = rescan_worlds
}

return lib
