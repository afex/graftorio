package = 'prometheus'
version = '1.0.0-1'
source  = {
    url    = 'git://github.com/tarantool/prometheus.git',
    tag = '1.0.0',
}
description = {
    summary  = 'Prometheus library to collect metrics from Tarantool',
    homepage = 'https://github.com/tarantool/prometheus.git',
    license  = 'BSD',
}
dependencies = {
    'lua >= 5.1';
}
build = {
    type = 'builtin',

    modules = {
        ['prometheus.tarantool-metrics'] = 'tarantool-metrics.lua',
        ['prometheus'] = 'prometheus.lua'
    }
}
