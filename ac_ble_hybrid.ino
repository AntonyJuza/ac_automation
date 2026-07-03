/*
 * ============================================================
 *  Smart AC Controller — BLE Edition
 *  Board   : ESP32 Dev Module
 *  Sensor  : HLK-LD2410
 *  IR TX   : GPIO 15  (IR LED)
 *  IR RX   : GPIO 13  (TSOP1838 — for learning)
 *  LD2410  : UART2  RX=16, TX=17
 *
 *  BLE GATT Service
 *  ├─ Command char   (WRITE)   — receive commands from app
 *  ├─ Status char    (NOTIFY)  — send status/events to app
 *  └─ IR Data char   (NOTIFY)  — send captured raw IR to app
 *
 *  NVS storage — profiles survive power cuts
 *  Up to MAX_PROFILES stored, each with up to MAX_BUTTONS buttons
 * ============================================================
 */

#include <Arduino.h>


#include <IRremoteESP8266.h>
#include <IRsend.h>
#include <IRrecv.h>
#include <IRutils.h>
#include <NimBLEDevice.h>
#include <Preferences.h>
#include <ArduinoJson.h>       // ArduinoJson v6 — install via Library Manager
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>      // PubSubClient by Nick O'Leary — install via Library Manager


#include "time.h"


// ============================================================
//  WIFI CONFIG
// ============================================================
String wifiSsid     = "";
String wifiPassword = "";

// ============================================================
//  MQTT CONFIG
// ============================================================
const char* MQTT_BROKER   = "iot.techenablesme.com";
const int   MQTT_PORT     = 8883;
const char* MQTT_USER     = "AC_04B247839580";
const char* MQTT_PASSWORD = "y£iNm7CV1Xr.37-w)@H6~~Bcy";

// Self-signed CA certificate for iot.techenablesme.com
// >>> PASTE YOUR ca.crt PEM CONTENT HERE <<<
// To get it: on the server run:  cat /home/welboundappsadmin/mqtt-ca/ca.crt
// Then paste the full PEM block between the R"EOF( and )EOF" markers.
const char* mqtt_ca_cert = R"EOF(
-----BEGIN CERTIFICATE-----
MIIF/zCCA+egAwIBAgIUJYVmH2egehxd4f/56mACUOu2/xUwDQYJKoZIhvcNAQEL
BQAwgY4xCzAJBgNVBAYTAklOMQ8wDQYDVQQIDAZLZXJhbGExDjAMBgNVBAcMBUtv
Y2hpMRQwEgYDVQQKDAtUZXJhb2JqZWN0czERMA8GA1UECwwIcm9ib3RpY3MxEDAO
BgNVBAMMB0FDSW90Q0ExIzAhBgkqhkiG9w0BCQEWFGFudG9ueWp1emFAZ21haWwu
Y29tMB4XDTI2MDYwMzE0NDIzMFoXDTM2MDUzMTE0NDIzMFowgY4xCzAJBgNVBAYT
AklOMQ8wDQYDVQQIDAZLZXJhbGExDjAMBgNVBAcMBUtvY2hpMRQwEgYDVQQKDAtU
ZXJhb2JqZWN0czERMA8GA1UECwwIcm9ib3RpY3MxEDAOBgNVBAMMB0FDSW90Q0Ex
IzAhBgkqhkiG9w0BCQEWFGFudG9ueWp1emFAZ21haWwuY29tMIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEA7BaX4lXzzQ7130XwXMPt26rPDZtkyDD3H3cJ
gQVOVEKol8VfmKnhhe0vnkcJ5Dxksi5WymXcsyF8eNr/12QQAyruiyWBOFefDvAA
7p1YNmNRXJAdH1EOzokAaFEU0BPX9jDCE/WIIsx81WRG0M1L2rcbBogv27Mkm+Kf
1k9R6V6eeqRLQDIMAQVSUF7+Gi2NhAV7FqdjiViZ9jX5W2cNa/yULgVIMVe2N/+r
IGZqRTKW32DuFRn9vbnqFS41Rc9SGprmaehoJ/+2zJuNDKrDmKKF3vuan5qPUixB
Tuv4WYvh2wtOL6i+FeQ+7MltAAyufiTOkJNyI5RGezGTZKbHUYcwveXtNiuBIfyU
XN1T+PtCD7K+2SXD+J4ZR++aDNceGcDG/sSYzHBJgF2jdCdz0aqMgN7Onhl1wdZF
cIpG4vdltNHM9CV7HUeQxISaW0NsCgHmYgZ4OiDA6rxq3wuftr4/tbb8LvVh+bSL
s7CMPxA0a9RSBsVbQXZxsfQHj2387BNIpNyUhXDtKWtaWfQ9YNXXShNwx1CB+q60
FMJ+pLUffYBFeP6h+Buzz4uU07KA1V66E7cmJt3PTYtEaso43jZZx7DN0hQbCa1P
EGJVTvtJSMj/xtQzmuAirVxUxjbu2UZtnAyZsMDoNsuvyIgSHfv7qJ6XmqrxYW/J
aaDPay0CAwEAAaNTMFEwHQYDVR0OBBYEFGbn4wnPwQJYGKC3QbVjhL0A15MNMB8G
A1UdIwQYMBaAFGbn4wnPwQJYGKC3QbVjhL0A15MNMA8GA1UdEwEB/wQFMAMBAf8w
DQYJKoZIhvcNAQELBQADggIBAGE7A6tqwdnmakQGxtfuec1rSOElZAe7yy2FmBQJ
+uDp6uIXFafJRuoW816ynpQAdu/dfOZ7urkVUi/nNoM1LvHPR1hbF93KqafamIBN
fEwC3PuDkHEMECBSzaDpZDfBBVS4PrR2A/+TWngpZ3rUXliVfFP6aO6Yh3rHqks2
hTyw1XM/uQjnLSyo5QmCs02qXaqWqF4A1y+EE4LvRQVTUkeSJRI7mxukDhYZbo+0
Zzl6eBX7A3yIY5RcEHRqZ4KDCaynoLwm6i7kB30Ly91sBf2NtGkgljDOv+rBzvkf
pWGkv2n0Y9TMhig9C2mfhi1ACXYNX093/ZDS+i/HXMhf/C7jP3532bglTIjM9W41
kmJPZS33K5itIk9OKfW03EvFJAdIdX/gZPrJAANS6LN33bHxInIWaXWi1lAIQqQv
Fo9YvODW6hrSKc2ROXknW80CwbuupUQlfavlDLk0Hmf1hjS2Eis2fXg2qxU6LZ3o
sX3536Pn2pn2TFLMTff7dUdJnkRSNt8JybDxe6QKFZBHZcBHosimkuRpUtw31Vxt
0vT5B41y9O0NE0nSAPES/Wxm66KoDwrzNeHnR0kCi+fkLNrlCeCvxQNrw4xIUdp4
HAuecWKJCyrpcx3OzN/wwybIKrAvcSrCpkJ8SvXrTM5RENYp9B1aGrPSlOyqT7E4
d4df
-----END CERTIFICATE-----
)EOF";

WiFiClientSecure espSecureClient;
PubSubClient     mqttClient(espSecureClient);

unsigned long lastMqttHeartbeat = 0;
#define MQTT_HEARTBEAT_INTERVAL 30000UL  // 30 seconds
unsigned long lastMqttReconnectAttempt = 0;
#define MQTT_RECONNECT_INTERVAL 5000UL   // retry every 5s




long  gmtOffset_sec = 19800;   // India = UTC+5:30 = 19800 seconds (change if different timezone)
int   daylightOffset_sec = 0;

// ============================================================
//  PIN DEFINITIONS
// ============================================================
#define IR_SEND_PIN       15
#define IR_RECEIVE_PIN    13
#define LD2410_RX_PIN     16
#define LD2410_TX_PIN     17

// ============================================================
//  TIMING (ms)
// ============================================================
#define DEFAULT_PRESENCE_ON_TIME   60000UL   // 1 min before AC turns ON
#define DEFAULT_PRESENCE_OFF_TIME 300000UL   // 5 min before AC turns OFF
#define SENSOR_CHECK_INTERVAL    1000UL   // how often we poll LD2410
#define STATUS_NOTIFY_INTERVAL   2000UL   // how often we push status to app

// ============================================================
//  BLE UUIDs  — must match Flutter constants.dart exactly
// ============================================================
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHAR_COMMAND_UUID   "12345678-1234-1234-1234-123456789001"
#define CHAR_STATUS_UUID    "12345678-1234-1234-1234-123456789002"
#define CHAR_IR_DATA_UUID   "12345678-1234-1234-1234-123456789003"

// ============================================================
//  IR PARAMETERS
// ============================================================
#define MAX_RAW_LEN    600    // bumped to 600 for Daikin, etc.
#define BLE_CHUNK_SIZE  400   // safe BLE notify payload size (MTU 512 - headers)
#define PROTOCOL_IS_LSB_FIRST 0 // 0 = LSB first, 1 = MSB first for IRremote flags
#define PROTOCOL_IS_MSB_FIRST 1
#define SUPPRESS_STOP_BIT    2

IRsend irsend(IR_SEND_PIN);
IRrecv irrecv(IR_RECEIVE_PIN);
decode_results results;

// ============================================================
//  GLOBALS
// ============================================================
uint64_t dynamicAcOnData[4];
uint64_t dynamicAcOffData[4];
uint16_t dynamicIrFreqKhz = 38;
uint16_t dynamicHdrMark = 0, dynamicHdrSpace = 0;
uint16_t dynamicBitMark = 0, dynamicOneSpace = 0, dynamicZeroSpace = 0, dynamicStopMark = 0;
uint16_t dynamicBitLength = 0;
uint8_t  dynamicSendRepeat = 3;
bool     hasDynamicConfig = false;
String   dynamicConfigName = "";

// --- Raw Hybrid Config ---
#define MAX_RAW_PATTERN_LEN 600
uint16_t* rawAcOnPattern = nullptr;
uint16_t* rawAcOffPattern = nullptr;
uint16_t  rawAcOnLen = 0;
uint16_t  rawAcOffLen = 0;
bool      useRawMode = false;

// Variables used for chunked loading of raw patterns
uint16_t* tempRawUploadBuf = nullptr;
uint16_t tempRawUploadLen = 0;

// Helper functions for sending encoded signals with IRremoteESP8266
void sendPulseDistanceWidthData(uint16_t aOneMarkMicros, uint16_t aOneSpaceMicros, uint16_t aZeroMarkMicros,
        uint16_t aZeroSpaceMicros, uint64_t aData, uint_fast8_t aNumberOfBits, uint8_t aFlags) {
    uint64_t tMask = 1ULL << (aNumberOfBits - 1);
    for (uint_fast8_t i = aNumberOfBits; i > 0; i--) {
        if (((aFlags & PROTOCOL_IS_MSB_FIRST) && (aData & tMask)) || (!(aFlags & PROTOCOL_IS_MSB_FIRST) && (aData & 1))) {
            irsend.mark(aOneMarkMicros);
            irsend.space(aOneSpaceMicros);
        } else {
            irsend.mark(aZeroMarkMicros);
            irsend.space(aZeroSpaceMicros);
        }
        if (aFlags & PROTOCOL_IS_MSB_FIRST) {
            tMask >>= 1;
        } else {
            aData >>= 1;
        }
    }
    if (!(aFlags & SUPPRESS_STOP_BIT)) {
        irsend.mark(aOneMarkMicros);
    }
}

void sendPulseDistanceWidthFromArray(uint_fast8_t aFrequencyKHz, uint16_t aHeaderMarkMicros, uint16_t aHeaderSpaceMicros,
        uint16_t aOneMarkMicros, uint16_t aOneSpaceMicros, uint16_t aZeroMarkMicros, uint16_t aZeroSpaceMicros,
        uint64_t *aDecodedRawDataArray, uint16_t aNumberOfBits, uint8_t aFlags, uint16_t aRepeatPeriodMillis,
        int_fast8_t aNumberOfRepeats) {

    irsend.enableIROut(aFrequencyKHz);

    uint_fast8_t tNumberOfCommands = aNumberOfRepeats + 1;
    uint_fast8_t tNumberOf64BitChunks = ((aNumberOfBits - 1) / 64) + 1;

    while (tNumberOfCommands > 0) {
        unsigned long tStartOfFrameMillis = millis();

        // Header
        irsend.mark(aHeaderMarkMicros);
        irsend.space(aHeaderSpaceMicros);

        uint16_t remainingBits = aNumberOfBits;
        for (uint_fast8_t i = 0; i < tNumberOf64BitChunks; ++i) {
            uint8_t tNumberOfBitsForOneSend;
            uint8_t tFlags;
            if (i == (tNumberOf64BitChunks - 1)) {
                tNumberOfBitsForOneSend = remainingBits;
                tFlags = aFlags;
            } else {
                tNumberOfBitsForOneSend = 64;
                tFlags = aFlags | SUPPRESS_STOP_BIT;
            }

            sendPulseDistanceWidthData(aOneMarkMicros, aOneSpaceMicros, aZeroMarkMicros, aZeroSpaceMicros, aDecodedRawDataArray[i],
                    tNumberOfBitsForOneSend, tFlags);
            remainingBits -= 64;
        }

        tNumberOfCommands--;
        if (tNumberOfCommands > 0) {
            auto tFrameDurationMillis = millis() - tStartOfFrameMillis;
            if (aRepeatPeriodMillis > tFrameDurationMillis) {
                delay(aRepeatPeriodMillis - tFrameDurationMillis);
            }
        }
    }
}
unsigned long presenceOnTime  = DEFAULT_PRESENCE_ON_TIME;
unsigned long presenceOffTime = DEFAULT_PRESENCE_OFF_TIME;

Preferences    prefs;
bool    acState            = false;
bool    presenceStable     = false;
bool    learnModeActive    = false;
uint8_t currentRadarState  = 0; // 0=None, 1=Moving, 2=Static, 3=Both
bool    bypassRadar        = false; // Default is to use radar

unsigned long presenceStartTime   = 0;
unsigned long absenceStartTime    = 0;
unsigned long lastSensorCheck     = 0;
unsigned long lastStatusNotify    = 0;

HardwareSerial ld2410Serial(2);
String deviceId = "";

// ============================================================
//  FORWARD DECLARATIONS
// ============================================================
void saveDynamicConfigToNVS();
void loadDynamicConfigFromNVS();
void saveRawConfigToNVS();
void loadRawConfigFromNVS();
void turnACOn();
void turnACOff();
void saveTimingToNVS();
void loadTimingFromNVS();
void handleCommand(String cmd);
void notifyStatus(String msg);
void sendRawIR(uint16_t* data, uint16_t len);
void restartLD2410();
void setRadarBypass(bool bypass);
void mqttPublishEvent(String eventName);
void mqttPublishSync();
void saveWifiToNVS();
void loadWifiFromNVS();
void initWiFi();
void saveMqttCredsToNVS();
void loadMqttCredsFromNVS();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void mqttReconnect();
void mqttPublishStatus(bool powerState);
void mqttPublishHeartbeat();
void mqttPublishStatusNotify(String msg);
void mqttPublishIRJson(String json);
void mqttPublishIRRaw(uint16_t* data, uint16_t len);



NimBLEServer* pServer = nullptr;
NimBLECharacteristic* pStatusChar = nullptr;
NimBLECharacteristic* pIRDataChar = nullptr;

bool deviceConnected = false;

class ServerCallbacks : public NimBLEServerCallbacks {

  void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
    deviceConnected = true;

    Serial.println("[BLE] Client connected");

    notifyStatus("CONNECTED");
  }

  void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {

    deviceConnected = false;
    learnModeActive = false;

    Serial.println("[BLE] Client disconnected");

    delay(500);

    NimBLEDevice::startAdvertising();

    Serial.println("[BLE] Advertising restarted");
  }
};

class CommandCallbacks : public NimBLECharacteristicCallbacks {

  void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {

    std::string rawVal = pChar->getValue();
    String value = String(rawVal.c_str());

    value.trim();

    if (value.length() > 0) {

      Serial.print("[BLE] Command received: ");
      Serial.println(value);

      handleCommand(value);
    }
  }
};

void setupBLE() {

  NimBLEDevice::init(deviceId.c_str());

  NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9);

  pServer = NimBLEDevice::createServer();

  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService* pService =
      pServer->createService(SERVICE_UUID);

  // Command characteristic
  NimBLECharacteristic* pCmdChar =
      pService->createCharacteristic(
          CHAR_COMMAND_UUID,
          NIMBLE_PROPERTY::WRITE
      );

  pCmdChar->setCallbacks(new CommandCallbacks());

  // Status characteristic
  pStatusChar =
      pService->createCharacteristic(
          CHAR_STATUS_UUID,
          NIMBLE_PROPERTY::NOTIFY
      );

  // IR characteristic
  pIRDataChar =
      pService->createCharacteristic(
          CHAR_IR_DATA_UUID,
          NIMBLE_PROPERTY::NOTIFY
      );

  pService->start();

  NimBLEAdvertising* pAdvertising =
      NimBLEDevice::getAdvertising();

  pAdvertising->setName(deviceId.c_str());

  pAdvertising->addServiceUUID(SERVICE_UUID);

  pAdvertising->enableScanResponse(true);

  pAdvertising->setPreferredParams(0x06, 0x12);

  NimBLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started");

  Serial.print("[BLE] Device name: ");
  Serial.println(deviceId);
}

// ============================================================
//  NOTIFY HELPERS
// ============================================================
void notifyStatus(String msg) {
  Serial.print("[STATUS] ");
  Serial.println(msg);
  if (deviceConnected && pStatusChar) {
    pStatusChar->setValue(msg.c_str());
    pStatusChar->notify();
  }
  mqttPublishStatusNotify(msg);
}

// Send raw IR data to app in BLE-safe chunks
// Protocol: "IR_START:<total>" → "IR:<chunk_csv>" × N → "IR_END"
// App reassembles chunks then parses the full CSV.
void notifyIRData(uint16_t* data, uint16_t len) {
  if (!deviceConnected || !pIRDataChar) return;

  // Build full CSV first
  String fullCsv = "";
  for (uint16_t i = 0; i < len; i++) {
    fullCsv += String(data[i]);
    if (i < len - 1) fullCsv += ",";
  }

  Serial.print("[IR] Full CSV size: ");
  Serial.print(fullCsv.length());
  Serial.println(" bytes");

  // Send START frame with total value count
  String startMsg = "IR_START:" + String(len);
  pIRDataChar->setValue(startMsg.c_str());
  pIRDataChar->notify();
  delay(30);

  // Send data in BLE_CHUNK_SIZE byte chunks
  int total = fullCsv.length();
  int sent  = 0;
  int chunk = 0;
  while (sent < total) {
    int end = sent + BLE_CHUNK_SIZE;
    if (end > total) end = total;

    // Make sure we don't split a number mid-digits
    // Walk back to last comma if not at end
    if (end < total) {
      while (end > sent && fullCsv[end] != ',') end--;
      if (end == sent) end = sent + BLE_CHUNK_SIZE; // no comma found, force cut
    }

    String chunkStr = "IR:" + fullCsv.substring(sent, end);
    pIRDataChar->setValue(chunkStr.c_str());
    pIRDataChar->notify();
    delay(20);  // give BLE stack time to deliver each chunk

    sent = end;
    // Skip the comma separator
    if (sent < total && fullCsv[sent] == ',') sent++;
    chunk++;
  }

  // Send END frame
  pIRDataChar->setValue("IR_END");
  pIRDataChar->notify();

  Serial.print("[IR] Sent to app in ");
  Serial.print(chunk);
  Serial.println(" chunks");
}

// Send encoded IR JSON to app using chunked protocol
void notifyIRJson(String& json) {
  if (!deviceConnected || !pIRDataChar) return;

  pIRDataChar->setValue("ENC_START");
  pIRDataChar->notify();
  delay(30);

  int total = json.length();
  int sent = 0;
  int chunkNum = 0;
  while (sent < total) {
    int end = sent + BLE_CHUNK_SIZE;
    if (end > total) end = total;

    String chunkStr = "ENC:" + json.substring(sent, end);
    pIRDataChar->setValue(chunkStr.c_str());
    pIRDataChar->notify();
    delay(20);

    sent = end;
    chunkNum++;
  }

  pIRDataChar->setValue("ENC_END");
  pIRDataChar->notify();

  Serial.print("[IR] Sent JSON to app in ");
  Serial.print(chunkNum);
  Serial.println(" chunks");
}

// ============================================================
//  COMMAND HANDLER
//  Commands from app:
//    LEARN_START          — enter IR capture mode
//    LEARN_STOP           — exit IR capture mode
//    STATUS               — push current status immediately
//    SEND:<key>:<csv>     — transmit stored IR button
//    SAVE_PROFILE:<json>  — save a new profile from app
//    SET_ACTIVE:<id>      — set which profile drives automation
//    DELETE:<id>          — delete a profile
//    LIST_PROFILES        — send profile list back
// ============================================================
void handleCommand(String cmd) {

  // ---- LEARN_START ----
  if (cmd == "LEARN_START") {
    learnModeActive = true;
    irrecv.enableIRIn();
    notifyStatus("LEARN_READY");
    return;
  }

  // ---- LEARN_STOP ----
  if (cmd == "LEARN_STOP") {
    learnModeActive = false;
    irrecv.disableIRIn();
    notifyStatus("LEARN_STOPPED");
    return;
  }

  // ---- STATUS ----
  if (cmd == "STATUS") {
    String s = "AC=";
    s += acState ? "ON" : "OFF";
    s += "|PRESENCE=";
    switch (currentRadarState) {
      case 1: s += "MOVING"; break;
      case 2: s += "STATIC"; break;
      case 3: s += "BOTH"; break;
      default: s += "NONE"; break;
    }
    s += "|CONFIG=";
    s += dynamicConfigName.length() > 0 ? dynamicConfigName : "NONE";
    s += "|ON_TIME=" + String((unsigned long)presenceOnTime);
    s += "|OFF_TIME=" + String((unsigned long)presenceOffTime);
    s += "|ID=" + deviceId;
    s += "|WIFI=";
    s += (WiFi.status() == WL_CONNECTED) ? "con" : "dis";
    s += "|RADAR=";
    s += bypassRadar ? "BYPASS" : "ACTIVE";
    s += "|MODE=";
    s += useRawMode ? "RAW" : "ENC";
    s += "|RAW_ON=";
    s += (rawAcOnPattern != nullptr && rawAcOnLen > 0) ? String(rawAcOnLen) : "0";
    s += "|RAW_OFF=";
    s += (rawAcOffPattern != nullptr && rawAcOffLen > 0) ? String(rawAcOffLen) : "0";
    notifyStatus(s);
    return;
  }

  // ---- BYPASS_RADAR / USE_RADAR ----
  if (cmd == "BYPASS_RADAR") {
    setRadarBypass(true);
    notifyStatus("RADAR=BYPASS");
    return;
  }
  if (cmd == "USE_RADAR") {
    setRadarBypass(false);
    notifyStatus("RADAR=ACTIVE");
    return;
  }

  // ---- MANUAL TOGGLES ----
  if (cmd == "AC_ON") {
    turnACOn();
    return;
  }

  if (cmd == "AC_OFF") {
    turnACOff();
    return;
  }

  // ---- CLEAR_CONFIG ----
  if (cmd == "CLEAR_CONFIG") {
    // Wipe dynamic config
    hasDynamicConfig = false;
    memset(dynamicAcOnData, 0, sizeof(dynamicAcOnData));
    memset(dynamicAcOffData, 0, sizeof(dynamicAcOffData));
    dynamicIrFreqKhz = 38;
    dynamicHdrMark = 0; dynamicHdrSpace = 0;
    dynamicBitMark = 0; dynamicOneSpace = 0; dynamicZeroSpace = 0; dynamicStopMark = 0;
    dynamicBitLength = 0; dynamicSendRepeat = 3;
    dynamicConfigName = "";
    saveDynamicConfigToNVS();

    // Wipe raw configuration
    useRawMode = false;
    rawAcOnLen = 0;
    rawAcOffLen = 0;
    if (rawAcOnPattern) { free(rawAcOnPattern); rawAcOnPattern = nullptr; }
    if (rawAcOffPattern) { free(rawAcOffPattern); rawAcOffPattern = nullptr; }
    saveRawConfigToNVS();

    // Sync cloud before wiping WiFi
    mqttPublishSync();

    // Reset AC state
    acState = false;
    presenceStable = false;
    // Wipe Wi-Fi
    wifiSsid = ""; wifiPassword = "";
    saveWifiToNVS();
    if (WiFi.status() == WL_CONNECTED) WiFi.disconnect();
    
    notifyStatus("CONFIG_CLEARED");
    Serial.println("[CMD] All config cleared");
    return;
  }

  // ---- SET_WIFI:<ssid>:<pass> ----
  if (cmd.startsWith("SET_WIFI:")) {
    int sep = cmd.indexOf(':', 9);
    if (sep > 0) {
      wifiSsid = cmd.substring(9, sep);
      wifiPassword = cmd.substring(sep + 1);
      saveWifiToNVS();
      initWiFi();
      Serial.printf("[CMD] Wi-Fi set: SSID=%s\n", wifiSsid.c_str());

      if (WiFi.status() == WL_CONNECTED) {
        if (!mqttClient.connected()) {
          if (!NimBLEDevice::isInitialized()) {
            // MQTT was never set up (first boot flow)
            initMQTT();
          }
          mqttReconnect();
        }

        if (mqttClient.connected()) {
          notifyStatus("MQTT_CONNECTED");
          delay(500);  // let notification reach app before BLE drops

          if (NimBLEDevice::isInitialized()) {
            Serial.println("[BLE] Disabling — MQTT connected, freeing RAM");
            NimBLEDevice::deinit(true);
          }
        } else {
          notifyStatus("WIFI_STATUS:CONNECTED");
        }
      } else {
        notifyStatus("WIFI_STATUS:FAILED");
      }
    } else {
      notifyStatus("ERR:BAD_WIFI_FORMAT");
    }
    return;
  }

  // ---- SET_TIME_CONFIG:<gmtOffset>:<dstOffset> ----
  if (cmd.startsWith("SET_TIME_CONFIG:")) {
    int sep = cmd.indexOf(':', 16);
    if (sep > 0) {
      gmtOffset_sec = strtol(cmd.substring(16, sep).c_str(), nullptr, 10);
      daylightOffset_sec = atoi(cmd.substring(sep + 1).c_str());
      saveTimingToNVS();
      configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org", "time.nist.gov", "time.google.com");
      String ack = "TIME_CFG_SET:" + String(gmtOffset_sec) + ":" + String(daylightOffset_sec);
      notifyStatus(ack);
      Serial.printf("[CMD] Time config set: GMT=%ld, DST=%d\n", gmtOffset_sec, daylightOffset_sec);
    } else {
      notifyStatus("ERR:BAD_TIME_CFG_FORMAT");
    }
    return;
  }

  // ---- SET_TIMING:<onMs>:<offMs> ----
  if (cmd.startsWith("SET_TIMING:")) {
    int sep = cmd.indexOf(':', 11);
    if (sep > 0) {
      presenceOnTime  = strtoul(cmd.substring(11, sep).c_str(), nullptr, 10);
      presenceOffTime = strtoul(cmd.substring(sep + 1).c_str(), nullptr, 10);
      saveTimingToNVS();
      String ack = "TIMING_SET:" + String((unsigned long)presenceOnTime) + ":" + String((unsigned long)presenceOffTime);
      notifyStatus(ack);
      Serial.printf("[CMD] Timing set: ON=%lums, OFF=%lums\n", presenceOnTime, presenceOffTime);
    } else {
      notifyStatus("ERR:BAD_TIMING_FORMAT");
    }
    return;
  }

  // ---- GET_TIMING ----
  if (cmd == "GET_TIMING") {
    String s = "TIMING:" + String((unsigned long)presenceOnTime) + ":" + String((unsigned long)presenceOffTime);
    notifyStatus(s);
    return;
  }


  // ---- SEND:<key>:<csv_rawdata> ----
  // App sends raw IR timings to transmit immediately
  if (cmd.startsWith("SEND:")) {
    int firstColon = cmd.indexOf(':', 5);
    if (firstColon < 0) { notifyStatus("ERR:BAD_SEND_FORMAT"); return; }
    String key     = cmd.substring(5, firstColon);
    String csvData = cmd.substring(firstColon + 1);
    uint16_t raw[MAX_RAW_LEN];
    uint16_t rawLen = 0;
    int start = 0, comma = csvData.indexOf(',');
    while (comma >= 0 && rawLen < MAX_RAW_LEN) {
      raw[rawLen++] = (uint16_t)csvData.substring(start, comma).toInt();
      start = comma + 1;
      comma = csvData.indexOf(',', start);
    }
    if (start < (int)csvData.length() && rawLen < MAX_RAW_LEN)
      raw[rawLen++] = (uint16_t)csvData.substring(start).toInt();
    sendRawIR(raw, rawLen);
    notifyStatus("SENT:" + key);
    return;
  }

  // ---- VAR_START ----
  if (cmd.startsWith("VAR_START:")) {
    dynamicConfigName = cmd.substring(10);
    hasDynamicConfig = true; // start building configuration
    // Reset all arrays
    memset(dynamicAcOnData, 0, sizeof(dynamicAcOnData));
    memset(dynamicAcOffData, 0, sizeof(dynamicAcOffData));
    Serial.print("[VAR] Config name: "); Serial.println(dynamicConfigName);
    notifyStatus("VAR_READY");
    return;
  }

  // ---- VAR_CHUNK:<key>:<value> ----
  if (cmd.startsWith("VAR_CHUNK:")) {
    int keyEnd = cmd.indexOf(':', 10);
    if (keyEnd > 0) {
      String key = cmd.substring(10, keyEnd);
      String val = cmd.substring(keyEnd + 1);

      if (key == "acOn" || key == "acOff") {
        uint64_t* dataArray = (key == "acOn") ? dynamicAcOnData : dynamicAcOffData;
        int wordIdx = 0;
        int start = 0, comma = 0;
        while ((comma = val.indexOf(',', start)) >= 0 && wordIdx < 4) {
          dataArray[wordIdx++] = (uint64_t)strtoull(val.substring(start, comma).c_str(), nullptr, 16);
          start = comma + 1;
        }
        if (start < val.length() && wordIdx < 4) {
          dataArray[wordIdx++] = (uint64_t)strtoull(val.substring(start).c_str(), nullptr, 16);
        }
      } 
      else if (key == "IR_FREQ_KHZ") dynamicIrFreqKhz = val.toInt();
      else if (key == "HDR_MARK")    dynamicHdrMark = val.toInt();
      else if (key == "HDR_SPACE")   dynamicHdrSpace = val.toInt();
      else if (key == "BIT_MARK")    dynamicBitMark = val.toInt();
      else if (key == "ONE_SPACE")   dynamicOneSpace = val.toInt();
      else if (key == "ZERO_SPACE")  dynamicZeroSpace = val.toInt();
      else if (key == "STOP_MARK")   dynamicStopMark = val.toInt();
      else if (key == "BIT_LENGTH")  dynamicBitLength = val.toInt();
      else if (key == "SEND_REPEAT") dynamicSendRepeat = val.toInt();
    }
    return;
  }

  // ---- VAR_END ----
  if (cmd == "VAR_END") {
    saveDynamicConfigToNVS();
    notifyStatus("VAR_SAVED");
    mqttPublishSync();
    return;
  }

  // ---- USE_RAW ----
  if (cmd == "USE_RAW") {
    useRawMode = true;
    saveRawConfigToNVS();
    notifyStatus("MODE=RAW");
    return;
  }

  // ---- USE_ENC ----
  if (cmd == "USE_ENC") {
    useRawMode = false;
    saveRawConfigToNVS();
    notifyStatus("MODE=ENC");
    return;
  }

  static String rawUploadTarget = "";

  // ---- RAW_START:<target>:<total_len> ----
  if (cmd.startsWith("RAW_START:")) {
    int sep = cmd.indexOf(':', 10);
    if (sep > 0) {
      rawUploadTarget = cmd.substring(10, sep);
      int totalLen = cmd.substring(sep + 1).toInt();
      if (totalLen > 0 && totalLen <= MAX_RAW_PATTERN_LEN) {
        tempRawUploadLen = totalLen;
        tempRawUploadBuf = (uint16_t*)realloc(tempRawUploadBuf, tempRawUploadLen * sizeof(uint16_t));
        memset(tempRawUploadBuf, 0, tempRawUploadLen * sizeof(uint16_t));
        notifyStatus("RAW_READY");
      } else {
        notifyStatus("ERR:BAD_RAW_LEN");
      }
    } else {
      notifyStatus("ERR:BAD_RAW_START_FORMAT");
    }
    return;
  }

  // ---- RAW_CHUNK:<index>:<csv_values> ----
  if (cmd.startsWith("RAW_CHUNK:")) {
    int sep = cmd.indexOf(':', 10);
    if (sep > 0 && tempRawUploadBuf != nullptr) {
      int index = cmd.substring(10, sep).toInt();
      String csv = cmd.substring(sep + 1);
      int start = 0, comma = 0;
      int currIdx = index;
      while ((comma = csv.indexOf(',', start)) >= 0 && currIdx < tempRawUploadLen) {
        tempRawUploadBuf[currIdx++] = (uint16_t)csv.substring(start, comma).toInt();
        start = comma + 1;
      }
      if (start < csv.length() && currIdx < tempRawUploadLen) {
        tempRawUploadBuf[currIdx++] = (uint16_t)csv.substring(start).toInt();
      }
    }
    return;
  }

  // ---- RAW_END ----
  if (cmd == "RAW_END") {
    if (tempRawUploadBuf != nullptr && tempRawUploadLen > 0) {
      if (rawUploadTarget == "on") {
        if (rawAcOnPattern) free(rawAcOnPattern);
        rawAcOnPattern = (uint16_t*)malloc(tempRawUploadLen * sizeof(uint16_t));
        memcpy(rawAcOnPattern, tempRawUploadBuf, tempRawUploadLen * sizeof(uint16_t));
        rawAcOnLen = tempRawUploadLen;
      } else if (rawUploadTarget == "off") {
        if (rawAcOffPattern) free(rawAcOffPattern);
        rawAcOffPattern = (uint16_t*)malloc(tempRawUploadLen * sizeof(uint16_t));
        memcpy(rawAcOffPattern, tempRawUploadBuf, tempRawUploadLen * sizeof(uint16_t));
        rawAcOffLen = tempRawUploadLen;
      }
      useRawMode = true;
      saveRawConfigToNVS();
      if (tempRawUploadBuf) {
        free(tempRawUploadBuf);
        tempRawUploadBuf = nullptr;
      }
      tempRawUploadLen = 0;
      notifyStatus("RAW_SAVED");
      mqttPublishSync();
    } else {
      notifyStatus("ERR:NO_RAW_BUF");
    }
    return;
  }

  // ---- RAW_GET:<target> ----
  if (cmd.startsWith("RAW_GET:")) {
    String target = cmd.substring(8);
    uint16_t* ptr = nullptr;
    uint16_t len = 0;
    if (target == "on") {
      ptr = rawAcOnPattern;
      len = rawAcOnLen;
    } else if (target == "off") {
      ptr = rawAcOffPattern;
      len = rawAcOffLen;
    }
    if (ptr != nullptr && len > 0) {
      notifyIRData(ptr, len);
    } else {
      notifyStatus("ERR:RAW_EMPTY");
    }
    return;
  }

  // ---- SEND_ENC:<key>:<bits>:<hdrMark>:<hdrSpace>:<bitMark>:<oneSpace>:<zeroSpace>:<hex1>,<hex2>... ----
  if (cmd.startsWith("SEND_ENC:")) {
    int p = 9;
    auto nextColon = [&]() -> String {
      int start = p;
      while (p < (int)cmd.length() && cmd[p] != ':') p++;
      String val = cmd.substring(start, p);
      if (p < (int)cmd.length()) p++;
      return val;
    };
    String key       = nextColon();
    int    bits      = nextColon().toInt();
    int    hdrMark   = nextColon().toInt();
    int    hdrSpace  = nextColon().toInt();
    int    bitMark   = nextColon().toInt();
    int    oneSpace  = nextColon().toInt();
    int    zeroSpace = nextColon().toInt();
    String hexList   = cmd.substring(p);

    uint64_t encodedData[4] = {0};
    uint8_t  wordCount = 0;
    int hStart = 0, comma;
    while ((comma = hexList.indexOf(',', hStart)) >= 0 && wordCount < 4) {
      String h = hexList.substring(hStart, comma); h.trim();
      encodedData[wordCount++] = (uint64_t)strtoull(h.c_str(), nullptr, 16);
      hStart = comma + 1;
    }
    if (hStart < (int)hexList.length() && wordCount < 4) {
      String h = hexList.substring(hStart); h.trim();
      encodedData[wordCount++] = (uint64_t)strtoull(h.c_str(), nullptr, 16);
    }
    if (wordCount > 0) {
      sendPulseDistanceWidthFromArray(
        dynamicIrFreqKhz, hdrMark, hdrSpace, bitMark, oneSpace, zeroSpace, bitMark,
        encodedData, bits, PROTOCOL_IS_LSB_FIRST, 0, dynamicSendRepeat
      );
    }
    notifyStatus("SENT_ENC:" + key);
    return;
  }

  notifyStatus("ERR:UNKNOWN_CMD:" + cmd);
}

// ============================================================
//  IR TRANSMIT
// ============================================================

void sendRawIR(uint16_t* data, uint16_t len) {
  if (len == 0) return;
  irsend.sendRaw(data, len, dynamicIrFreqKhz);
  Serial.printf("[IR] Sent raw, %d marks/spaces\n", len);
}

// ============================================================
//  IR LEARN MODE — called from loop when active
// ============================================================
void handleLearnMode() {
  if (!irrecv.decode(&results)) return;

  uint16_t len = results.rawlen;

  if (len < 10) {
    irrecv.resume();
    notifyStatus("LEARN_NOISE");
    return;
  }

  // Print decoded result to serial for debug
  Serial.printf("[IR] Received protocol: %s, bits: %d\n", typeToString(results.decode_type).c_str(), results.bits);

  // ── RAW CAPTURE PATH ────────────────────────────────────────
  // We capture raw timings for everything since we are in hybrid/raw mode
  uint16_t raw[MAX_RAW_LEN];
  uint16_t copyLen = min((uint16_t)(len - 1), (uint16_t)MAX_RAW_LEN);
  for (uint16_t i = 0; i < copyLen; i++) {
    raw[i] = results.rawbuf[i + 1] * kRawTick;
  }
  Serial.print("[IR] Raw captured, ");
  Serial.print(copyLen);
  Serial.println(" values");
  notifyIRData(raw, copyLen);
  mqttPublishIRRaw(raw, copyLen);

  irrecv.resume();
}

// ============================================================
//  LD2410 PRESENCE PARSER
// ============================================================
void updateRadarState() {
  static uint8_t frame[23];
  while (ld2410Serial.available() >= 23) {
    if (ld2410Serial.peek() != 0xF4) { ld2410Serial.read(); continue; }
    ld2410Serial.readBytes(frame, 23);
    if (frame[0] == 0xF4 && frame[1] == 0xF3 &&
        frame[2] == 0xF2 && frame[3] == 0xF1) {
      currentRadarState = frame[8];
    }
  }
}



// ============================================================
//  AC CONTROL — uses active profile buttons
// ============================================================
void turnACOn() {
  if (acState) return;

  if (useRawMode) {
    if (rawAcOnPattern == nullptr || rawAcOnLen == 0) {
      notifyStatus("ERR:NO_RAW_ON");
      presenceStartTime = millis();
      return;
    }
    irsend.sendRaw(rawAcOnPattern, rawAcOnLen, dynamicIrFreqKhz);
    Serial.printf("[AC] Turned ON via RAW, %d ticks\n", rawAcOnLen);
  } else {
    if (!hasDynamicConfig || dynamicBitLength == 0) {
      notifyStatus("ERR:NO_CONFIG");
      presenceStartTime = millis();
      return;
    }
    sendPulseDistanceWidthFromArray(
      dynamicIrFreqKhz,
      dynamicHdrMark, dynamicHdrSpace,
      dynamicBitMark, dynamicOneSpace, dynamicZeroSpace,
      dynamicStopMark,
      dynamicAcOnData, dynamicBitLength,
      PROTOCOL_IS_LSB_FIRST, 0, dynamicSendRepeat
    );
    Serial.println("[AC] Turned ON via ENCODED");
  }

  acState = true;
  notifyStatus("AC=ON");
  mqttPublishEvent("AC_ON");
  mqttPublishStatus(true);
  restartLD2410();
}

void turnACOff() {
  if (!acState) return;

  if (useRawMode) {
    if (rawAcOffPattern == nullptr || rawAcOffLen == 0) {
      notifyStatus("ERR:NO_RAW_OFF");
      return;
    }
    irsend.sendRaw(rawAcOffPattern, rawAcOffLen, dynamicIrFreqKhz);
    Serial.printf("[AC] Turned OFF via RAW, %d ticks\n", rawAcOffLen);
  } else {
    if (!hasDynamicConfig || dynamicBitLength == 0) return;
    sendPulseDistanceWidthFromArray(
      dynamicIrFreqKhz,
      dynamicHdrMark, dynamicHdrSpace,
      dynamicBitMark, dynamicOneSpace, dynamicZeroSpace,
      dynamicStopMark,
      dynamicAcOffData, dynamicBitLength,
      PROTOCOL_IS_LSB_FIRST, 0, dynamicSendRepeat
    );
    Serial.println("[AC] Turned OFF via ENCODED");
  }

  acState = false;
  notifyStatus("AC=OFF");
  mqttPublishEvent("AC_OFF");
  mqttPublishStatus(false);
  restartLD2410();
}

// ============================================================
//  NVS STORAGE
// ============================================================

void saveRawConfigToNVS() {
  prefs.begin("raw_config", false);
  prefs.putBool("useRaw", useRawMode);
  prefs.putUShort("rawOnLen", rawAcOnLen);
  prefs.putUShort("rawOffLen", rawAcOffLen);

  if (rawAcOnPattern != nullptr && rawAcOnLen > 0) {
    prefs.putBytes("rawOnPat", rawAcOnPattern, rawAcOnLen * sizeof(uint16_t));
  } else {
    prefs.remove("rawOnPat");
  }

  if (rawAcOffPattern != nullptr && rawAcOffLen > 0) {
    prefs.putBytes("rawOffPat", rawAcOffPattern, rawAcOffLen * sizeof(uint16_t));
  } else {
    prefs.remove("rawOffPat");
  }

  prefs.end();
  Serial.println("[NVS] Raw config saved");
}

void loadRawConfigFromNVS() {
  prefs.begin("raw_config", true);
  useRawMode = prefs.getBool("useRaw", false);
  rawAcOnLen = prefs.getUShort("rawOnLen", 0);
  rawAcOffLen = prefs.getUShort("rawOffLen", 0);

  if (rawAcOnLen > 0) {
    rawAcOnPattern = (uint16_t*)realloc(rawAcOnPattern, rawAcOnLen * sizeof(uint16_t));
    prefs.getBytes("rawOnPat", rawAcOnPattern, rawAcOnLen * sizeof(uint16_t));
  } else {
    if (rawAcOnPattern) { free(rawAcOnPattern); rawAcOnPattern = nullptr; }
  }

  if (rawAcOffLen > 0) {
    rawAcOffPattern = (uint16_t*)realloc(rawAcOffPattern, rawAcOffLen * sizeof(uint16_t));
    prefs.getBytes("rawOffPat", rawAcOffPattern, rawAcOffLen * sizeof(uint16_t));
  } else {
    if (rawAcOffPattern) { free(rawAcOffPattern); rawAcOffPattern = nullptr; }
  }

  prefs.end();
  Serial.printf("[NVS] Raw config loaded: useRaw=%d, rawOnLen=%d, rawOffLen=%d\n", useRawMode, rawAcOnLen, rawAcOffLen);
}

void saveDynamicConfigToNVS() {
  prefs.begin("dyn_config", false);
  prefs.putBool("hasCfg", hasDynamicConfig);
  if (hasDynamicConfig) {
    prefs.putBytes("acOn", dynamicAcOnData, sizeof(dynamicAcOnData));
    prefs.putBytes("acOff", dynamicAcOffData, sizeof(dynamicAcOffData));
    prefs.putUShort("irFreq", dynamicIrFreqKhz);
    prefs.putUShort("hdrMark", dynamicHdrMark);
    prefs.putUShort("hdrSpace", dynamicHdrSpace);
    prefs.putUShort("bitMark", dynamicBitMark);
    prefs.putUShort("oneSpace", dynamicOneSpace);
    prefs.putUShort("zeroSpace", dynamicZeroSpace);
    prefs.putUShort("stopMark", dynamicStopMark);
    prefs.putUShort("bitLen", dynamicBitLength);
    prefs.putUChar("sendRep", dynamicSendRepeat);
    prefs.putString("cfgName", dynamicConfigName);
  }
  prefs.end();
  Serial.println("[NVS] Dynamic config saved");
  
  // Re-use load to display what was saved perfectly
  loadDynamicConfigFromNVS();
}

void loadDynamicConfigFromNVS() {
  prefs.begin("dyn_config", true);
  hasDynamicConfig = prefs.getBool("hasCfg", false);
  if (hasDynamicConfig) {
    prefs.getBytes("acOn", dynamicAcOnData, sizeof(dynamicAcOnData));
    prefs.getBytes("acOff", dynamicAcOffData, sizeof(dynamicAcOffData));
    dynamicIrFreqKhz  = prefs.getUShort("irFreq", 38);
    dynamicHdrMark    = prefs.getUShort("hdrMark", 0);
    dynamicHdrSpace   = prefs.getUShort("hdrSpace", 0);
    dynamicBitMark    = prefs.getUShort("bitMark", 0);
    dynamicOneSpace   = prefs.getUShort("oneSpace", 0);
    dynamicZeroSpace  = prefs.getUShort("zeroSpace", 0);
    dynamicStopMark   = prefs.getUShort("stopMark", 0);
    dynamicBitLength  = prefs.getUShort("bitLen", 0);
    dynamicSendRepeat = prefs.getUChar("sendRep", 3);
    dynamicConfigName = prefs.getString("cfgName", "");
  }
  prefs.end();
  
  if (hasDynamicConfig) {
    Serial.println("[NVS] Dynamic config loaded successfully.");
    if (dynamicConfigName.length() > 0) {
      Serial.printf("  ├─ AC: %s\n", dynamicConfigName.c_str());
    }
    Serial.printf("  ├─ Freq: %d kHz, Bits: %d, Repeat: %d\n", dynamicIrFreqKhz, dynamicBitLength, dynamicSendRepeat);
    Serial.printf("  ├─ HDR: Mark=%d, Space=%d\n", dynamicHdrMark, dynamicHdrSpace);
    Serial.printf("  ├─ BIT: Mark=%d, OneSpace=%d, ZeroSpace=%d\n", dynamicBitMark, dynamicOneSpace, dynamicZeroSpace);
    Serial.printf("  ├─ STOP: Mark=%d\n", dynamicStopMark);
    Serial.print("  ├─ acOnData:  ");
    for(int i=0; i<4; i++) Serial.printf("0x%llX ", (unsigned long long)dynamicAcOnData[i]);
    Serial.println();
    Serial.print("  └─ acOffData: ");
    for(int i=0; i<4; i++) Serial.printf("0x%llX ", (unsigned long long)dynamicAcOffData[i]);
    Serial.println();
  } else {
    Serial.println("[NVS] No dynamic config found");
  }
}

void saveTimingToNVS() {
  prefs.begin("ac_timing", false);
  prefs.putULong("onTime", presenceOnTime);
  prefs.putULong("offTime", presenceOffTime);
  prefs.putLong("gmtOffset", gmtOffset_sec);
  prefs.putInt("dstOffset", daylightOffset_sec);
  prefs.end();
  Serial.printf("[NVS] Timing/Timezone saved: ON=%lums, OFF=%lums, GMT=%ld, DST=%d\n", presenceOnTime, presenceOffTime, gmtOffset_sec, daylightOffset_sec);
}

void loadTimingFromNVS() {
  prefs.begin("ac_timing", true);
  presenceOnTime  = prefs.getULong("onTime", DEFAULT_PRESENCE_ON_TIME);
  presenceOffTime = prefs.getULong("offTime", DEFAULT_PRESENCE_OFF_TIME);
  gmtOffset_sec   = prefs.getLong("gmtOffset", 19800);
  daylightOffset_sec = prefs.getInt("dstOffset", 0);
  prefs.end();
  Serial.printf("[NVS] Timing/Timezone loaded: ON=%lums, OFF=%lums, GMT=%ld, DST=%d\n", presenceOnTime, presenceOffTime, gmtOffset_sec, daylightOffset_sec);
}

void saveWifiToNVS() {
  prefs.begin("wifi_cfg", false);
  prefs.putString("ssid", wifiSsid);
  prefs.putString("pass", wifiPassword);
  prefs.end();
  Serial.println("[NVS] Wi-Fi credentials saved");
}

void loadWifiFromNVS() {
  prefs.begin("wifi_cfg", true);
  wifiSsid = prefs.getString("ssid", "");
  wifiPassword = prefs.getString("pass", "");
  prefs.end();
  Serial.println("[NVS] Wi-Fi credentials loaded");
}

void saveMqttCredsToNVS() {
  // Not used anymore since credentials are hardcoded
}

void loadMqttCredsFromNVS() {
  // Not used anymore since credentials are hardcoded
}

// ============================================================
//  MQTT FUNCTIONS
// ============================================================

// Called when a message arrives on a subscribed topic
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Null-terminate the payload
  char msg[length + 1];
  memcpy(msg, payload, length);
  msg[length] = '\0';

  Serial.printf("[MQTT] Received: %s → %s\n", topic, msg);

  // Parse topic: ac/{deviceId}/cmd
  String topicStr = String(topic);
  String expectedCmdTopic = "ac/" + deviceId + "/cmd";

  if (topicStr == expectedCmdTopic) {
    // Parse JSON payload: {"action":"power_on","timestamp":...}
    DynamicJsonDocument doc(5120);  // large enough for Daikin raw patterns
    DeserializationError err = deserializeJson(doc, msg);
    if (err) {
      Serial.printf("[MQTT] JSON parse error: %s\n", err.c_str());
      return;
    }

    String action = doc["action"] | "";
    Serial.printf("[MQTT] Action: %s\n", action.c_str());

    if (action == "power_on" || action == "AC_ON") {
      turnACOn();
    } else if (action == "power_off" || action == "AC_OFF") {
      turnACOff();
    } else if (action == "learn_start") {
      learnModeActive = true;
      irrecv.enableIRIn();
      notifyStatus("LEARN_READY");
    } else if (action == "learn_stop") {
      learnModeActive = false;
      irrecv.disableIRIn();
      notifyStatus("LEARN_STOPPED");
    } else if (action == "send_ir") {
      String method = doc["method"] | "encoded";
      int freq = doc["freq"] | dynamicIrFreqKhz;
      if (freq <= 0) freq = 38;

      if (method == "raw" && doc.containsKey("rawData")) {
        JsonArray rawArr = doc["rawData"];
        uint16_t rawLen = rawArr.size();
        if (rawLen > 0 && rawLen <= MAX_RAW_LEN) {
          uint16_t raw[MAX_RAW_LEN];
          for (int i = 0; i < rawLen; i++) {
            raw[i] = rawArr[i].as<uint16_t>();
          }
          irsend.sendRaw(raw, rawLen, freq);
          Serial.printf("[MQTT CMD] Sent raw IR (%d timings)\n", rawLen);
          notifyStatus("SENT_RAW_MQTT");
        }
      } else if (method == "encoded" && doc.containsKey("hexData")) {
        JsonArray hexArr = doc["hexData"];
        uint8_t wordCount = hexArr.size();
        if (wordCount > 0 && wordCount <= 4) {
          uint64_t encodedData[4] = {0};
          for (int i = 0; i < wordCount; i++) {
            if (hexArr[i].is<const char*>()) {
              encodedData[i] = (uint64_t)strtoull(hexArr[i].as<const char*>(), nullptr, 0);
            } else {
              encodedData[i] = hexArr[i].as<uint64_t>();
            }
          }
          int bits = doc["bits"] | dynamicBitLength;
          int hdrMark = doc["hdrMark"] | dynamicHdrMark;
          int hdrSpace = doc["hdrSpace"] | dynamicHdrSpace;
          int bitMark = doc["bitMark"] | dynamicBitMark;
          int oneSpace = doc["oneSpace"] | dynamicOneSpace;
          int zeroSpace = doc["zeroSpace"] | dynamicZeroSpace;
          int sendRep = doc["sendRep"] | dynamicSendRepeat;
          if (sendRep <= 0) sendRep = 3;

          sendPulseDistanceWidthFromArray(
            freq, hdrMark, hdrSpace, bitMark, oneSpace, zeroSpace, bitMark,
            encodedData, bits, PROTOCOL_IS_LSB_FIRST, 0, sendRep
          );
          Serial.println("[MQTT CMD] Sent encoded IR from MQTT payload");
          notifyStatus("SENT_ENC_MQTT");
        }
      }
    } else if (action == "set_timing") {
      if (doc.containsKey("onTime") && doc.containsKey("offTime")) {
        presenceOnTime = doc["onTime"].as<unsigned long>();
        presenceOffTime = doc["offTime"].as<unsigned long>();
        saveTimingToNVS();
        notifyStatus("TIMING_SET:" + String(presenceOnTime) + ":" + String(presenceOffTime));
      } else {
        notifyStatus("ERR:BAD_TIMING_FORMAT");
      }
    } else if (action == "set_time_config") {
      if (doc.containsKey("gmtOffset") && doc.containsKey("dstOffset")) {
        gmtOffset_sec = doc["gmtOffset"].as<long>();
        daylightOffset_sec = doc["dstOffset"].as<int>();
        saveTimingToNVS();
        configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org", "time.nist.gov", "time.google.com");
        notifyStatus("TIME_CFG_SET:" + String(gmtOffset_sec) + ":" + String(daylightOffset_sec));
      } else {
        notifyStatus("ERR:BAD_TIME_CFG_FORMAT");
      }
    } else if (action == "radar_off" || action == "bypass_radar" || action == "RADAR_OFF") {
      setRadarBypass(true);
      notifyStatus("RADAR=BYPASS");
    } else if (action == "radar_on" || action == "use_radar" || action == "RADAR_ON") {
      setRadarBypass(false);
      notifyStatus("RADAR=ACTIVE");
    } else if (action == "status") {
      mqttPublishStatus(acState);
      mqttPublishHeartbeat();
      mqttPublishSync();
      
      String s = "AC=";
      s += acState ? "ON" : "OFF";
      s += "|PRESENCE=";
      switch (currentRadarState) {
        case 1: s += "MOVING"; break;
        case 2: s += "STATIC"; break;
        case 3: s += "BOTH"; break;
        default: s += "NONE"; break;
      }
      s += "|CONFIG=";
      s += dynamicConfigName.length() > 0 ? dynamicConfigName : "NONE";
      s += "|ON_TIME=" + String((unsigned long)presenceOnTime);
      s += "|OFF_TIME=" + String((unsigned long)presenceOffTime);
      s += "|ID=" + deviceId;
      s += "|WIFI=";
      s += (WiFi.status() == WL_CONNECTED) ? "con" : "dis";
      s += "|RADAR=";
      s += bypassRadar ? "BYPASS" : "ACTIVE";
      notifyStatus(s);
    } else if (action == "set_config") {
      dynamicConfigName = doc["cfgName"] | "";
      dynamicIrFreqKhz  = doc["irFreq"] | 38;
      dynamicHdrMark    = doc["hdrMark"] | 0;
      dynamicHdrSpace   = doc["hdrSpace"] | 0;
      dynamicBitMark    = doc["bitMark"] | 0;
      dynamicOneSpace   = doc["oneSpace"] | 0;
      dynamicZeroSpace  = doc["zeroSpace"] | 0;
      dynamicStopMark   = doc["stopMark"] | 0;
      dynamicBitLength  = doc["bitLen"] | 0;
      dynamicSendRepeat = doc["sendRep"] | 3;

      // Reset dynamic arrays
      memset(dynamicAcOnData, 0, sizeof(dynamicAcOnData));
      memset(dynamicAcOffData, 0, sizeof(dynamicAcOffData));

      // Parse acOn array
      JsonArray acOnArr = doc["acOn"];
      int idx = 0;
      for (JsonVariant val : acOnArr) {
        if (idx < 4) {
          if (val.is<const char*>()) {
            dynamicAcOnData[idx++] = (uint64_t)strtoull(val.as<const char*>(), nullptr, 0);
          } else {
            dynamicAcOnData[idx++] = val.as<uint64_t>();
          }
        }
      }

      // Parse acOff array
      JsonArray acOffArr = doc["acOff"];
      idx = 0;
      for (JsonVariant val : acOffArr) {
        if (idx < 4) {
          if (val.is<const char*>()) {
            dynamicAcOffData[idx++] = (uint64_t)strtoull(val.as<const char*>(), nullptr, 0);
          } else {
            dynamicAcOffData[idx++] = val.as<uint64_t>();
          }
        }
      }

      hasDynamicConfig = true;
      saveDynamicConfigToNVS();
      notifyStatus("VAR_SAVED");
      mqttPublishSync();
      Serial.println("[MQTT CMD] Configuration saved to NVS successfully");
    } else if (action == "set_raw_on" || action == "set_raw_off") {
      // ── RAW PATTERN UPLOAD VIA MQTT ──────────────────────────
      // JSON: {"action":"set_raw_on","rawData":[3444,1712,428,...]}
      // or:   {"action":"set_raw_off","rawData":[3444,1712,428,...]}
      if (doc.containsKey("rawData")) {
        JsonArray rawArr = doc["rawData"];
        uint16_t rawLen = rawArr.size();
        if (rawLen > 0 && rawLen <= MAX_RAW_PATTERN_LEN) {
          uint16_t* newPattern = (uint16_t*)malloc(rawLen * sizeof(uint16_t));
          if (newPattern != nullptr) {
            for (uint16_t i = 0; i < rawLen; i++) {
              newPattern[i] = rawArr[i].as<uint16_t>();
            }
            if (action == "set_raw_on") {
              if (rawAcOnPattern) free(rawAcOnPattern);
              rawAcOnPattern = newPattern;
              rawAcOnLen = rawLen;
              Serial.printf("[MQTT CMD] Raw ON pattern saved, %d entries\n", rawLen);
            } else {
              if (rawAcOffPattern) free(rawAcOffPattern);
              rawAcOffPattern = newPattern;
              rawAcOffLen = rawLen;
              Serial.printf("[MQTT CMD] Raw OFF pattern saved, %d entries\n", rawLen);
            }
            useRawMode = true;
            saveRawConfigToNVS();
            notifyStatus("RAW_SAVED");
            mqttPublishSync();
          } else {
            notifyStatus("ERR:MALLOC_FAIL");
          }
        } else {
          notifyStatus("ERR:BAD_RAW_LEN");
        }
      } else {
        notifyStatus("ERR:NO_RAW_DATA");
      }
    } else if (action == "use_raw") {
      useRawMode = true;
      saveRawConfigToNVS();
      notifyStatus("MODE=RAW");
    } else if (action == "use_enc") {
      useRawMode = false;
      saveRawConfigToNVS();
      notifyStatus("MODE=ENC");
    } else if (action == "clear_config") {
      hasDynamicConfig = false;
      memset(dynamicAcOnData, 0, sizeof(dynamicAcOnData));
      memset(dynamicAcOffData, 0, sizeof(dynamicAcOffData));
      dynamicIrFreqKhz = 38;
      dynamicHdrMark = 0; dynamicHdrSpace = 0;
      dynamicBitMark = 0; dynamicOneSpace = 0; dynamicZeroSpace = 0; dynamicStopMark = 0;
      dynamicBitLength = 0; dynamicSendRepeat = 3;
      dynamicConfigName = "";
      saveDynamicConfigToNVS();
      mqttPublishSync();
      acState = false;
      presenceStable = false;
      wifiSsid = ""; wifiPassword = "";
      saveWifiToNVS();
      notifyStatus("CONFIG_CLEARED");
      Serial.println("[MQTT CMD] All config cleared");
      if (WiFi.status() == WL_CONNECTED) WiFi.disconnect();
    } else {
      Serial.printf("[MQTT] Unknown action: %s\n", action.c_str());
    }
  }
}

// Attempt to connect/reconnect to the MQTT broker
void mqttReconnect() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (strlen(MQTT_USER) == 0) return;

  String clientId = deviceId;
  String cmdTopic = "ac/" + deviceId + "/cmd";

  Serial.printf("[MQTT] Connecting to %s:%d as %s...\n", MQTT_BROKER, MQTT_PORT, clientId.c_str());

  espSecureClient.setInsecure();
  Serial.printf("[MEM] Free heap: %d | Max alloc: %d\n", ESP.getFreeHeap(), ESP.getMaxAllocHeap());

  if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
    Serial.println("[MQTT] ✓ Connected!");
    mqttClient.subscribe(cmdTopic.c_str());
    Serial.printf("[MQTT] Subscribed to: %s\n", cmdTopic.c_str());
    mqttPublishHeartbeat();
    mqttPublishStatus(acState);
    mqttPublishSync();
  } else {
    int state = mqttClient.state();
    Serial.printf("[MQTT] ✗ Failed, rc=%d\n", state);
    switch (state) {
      case -4: Serial.println("[MQTT]   → Connection timeout"); break;
      case -2: Serial.println("[MQTT]   → Connect failed (low memory or TLS issue)"); break;
      case  4: Serial.println("[MQTT]   → Bad credentials"); break;
      case  5: Serial.println("[MQTT]   → Unauthorized (check ACL)"); break;
      default: Serial.printf("[MQTT]   → State: %d\n", state); break;
    }
  }

  if (mqttClient.connected()) {
    notifyStatus("MQTT_CONNECTED");
  } else {
    notifyStatus("MQTT_FAILED:" + String(mqttClient.state()));
  }
}

// Publish power status to ac/{deviceId}/status
void mqttPublishStatus(bool powerState) {
  if (!mqttClient.connected()) return;

  String topic = "ac/" + deviceId + "/status";
  DynamicJsonDocument doc(64);
  doc["power"] = powerState;
  String jsonStr;
  serializeJson(doc, jsonStr);

  mqttClient.publish(topic.c_str(), jsonStr.c_str());
  Serial.printf("[MQTT] Published status: %s → %s\n", topic.c_str(), jsonStr.c_str());
}

// Publish heartbeat to ac/{deviceId}/heartbeat
void mqttPublishHeartbeat() {
  if (!mqttClient.connected()) return;

  String topic = "ac/" + deviceId + "/heartbeat";
  DynamicJsonDocument doc(256);
  doc["online"] = true;
  doc["wifi"] = WiFi.RSSI();
  doc["uptime"] = millis() / 1000;
  doc["freeHeap"] = ESP.getFreeHeap();
  doc["power"] = acState;
  doc["presence"] = presenceStable;
  doc["radarBypassed"] = bypassRadar;
  String jsonStr;
  serializeJson(doc, jsonStr);

  mqttClient.publish(topic.c_str(), jsonStr.c_str());
  Serial.printf("[MQTT] Heartbeat: %s\n", jsonStr.c_str());
}

// Publish event to ac/{deviceId}/event
void mqttPublishEvent(String eventName) {
  if (!mqttClient.connected()) return;
  String topic = "ac/" + deviceId + "/event";
  DynamicJsonDocument doc(128);
  doc["event"] = eventName;
  doc["temperature"] = 24;
  doc["presence"] = presenceStable;
  String jsonStr;
  serializeJson(doc, jsonStr);
  mqttClient.publish(topic.c_str(), jsonStr.c_str());
  Serial.printf("[MQTT] Event: %s → %s\n", topic.c_str(), jsonStr.c_str());
}

// Publish device sync metadata to ac/{deviceId}/sync
void mqttPublishSync() {
  if (!mqttClient.connected()) return;
  String topic = "ac/" + deviceId + "/sync";
  String cfgName = dynamicConfigName.length() > 0 ? dynamicConfigName : "NONE";
  DynamicJsonDocument doc(256);
  doc["deviceId"] = deviceId;
  doc["activeConfigName"] = cfgName;
  doc["useRaw"] = useRawMode;
  doc["rawOnLen"] = rawAcOnLen;
  doc["rawOffLen"] = rawAcOffLen;
  String jsonStr;
  serializeJson(doc, jsonStr);
  mqttClient.publish(topic.c_str(), jsonStr.c_str());
  Serial.printf("[MQTT] Sync: %s\n", jsonStr.c_str());
}

void mqttPublishStatusNotify(String msg) {
  if (!mqttClient.connected()) return;
  String topic = "ac/" + deviceId + "/status_notify";
  mqttClient.publish(topic.c_str(), msg.c_str());
  Serial.printf("[MQTT] Status notify: %s\n", msg.c_str());
}

void mqttPublishIRJson(String json) {
  if (!mqttClient.connected()) return;
  String topic = "ac/" + deviceId + "/ir_data";
  bool ok = mqttClient.publish(topic.c_str(), json.c_str());

  Serial.printf(
      "[MQTT] Publish IR result=%s topic=%s size=%d\n",
      ok ? "SUCCESS" : "FAILED",
      topic.c_str(),
      json.length()
  );
}

void mqttPublishIRRaw(uint16_t* data, uint16_t len) {
  if (!mqttClient.connected()) return;
  String topic = "ac/" + deviceId + "/ir_data";
  DynamicJsonDocument doc(2048);
  doc["method"] = "raw";
  doc["len"] = len;
  JsonArray arr = doc.createNestedArray("data");
  for (uint16_t i = 0; i < len; i++) {
    arr.add(data[i]);
  }
  String jsonStr;
  serializeJson(doc, jsonStr);
  mqttClient.publish(topic.c_str(), jsonStr.c_str());
  Serial.printf("[MQTT] Published learned raw IR data to %s\n", topic.c_str());
}

void initMQTT() {
  espSecureClient.setInsecure();
  espSecureClient.setTimeout(15);      // 15s timeout
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(5120);       // large enough for Daikin 600-entry raw IR patterns (~4KB JSON)
  mqttClient.setKeepAlive(60);
  mqttClient.setSocketTimeout(15);
}



void initWiFi() {
  if (wifiSsid.length() == 0) {
    Serial.println("[WIFI] No SSID set. Skipping connection.");
    notifyStatus("WIFI_STATUS:NO_CREDS");
    return;
  }

  // Disconnect if already connected
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(500);
  }

  Serial.print("[WIFI] Connecting to ");
  Serial.println(wifiSsid);
  WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected! IP: " + WiFi.localIP().toString());
    notifyStatus("WIFI_STATUS:CONNECTED");

    // Give the TCP/IP stack a moment to fully initialize
    delay(1000);

    // ---- NTP TIME SYNC ----
    WiFi.setAutoReconnect(true);

    configTime(
      gmtOffset_sec,
      daylightOffset_sec,
      "pool.ntp.org",
      "time.nist.gov",
      "time.google.com"
    );

    Serial.print("[TIME] Waiting for NTP sync");

    struct tm timeinfo;
    bool ntpOk = false;

    for (int i = 0; i < 30; i++) {

      // internet stack not fully ready yet
      if (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print("x");
        continue;
      }

      if (getLocalTime(&timeinfo, 2000)) {
        ntpOk = true;
        break;
      }

      Serial.print(".");
      delay(500);
    }

    if (ntpOk) {
      Serial.println(" synced!");

      Serial.printf(
        "[TIME] %02d:%02d:%02d %02d-%02d-%04d\n",
        timeinfo.tm_hour,
        timeinfo.tm_min,
        timeinfo.tm_sec,
        timeinfo.tm_mday,
        timeinfo.tm_mon + 1,
        timeinfo.tm_year + 1900
      );

    } else {
      Serial.println(" failed!");
    }

    // Sync moved to mqttReconnect() success block to avoid crash on first boot
  } else {
    Serial.println("\n[WIFI] Failed to connect.");
    notifyStatus("WIFI_STATUS:FAILED");
  }
}

// ============================================================
//  RADAR SENSOR BYPASS
// ============================================================
void setRadarBypass(bool bypass) {
  bypassRadar = bypass;
  Serial.printf("[RADAR] Bypass status updated: %s\n", bypass ? "BYPASSED" : "ACTIVE");
}

// ============================================================
//  LD2410 RESTART
//  The LD2410 silently ignores 0xA3 unless it is in config mode.
//  Sequence: enable config → restart → wait for boot.
// ============================================================
void restartLD2410() {
  // Step 1: Enable configuration mode (required before any command)
  uint8_t enableCfg[] = {
    0xFD, 0xFC, 0xFB, 0xFA,   // header
    0x04, 0x00,                // length = 4 bytes
    0xFF, 0x00,                // command: enable config
    0x01, 0x00,                // value: 1 (enter config)
    0x04, 0x03, 0x02, 0x01    // end frame
  };
  ld2410Serial.write(enableCfg, sizeof(enableCfg));
  Serial.println("[LD2410] Config mode enabled");
  delay(100); // wait for ACK

  // Step 2: Flush any incoming ACK bytes so buffer stays clean
  while (ld2410Serial.available()) ld2410Serial.read();

  // Step 3: Send restart command
  uint8_t restartCmd[] = {
    0xFD, 0xFC, 0xFB, 0xFA,   // header
    0x02, 0x00,                // length = 2 bytes
    0xA3, 0x00,                // command: restart
    0x04, 0x03, 0x02, 0x01    // end frame
  };
  ld2410Serial.write(restartCmd, sizeof(restartCmd));
  Serial.println("[LD2410] Restart command sent — waiting for reboot...");

  // Step 4: Wait for sensor to fully reboot and resume data stream
  delay(1500);
  Serial.println("[LD2410] Sensor should be back online");
}

// ============================================================
//  PROFILE HELPERS — removed (superseded by dynamic config)
// ============================================================

// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(500);

  // MAC-based device ID
  uint64_t chipid = ESP.getEfuseMac();
  uint8_t* mac = (uint8_t*)&chipid;
  char macStr[13];
  snprintf(macStr, sizeof(macStr), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  deviceId = "AC_" + String(macStr);

  Serial.println("\n=== AC Automation BLE Edition ===");
  Serial.println("[SYS] Device ID: " + deviceId);

  // Load all NVS data first
  loadDynamicConfigFromNVS();
  loadRawConfigFromNVS();
  loadTimingFromNVS();
  loadWifiFromNVS();

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  bool mqttReady = false;

  if (wifiSsid.length() > 0) {
    initWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      initMQTT();         // configure client settings
      mqttReconnect();    // first connect with full ~140KB heap
      mqttReady = mqttClient.connected();
    }
  }

  // BLE only if cloud connectivity failed or no credentials
  if (!mqttReady) {
    setupBLE();
    Serial.println("[BLE] Active — awaiting provisioning or credential fix");
    // If WiFi was up but MQTT failed, still init MQTT for loop() retries
    if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
      initMQTT();
    }
  } else {
    Serial.println("[BLE] Skipped — MQTT connected, RAM conserved");
  }

  // IR and LD2410 always last (after BLE timer allocation)
  irsend.begin();
  Serial.println("[IR] Sender ready on GPIO " + String(IR_SEND_PIN));

  ld2410Serial.begin(256000, SERIAL_8N1, LD2410_RX_PIN, LD2410_TX_PIN);
  delay(300);
  Serial.println("[LD2410] Ready on UART2");

  Serial.println("[SYS] Automation engine active");
  Serial.println("[SYS] Ready\n");
}

// ============================================================
//  LOOP
// ============================================================
void loop() {

  // ---- MQTT connection status tracking ----
  static bool lastMqttConnectedState = false;
  bool currentMqttConnected = mqttClient.connected();
  if (currentMqttConnected != lastMqttConnectedState) {
    lastMqttConnectedState = currentMqttConnected;
    if (currentMqttConnected) {
      Serial.println("[MQTT] Connection status: CONNECTED");

      // Disable BLE now that cloud is healthy (only if no app is connected)
      if (!deviceConnected && NimBLEDevice::isInitialized()) {
        Serial.println("[BLE] MQTT restored — disabling BLE, freeing ~80KB RAM");
        NimBLEDevice::deinit(true);
      }
    } else {
      Serial.printf("[MQTT] Disconnected, state: %d\n", mqttClient.state());
    }
  }

  // ---- MQTT keep-alive & reconnect ----
  if (WiFi.status() == WL_CONNECTED && strlen(MQTT_USER) > 0) {
    if (!mqttClient.connected()) {
      unsigned long now2 = millis();
      if (now2 - lastMqttReconnectAttempt >= MQTT_RECONNECT_INTERVAL) {
        lastMqttReconnectAttempt = now2;
        mqttReconnect();
      }
    } else {
      mqttClient.loop();  // Process incoming messages & keep-alive
    }

    // Periodic heartbeat
    if (mqttClient.connected() && (millis() - lastMqttHeartbeat >= MQTT_HEARTBEAT_INTERVAL)) {
      lastMqttHeartbeat = millis();
      mqttPublishHeartbeat();
    }
  }

  unsigned long now = millis();

  // ---- Serial Command Handler ----
  // Type "dump" into the Serial Monitor at any point!
  if (Serial.available()) {
    String serialCmd = Serial.readStringUntil('\n');
    serialCmd.trim();
    if (serialCmd.equalsIgnoreCase("dump") || serialCmd.equalsIgnoreCase("info") || serialCmd == "?") {
      Serial.println("\n==================================================");
      Serial.println("   [USER_CMD] Manual Status & NVS Dump");
      Serial.printf("   [STATE] AC is %s | Presence is %s | Profile: %s\n", 
          acState ? "ON" : "OFF", 
          presenceStable ? "YES" : "NO",
          dynamicConfigName.length() > 0 ? dynamicConfigName.c_str() : "NONE");
      Serial.printf("   [MQTT] Status: %s | Broker: %s:%d | User: %s\n",
          mqttClient.connected() ? "CONNECTED" : "DISCONNECTED",
          MQTT_BROKER, MQTT_PORT,
          strlen(MQTT_USER) > 0 ? MQTT_USER : "NONE");
      Serial.println("--------------------------------------------------");
      loadDynamicConfigFromNVS();
      loadRawConfigFromNVS();
      Serial.println("==================================================\n");
    }
  }

  // ---- IR Learn Mode ----
  if (learnModeActive) {
    handleLearnMode();
  }

  // ---- Sensor polling (every SENSOR_CHECK_INTERVAL) ----
  if (now - lastSensorCheck < SENSOR_CHECK_INTERVAL) return;
  lastSensorCheck = now;

  updateRadarState();
  bool presenceNow = (currentRadarState > 0);

  // ---- Periodic status notification to app ----
  if (deviceConnected && !learnModeActive && now - lastStatusNotify >= STATUS_NOTIFY_INTERVAL) {
    lastStatusNotify = now;
    String s = "AC=";
    s += acState ? "ON" : "OFF";
    s += "|PRESENCE=";
    switch (currentRadarState) {
      case 1: s += "MOVING"; break;
      case 2: s += "STATIC"; break;
      case 3: s += "BOTH"; break;
      default: s += "NONE"; break;
    }
    s += "|CONFIG=";
    s += dynamicConfigName.length() > 0 ? dynamicConfigName : "NONE";
    s += "|ON_TIME=" + String((unsigned long)presenceOnTime);
    s += "|OFF_TIME=" + String((unsigned long)presenceOffTime);
    s += "|ID=" + deviceId; // <- ADDED THIS
    s += "|WIFI=";
    s += (WiFi.status() == WL_CONNECTED) ? "CONNECTED" : "DISCONNECTED";
    s += "|RADAR=";
    s += bypassRadar ? "BYPASS" : "ACTIVE";
    notifyStatus(s);
  }

  // ---- Presence Logic ----
  if (presenceNow) {

    absenceStartTime = 0;

    if (!presenceStable) {
      presenceStable    = true;
      presenceStartTime = now;
      Serial.println("[PRESENCE] Detected");
      // logToSupabase("PRESENCE_DETECTED");
    }

    if (!acState && (now - presenceStartTime >= presenceOnTime)) {
      Serial.println("[PRESENCE] Stable → AC ON");
      if (!bypassRadar) {
        turnACOn();
      }
    }

  } else {

    presenceStartTime = 0;

    if (presenceStable) {
      presenceStable  = false;
      absenceStartTime = now;
      Serial.println("[PRESENCE] Lost");
      // logToSupabase("PRESENCE_LOST");
    }

    if (acState && absenceStartTime &&
        (now - absenceStartTime >= presenceOffTime)) {
      Serial.println("[PRESENCE] Gone → AC OFF");
      if (!bypassRadar) {
        turnACOff();
      }
      absenceStartTime = 0;
    }
  }
  //Serial.printf("[MEM] Free heap: %d | MQTT: %s\n", ESP.getFreeHeap(), currentMqttConnected ? "CONNECTED" : "DISCONNECTED"); 
}