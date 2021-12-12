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
