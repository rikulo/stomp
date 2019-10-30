//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Aug 15, 2013  9:48:37 AM
// Author: tomyeh
library stomp_impl_plugin_vm;

import "dart:async";
import 'package:web_socket_channel/io.dart';
import "plugin.dart" show StringStompConnector;
import 'package:web_socket_channel/status.dart' as status;

/** The implementation on top of [Socket].
 */
class SocketStompConnector extends StringStompConnector {
  final IOWebSocketChannel _socket;
  StreamSubscription _listen;

  SocketStompConnector(this._socket) {
    _init();
  }
  void _init() {
    _listen = _socket.stream.listen((data)  {
      if (data != null) {
        final String sdata = data.toString();
        if (sdata.isNotEmpty) onString(sdata);
      }
    });
    
    _listen.onError((err) => onError(err, null));
    _listen.onDone(() => onClose());

    _socket.stream.handleError((error) => onError(error, null));

    _socket.sink.done.then((v) {
      onClose();
    });
  }

  @override
  Future close() {
    _listen.cancel();
    _socket.sink.close(status.goingAway);
    return new Future.value();
  }
 
  @override
  Future writeStream_(Stream<List<int>> stream)
  => _socket.sink.addStream(stream);

  @override
  void writeString_(String string) {
    _socket.sink.add(string);
    // TODO: implement writeString_
  }
}
