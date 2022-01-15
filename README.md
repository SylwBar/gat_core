# OGNCore

Project related to Open Glider Network (OGN).
The main idea is to add more functionalities to OGN packet routing system which is currently based on APRS protocol.

Project goals:
- replace APRS with more compact format, better suited for aviation,
- add features that are hard to achieve using APRS based servers: packet delays, emergency services,
- allow interoperability between APRS and OGN Core systems.

## Configurations

The project uses Elixir's Config module to configure project depending on situation. There are three configurations defined:
* dev - default configuration, used for development,
* test - configuration used during testing (mix test),
* prod - configuration that should be selected for building project for target host.

Selecting configuration is done using MIX_ENV shell variable, dev is selected by default.

## Compiling for development and tests

First, dependencies should be downloaded:
```
  $ mix deps.get
```

then:
* to start OGN Core with interactive Elixir shell (IEx) attached:
```
$ iex -S mix
```
* to start OGN Core without shell:
```
  $ mix run --no-halt
```
2x Ctrl-C quits program.

## Compiling for target release

Prod configuration should be selected

```
MIX_ENV=prod mix release
```
Mix will analize project's dependencies and create customized Erlang+Elixir+OGN Core release in:
 _build/prod/rel/ogn_core/bin/ogn_core

Prepared ogn_core script is suitable to be executed in systemd scripts

```
Usage: ogn_core COMMAND [ARGS]

The known commands are:

    start          Starts the system
    start_iex      Starts the system with IEx attached
    daemon         Starts the system as a daemon
    daemon_iex     Starts the system as a daemon with IEx attached
    eval "EXPR"    Executes the given expression on a new, non-booted system
    rpc "EXPR"     Executes the given expression remotely on the running system
    remote         Connects to the running system via a remote shell
    restart        Restarts the running system via a remote command
    stop           Stops the running system via a remote command
    pid            Prints the operating system PID of the running system via a remote command
    version        Prints the release name and version to be booted
```
## Testing

Basic tests suite is executed using mix:

```
  $ mix test
```

## OGNCore configuration
Configuration files are read from "config" directory.
Different files are selected for different mix configurations.

Example configuration file (TOML format) (split into parts):

### OGNCore server general settings

```
[Core]
server_name = "Core1"
server_port = 8701
server_max_conn = 500
```

- server_name: server identifier used in OGNCore network,
- server_port: TCP port used by OGNCore server,
- server_max_conn: maximum number of TCP connections (must be less than open files limit: "ulimit -n")

### OGN APRS server connection settings
```
[APRS]
server_addr = "aprs.glidernet.org"
server_port = 14580
client_id = 999
```

- server_addr: APRS server used by OGNCore server,
- server_port: TCP port of APRS server,
- client_id: numeric suffix of APRS login, full login will be CORE-999. 

### MQTT broker connection settings

```
[MQTT]
enabled = false
server_addr = "localhost"
server_port = 1883
user_name = "core"
password = "corepassword"
```

- enabled: MQTT connection switch,
- server_addr: MQTT broker address,
- server_port: MQTT broker port,
- user_name: MQTT broker user name used by OGNCore server,
- password: MQTT broker user password, for security reasons it should be customized

Note: MQTT protocol defines ClientID parameter which purpose is different than "user_name". OGNCore server will set ClientID to Core/server_name setting (e.g. Core1)

## OGNCore features
OGNCore is designed to be feature compatible with APRSC, but its internal architecture allows new functionalities to be added.

### Timeout events
OGNCore remembers time of last received packet for each tracked entity. Special type of message (event) is sent after predefined time of inactivity.
Currently timeout is set to 30 minutes for stations and objects. It could be changed manually by configuring module parameter:

```
 @inactive_event_time_msec 30 * 60_000
```

in ogn_object.ex and station.ex

Event format is defined in docs/OGNCore_message_format.pdf, they published on "events" MQTT topic.

