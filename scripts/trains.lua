local function split(inputstr, sep)
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local train_buckets = {}
local bucket_settings = split(settings.startup["graftorio-train-histogram-buckets"].value, ",")
for _, bucket in pairs(bucket_settings) do
  table.insert(train_buckets, tonumber(bucket))
end

gauges.total_trains = prometheus.gauge("factorio_train_total", "total trains", {"force"})
gauges.total_waiting_station_trains = prometheus.gauge("factorio_train_waiting_station", "waiting trains at station", {"force"})
gauges.total_waiting_signal_trains = prometheus.gauge("factorio_train_waiting_signal", "waiting trains at signal", {"force"})
gauges.total_traveling_trains = prometheus.gauge("factorio_train_traveling", "traveling_trains", {"force"})

gauges.train_trip_time = prometheus.gauge("factorio_train_trip_time", "train trip time", {"from", "to", "train_id"})
gauges.train_wait_time = prometheus.gauge("factorio_train_wait_time", "train wait time", {"from", "to", "train_id"})
histograms.train_trip_time = prometheus.histogram("factorio_train_trip_time_groups", "train trip time", {"from", "to", "train_id"}, train_buckets)
histograms.train_wait_time = prometheus.histogram("factorio_train_wait_time_groups", "train wait time", {"from", "to", "train_id"}, train_buckets)

gauges.train_direct_loop_time = prometheus.gauge("factorio_train_direct_loop_time", "train direct loop time", {"a", "b"})
histograms.train_direct_loop_time = prometheus.histogram("factorio_train_direct_loop_time_groups", "train direct loop time", {"a", "b"}, train_buckets)

gauges.train_arrival_time = prometheus.gauge("factorio_train_arrival_time", "train arrival time", {"station"})
histograms.train_arrival_time = prometheus.histogram("factorio_train_arrival_time_groups", "train arrival time", {"station"}, train_buckets)

local train_trips = {}
local arrivals = {}

local function create_train(event)
  if event.train.path_end_stop == nil then
    return
  end

  -- {source station, tick it departed there, tick last begun waiting, total ticks spent waiting}
  train_trips[event.train.id] = {event.train.path_end_stop.backer_name, event.tick, 0, 0}
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

  train_trips[event.train.id] = {event.train.path_end_stop.backer_name, event.tick, 0, 0}
end

local seen = {}
local function direct_loop(event, duration, labels)
  local from = labels[1]
  local to = labels[2]
  local train_id = labels[3]
  local seen = seen

  if seen[train_id] == nil then
    seen[train_id] = {}
  end

  if seen[train_id][from] == nil then
    seen[train_id][from] = {}
  end

  if seen[train_id][from][to] then
    local total = (event.tick - seen[train_id][from][to]) / 60

    local sorted = {from, to}
    table.sort(sorted)

    -- watch_train(event, sorted[1] .. ":" .. sorted[2] .. " total " .. total)

    gauges.train_direct_loop_time:set(total, sorted)
    histograms.train_direct_loop_time:observe(total, sorted)
  end

  if seen[train_id][to] and seen[train_id][to][from] then
  -- watch_train(event, from .. ":" .. to .. " lap " .. (game.tick - seen[train_id][to][from]) / 60)
  end

  seen[train_id][from][to] = event.tick
end

local function track_arrival(event)
  if event.train.path_end_stop == nil then
    return
  end

  local arrivals = arrivals
  local arrival = arrivals[event.train.path_end_stop.backer_name]
  if arrival == nil then
    create_station(event)
    arrival = arrivals[event.train.path_end_stop.backer_name]
  end

  -- watch_station(event, "arrived at " .. event.train.path_end_stop.backer_name)
  if arrival ~= 0 then
    local lag = (event.tick - arrivals[event.train.path_end_stop.backer_name][1]) / 60
    local labels = {event.train.path_end_stop.backer_name}

    gauges.train_arrival_time:set(lag, labels)
    histograms.train_arrival_time:observe(lag, labels)

  -- watch_station(event, "lag was " .. lag)
  end

  arrival[1] = event.tick
end

local lib = {
  events = {
    [defines.events.on_tick] = function(event)
      if event.tick % 600 == 120 then
        local total = 0
        local moving = 0
        local wait_at_station = 0
        local wait_at_signal = 0

        for force_name, force in pairs(game.forces) do
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

          gauges.total_trains:set(total, {force_name})
          gauges.total_waiting_signal_trains:set(wait_at_signal, {force_name})
          gauges.total_waiting_station_trains:set(wait_at_station, {force_name})
          gauges.total_traveling_trains:set(moving, {force_name})
        end
      end
    end,
    [defines.events.on_train_changed_state] = function(event)
      -- disable for slightly better performance
      if true then
        return
      end
      local current_train = event.train
      local tick = event.tick
      local gauges = gauges
      local histograms = histograms

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

          gauges.train_trip_time:set(duration, labels)
          gauges.train_wait_time:set(wait, labels)
          histograms.train_trip_time:observe(duration, labels)
          histograms.train_wait_time:observe(wait, labels)
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
  }
}

return lib
