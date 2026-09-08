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

/// Immutable configuration parameters for a serial connection.
class SerialConfig {
  const SerialConfig({
    this.port = '',
    this.baudRate = 115200,
    this.encoding = SerialEncoding.utf8,
    this.newLine = NewLine.none,
  });

  final String port;
  final int baudRate;
  final SerialEncoding encoding;
  final NewLine newLine;

  SerialConfig copyWith({
    String? port,
    int? baudRate,
    SerialEncoding? encoding,
    NewLine? newLine,
  }) {
    return SerialConfig(
      port: port ?? this.port,
      baudRate: baudRate ?? this.baudRate,
      encoding: encoding ?? this.encoding,
      newLine: newLine ?? this.newLine,
    );
  }

  Map<String, dynamic> toJson() => {
    'port': port,
    'baudRate': baudRate,
    'encoding': encoding.name,
    'newLine': newLine.name,
  };

  factory SerialConfig.fromJson(Map<String, dynamic> json) {
    return SerialConfig(
      port: json['port'] as String? ?? '',
      baudRate: json['baudRate'] as int? ?? 115200,
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
          encoding == other.encoding &&
          newLine == other.newLine;

  @override
  int get hashCode =>
      port.hashCode ^ baudRate.hashCode ^ encoding.hashCode ^ newLine.hashCode;
}
