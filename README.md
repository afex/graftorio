# graftorio

visualize metrics from your factorio game in grafana

![](https://mods-data.factorio.com/assets/89653f5de75cdb227b5140805d632faf41459eee.png)

## What is this?

[grafana](https://grafana.com/) is an open-source project for rendering time-series metrics. by using graftorio, you can create a dashboard with various charts monitoring aspects of your factorio factory. this dashboard is viewed using a web browser outside of the game client. (works great in a 2nd monitor!)

in order to use graftorio, you need to run the grafana software and a database called [prometheus](https://prometheus.io/) locally. graftorio automates this process using docker, or you can set these up by hand.

This can be used for factorio running on a server or a local instance. Since it will always export it to `{factorio-path}/script-output/graftorio/game.prom`

## Installation

1. download the latest [release](https://github.com/afex/graftorio/releases), and extract it into the location you want to host the local database
2. [install docker](https://docs.docker.com/install/)
   - if using windows, you will need to be running Windows 10 Pro
3. if using macOS or Linux, open the extracted `docker-compose.yml` in a text editor and uncomment the correct path to your factorio install
   - Update the rights in the data dir (since the containers need those rights):
   - `chown -R 472 data/grafana`
   - `chown -R 65534 data/promotheus`
   - `chown -R 65534 data/promotheus.yml`
4. using a terminal, run `docker-compose up` inside the extracted directory
5. load `localhost:3000` in a browser, you should see the grafana login screen
6. login with admin:admin and create a prometheus data source using the exact string `http://prometheus:9090` as its address, and `10s` as the scrape interval. (don't forget the 's')
7. launch factorio
8. install the "graftorio" mod via the mods menu -- (Currently this version is not on the dashboard, so a manual install is required)
9. load up your game, and see your statistics in the grafana dashboard
   - [beginner instructions for building dashboards](https://youtu.be/sKNZMtoSHN4)


## Grafana

We have included some dashboards copied from [stats.nilaus.tv](https://stats.nilaus.tv) in the dashboards directory.
Keep in mind that when the server is paused grafana doesn't get any info. If you have an always on server this should reflect nicely what is happening in the base.

## Hosting
Whenever you want to publish your dashboard to the public you can do this by placing this upon a server and opening up the ports for your game.
Preferable all runs on the same server, but separating the game and the grafana dahsboard is possible.
In the following example we'll explain on how to set it up all on 1 server.

### Part 1 Website
When ever you are hosting this on a server it's prefered to run this as the docker instance.
We placed an nginx proxy pass in front of it to forward the http requests to the grafana server.

```
server {
	listen 80;
	listen [::]:80;
	server_name domain.name;
	return 301 https://domain.name$request_uri;
}

server {
	location / {
		proxy_pass http://127.0.0.1:3000/;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	}

    ssl on;
    listen [::]:443 ssl;
    listen 443 ssl;
    # Here we used a letsencrypt cert (stripped out the actual files)
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}
```

### Part 2 The settings

Change in env.grafana the domain name and the organisation name you're going to use for the public.
This way certain dashboards can be made visible to the public.

```
GF_SERVER_DOMAIN=domain.name
GF_AUTH_ANONYMOUS_ORG_NAME=MyOrganisationForPublicView
```

### Part 3 The exporter
The exporter needs to have access to your game.prom file, so change the path in the `docker-compose.yml` to where `script-output/graftorio` is found

**Separate servers**

Whenever you want to run the game on a different server you would have to change a few things.

1. The exporter needs to run on the same server/computer as your factorio server/instance.
2. The factorio server/instance doesn't need the prometheus and grafana dockers. So remove those 2 entries from the `docker-compose.yml`
3. The exporter needs to be accesible from the web, so that the prometheus db can access it to load in the required data. More information for the exporter is found here https://github.com/prometheus/node_exporter
4. Change over the `data/prometheus.yml` to let the targets point to your exporters ip:port

However when you want to separate this all, keep in mind that most of the default settings in this readme/repo are not correct. So these have to be changed to your needs.

### Finally

Open your http://domain.name and see the login for grafana.
Keep in mind that this short guide doesn't explain on how to properly secure everything. This is up to you to fix yourself.

## Debugging

### mod

To see if factorio is generating stats, confirm a `game.prom` file exists at the configured exporter volume directory.  when opened, it should look something like this:

```
# HELP factorio_item_production_input items produced
# TYPE factorio_item_production_input gauge
factorio_item_production_input{force="player",name="burner-mining-drill"} 3
factorio_item_production_input{force="player",name="iron-chest"} 1
```

### prometheus

To see if prometheus is scraping the data, load `localhost:9090/targets` in a browser and confirm that the status is "UP"

### grafana

To see if the grafana data source can read correctly, start a new dashboard and add a graph with the query `factorio_item_production_input`. the graph should render the total of every item produced in your game.

## Plugin

To add stats from your own mod into graftorio you can use the following example:

**info.json**
add graftorio as a prerequisite
```
  "dependencies": [
    "graftorio >= 1.0.12"
  ],
```

**control.lua**

```
-- Example plugin
local remote_events = {}
local prometheus
local gauges = {}
local load_event = function(event)
  if remote.interfaces["graftorio"] then
    remote_events = remote.call("graftorio", "get_plugin_events")
    register_event()
  end
end
script.on_init(load_event)
script.on_load(load_event)

function register_event()
   script.on_event(remote_events.graftorio_add_stats, function(event)
      -- Reset the gauge every time its calculated (helpfull for changing mod names or like the research queue)
      remote.call('graftorio', 'make_gauge', 'gauge_name', {"extra_label", "item"})

      -- Do your data collection here and number must be a float/int
      -- Can call the set multiple times (e.g. per item)

      remote.call('graftorio', 'gauge_set', 'gauge_name', number, {"extra_label_value", "item_name"})
   end)
end
```