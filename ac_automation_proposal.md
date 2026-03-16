# AC Automation Product — Problem, Solution & Development Proposal

**Project:** Smart AC Automation using HLK-LD2410 + ESP32 + IR Transmitter  
**Prepared by:** Developer  
**Date:** March 2026

---

## 1. Project Overview

This project is a smart AC automation device built around the **HLK-LD2410 mmWave presence sensor** and an **ESP32 microcontroller** with an IR transmitter. The device detects human presence and automatically controls an air conditioner — turning it on when someone is in the room and off when the room is empty.

The device is functional and working. The goal now is to turn it into a **scalable product** suitable for demos, sampling, and eventual commercial distribution.

---

## 2. The Problem

### 2.1 Manual IR Pattern Recording

Every AC model uses a different IR (infrared) communication protocol and command pattern. To make the device work with a specific AC, the IR signals for that unit must be recorded and embedded into the firmware.

Currently, this is done **manually**:

1. Developer points the AC remote at an IR receiver
2. Raw pulse patterns are recorded
3. Patterns are added to the firmware source code
4. Firmware is recompiled and flashed to the ESP32

### 2.2 Why This Doesn't Scale

- Every new AC brand or model requires a firmware update
- Most Indian AC brands (Voltas, Blue Star, Lloyd, Carrier, etc.) are **not available** in common IR libraries
- Customers cannot do this themselves — it requires technical knowledge and a laptop
- For a product meant to be installed at customer premises, this is a **critical bottleneck**
- As the product scales to more customers, the manual effort grows linearly

---

## 3. The Solution

### 3.1 Self-Learning Mode (Core Feature)

Add an **IR learning capability** to the device itself. Using an IR receiver component (TSOP1838, ~₹20), the device can listen to and record signals from any AC remote, regardless of brand or model.

The captured IR patterns are stored in the ESP32's **NVS (Non-Volatile Storage)** — persistent flash memory that survives reboots and power cuts.

**This eliminates the need for firmware updates entirely when adding a new AC brand.**

### 3.2 Flutter Mobile App (Control & Setup Interface)

A dedicated mobile app connects to the device via **Bluetooth Low Energy (BLE)**. The app provides:

- Guided IR learning flow — step by step button capture
- AC control panel — send commands from phone
- Profile management — save, load, and manage AC profiles
- Hardware status monitoring — live connection and sensor state

### 3.3 Cloud Profile Database (Future Phase)

Once the app is in use, captured profiles are uploaded to a cloud database. When a new customer sets up the same AC brand and model, they can **skip the learning step entirely** by downloading an existing profile — similar to how Waze crowdsources map data.

---

## 4. Proposed System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                   │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  Setup &    │  │  AC Control  │  │  Profile       │  │
│  │  Learn Flow │  │  Panel       │  │  Manager       │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │ BLE (Bluetooth Low Energy)
┌────────────────────────▼────────────────────────────────┐
│                      ESP32 Device                        │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  BLE GATT   │  │  NVS Profile │  │  HLK-LD2410    │  │
│  │  Server     │  │  Storage     │  │  Presence      │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
│  ┌─────────────┐  ┌──────────────┐                       │
│  │  IR Tx      │  │  IR Rx       │                       │
│  │  (Transmit) │  │  (Learn)     │                       │
│  └─────────────┘  └──────────────┘                       │
└─────────────────────────────────────────────────────────┘
                         │ (Future)
┌────────────────────────▼────────────────────────────────┐
│                    Cloud Server                          │
│         IR Profile Database (Brand / Model)              │
│         Community-contributed profiles                   │
└─────────────────────────────────────────────────────────┘
```

---

## 5. IR Learning Flow (User Experience)

### Step 1 — Initiate Learning
- Customer opens app and taps **"Setup New AC"**
- App asks for brand name, model, and year (for cloud profile matching later)
- App sends **Learn Mode** command to hardware via BLE

### Step 2 — Button Capture (One by One)
App guides customer through each button:

| Step | Instruction |
|------|-------------|
| 1 | "Point your AC remote at the device and press **POWER OFF**" |
| 2 | "Now press **POWER ON**" |
| 3 | "Press **TEMP +**" |
| 4 | "Press **TEMP −**" |
| 5 | "Press **MODE**" |
| 6 | "Press **FAN SPEED**" |
| 7 | "Press **SWING**" *(optional)* |
| 8 | "Press **SLEEP**" *(optional)* |

After each capture:
- App shows **Re-record** option if customer pressed wrong button
- App shows **Skip** for optional buttons
- App shows **Confirm & Next** to proceed

### Step 3 — Profile Review & Save
- App shows complete summary of all captured buttons
- Customer names the profile (e.g., *"Voltas 1.5T Bedroom"*)
- Taps **Save to Device** — profile written to ESP32 NVS
- App optionally uploads profile to cloud for community sharing

---

## 6. Flutter App Structure

```
ac_automation/
├── lib/
│   ├── main.dart                  # Entry point
│   ├── app.dart                   # Theme, routing
│   │
│   ├── models/
│   │   ├── ac_profile.dart        # Profile data model
│   │   └── ir_button.dart         # Individual button/code model
│   │
│   ├── services/
│   │   ├── ble_service.dart       # BLE scan, connect, read, write
│   │   ├── profile_service.dart   # Local save/load (shared_preferences)
│   │   └── cloud_service.dart     # Cloud sync (stub for now)
│   │
│   ├── screens/
│   │   ├── home_screen.dart       # Device list / dashboard
│   │   ├── setup_screen.dart      # First time setup
│   │   ├── learn_screen.dart      # IR learning mode UI
│   │   ├── control_screen.dart    # AC control panel
│   │   └── profile_screen.dart    # Manage saved profiles
│   │
│   ├── widgets/
│   │   ├── ble_device_tile.dart   # BLE scan result card
│   │   ├── ac_button.dart         # Reusable control button
│   │   └── status_indicator.dart  # Connection status widget
│   │
│   └── utils/
│       ├── constants.dart         # BLE UUIDs, app-wide constants
│       └── helpers.dart           # Utility functions
│
└── pubspec.yaml
```

### Key Dependencies

```yaml
dependencies:
  flutter_blue_plus: ^1.31.0     # BLE communication
  provider: ^6.1.2               # State management
  shared_preferences: ^2.3.2     # Local profile storage
  permission_handler: ^11.3.1    # BLE & location permissions
  go_router: ^14.2.0             # Navigation
```

---

## 7. BLE Communication Design

The ESP32 exposes a **GATT server** with one service and three characteristics:

| Characteristic | UUID Suffix | Type | Purpose |
|---|---|---|---|
| Command | `...9001` | Write | Send commands to device (learn mode, IR transmit) |
| Status | `...9002` | Notify | Device status updates (connected, sensor state) |
| IR Data | `...9003` | Notify | Captured IR raw data sent back to app |

### BLE UUID Constants (must match ESP32 firmware)

```dart
const String SERVICE_UUID      = "12345678-1234-1234-1234-123456789abc";
const String CHAR_COMMAND_UUID = "12345678-1234-1234-1234-123456789001";
const String CHAR_STATUS_UUID  = "12345678-1234-1234-1234-123456789002";
const String CHAR_IR_DATA_UUID = "12345678-1234-1234-1234-123456789003";
```

---

## 8. Profile Data Format (JSON)

Profiles are stored as JSON in ESP32 NVS and synced to cloud:

```json
{
  "profile_id": "uuid-xxxx",
  "brand": "Voltas",
  "model": "185V Vectra Elite",
  "year": "2022",
  "created_at": "2026-03-16",
  "buttons": {
    "power_on":    [9000, 4500, 560, 560, 560, 1680],
    "power_off":   [9000, 4500, 560, 560, 560, 1680],
    "temp_up":     [9000, 4500, 560, 1680, 560, 560],
    "temp_down":   [9000, 4500, 560, 560, 1680, 560],
    "mode":        [9000, 4500, 560, 560, 560, 560],
    "fan_speed":   [9000, 4500, 1680, 560, 560, 560],
    "swing":       null,
    "sleep":       null
  }
}
```

---

## 9. Development Phases

### Phase 1 — Demo Ready *(Current Goal)*
- BLE learning mode working on ESP32
- Flutter app: scan, connect, learn flow, local profile save
- AC control panel functional via BLE
- Hardware status visible in app
- **Goal: Working demo units for customer sampling**

### Phase 2 — Early Product
- Cloud profile upload and download
- Brand/model search before learning (skip if profile exists)
- OTA firmware update support
- App published on Google Play Store

### Phase 3 — Scale
- Profile moderation and quality control
- Analytics dashboard (device health, usage patterns)
- Multi-device management from one app
- iOS support

---

## 10. Why This Approach Works for Indian Market

- **No dependency on foreign IR libraries** — self-learning works for any brand
- **Android-first** — covers 95%+ of Indian smartphone users
- **BLE setup** — works without WiFi during installation, important for sites with restricted networks
- **Community profiles** — over time, database covers all Indian brands organically
- **Low hardware cost** — adding IR receiver (TSOP1838) costs ~₹20, removes the biggest product limitation

---

## 11. Next Steps

1. Add TSOP1838 IR receiver to hardware design
2. Update ESP32 firmware with BLE GATT server and NVS storage
3. Build Flutter app Phase 1 (BLE scan + learn flow)
4. Test end-to-end with 2–3 different AC brands
5. Prepare demo units for sampling

---

*This document will be updated as development progresses. Firmware and app code will be version-controlled and shared iteratively.*
