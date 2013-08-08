//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:56:09 PM
// Author: tomyeh
library stomp_websocket;

import "dart:async";
import "dart:html" show WebSocket, MessageEvent, ByteBuffer;
import "dart:utf" show decodeUtf8;
import "package:meta/meta.dart";

import "stomp.dart" show StompClient;
import "impl/plugin.dart";

/** Connects a STOMP server, and instantiates a [StompClient]
 * to represent the connection.
 *
 *     import "package:stomp/stomp.dart";
 *     import "package:stomp/websocket.dart" show connect;
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
 * * [url] -- the URL of WebSocket to connect, such as `'ws://127.0.0.1:1337/foo'`.
 */
Future<StompClient> connect(String url, {
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message)})
=> StompClient.connect(new _StompConnector(url),
    host: host, login: login, passcode: passcode, heartbeat: heartbeat,
    onDisconnect: onDisconnect, onError: onError);

///The implementation
class _StompConnector extends StompConnector {
  final WebSocket _socket;

  _StompConnector(String url): _socket = new WebSocket(url) {
    _init();
  }
  void _init() {
    ///Note: when this method is called, onString/onError/onClose are not set yet
    _socket.onMessage.listen((MessageEvent event) {
      final data = event.data;
      if (data != null) {
        //TODO: handle Blob and TypedData more effectively
        final String sdata = data.toString();
        if (!sdata.isEmpty)
          onString(sdata);
      }
    }, onError: (error) {
      onError(error);
    }, onDone: () {
      onClose();
    });
  }

  @override
  void set encoding(String encoding) {
    if (encoding != "UTF-8")
      throw new UnsupportedError(encoding);
  }

  @override
  void writeBytes(List<int> data) {
    if (data != null && !data.isEmpty)
      writeString(decodeUtf8(data));
  }
  @override
  void writeString(String data) {
    if (data != null && !data.isEmpty) {
      final int len = data.length;
      if (len <= _MAX_FRAME_SIZE) {
        _socket.send(data);
      } else {
        for (int i = 0;;) {
          final int j = i + _MAX_FRAME_SIZE;
          final bool end = j >= len;
          _socket.send(data.substring(i, end ? len: j));
          if (end)
            break; //done
          i = j;
        }
      }
    }
  }
  @override
  Future writeStream(Stream<List<int>> stream) {
    final Completer completer = new Completer();
    stream.listen((List<int> data) {
      writeBytes(data);
    }, onDone: () {
      completer.complete();
    }, onError: (error) {
      completer.completeError(error);
    });
    return completer.future;
  }
  @override
  void writeNull() {
    writeString(_NULL);
  }
  @override
  void writeLF() {
    writeString("\n");
  }
}

final String _NULL = new String.fromCharCode(0);
const int _MAX_FRAME_SIZE = 16 * 1024;
