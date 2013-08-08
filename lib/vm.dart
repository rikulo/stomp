//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:54:51 PM
// Author: tomyeh
library stomp_vm;

import "dart:async";
import "dart:io";
import "dart:utf" show encodeUtf8;
import "package:meta/meta.dart";

import "stomp.dart" show StompClient;
import "impl/plugin.dart";

/** Connects a STOMP server, and instantiates a [StompClient]
 * to represent the connection.
 *
 *     import "package:stomp/stomp.dart";
 *     import "package:stomp/vm.dart" show connect;
 * 
 *     void main() {
 *       connect("foo.server.com").then((StompClient stomp) {
 *         stomp.subscribeString("/foo", (String message) {
 *           print("Recieve $message");
 *         });
 * 
 *         stomp.sendString("/foo", "Hi, Stomp");
 *       });
 *     }
 *
 * * [address] - either be a [String] or an [InternetAddress]. If it is a String,
 * it will perform a[] InternetAddress.lookup] and use the first value in the list.
 */
Future<StompClient> connect(address, {int port: 61626,
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message)})
=> Socket.connect(address, port).then((Socket socket)
  => StompClient.connect(new _StompConnector(socket),
    host: host, login: login, passcode: passcode, heartbeat: heartbeat,
    onDisconnect: onDisconnect, onError: onError));

///The implementation
class _StompConnector extends StompConnector {
  final Socket _socket;

  _StompConnector(this._socket) {
    _init();
  }
  void _init() {
    ///Note: when this method is called, onBytes/onError/onClose are not set yet
    _socket.listen((List<int> data) {
      if (data != null && !data.isEmpty)
        onBytes(data);
    }, onError: (error) {
      onError(error);
    }, onDone: () {
      onClose();
    });
  }

  @override
  void set encoding(String encoding) {
    if (encoding != "UTF-8") //TODO: we can support it (because dart:io supports it)
      throw new UnsupportedError(encoding);
  }

  @override
  void writeBytes(List<int> data) {
    _socket.add(data);
  }
  @override
  void writeString(String data) {
    _socket.add(encodeUtf8(data));
  }
  @override
  Future writeStream(Stream<List<int>> stream)
  => _socket.addStream(stream);
  @override
  void writeNull() {
    writeBytes(_NULL);
  }
  @override
  void writeLF() {
    writeBytes(_LF);
  }
}

const List<int> _NULL = const [0];
const List<int> _LF = const [10];
