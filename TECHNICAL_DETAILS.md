# Technical Documentation — AC Automation

## 1. Firmware Logic (ESP32)

### Presence State Machine
The firmware polls the LD2410 sensor every 1 second.
- **Moving State**: High sensitivity detection of movement.
- **Static State**: Detection of stationary humans based on micro-movements.

**State Transitions:**
- `Presence Detected` (Moving or Static) → Start `presenceStartTime`.
- `Continuous Presence > ON_TIME` → Execute `turnACOn()`.
- `Presence Lost` (None) → Start `absenceStartTime`.
- `Continuous Absence > OFF_TIME` → Execute `turnACOff()`.

### IR Signal Handling
The system supports two methods of IR transmission:
1. **Encoded (Preferred)**: Uses `PulseDistanceWidth` protocol. Provides high reliability and jitter-free transmission.
2. **Raw (Fallback)**: Stores raw millisecond timings. Used when the protocol cannot be automatically identified.

### NVS (Non-Volatile Storage)
Data is organized into namespaces in the ESP32 Flash:
- `ac_profiles`: Stores binary blobs of `ACProfile` structs.
- `dyn_config`: Stores brand-specific dynamic IR configurations.
- `ac_timing`: Stores automation millisecond values.
- `wifi_cfg`: Stores SSID and Password.

## 2. BLE Command Reference

| Command | Format | Description |
|---------|--------|-------------|
| `AC_ON` | `AC_ON` | Manually triggers the ON signal. |
| `AC_OFF` | `AC_OFF` | Manually triggers the OFF signal. |
| `LEARN_START` | `LEARN_START` | Puts ESP32 in IR capture mode. |
| `SET_TIMING` | `SET_TIMING:onMs:offMs` | Sets automation durations. |
| `SET_WIFI` | `SET_WIFI:ssid:pass` | Updates device Wi-Fi credentials. |
| `LIST_PROFILES`| `LIST_PROFILES` | Requests a list of stored profiles. |
| `STATUS` | `STATUS` | Forces an immediate status notification. |

## 3. Backend Integration

The backend serves as a proxy to MongoDB Atlas. It simulates the Supabase REST API structure to minimize firmware changes:

**Endpoint**: `POST /rest/v1/sensor_logs`
**Payload**:
```json
{
  "event": "AC_ON",
  "deviceId": "ESP_AABBCCDDEEFF"
}
```

## 4. Hardware Pinout

| Component | Pin | Note |
|-----------|-----|------|
| IR LED    | 15  | Requires transistor (2N2222) if high power. |
| IR RX     | 13  | 38kHz TSOP receiver. |
| LD2410 TX | 16  | Connected to ESP32 RX2. |
| LD2410 RX | 17  | Connected to ESP32 TX2. |
