local prometheus = require("prometheus/prometheus")

local function split(inputstr, sep)
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local train_buckets = {}
bucket_settings = split(settings.startup["graftorio-train-histogram-buckets"].value, ",")
for _, bucket in pairs(bucket_settings) do
  table.insert(train_buckets, tonumber(bucket))
end

local single_set = {
  ["seed"] = false,
  ["mods"] = false
}

gauge_tick = prometheus.gauge("factorio_tick", "game tick")
gauge_players_online = prometheus.gauge("factorio_online_players", "online players")
gauge_evolution = prometheus.gauge("factorio_evolution", "evolution", {"force", "type"})
gauge_seed = prometheus.gauge("factorio_seed", "seed", {"surface"})
gauge_mods = prometheus.gauge("factorio_mods", "mods", {"name", "version"})
gauge_research_queue = prometheus.gauge("factorio_research_queue", "research", {"force", "cur_pos"})

gauge_item_production_input = prometheus.gauge("factorio_item_production_input", "items produced", {"force", "name"})
gauge_item_production_output = prometheus.gauge("factorio_item_production_output", "items consumed", {"force", "name"})
gauge_fluid_production_input = prometheus.gauge("factorio_fluid_production_input", "fluids produced", {"force", "name"})
gauge_fluid_production_output = prometheus.gauge("factorio_fluid_production_output", "fluids consumed", {"force", "name"})
gauge_kill_count_input = prometheus.gauge("factorio_kill_count_input", "kills", {"force", "name"})
gauge_kill_count_output = prometheus.gauge("factorio_kill_count_output", "losses", {"force", "name"})
gauge_entity_build_count_input = prometheus.gauge("factorio_entity_build_count_input", "entities placed", {"force", "name"})
gauge_entity_build_count_output = prometheus.gauge("factorio_entity_build_count_output", "entities removed", {"force", "name"})

gauge_items_launched = prometheus.gauge("factorio_items_launched_total", "items launched in rockets", {"force", "name"})

gauge_logistic_network_items = prometheus.gauge("factorio_logistics_items", "Items in logistics", {"force", "surface", "network_idx", "name"})
gauge_logistic_network_bots = prometheus.gauge("factorio_logistics_bots", "Bots in logistic networks", {"force", "surface", "network_idx", "type"})

gauge_total_trains = prometheus.gauge("factorio_train_total", "total trains", {"force"})
gauge_total_waiting_station_trains = prometheus.gauge("factorio_train_waiting_station", "waiting trains at station", {"force"})
gauge_total_waiting_signal_trains = prometheus.gauge("factorio_train_waiting_signal", "waiting trains at signal", {"force"})
gauge_total_traveling_trains = prometheus.gauge("factorio_train_traveling", "traveling_trains", {"force"})

gauge_train_trip_time = prometheus.gauge("factorio_train_trip_time", "train trip time", {"from", "to", "train_id"})
gauge_train_wait_time = prometheus.gauge("factorio_train_wait_time", "train wait time", {"from", "to", "train_id"})
histogram_train_trip_time = prometheus.histogram("factorio_train_trip_time_groups", "train trip time", {"from", "to", "train_id"}, train_buckets)
histogram_train_wait_time = prometheus.histogram("factorio_train_wait_time_groups", "train wait time", {"from", "to", "train_id"}, train_buckets)

gauge_train_direct_loop_time = prometheus.gauge("factorio_train_direct_loop_time", "train direct loop time", {"a", "b"})
histogram_train_direct_loop_time = prometheus.histogram("factorio_train_direct_loop_time_groups", "train direct loop time", {"a", "b"}, train_buckets)

gauge_train_arrival_time = prometheus.gauge("factorio_train_arrival_time", "train arrival time", {"station"})
histogram_train_arrival_time = prometheus.histogram("factorio_train_arrival_time_groups", "train arrival time", {"station"}, train_buckets)

local train_trips = {}
local arrivals = {}
local watched_train = 0
local watched_station = ""
local function watch_train(event, msg)
  if event.train.id == watched_train then
    game.print(msg)
  end
end

local function watch_station(event, msg)
  if event.train.path_end_stop.backer_name == watched_station then
    game.print(msg)
  end
end

local function create_train(event)
  if event.train.path_end_stop == nil then
    return
  end

  -- {source station, tick it departed there, tick last begun waiting, total ticks spent waiting}
  train_trips[event.train.id] = {event.train.path_end_stop.backer_name, game.tick, 0, 0}
  -- watch_train(event, "begin tracking " .. event.train.id)
end

local function create_station(event)
  if event.train.path_end_stop == nil then
    return
  end

  -- {last arrival tick}
  arrivals[event.train.path_end_stop.backer_name] = {0}
  -- watch_station(event, "created station " .. event.train.path_end_stop.backer_name)
end

local function reset_train(event)
  if event.train.path_end_stop == nil then
    return
  end

  train_trips[event.train.id] = {event.train.path_end_stop.backer_name, game.tick, 0, 0}
end

local seen = {}
local function direct_loop(event, duration, labels)
  local from = labels[1]
  local to = labels[2]
  local train_id = labels[3]

  if seen[train_id] == nil then
    seen[train_id] = {}
  end

  if seen[train_id][from] == nil then
    seen[train_id][from] = {}
  end

  if seen[train_id][from][to] then
    local total = (game.tick - seen[train_id][from][to]) / 60

    local sorted = {from, to}
    table.sort(sorted)

    -- watch_train(event, sorted[1] .. ":" .. sorted[2] .. " total " .. total)

    gauge_train_direct_loop_time:set(total, sorted)
    histogram_train_direct_loop_time:observe(total, sorted)
  end

  if seen[train_id][to] and seen[train_id][to][from] then
  -- watch_train(event, from .. ":" .. to .. " lap " .. (game.tick - seen[train_id][to][from]) / 60)
  end

  seen[train_id][from][to] = game.tick
end

local function track_arrival(event)
  if event.train.path_end_stop == nil then
    return
  end

  local arrival = arrivals[event.train.path_end_stop.backer_name]
  if arrival == nil then
    create_station(event)
  end

  -- watch_station(event, "arrived at " .. event.train.path_end_stop.backer_name)
  arrival = arrivals[event.train.path_end_stop.backer_name]
  if arrival ~= 0 then
    local lag = (game.tick - arrivals[event.train.path_end_stop.backer_name][1]) / 60
    local labels = {event.train.path_end_stop.backer_name}

    gauge_train_arrival_time:set(lag, labels)
    histogram_train_arrival_time:observe(lag, labels)

  -- watch_station(event, "lag was " .. lag)
  end

  arrival[1] = game.tick
end

local function register_events()
  script.on_nth_tick(
    600,
    function(event)
      gauge_tick:set(game.tick)

      if not single_set.seed then
        for _, surface in pairs(game.surfaces) do
          gauge_seed:set(surface.map_gen_settings.seed, {surface = surface.name})
        end
      end

      if not single_set.mods then
        for name, version in pairs(game.active_mods) do
          gauge_mods:set(name, {version = version})
        end
      end

      gauge_players_online:set(table_size(game.connected_players))

      for _, force in pairs(game.forces) do
        local force_name = force.name
        local evolution = {
          {force.evolution_factor, "total"},
          {force.evolution_factor_by_pollution, "by_polution"},
          {force.evolution_factor_by_time, "by_time"},
          {force.evolution_factor_by_killing_spawners, "by_killing_spawners"}
        }
        for _, stat in pairs(evolution) do
          gauge_evolution:set(stat[1], {force = force_name, type = stat[2]})
        end

        for idx, tech in pairs(force.research_queue) do
          gauge_research_queue:set(tech.name, {force = force_name, cur_pos = idx})
        end

        local total = 0
        local moving = 0
        local wait_at_station = 0
        local wait_at_signal = 0

        for _, train in pairs(force.get_trains()) do
          total = total + 1
          if train.state == defines.train_state.wait_station then
            wait_at_station = wait_at_station + 1
          elseif train.state == defines.train_state.wait_signal then
            wait_at_signal = wait_at_signal + 1
          else
            moving = moving + 1
          end
        end

        gauge_total_trains:set(total, {force = force_name})
        gauge_total_waiting_signal_trains:set(wait_at_signal, {force = force_name})
        gauge_total_waiting_station_trains:set(wait_at_station, {force = force_name})
        gauge_total_traveling_trains:set(moving, {force = force_name})

        local stats = {
          {force.item_production_statistics, gauge_item_production_input, gauge_item_production_output},
          {force.fluid_production_statistics, gauge_fluid_production_input, gauge_fluid_production_output},
          {force.kill_count_statistics, gauge_kill_count_input, gauge_kill_count_output},
          {force.entity_build_count_statistics, gauge_entity_build_count_input, gauge_entity_build_count_output}
        }

        for _, stat in pairs(stats) do
          for name, n in pairs(stat[1].input_counts) do
            stat[2]:set(n, {force_name, name})
          end

          for name, n in pairs(stat[1].output_counts) do
            stat[3]:set(n, {force_name, name})
          end
        end

        for name, n in pairs(force.items_launched) do
          gauge_items_launched:set(n, {force_name, name})
        end

        local bot_stats = {
          "available_logistic_robots",
          "all_logistic_robots",
          "available_construction_robots",
          "all_construction_robots"
        }
        for surface, networks in pairs(force.logistic_networks) do
          for idx, network in pairs(networks) do
            for name, n in pairs(network.get_contents()) do
              local v = (n + 2 ^ 31) % 2 ^ 32 - 2 ^ 31
              gauge_logistic_network_items:set(v, {force_name, surface, idx, name})
            end
            for _, src in pairs(bot_stats) do
              gauge_logistic_network_bots:set(network[src], {force_name, surface, idx, src})
            end
            local charging_bots = 0
            local waiting_for_charge = 0
            for _, cell in pairs(network.cells) do
              charging_bots = charging_bots + cell.charging_robot_count
              waiting_for_charge = waiting_for_charge + cell.to_charge_robot_count
            end

            gauge_logistic_network_bots:set(charging_bots, {force_name, surface, idx, "charging_bots"})
            gauge_logistic_network_bots:set(waiting_for_charge, {force_name, surface, idx, "waiting_for_charge"})
          end
        end
      end

      game.write_file("graftorio/game.prom", prometheus.collect(), false)
    end
  )

  script.on_event(
    defines.events.on_train_changed_state,
    function(event)
      local current_train = event.train
      local tick = game.tick

      if current_train.state == defines.train_state.arrive_station then
        track_arrival(event)
      end

      local current_train_trip = train_trips[current_train.id]
      if current_train_trip ~= nil then
        if current_train.state == defines.train_state.arrive_station then
          if current_train.path_end_stop == nil then
            return
          end

          if current_train_trip[1] == current_train.path_end_stop.backer_name then
            return
          end

          local duration = (tick - current_train_trip[2]) / 60
          local wait = current_train_trip[4] / 60

          -- watch_train(event, event.train.id .. ": " .. train_trips[event.train.id][1] .. "->" .. event.train.path_end_stop.backer_name .. " took " .. duration .. "s waited " .. wait .. "s")

          local labels = {current_train_trip[1], current_train.path_end_stop.backer_name, current_train.id}

          gauge_train_trip_time:set(duration, labels)
          gauge_train_wait_time:set(wait, labels)
          histogram_train_trip_time:observe(duration, labels)
          histogram_train_wait_time:observe(wait, labels)
          direct_loop(event, duration, labels)

          reset_train(event)
        elseif event.train.state == defines.train_state.on_the_path and event.old_state == defines.train_state.wait_station then
          -- watch_train(event, event.train.id .. " leaving for " .. event.train.path_end_stop.backer_name)
          -- begin moving after waiting at a station
          current_train_trip[2] = tick
        elseif event.train.state == defines.train_state.wait_signal then
          -- watch_train(event, event.train.id .. " waiting")
          -- waiting at a signal
          current_train_trip[3] = tick
        elseif event.old_state == defines.train_state.wait_signal then
          -- begin moving after waiting at a signal
          current_train_trip[4] = current_train_trip[4] + (tick - current_train_trip[3])
          -- watch_train(event, event.train.id .. " waited for " .. (game.tick - train_trips[event.train.id][3]) / 60)
          current_train_trip[3] = 0
        end
      end

      if train_trips[event.train.id] == nil and event.train.state == defines.train_state.arrive_station then
        create_train(event)
      end
    end
  )
end

script.on_init(
  function()
    register_events()
  end
)

script.on_load(
  function()
    register_events()
  end
)

script.on_configuration_changed(
  function(event)
  end
)
