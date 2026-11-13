/// Supported serial text encodings.
enum SerialEncoding { utf8, latin1, raw, hex }

/// Extension providing display labels for [SerialEncoding].
extension SerialEncodingLabel on SerialEncoding {
  String get label => switch (this) {
    SerialEncoding.utf8 => 'UTF-8',
    SerialEncoding.latin1 => 'Latin1',
    SerialEncoding.raw => 'Raw',
    SerialEncoding.hex => 'Hex',
  };
}

/// Line termination modes appended to user input before transmission.
enum NewLine { lf, crlf, cr, none }

/// Extension providing display labels and suffix strings for [NewLine].
extension NewLineExt on NewLine {
  String get label => switch (this) {
    NewLine.lf => 'LF',
    NewLine.crlf => 'CR+LF',
    NewLine.cr => 'CR',
    NewLine.none => 'None',
  };

  String get suffix => switch (this) {
    NewLine.lf => '\n',
    NewLine.crlf => '\r\n',
    NewLine.cr => '\r',
    NewLine.none => '',
  };
}

/// Supported serial parity modes.
enum SerialParity { none, odd, even, mark, space }

/// Extension providing display labels and Win32 DCB parity values.
extension SerialParityExt on SerialParity {
  String get label => switch (this) {
    SerialParity.none => 'None',
    SerialParity.odd => 'Odd',
    SerialParity.even => 'Even',
    SerialParity.mark => 'Mark',
    SerialParity.space => 'Space',
  };

  /// Win32 DCB `Parity` byte value (`NOPARITY=0 .. SPACEPARITY=4`).
  int get win32Value => index;
}

/// Supported serial stop-bit modes.
enum SerialStopBits { one, onePointFive, two }

/// Extension providing display labels and Win32 DCB stop-bit values.
extension SerialStopBitsExt on SerialStopBits {
  String get label => switch (this) {
    SerialStopBits.one => '1',
    SerialStopBits.onePointFive => '1.5',
    SerialStopBits.two => '2',
  };

  /// Win32 DCB `StopBits` byte value (`ONESTOPBIT=0, ONE5STOPBITS=1, TWOSTOPBITS=2`).
  int get win32Value => index;

  int get libserialportValue => this == SerialStopBits.two ? 2 : 1;
}

/// Supported serial flow control modes.
enum SerialFlowControl { none, rtsCts, xonXoff }

/// Extension providing display labels for [SerialFlowControl].
extension SerialFlowControlExt on SerialFlowControl {
  String get label => switch (this) {
    SerialFlowControl.none => 'None',
    SerialFlowControl.rtsCts => 'RTS/CTS',
    SerialFlowControl.xonXoff => 'XON/XOFF',
  };
}

/// Immutable configuration parameters for a serial connection.
class SerialConfig {
  const SerialConfig({
    this.port = '',
    this.baudRate = 115200,
    this.dataBits = 8,
    this.parity = SerialParity.none,
    this.stopBits = SerialStopBits.one,
    this.flowControl = SerialFlowControl.none,
    this.encoding = SerialEncoding.utf8,
    this.newLine = NewLine.none,
  });

  final String port;
  final int baudRate;
  final int dataBits;
  final SerialParity parity;
  final SerialStopBits stopBits;
  final SerialFlowControl flowControl;
  final SerialEncoding encoding;
  final NewLine newLine;

  SerialConfig copyWith({
    String? port,
    int? baudRate,
    int? dataBits,
    SerialParity? parity,
    SerialStopBits? stopBits,
    SerialFlowControl? flowControl,
    SerialEncoding? encoding,
    NewLine? newLine,
  }) {
    return SerialConfig(
      port: port ?? this.port,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      parity: parity ?? this.parity,
      stopBits: stopBits ?? this.stopBits,
      flowControl: flowControl ?? this.flowControl,
      encoding: encoding ?? this.encoding,
      newLine: newLine ?? this.newLine,
    );
  }

  Map<String, dynamic> toJson() => {
    'port': port,
    'baudRate': baudRate,
    'dataBits': dataBits,
    'parity': parity.name,
    'stopBits': stopBits.name,
    'flowControl': flowControl.name,
    'encoding': encoding.name,
    'newLine': newLine.name,
  };

  factory SerialConfig.fromJson(Map<String, dynamic> json) {
    final rawBits = json['dataBits'] as int? ?? 8;
    return SerialConfig(
      port: json['port'] as String? ?? '',
      baudRate: json['baudRate'] as int? ?? 115200,
      dataBits: (rawBits >= 5 && rawBits <= 8) ? rawBits : 8,
      parity: SerialParity.values.firstWhere(
        (e) => e.name == json['parity'],
        orElse: () => SerialParity.none,
      ),
      stopBits: SerialStopBits.values.firstWhere(
        (e) => e.name == json['stopBits'],
        orElse: () => SerialStopBits.one,
      ),
      flowControl: SerialFlowControl.values.firstWhere(
        (e) => e.name == json['flowControl'],
        orElse: () => SerialFlowControl.none,
      ),
      encoding: SerialEncoding.values.firstWhere(
        (e) => e.name == json['encoding'],
        orElse: () => SerialEncoding.utf8,
      ),
      newLine: NewLine.values.firstWhere(
        (e) => e.name == json['newLine'],
        orElse: () => NewLine.none,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerialConfig &&
          runtimeType == other.runtimeType &&
          port == other.port &&
          baudRate == other.baudRate &&
          dataBits == other.dataBits &&
          parity == other.parity &&
          stopBits == other.stopBits &&
          flowControl == other.flowControl &&
          encoding == other.encoding &&
          newLine == other.newLine;

  @override
  int get hashCode => Object.hash(
    port,
    baudRate,
    dataBits,
    parity,
    stopBits,
    flowControl,
    encoding,
    newLine,
  );
}
