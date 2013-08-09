//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Aug 10, 2013 12:02:59 AM
// Author: tomyeh
part of stomp_impl_util;

/** Writes the headers (excluding body and End-of-Frame)
 *
 * * [endOfHeaders] - specifies whether to write an empty line to
 * indicate the end of the headers.
 */
void writeHeaders(StompConnector connector, String command,
    Map<String, String> headers, {bool endOfHeaders: true}) {
  connector
    ..write(command)
    ..writeLF();

  if (headers != null) {
    for (final String name in headers.keys) {
      connector
        ..write(_escape(name))
        ..write(':')
        ..write(_escape(headers[name]))
        ..writeLF();
    }
  }

  if (endOfHeaders)
    connector.writeLF();
}

///Write a simple frame, such as STOMP, CONNECTED.
void writeSimpleFrame(StompConnector connector, String command,
    Map<String, String> headers) {
  writeHeaders(connector, command, headers);
  connector.writeEof();
}

///Write a data frame, such as SEND, ERROR.
void writeDataFrame(StompConnector connector, String command,
    Map<String, String> headers, String text, [List<int> bytes]) {
  writeHeaders(connector, command, headers, endOfHeaders: false);

  int len = 0;
  if (bytes != null) {
    len = bytes.length;
  } else if (text != null && !text.isEmpty) {
    bytes = encodeUtf8(text);
    len = bytes.length;
  }
  connector..write("content-length:")
    ..write(len.toString())..writeLF()..writeLF();

  connector.write(text, bytes);
  connector.writeEof();
}

///Write a frame from the given stream
Future writeStreamFrame(StompConnector connector, String command,
    Map<String, String> headers, Stream<List<int>> stream) {
  writeHeaders(connector, command, headers);
  return connector.writeStream(stream).then((_) {
    connector.writeEof();
  });
}

String _escape(String value) {
  if (value == null)
    return "";

  StringBuffer buf;
  int pre = 0;
  for (int i = 0, len = value.length; i < len; ++i) {
    final String cc = value[i];
    String esc;
    switch (cc) {
      case '\r': esc = 'r'; break;
      case '\n': esc = 'n'; break;
      case ':': esc = 'c'; break;
      case '\\': esc = '\\'; break;
    }
    if (esc != null) {
      if (buf != null)
        buf = new StringBuffer();
      buf
        ..write(value.substring(pre, i))
        ..write('\\')
        ..write(esc);
      pre = i + 1;
    }
  }
  return buf != null ? (buf..write(value.substring(pre))).toString(): value;
}
