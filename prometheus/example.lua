#!/usr/bin/env tarantool
-- luacheck: globals box

local http = require('http.server')
local prometheus = require('prometheus')
local fiber = require('fiber')

box.cfg{}
prometheus.init()

local httpd = http.new('0.0.0.0', 8080)

local space = box.schema.space.create("test_space")
space:create_index('primary', {type = 'hash', parts = {1, 'NUM'}})

local function random_write()
    local num = math.random(10000)

    box.space.test_space:truncate()
    for i=0,num do
        box.space.test_space:insert({i, tostring(i)})
    end
end

local function worker()
    local exec_count = prometheus.counter("tarantool_worker_execution_count",
                                          "Number of times worker process has been executed")
    local exec_time = prometheus.histogram("tarantool_worker_execution_time",
                                           "Time of each worker process execution")
    local arena_used = prometheus.gauge("tarantool_arena_used",
                                  "The amount of arena used by Tarantool")


    while true do
        local time_start = fiber.time()
        random_write()
        local time_end = fiber.time()

        exec_time:observe(time_end - time_start)
        exec_count:inc()
        arena_used:set(box.slab.info().arena_used)

        fiber.sleep(1)
    end

end



httpd:route( { path = '/metrics' }, prometheus.collect_http)

httpd:start()
fiber.create(worker)
