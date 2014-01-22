//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:56:09 PM
// Author: tomyeh
library stomp_websocket;

import "dart:async";
import "dart:html" show WebSocket, MessageEvent, ByteBuffer;

import "stomp.dart" show StompClient;
import "impl/plugin.dart" show StringStompConnector;

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
 * 
 * Future<Map> - Map is [ "stompClient": socket, "frame": the first frame response ]
 * - the first frame response is needed in cases such as Spring 4 with a security token
 *  coming back as part of the connect message.
 */
Future<Map> connect(String url, {
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message, String detail, [Map<String, String> headers]),
    void onConnectionError(event)}) {
  
      //Need to set error in here before connection starts else connection errors are swallowed.
      return _WSStompConnector.start(url, onConnectionError: onConnectionError).then((_WSStompConnector connector)
        => StompClient.connect(connector,
            host: host, login: login, passcode: passcode, heartbeat: heartbeat,
            onDisconnect: onDisconnect, onError: onError)
      );
        
}

///The implementation
class _WSStompConnector extends StringStompConnector {
  final WebSocket _socket;
  final StringBuffer _buf = new StringBuffer();
  Completer<_WSStompConnector> _starting = new Completer();

  static Future<_WSStompConnector> start(String url, 
                                         {void onConnectionError(event)}) {
    WebSocket ws = new WebSocket(url);
    ws.onError.listen(onConnectionError);
    return new _WSStompConnector(ws)._starting.future;
  }

  _WSStompConnector(this._socket) {
    _init();  
  }
  
  void _init() {
    _socket.onOpen.listen((_) {
      _starting.complete(this);
      _starting = null;
    });
    _socket.onError.listen((event) {
      if (_starting != null) {
        _starting.completeError(event);
        _starting = null;
        if (onError != null) {
          onError("Socket error", "$event");
        }
      } else if (onError != null) {
        onError("Socket error", "$event");
      } else {
        print("Socket error: $event");
      }
    });

    ///Note: when this method is called, onString/onError/onClose are not set yet
    _socket.onMessage.listen((MessageEvent event) {
      final data = event.data;
      if (data != null) {
        //TODO: handle Blob and TypedData more effectively
        final String sdata = data.toString();
        if (!sdata.isEmpty)
          onString(sdata);
      }
    }, onError: (error, stackTrace) {
      onError(error, stackTrace);
    }, onDone: () {
      //if Socket cannot connect there is no onClose
      if (onClose != null) onClose();
    });
    _socket.onClose.listen((event) {
      if (onClose != null) onClose();
    }); 
  
  }

  @override
  void writeString_(String string) {
    _socket.send(string);
  }
  @override
  Future close() {
    _socket.close();
    return new Future.value();
  }
}

const String _EOF = '\x00';
const int _MAX_FRAME_SIZE = 16 * 1024;
