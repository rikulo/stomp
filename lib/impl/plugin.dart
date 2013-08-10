//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:52:46 PM
// Author: tomyeh
library stomp_impl_plugin;

import "dart:async";
import "dart:utf" show encodeUtf8;
import "package:meta/meta.dart";
import "../stomp.dart" show StompClient;

typedef void BytesCallback(List<int> data);
typedef void StringCallback(String data);
typedef void ErrorCallback(error);
typedef void CloseCallback();

/** A STOMP connector for binding with different networking, such as
 * WebSocket and Socket.
 */
abstract class StompConnector {
  /** Write an array of bytes or a [String].
   *
   * *Implementation Notes*
   *
   * If both [bytes] and [string] are specified, they must be
   * equivalent and the implementation can pick up any one that
   * is easier to handle.
   *
   * Otherwise, this method shall pick the non-null one.
   */
  void write(String string, [List<int> bytes]);
  ///Write a stream
  Future writeStream(Stream<List<int>> stream);
  ///Write the NULL octet to indicate the end of a frame.
  void writeEof();
  ///Write the end of line (LF)
  void writeLF();

  /** Called when data in bytes format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation shall invoke [onBytes] or [onString],
   * but not both.
   */
  BytesCallback onBytes;
  /** Called when data in String format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation shall invoke [onBytes] or [onString],
   * but not both.
   */
  StringCallback onString;
  /** Called when there is an error.
   * The implementation can assume it is never null.
   */
  ErrorCallback onError;
  /** Called when the connection is closed.
   * The implementation can assume it is never null.
   */
  CloseCallback onClose;
}

const int _BUFFER_SIZE = 16 * 1024;
const int _MIN_FRAME_SIZE = _BUFFER_SIZE ~/ 4;

/** A skeletal implementation for binary connector.
 * The subclass shall implement [listenBytes_], [writeBytes_]
 * and [writeStream_].
 */
abstract class BytesStompConnector extends StompConnector {
  final List<int> _buf = new List(_BUFFER_SIZE);
  int _buflen = 0;

  BytesStompConnector() {
    ///Note: when this method is called, onBytes/onError/onClose are not set yet
    listenBytes_((List<int> data) {
      if (data != null && !data.isEmpty)
        onBytes(data);
    }, (error) {
      onError(error);
    }, () {
      onClose();
    });
  }

  /** Adds listeners to this connector.
   * The deriving class shall provide an implementation.
   * It is called internally when the constructor is called.
   */
  void listenBytes_(void onData(List<int> bytes), void onError(error), void onDone());
  /** Writes bytes (aka., octets) for sending to the peer.
   * The deriving class shall provide an implementation.
   * It is called only internally.
   */
  void writeBytes_(List<int> bytes);
  /** Writes the given stream.
   * Subclass shall implement this method, and shall not override [writeStream].
   */
  Future writeStream_(Stream<List<int>> stream);

  @override
  Future writeStream(Stream<List<int>> stream) {
    _flush();
    return writeStream_(stream);
  }

  void _write(List<int> bytes) {
    final int len = bytes.length;
    if (len >= _MIN_FRAME_SIZE || _buflen + len >= _BUFFER_SIZE) { //_buf will be full
      _flush();

      if (len >= _MIN_FRAME_SIZE) {
        writeBytes_(bytes);
        return;
      }
    }

    for (int i = 0; i < len; ++i)
      _buf[_buflen++] = bytes[i];
  }
  void _flush() {
    if (_buflen > 0) {
      final int len = _buflen;
      _buflen = 0;
      writeBytes_(_buf.sublist(0, len));
    }
  }

  @override
  void write(String string, [List<int> bytes]) {
    if (bytes != null) {
       _write(bytes);
    } else if (string != null && !string.isEmpty) {
      _write(encodeUtf8(string));
    }
  }
  @override
  void writeEof() {
    _write(_EOF);
    _flush();
  }
  @override
  void writeLF() {
    _write(_LF);
  }
}

const List<int> _EOF = const [0];
const List<int> _LF = const [10];
