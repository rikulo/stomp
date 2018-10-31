//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:52:46 PM
// Author: tomyeh
library stomp_impl_plugin;

import "dart:async";
import "dart:convert" show utf8;

typedef void BytesCallback(List<int> data);
typedef void StringCallback(String data);
/** The error callback.
 *
 * * [error] - the error. It could be an exception, or
 * an event (e.g., received in `WebSocket.onError`)
 */
typedef void ErrorCallback(error, stackTrace);
typedef void CloseCallback();

/** A STOMP connector for binding with different networking, such as
 * WebSocket and Socket.
 */
abstract class StompConnector {
  /** Closes the connector.
   */
  Future close();

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

const List<int> _EOF = const [0];
const List<int> _LF = const [10];
const String _EOF_STRING = '\x00';

/** A skeletal implementation for bytes-based connector.
 * The subclass shall implement [writeBytes_] and [writeStream_].
 */
abstract class BytesStompConnector extends StompConnector {
  final List<int> _buf = new List(_BUFFER_SIZE);
  int _buflen = 0;

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
    _flushAsync();
    return writeStream_(stream);
  }

  void _write(List<int> bytes) {
    final int len = bytes.length;
    if (len >= _MIN_FRAME_SIZE || _buflen + len >= _BUFFER_SIZE) {
      //_buf will be full
      _flush();

      if (len >= _MIN_FRAME_SIZE) {
        writeBytes_(bytes);
        return;
      }
    }

    for (int i = 0; i < len; ++i) _buf[_buflen++] = bytes[i];
  }

  void _flush() {
    if (_buflen > 0) {
      final int len = _buflen;
      _buflen = 0;
      writeBytes_(_buf.sublist(0, len));
    }
  }

  void _flushAsync() {
    //to accumulate multiple _flush into one, if any
    scheduleMicrotask(() {
      _flush();
    });
  }

  @override
  void write(String string, [List<int> bytes]) {
    if (bytes != null) {
      _write(bytes);
    } else if (string != null && !string.isEmpty) {
      _write(utf8.encode(string));
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

/** A skeletal implementation for String-based connector.
 * The subclass shall implement [writeString_].
 */
abstract class StringStompConnector extends StompConnector {
  final StringBuffer _buf = new StringBuffer();

  /** Writes bytes (aka., octets) for sending to the peer.
   * The deriving class shall provide an implementation.
   * It is called only internally.
   */
  void writeString_(String string);

  @override
  void write(String string, [List<int> bytes]) {
    if (string != null) {
      _write(string);
    } else if (bytes != null && !bytes.isEmpty) {
      _write(utf8.decode(bytes));
    }
  }

  void _write(String data) {
    final int len = data.length;
    if (_buf.length + len >= _BUFFER_SIZE) {
      //_buf will be full
      _flush();

      for (int i = 0;;) {
        final int j = i + _BUFFER_SIZE;
        if (j > len) {
          data = data.substring(i);
          break;
        }
        writeString_(data.substring(i, j));
        i = j;
      }
    }
    _buf.write(data);
  }

  void _flush() {
    if (!_buf.isEmpty) {
      final String str = _buf.toString();
      _buf.clear();
      writeString_(str);
    }
  }

  void _flushAsync() {
    //to accumulate multiple _flush into one, if any
    scheduleMicrotask(() {
      _flush();
    });
  }

  @override
  Future writeStream(Stream<List<int>> stream) {
    _flushAsync();

    final Completer completer = new Completer();
    stream.listen((List<int> data) {
      write(null, data);
    }, onDone: () {
      completer.complete();
    }, onError: (error, stackTrace) {
      completer.completeError(error, stackTrace);
    });
    return completer.future;
  }

  @override
  void writeEof() {
    _write(_EOF_STRING);
    _flush();
  }

  @override
  void writeLF() {
    _write("\n");
  }
}
