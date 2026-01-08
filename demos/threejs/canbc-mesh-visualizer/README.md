# CANBC Mesh Visualizer (Three.js)

Live (or replay) visualization of `bicf/*` MQTT traffic for the CANBC demo.

## Run (live)

1) Start a broker (example):

```bash
cat >/tmp/mosquitto-demo.conf <<'EOF'
listener 1883 0.0.0.0
allow_anonymous true
EOF
mosquitto -c /tmp/mosquitto-demo.conf -v
```

2) Start the bridge (writes `events.jsonl` and serves the UI):

```bash
python3 demos/threejs/canbc-mesh-visualizer/bridge_mqtt.py \
  --broker 127.0.0.1 \
  --out /tmp/canbc-events.jsonl
```

3) Open the UI:

- http://127.0.0.1:8766/

4) Run the demo (in another terminal):

```bash
scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto
```

## Replay

```bash
python3 demos/threejs/canbc-mesh-visualizer/bridge_mqtt.py \
  --broker 127.0.0.1 \
  --replay /tmp/canbc-events.jsonl
```

