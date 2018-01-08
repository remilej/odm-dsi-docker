# How to use JProfiler9 to profile a DSI Runtime container

## Offline profiling

In order to create a Docker container with a DSI runtime which is periodically
generating JProfiler snapshots, you just have to define the environment variable
DSI_JPROFILER:

```
docker run -e DSI_JPROFILER=true dsi-runtime
```

## Live profiling of a running DSI runtime

Run a DSI Runtime container using the OpenJDK and bind the port 8849 to the docker host:

```bash
docker run -p9080:9080 -p9443:9443 -p8849 -ti --name my-dsi-runtime dsi-runtime-openjdk
```

Installation of the JProfiler agent:

```bash
./install_jp9.sh my-dsi-runtime
```

It will download the agent, install it and run it on the default profiling port 8849.

Finally, open JProfiler and attach a profiling session to localhost:8849.
