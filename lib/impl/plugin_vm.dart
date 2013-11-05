//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Aug 15, 2013  9:48:37 AM
// Author: tomyeh
library stomp_impl_plugin_vm;

import "dart:async";
import "dart:io";

import "plugin.dart" show BytesStompConnector;

/** The implementation on top of [Socket].
 */
class SocketStompConnector extends BytesStompConnector {
  final Socket _socket;

  SocketStompConnector(this._socket) {
    _init();
  }
  void _init() {
    _socket.listen((List<int> data) {
      if (data != null && !data.isEmpty)
        onBytes(data);
    }, onError: (error, stackTrace) {
      onError(error, stackTrace);
    }, onDone: () {
      onClose();
    });
  }

  @override
  Future close() {
    _socket.destroy();
    return new Future.value();
  }

  @override
  void writeBytes_(List<int> bytes) {
    _socket.add(bytes);
  }
  @override
  Future writeStream_(Stream<List<int>> stream)
  => _socket.addStream(stream);
}
