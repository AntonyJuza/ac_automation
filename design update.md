# AC Automation Mobile App – Design & Feature Roadmap

## Overview

The AC Automation mobile application will serve as the primary interface between users and AC Automation devices.

The app should support:

- User authentication
- Device onboarding
- Device ownership
- Multi-device management
- Device sharing
- Remote AC control
- Automation configuration
- Device monitoring
- Notifications

The design should be scalable enough to support thousands of users and multiple devices per user.

---

# User Journey

## New User

```text
Install App
    ↓
Register Account
    ↓
Login
    ↓
Add Device
    ↓
Scan QR Code
    ↓
BLE Provisioning
    ↓
WiFi Setup
    ↓
MQTT Verification
    ↓
Device Online
```

---

## Existing User

```text
Login
   ↓
Dashboard
   ↓
Select Device
   ↓
Monitor / Control
```

---

# App Navigation Structure

```text
Login
Register
Forgot Password

Dashboard
├── Device Details
├── Device Settings
├── Device Sharing
├── Device History
├── Device Setup
├── Automation Settings
├── Notifications

Profile
├── Account Settings
├── Security
├── Help
└── Logout
```

---

# Screen Designs

---

# 1. Splash Screen

## Purpose

Initial loading screen.

### Content

- Logo
- App Name
- Version

### Actions

- Check login session
- Load user data

### Navigation

```text
Logged In  → Dashboard
Not Logged In → Login
```

---

# 2. Login Screen

## Purpose

User authentication.

### Fields

- Email
- Password

### Buttons

- Login
- Register
- Forgot Password

### Future

- Google Login
- Apple Login

---

# 3. Registration Screen

## Purpose

Create new account.

### Fields

- Full Name
- Email
- Password
- Confirm Password

### Validation

- Email uniqueness
- Password strength

---

# 4. Forgot Password Screen

## Purpose

Password recovery.

### Fields

- Email Address

### Action

Send reset email.

---

# 5. Dashboard Screen

## Purpose

Central device overview.

### Display

For each device:

```text
Device Name
Online Status
AC Status
Temperature
Last Seen
```

Example:

```text
Living Room AC
● Online
AC ON
24°C
```

---

### Actions

- Open Device
- Add Device

---

# 6. Add Device Screen

## Purpose

Add a new controller.

### Options

```text
Scan QR Code
Enter Device Code Manually
```

---

## QR Flow

```text
Scan QR
   ↓
Device Found
   ↓
Connect BLE
   ↓
Configure WiFi
```

---

## Manual Code Flow

```text
Enter Device ID
   ↓
Validate
   ↓
Connect BLE
```

---

# 7. WiFi Provisioning Screen

## Purpose

Send WiFi credentials to ESP32.

### Fields

- SSID
- Password

### Actions

```text
Connect Device
```

---

## Progress

```text
Sending Credentials
Connecting WiFi
Connecting MQTT
Verification
Completed
```

---

# 8. Setup Complete Screen

## Purpose

Confirm successful onboarding.

### Display

```text
Device Connected
MQTT Connected
Ready
```

### Actions

```text
Rename Device
Go To Dashboard
```

---

# 9. Device Details Screen

## Purpose

Main control page.

---

## Device Information

```text
Device Name
Device ID
Firmware Version
Online Status
Last Seen
```

---

## AC Status

```text
Power ON/OFF
Current Temperature
Mode
Fan Speed
```

---

## Presence Status

```text
Presence Detected
No Presence
```

---

## Quick Controls

```text
Power Toggle
Temperature +
Temperature -
```

---

# 10. Remote Control Screen

## Purpose

Manual AC operation.

### Controls

```text
Power
Temperature
Mode
Fan Speed
Swing
```

---

## Example

```text
Power: ON

Temp: 24°C

Mode:
[Cool]
[Dry]
[Fan]

Fan:
[Low]
[Medium]
[High]
```

---

# 11. Automation Screen

## Purpose

Configure automatic behavior.

---

### Settings

```text
Auto ON Delay
Auto OFF Delay
Presence Timeout
```

---

Example:

```text
Turn ON after:
30 seconds

Turn OFF after:
5 minutes
```

---

# 12. Device Settings Screen

## Purpose

Configure device-specific options.

---

### Options

```text
Device Name
Timezone
WiFi Settings
Firmware Update
Factory Reset
```

---

# 13. Device Sharing Screen

## Purpose

Allow multiple users.

---

### User Roles

```text
Owner
Admin
Viewer
```

---

## Features

```text
Add User
Remove User
Change Permissions
```

---

### Example

```text
Owner
└─ Antony

Admin
└─ Family Member

Viewer
└─ Technician
```

---

# 14. Device History Screen

## Purpose

View historical activity.

---

### Events

```text
AC ON
AC OFF
Presence Detected
Manual Override
Device Offline
```

---

### Filters

```text
Today
Week
Month
Custom Range
```

---

# 15. Notifications Screen

## Purpose

System alerts.

---

Examples:

```text
Device Offline

AC Turned OFF

Firmware Update Available

WiFi Reconnected
```

---

# 16. Firmware Update Screen

## Purpose

OTA updates.

---

### Display

```text
Current Version
Latest Version
```

---

### Actions

```text
Update Now
Schedule Update
```

---

# 17. Profile Screen

## Purpose

User account management.

---

### Sections

```text
Name
Email
Phone
Password
```

---

### Actions

```text
Change Password
Logout
Delete Account
```

---

# Backend APIs Required

## Authentication

```http
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout
POST /api/auth/reset-password
```

---

## Devices

```http
GET  /api/devices
GET  /api/devices/:id
POST /api/devices/claim
POST /api/devices/share
DELETE /api/devices/share
```

---

## Device Control

```http
POST /api/devices/:id/power
POST /api/devices/:id/temperature
POST /api/devices/:id/mode
POST /api/devices/:id/fan
```

---

## Device Settings

```http
GET  /api/devices/:id/settings
POST /api/devices/:id/settings
```

---

## Events

```http
GET /api/devices/:id/events
```

---

# MQTT Topics Needed

## Commands

```text
ac/{deviceId}/cmd
```

Examples:

```json
{
  "action": "set_power",
  "value": true
}
```

```json
{
  "action": "set_temperature",
  "value": 24
}
```

---

## Status

```text
ac/{deviceId}/status
```

Example:

```json
{
  "online": true,
  "power": true,
  "temperature": 24
}
```

---

## Heartbeat

```text
ac/{deviceId}/heartbeat
```

Example:

```json
{
  "timestamp": 1780000000
}
```

---

# Recommended Development Order

## Phase 1

Core Platform

- Login
- Register
- Dashboard
- Device Claim
- Device List

---

## Phase 2

Device Setup

- QR Scan
- BLE Provisioning
- MQTT Verification

---

## Phase 3

Remote Control

- Power Control
- Temperature Control
- Status Updates

---

## Phase 4

Automation

- Delay Settings
- Scheduling
- Presence Rules

---

## Phase 5

Advanced Features

- Device Sharing
- Notifications
- OTA Updates
- Analytics
- Energy Reports

---

# Final Goal

A cloud-connected AC automation platform where:

- One user can manage multiple devices
- One device can be shared with multiple users
- Devices are provisioned via BLE only once
- All future communication happens through MQTT and backend APIs
- Users can monitor, configure, and control AC units remotely from anywhere.