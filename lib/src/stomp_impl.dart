//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:51:51 PM
// Author: tomyeh
part of stomp;

typedef void _DisconnectCallback();
typedef void _ErrorCallback(String message, stackTrace);

class _StompClient implements StompClient {
  final StompConnector _connector;
  FrameParser _parser;
  String _session, _server;
  final _DisconnectCallback _onDisconnect;
  final _ErrorCallback _onError;
  ///<String id, _Subscriber>
  final Map<String, _Subscriber> _subscribers = new HashMap();

  /** A session identifier that uniquely identifies the session.
   * It is null if the server doesn't support it.
   */
  String get session => _session;
  ///The information about the STOMP server, such as `Ripple/1.0.0`.
  String get server => _server;
  /** The heart beat. A two-element array. The first element is
   * the smallest number of milliseconds that the server can do.
   * The second element is the desired number of milliseconds the
   * server would like to get.
   */
  final List<int> heartbeat = new List(2);
  Completer _connecting;
  bool _sendingBlob = false;

  static Future<StompClient> connect(StompConnector connector,
      String host, String login, String passcode, List<int> heartbeat,
      void onDisconnect(),
      void onError(String message, stackTrace)) {
    _StompClient client = new _StompClient(connector, onDisconnect, onError);
    client._connecting = new Completer();

    final Map<String, String> headers = new LinkedHashMap();
    headers["accept-version"] = "1.2";
    if (host != null)
      headers["host"] = host;
    if (login != null)
      headers["login"] = login;
    if (passcode != null)
      headers["passcode"] = passcode;
    if (heartbeat != null) {
      client.heartbeat[0] = heartbeat[0];
      client.heartbeat[1] = heartbeat[1];
      headers["heartbeat"] = heartbeat.join(",");
    } else {
      client.heartbeat[0] = client.heartbeat[1] = 0;
    }
    writeSimpleFrame(connector, STOMP, headers);

    return client._connecting.future;
  }

  _StompClient(this._connector, this._onDisconnect, this._onError) {
    _init();
  }
  void _init() {
    _parser = new FrameParser((Frame frame) {
print("<<from server:${frame.command}:${frame.headers}:${frame.message}");
      final _FrameHandler handler = _frameHandlers[frame.command];
      if (handler != null)
        handler(this, frame);
      else
        _handleErr("Unknown command: ${frame.command}");
    }, (error, stackTrace) {
      _handleErr(error, stackTrace);
    });

    _connector
      ..onBytes = (List<int> data) {
        _parser.addBytes(data);
      }
      ..onString = (String data) {
        _parser.addString(data);
      }
      ..onError = (error, stackTrace) {
        _handleErr(error, stackTrace);
      }
      ..onClose = () {
        //TODO
      };
  }
  void _handleErr(error, [stackTrace]) {
    if (_onError != null) {
      _onError("$error", stackTrace);
    } else {
      print(stackTrace != null ? "$error\n$stackTrace": "$error");
    }
  }

  @override
  Future disconnect({String receipt}) {

  }

  @override
  void sendBytes(String destination, List<int> message,
      {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(_connector, SEND, _headerOfSend(headers, destination),
      null, message);
  }

  @override
  void sendString(String destination, String message,
      {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(_connector, SEND,
      _headerOfSend(headers, destination, "text/plain"), message);
  }
  @override
  void sendJson(String destination, message,
      {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(_connector, SEND,
      _headerOfSend(headers, destination, "application/json"),
      Json.stringify(message));
  }

  @override
  Future sendBlob(String destination, Stream<List<int>> message,
      {Map<String, String> headers}) {
    _checkSend();
    _sendingBlob = true;
    return writeStreamFrame(_connector, SEND,
        _headerOfSend(headers, destination), message).whenComplete(() {
      _sendingBlob = false;
    });
  }

  //utilities of send//
  static Map<String, String> _headerOfSend(Map<String, String> headers,
      String destination, [String contentType])
  => _addContentType(addHeaders(headers, {"destination": destination}),
        "text/plain");

  static Map<String, String> _addContentType(
      Map<String, String> headers, String contentType) {
    if (headers == null || headers[CONTENT_TYPE] == null) {
      headers = headers != null ? new LinkedHashMap.from(headers): new LinkedHashMap();
      headers[CONTENT_TYPE] = contentType;
    }
    return headers;
  }
  void _checkSend() {
    if (_sendingBlob)
      throw new StateError("Previous sending of BLOB not completed yet");
  }


  @override
  void subscribeBytes(String id, String destination,
      void onMessage(Map<String, String> headers, List<int> message),
      {Ack ack: AUTO}) {
    _subscribe(new _Subscriber.bytes(id, destination, onMessage, ack));
  }
  @override
  void subscribeString(String id, String destination,
      void onMessage(Map<String, String> headers, String message),
      {Ack ack: AUTO}) {
    _subscribe(new _Subscriber.string(id, destination, onMessage, ack));
  }
  @override
  void subscribeJson(String id, String destination,
      void onMessage(Map<String, String> headers, message),
      {Ack ack: AUTO}) {
    _subscribe(new _Subscriber.json(id, destination, onMessage, ack));
  }
  @override
  void subscribeBlob(String id, String destination,
      void onMessage(Map<String, String> headers, Stream<List<int>> message),
      {Ack ack: AUTO}) {
    _subscribe(new _Subscriber.blob(id, destination, onMessage, ack));
  }
  @override
  void unsubscribe(String id) {
    final _Subscriber sub = _subscribers[id];
    if (sub != null) {
      _subscribers.remove(id);

      writeSimpleFrame(_connector, UNSUBSCRIBE, {"id": id});
    }
  }

  void _subscribe(_Subscriber subscriber) {
    final String id = subscriber.id;
    if (_subscribers.containsKey(id))
      throw new StateError("Subscription $id can't be subscribed twice");

    _subscribers[id] = subscriber;

    final Map<String, String> headers = {
      "id": id,
      "destination": subscriber.destination
    };
    final Ack ack = subscriber.ack;
    if (ack != AUTO)
      headers["ack"] = ack.id;

    writeSimpleFrame(_connector, SUBSCRIBE, headers);
  }

  //Frame Handlers//
  void _connected(Frame frame) {
    final Map<String, String> headers = frame.headers;
    if (headers != null) {
      _session = headers["session"];
      _server = headers["server"];
      _handleHeartbeat(this, headers["heart-beat"]);
    }

    final Completer connecting = _connecting;
    if (connecting != null) {
      //FUTURE: check version
      _connecting = null;
      connecting.complete(this);
    }
  }
  void _error(Frame frame) {
    final Completer connecting = _connecting;
    if (connecting != null) {
      _connecting = null;
      connecting.completeError(frame.message);
    } else {
      _handleErr(frame.message);
    }
  }

  void _message(Frame frame) {
    final Map<String, String> headers = frame.headers;
    if (headers != null) {
      final String id = headers["subscription"];
      if (id != null) {
        final _Subscriber sub = _subscribers[id];
        if (sub != null && sub.destination == headers["destination"]) {
          switch (sub.type) {
            case _SUB_BYTES:
              sub.callback(frame.headers, frame.messageBytes);
              break;
            case _SUB_STRING:
              sub.callback(frame.headers, frame.message);
              break;
            case _SUB_JSON:
              sub.callback(frame.headers, Json.parse(frame.message));
              break;
            case _SUB_BLOB:
              sub.callback(frame.headers,
                new Stream.fromIterable([frame.messageBytes]));
              break;
          }
        }
      }
    }
  }
}

typedef void _FrameHandler(_StompClient client, Frame frame);
final Map<String, _FrameHandler> _frameHandlers = {
  "CONNECTED": (_StompClient client, Frame frame) {
    client._connected(frame);
  },
  "ERROR": (_StompClient client, Frame frame) {
    client._error(frame);
  },
  "MESSAGE": (_StompClient client, Frame frame) {
    client._message(frame);
  },
};
