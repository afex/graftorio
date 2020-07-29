package = 'prometheus'
version = 'scm-1'
source  = {
    url    = 'git://github.com/tarantool/prometheus.git',
    branch = 'master',
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
