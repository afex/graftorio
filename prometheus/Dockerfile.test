FROM tarantool/tarantool:1.7

COPY . /opt/tarantool/

WORKDIR /opt/tarantool

RUN set -x \
    && apk add --no-cache --virtual .build-deps \
       git\
    && ./deps.sh \
    && tarantoolctl rocks make rockspecs/prometheus-scm-1.rockspec \
    && : "---------- remove build deps ----------" \
    && apk del .build-deps
