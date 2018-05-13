prometheus = require("prometheus/prometheus")

gauge_item_production_input = prometheus.gauge("factorio_item_production_input", "items produced", {"force", "name"})
gauge_item_production_output = prometheus.gauge("factorio_item_production_output", "items consumed", {"force", "name"})
gauge_fluid_production_input = prometheus.gauge("factorio_fluid_production_input", "fluids produced", {"force", "name"})
gauge_fluid_production_output = prometheus.gauge("factorio_fluid_production_output", "fluids consumed", {"force", "name"})
gauge_kill_count_input = prometheus.gauge("factorio_kill_count_input", "kills", {"force", "name"})
gauge_kill_count_output = prometheus.gauge("factorio_kill_count_output", "losses", {"force", "name"})
gauge_entity_build_count_input = prometheus.gauge("factorio_entity_build_count_input", "entities placed", {"force", "name"})
gauge_entity_build_count_output = prometheus.gauge("factorio_entity_build_count_output", "entities removed", {"force", "name"})
gauge_items_launched = prometheus.gauge("factorio_items_launched_total", "items launched in rockets", {"force", "name"})
gauge_electric_input = prometheus.gauge("factorio_electric_input", "electricity consumed", {"force", "index", "name"})
gauge_electric_output = prometheus.gauge("factorio_electric_output", "electricity produced", {"force", "index", "name"})

gauge_yarm_site_amount = prometheus.gauge("factorio_yarm_site_amount", "YARM - site amount remaining", {"force", "name", "type"})
gauge_yarm_site_ore_per_minute = prometheus.gauge("factorio_yarm_site_ore_per_minute", "YARM - site ore per minute", {"force", "name", "type"})
gauge_yarm_site_remaining_permille = prometheus.gauge("factorio_yarm_site_remaining_permille", "YARM - site permille remaining", {"force", "name", "type"})

local function handleYARM(site)
  gauge_yarm_site_amount:set(site.amount, {site.force_name, site.site_name, site.ore_type})
  gauge_yarm_site_remaining_permille:set(site.remaining_permille, {site.force_name, site.site_name, site.ore_type})
  gauge_yarm_site_ore_per_minute:set(site.ore_per_minute, {site.force_name, site.site_name, site.ore_type})
end

local function hookupYARM()
  if global.yarm_enabled then
    script.on_event(remote.call("YARM", "get_on_site_updated_event_id"), handleYARM)
  end
end

script.on_init(function()
  global.yarm_enabled = false
  global.electric_networks = {}

  if game.active_mods["YARM"] then
    global.yarm_enabled = true
  end

  hookupYARM()
end)

script.on_configuration_changed(function(event)
  if game.active_mods["YARM"] then
    global.yarm_enabled = true
  else
    global.yarm_enabled = false
  end

  hookupYARM()
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick % 600 == 0 then
    for _, player in pairs(game.players) do
      stats = {
        {player.force.item_production_statistics, gauge_item_production_input, gauge_item_production_output},
        {player.force.fluid_production_statistics, gauge_fluid_production_input, gauge_fluid_production_output},
        {player.force.kill_count_statistics, gauge_kill_count_input, gauge_kill_count_output},
        {player.force.entity_build_count_statistics, gauge_entity_build_count_input, gauge_entity_build_count_output},
      }

      for _, stat in pairs(stats) do
        for name, n in pairs(stat[1].input_counts) do
          stat[2]:set(n, {player.force.name, name})
        end

        for name, n in pairs(stat[1].output_counts) do
          stat[3]:set(n, {player.force.name, name})
        end
      end

      for name, n in pairs(player.force.items_launched) do
        gauge_items_launched:set(n, {player.force.name, name})
      end
    end

    if global.electric_networks then
      for index, network in pairs(global.electric_networks) do
        for name, n in pairs(network.input_counts) do
          gauge_electric_input:set(n, {network.force.name, index, name})
        end

        for name, n in pairs(network.output_counts) do
          gauge_electric_output:set(n, {network.force.name, index, name})
        end
      end
    end

    game.write_file("graftorio/game.prom", prometheus.collect(), false)
  end

  -- for _, force in pairs(game.forces) do
  --   for id, network in pairs(force.logistic_networks) do
  --     game.print(id)
  --     game.print(network)
  --   end
  -- end
end)

local function electricNetworksAreSame(a, b)
  if a == b then
    return true
  end

  local ainputs = 0
  local asuminputs = 0
  local binputs = 0
  local bsuminputs = 0
  local aoutputs = 0
  local asumoutputs = 0
  local boutputs = 0
  local bsumoutputs = 0

  for aname, n in pairs(a.input_counts) do
    ainputs = ainputs + 1
    asuminputs = asuminputs + n
  end
  for bname, n in pairs(b.input_counts) do
    binputs = binputs + 1
    bsuminputs = bsuminputs + n
  end
  for aname, n in pairs(a.output_counts) do
    aoutputs = aoutputs + 1
    asumoutputs = asumoutputs + n
  end
  for bname, n in pairs(b.output_counts) do
    boutputs = boutputs + 1
    bsumoutputs = bsumoutputs + n
  end

  if ainputs == binputs and
     aoutputs == boutputs and
     asuminputs == bsuminputs and
     asumoutputs == bsumoutputs then
    return true
  end

  return false
end

script.on_event(defines.events.on_selected_entity_changed, function(event)
  if event.last_entity and event.last_entity.type == "electric-pole" and event.last_entity.electric_network_statistics then
    local found = false
    if global.electric_networks == nil then
      global.electric_networks = {}
    end

    for _, network in pairs(global.electric_networks) do
      if electricNetworksAreSame(network, event.last_entity.electric_network_statistics) then
        found = true
      end
    end

    if found ~= true then
      table.insert(global.electric_networks, event.last_entity.electric_network_statistics)
      game.print("graftorio: discovered new electric network")
    end
  end
end)
