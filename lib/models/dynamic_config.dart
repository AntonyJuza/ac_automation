class DynamicConfig {
  final List<String> acOnData;
  final List<String> acOffData;
  final int irFreqKhz;
  final int hdrMark;
  final int hdrSpace;
  final int bitMark;
  final int oneSpace;
  final int zeroSpace;
  final int stopMark;
  final int bitLength;
  final int sendRepeat;

  DynamicConfig({
    required this.acOnData,
    required this.acOffData,
    required this.irFreqKhz,
    required this.hdrMark,
    required this.hdrSpace,
    required this.bitMark,
    required this.oneSpace,
    required this.zeroSpace,
    required this.stopMark,
    required this.bitLength,
    required this.sendRepeat,
  });

  Map<String, String> toPayload() {
    return {
      'acOn': acOnData.join(','),
      'acOff': acOffData.join(','),
      'IR_FREQ_KHZ': irFreqKhz.toString(),
      'HDR_MARK': hdrMark.toString(),
      'HDR_SPACE': hdrSpace.toString(),
      'BIT_MARK': bitMark.toString(),
      'ONE_SPACE': oneSpace.toString(),
      'ZERO_SPACE': zeroSpace.toString(),
      'STOP_MARK': stopMark.toString(),
      'BIT_LENGTH': bitLength.toString(),
      'SEND_REPEAT': sendRepeat.toString(),
    };
  }
}
