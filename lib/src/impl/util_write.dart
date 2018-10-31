//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Aug 10, 2013 12:02:59 AM
// Author: tomyeh
part of stomp_impl_util;

//Commands//
const String CONNECT = "CONNECT";
const String STOMP = "STOMP";
const String CONNECTED = "CONNECTED";
const String DISCONNECT = "DISCONNECT";
const String SEND = "SEND";
const String SUBSCRIBE = "SUBSCRIBE";
const String UNSUBSCRIBE = "UNSUBSCRIBE";
const String MESSAGE = "MESSAGE";
const String RECEIPT = "RECEIPT";
const String ERROR = "ERROR";
const String ACK = "ACK";
const String NACK = "NACK";
const String BEGIN = "BEGIN";
const String COMMIT = "COMMIT";
const String ABORT = "ABORT";

/** Writes the headers (excluding body and End-of-Frame)
 *
 * * [endOfHeaders] - specifies whether to write an empty line to
 * indicate the end of the headers.
 */
void writeHeaders(
    StompConnector connector, String command, Map<String, String> headers,
    {bool endOfHeaders: true}) {
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

  if (endOfHeaders) connector.writeLF();
}

///Write a simple frame, such as STOMP, CONNECTED.
void writeSimpleFrame(
    StompConnector connector, String command, Map<String, String> headers) {
  writeHeaders(connector, command, headers);
  connector.writeEof();
}

///Write a data frame used by SEND, ERROR and MESSAGE.
void writeDataFrame(StompConnector connector, String command,
    Map<String, String> headers, String string,
    [List<int> bytes]) {
  writeHeaders(connector, command, headers, endOfHeaders: false);

  if (headers == null || headers[CONTENT_LENGTH] == null) {
    int len = 0;
    if (bytes != null) {
      len = bytes.length;
    } else if (string != null && !string.isEmpty) {
      bytes = utf8.encode(string);
      len = bytes.length;
    }
    connector
      ..write(CONTENT_LENGTH)
      ..write(':')
      ..write(len.toString())
      ..writeLF();
  }

  connector.writeLF();
  connector.write(string, bytes);
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

/** Adds the additional headers ([extra]) into a given header ([headers]).
 * If both [headers] and [extra] are null, null is returned.
 * Otherwise, a non-null map is returned.
 */
Map<String, String> addHeaders(
    Map<String, String> headers, Map<String, String> extra) {
  if (headers != null || extra != null) {
    if (headers == null) headers = new LinkedHashMap();
    if (extra != null) headers.addAll(extra);
  }
  return headers;
}

String _escape(String value) {
  if (value == null) return "";

  StringBuffer buf;
  int pre = 0;
  for (int i = 0, len = value.length; i < len; ++i) {
    final String cc = value[i];
    String esc;
    switch (cc) {
      case '\r':
        esc = 'r';
        break;
      case '\n':
        esc = 'n';
        break;
      case ':':
        esc = 'c';
        break;
      case '\\':
        esc = '\\';
        break;
    }
    if (esc != null) {
      if (buf == null) buf = new StringBuffer();
      buf..write(value.substring(pre, i))..write('\\')..write(esc);
      pre = i + 1;
    }
  }
  return buf != null ? (buf..write(value.substring(pre))).toString() : value;
}
