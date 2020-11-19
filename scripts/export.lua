local translate = require("scripts/translation")
local await_export = false

global.export_data = {}

local function table_chunk(tbl, size)
  local chunks = {[1] = {}}
  local i = 1
  local j = 0
  for k, v in pairs(tbl) do
    if j == size then
      i = i + 1
      j = 0
      chunks[i] = {}
    end
    j = j + 1
    chunks[i][k] = v
  end
  return chunks
end

local function doExport()
  local reg = prometheus.get_registry()
  local chunkSize = math.ceil(table_size(reg.collectors) / 10)
  for _, registered_callback in ipairs(reg.callbacks) do
    registered_callback()
  end

  local slices = table_chunk(reg.collectors, chunkSize)
  global.export_data = {
    current = 1,
    chunks = slices,
    save_mode = settings.global["graftorio-server-save"].value or false
  }

  -- clear out file
  if global.export_data.save_mode then
    game.write_file("graftorio/game.prom", "", false, 0)
  else
    game.write_file("graftorio/game.prom", "", false)
  end
end

local lib = {
  ["on_nth_tick"] = {
    [600] = function(event)
      if translate.in_progress() then
        await_export = true
      else
        doExport()
        await_export = false
      end
    end
  },
  events = {
    [defines.events.on_tick] = function(event)
      local d = global.export_data
      if d and d.current and d.chunks[d.current] and event.tick % 4 == 0 and not translate.in_progress() then
        local insert = table.insert
        local result = {}
        for _, collector in pairs(d.chunks[d.current]) do
          if collector.collect then
            for _, metric in pairs(collector:collect()) do
              insert(result, metric)
            end
            insert(result, "")
          end
        end
        d.current = d.current + 1
        if table_size(result) > 0 then
          if d.save_mode then
            game.write_file("graftorio/game.prom", table.concat(result, "\n") .. "\n", true, 0)
          else
            game.write_file("graftorio/game.prom", table.concat(result, "\n") .. "\n", true)
          end
        end
      end
      if await_export and event.tick % 30 == 0 and not translate.in_progress() then
        doExport()
        await_export = false
      end
    end
  }
}

return lib
