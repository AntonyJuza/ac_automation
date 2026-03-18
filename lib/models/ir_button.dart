/// How this button's IR signal is stored and replayed.
enum IRMethod { encoded, raw }

/// One captured IR button.
/// - [method] == encoded: use hex words + timing params → sendPulseDistanceWidthFromArray
/// - [method] == raw:     use rawData timing array     → sendRaw (fallback)
class IRButton {
  final String name;
  final IRMethod method;

  // ── Encoded fields (PulseDistance protocol) ──────────────────
  final List<String>? hexData;   // e.g. ["0x90E428", "0x98010100"]
  final int? bits;               // total bit count, e.g. 96
  final int? hdrMark;
  final int? hdrSpace;
  final int? bitMark;
  final int? oneSpace;
  final int? zeroSpace;

  // ── Raw fallback ─────────────────────────────────────────────
  final List<int>? rawData;

  const IRButton({
    required this.name,
    this.method = IRMethod.raw,
    this.hexData,
    this.bits,
    this.hdrMark,
    this.hdrSpace,
    this.bitMark,
    this.oneSpace,
    this.zeroSpace,
    this.rawData,
  });

  bool get isEncoded => method == IRMethod.encoded;
  bool get isValid   => isEncoded
      ? (hexData != null && hexData!.isNotEmpty && bits != null)
      : (rawData != null && rawData!.isNotEmpty);

  Map<String, dynamic> toJson() {
    if (isEncoded) {
      return {
        'name':       name,
        'method':     'encoded',
        'data':       hexData,
        'bits':       bits,
        'hdr_mark':   hdrMark,
        'hdr_space':  hdrSpace,
        'bit_mark':   bitMark,
        'one_space':  oneSpace,
        'zero_space': zeroSpace,
      };
    }
    return {
      'name':    name,
      'method':  'raw',
      'rawData': rawData,
    };
  }

  factory IRButton.fromJson(Map<String, dynamic> json) {
    final method = json['method'] == 'encoded' ? IRMethod.encoded : IRMethod.raw;
    if (method == IRMethod.encoded) {
      return IRButton(
        name:      json['name'] ?? '',
        method:    IRMethod.encoded,
        hexData:   json['data'] != null ? List<String>.from(json['data']) : null,
        bits:      json['bits'],
        hdrMark:   json['hdr_mark'],
        hdrSpace:  json['hdr_space'],
        bitMark:   json['bit_mark'],
        oneSpace:  json['one_space'],
        zeroSpace: json['zero_space'],
      );
    }
    return IRButton(
      name:    json['name'] ?? '',
      method:  IRMethod.raw,
      rawData: json['rawData'] != null ? List<int>.from(json['rawData']) : null,
    );
  }

  /// Build the SEND command string for this button.
  /// Encoded: `SEND_ENC:<key>:<bits>:<hdrMark>:<hdrSpace>:<bitMark>:<oneSpace>:<zeroSpace>:<hex1>,<hex2>...`
  /// Raw:     `SEND:<key>:<csv>`
  String toSendCommand(String key) {
    if (isEncoded) {
      return 'SEND_ENC:$key:$bits:$hdrMark:$hdrSpace:$bitMark:$oneSpace:$zeroSpace:${hexData!.join(",")}';
    }
    return 'SEND:$key:${rawData!.join(",")}';
  }
}
