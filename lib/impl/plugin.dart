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
  /** Write an array of bytes or a String text.
   *
   * *Implementation Notes*
   *
   * If both [bytes] and [text] are specified, they must be
   * equivalent and the implementation can pick up any one that
   * is easier to handle.
   *
   * Otherwise, this method shall pick the non-null one.
   */
  void write(List<int> bytes, String text);
  ///Write a stream
  Future writeStream(Stream<List<int>> stream);
  ///Write the NULL octet to indicate the end of a frame.
  void writeEof();
  ///Write the end of line (LF)
  void writeLF();

  /** Called when data in bytes format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation needs only to support one of
   * [onBytes] and [onString], depending how data is transmitted.
   */
  BytesCallback onBytes;
  /** Called when data in String format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation needs only to support one of
   * [onBytes] and [onString], depending how data is transmitted.
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

/** A skeletal implementation for binary connector.
 * The deriving class shall implement [listen_], [write_] and [addStream].
 */
abstract class BytesStompConnector extends StompConnector {
  BytesStompConnector() {
    ///Note: when this method is called, onBytes/onError/onClose are not set yet
    listen_((List<int> data) {
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
  void listen_(void onData(List<int> bytes), void onError(error), void onDone());
  /** Writes bytes (aka., octets) for sending to the peer.
   * The deriving class shall provide an implementation.
   * It is called only internally.
   */
  void write_(List<int> bytes);

  @override
  void write(List<int> bytes, String text) {
    if (bytes != null)
      write_(bytes);
    else if (text != null && !text.isEmpty)
      write_(encodeUtf8(text));
  }
  @override
  void writeEof() {
    write_(_EOF);
  }
  @override
  void writeLF() {
    write_(_LF);
  }
}

const List<int> _EOF = const [0];
const List<int> _LF = const [10];
