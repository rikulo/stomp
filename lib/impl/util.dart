//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:52:15 PM
// Author: tomyeh
library stomp_impl_util;

import "plugin.dart" show StompConnector;

///Writes the headers (excluding body and End-of-Frame)
void writeHeaders(StompConnector connector, String command,
    Map<String, String> headers) {
  connector
    ..write(command)
    ..writeLF();

  if (headers != null)
    for (final String name in headers.keys) {
      connector
        ..write(_escape(name))
        ..write(':')
        ..write(_escape(headers[name]));
    }
}

///Write a simple frame.
void writeFrame(StompConnector connector, String command,
    Map<String, String> headers, [String text, List<int> bytes]) {
  writeHeaders(connector, command, headers);
  connector.write(text, bytes);
  connector.writeEof();
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
