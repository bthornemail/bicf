# ESP32 ESPNOW Node C (Orchestrator)

Role: **C** = orchestrates a deterministic A/B demo over ESPNOW.

On boot it:
1. Discovers Node A (NRR) + Node B (VERIFY)
2. Appends a fixed CLBC blob to A
3. Replays A’s log (expects count=1)
4. Asks B to verify the same CLBC
5. Prints `DEMO_PASS=1` iff all hashes match

