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
    chunks = slices
  }
  -- clear out file
  game.write_file("graftorio/game.prom", "", false)
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
      if d and d.current and d.chunks[d.current] then
        local concat = table.concat
        local insert = table.insert
        local result = {}
        for _, collector in pairs(d.chunks[d.current]) do
          for _, metric in ipairs(collector:collect()) do
            insert(result, metric)
          end
          insert(result, "")
        end
        d.current = d.current + 1
        game.write_file("graftorio/game.prom", concat(result, "\n") .. "\n", true)
      end
      if await_export and event.tick % 30 == 0 and not translate.in_progress() then
        doExport()
        await_export = false
      end
    end
  }
}

return lib
