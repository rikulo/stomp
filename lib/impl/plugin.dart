//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:52:46 PM
// Author: tomyeh
library stomp_impl_plugin;

import "dart:async";
import "../stomp.dart" show StompClient;

typedef void OnBytesCallback(List<int> data);
typedef void OnStringCallback(String data);
typedef void OnErrorCallback(error);
typedef void OnCloseCallback();

/** A STOMP connector for binding with different networking, such as
 * WebSocket and Socket.
 */
abstract class StompConnector {
  /** The encoding. Default: UTF-8.
   *
   * If the implementation doesn't support other kind of encoding,
   * just throw an exception.
   */
  String encoding = "UTF-8";

  ///Write an array of bytes
  void writeBytes(List<int> data);
  ///Write a string
  void writeString(String data);
  ///Write a stream
  Future writeStream(Stream<List<int>> stream);
  ///Write the NULL octet to indicate the end
  void writeNull();
  ///Write the end of line (LF)
  void writeLF();

  /** Called when data in bytes format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation needs only to support one of
   * [onBytes] and [onString], depending how data is transmitted.
   */
  OnBytesCallback onBytes;
  /** Called when data in String format is received.
   * The implementation can assume it is never null.
   *
   * Note: the implementation needs only to support one of
   * [onBytes] and [onString], depending how data is transmitted.
   */
  OnStringCallback onString;
  /** Called when there is an error.
   * The implementation can assume it is never null.
   */
  OnErrorCallback onError;
  /** Called when the connection is closed.
   * The implementation can assume it is never null.
   */
  OnCloseCallback onClose;
}
