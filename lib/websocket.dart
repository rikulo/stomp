//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:56:09 PM
// Author: tomyeh
library stomp_websocket;

import "dart:async";
import "dart:html" show WebSocket, MessageEvent, ByteBuffer;
import "dart:utf" show decodeUtf8;
import "package:meta/meta.dart";

import "stomp.dart" show StompClient;
import "impl/plugin.dart" show StompConnector;

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
=> StompClient.connect(new _WSStompConnector(url),
    host: host, login: login, passcode: passcode, heartbeat: heartbeat,
    onDisconnect: onDisconnect, onError: onError);

///The implementation
class _WSStompConnector extends StompConnector {
  final WebSocket _socket;
  final StringBuffer _buf = new StringBuffer();

  _WSStompConnector(String url): _socket = new WebSocket(url) {
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
  void write(String string, [List<int> bytes]) {
    if (string != null) {
      _write(string);
    } else if (bytes != null && !bytes.isEmpty) {
      _write(decodeUtf8(bytes));
    }
  }
  void _write(String data) {
    final int len = data.length;
    if (_buf.length + len >= _MAX_FRAME_SIZE) { //_buf will be full
      _flush();

      for (int i = 0;;) {
        final int j = i + _MAX_FRAME_SIZE;
        if (j > len) {
          data = data.substring(i);
          break;
        }
        _socket.send(data.substring(i, j));
        i = j;
      }

    }
    _buf.write(data);
  }
  void _flush() {
    if (!_buf.isEmpty) {
      final String str = _buf.toString();
      _buf.clear();
      _socket.send(str);
    }
  }

  @override
  Future writeStream(Stream<List<int>> stream) {
    final Completer completer = new Completer();
    stream.listen((List<int> data) {
      write(null, data);
    }, onDone: () {
      completer.complete();
    }, onError: (error) {
      completer.completeError(error);
    });
    return completer.future;
  }
  @override
  void writeEof() {
    _write(_EOF);
    _flush();
  }
  @override
  void writeLF() {
    _write("\n");
  }
}

const String _EOF = '\x00';
const int _MAX_FRAME_SIZE = 16 * 1024;
