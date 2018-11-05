//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:51:51 PM
// Author: tomyeh
part of stomp;

typedef void _ConnectCallback(StompClient client, Map<String, String> headers);
typedef void _DisconnectCallback(StompClient client);
typedef void _ErrorCallback(StompClient client, String message, String detail,
    Map<String, String> headers);
typedef void _FaultCallback(StompClient client, error, stackTrace);
typedef void _ReceiptCallback(String receipt);

class _ExactMatcher implements Matcher {
  const _ExactMatcher();

  @override
  bool matches(String pattern, String destination) {
    return pattern == destination;
  }
}

class _GlobMatcher implements Matcher {
  const _GlobMatcher();

  @override
  bool matches(String pattern, String destination) {
    return new qp.Glob(pattern).hasMatch(destination);
  }
}

class _RegExpMatcher implements Matcher {
  const _RegExpMatcher();

  @override
  bool matches(String pattern, String destination) {
    return new RegExp(pattern).hasMatch(destination);
  }
}

class _AllMatcher implements Matcher {
  const _AllMatcher();

  @override
  bool matches(String pattern, String destination) {
    return true;
  }
}

class _StompClient implements StompClient {
  final StompConnector _connector;
  FrameParser _parser;
  String _session, _server;
  final _ConnectCallback _onConnect;
  final _DisconnectCallback _onDisconnect;
  final _ErrorCallback _onError;
  final _FaultCallback _onFault;

  ///<String subscription-id, _Subscriber>
  final Map<String, _Subscriber> _subscribers = new HashMap();

  ///<String receipt-id, _ReceiptCallback>
  final Map<String, _ReceiptCallback> _receipts = new HashMap();
  Completer<StompClient> _connecting;
  bool _sendingBlob = false, _disconnected = false;

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
  bool get isDisconnected => _disconnected;

  static Future<StompClient> connect(
      StompConnector connector,
      String host,
      String login,
      String passcode,
      List<int> heartbeat,
      void onConnect(StompClient client, Map<String, String> headers),
      void onDisconnect(StompClient client),
      void onError(StompClient client, String message, String detail,
          Map<String, String> headers),
      void onFault(StompClient client, error, stackTrace)) {
    final _StompClient client =
        new _StompClient(connector, onConnect, onDisconnect, onError, onFault);
    client._connecting = new Completer<StompClient>();

    final Map<String, String> headers = new LinkedHashMap();
    headers["accept-version"] = "1.2";
    if (host != null) headers["host"] = host;
    if (login != null) headers["login"] = login;
    if (passcode != null) headers["passcode"] = passcode;
    if (heartbeat != null) {
      client.heartbeat[0] = heartbeat[0];
      client.heartbeat[1] = heartbeat[1];
      headers["heart-beat"] = heartbeat.join(",");
    } else {
      client.heartbeat[0] = client.heartbeat[1] = 0;
    }
    writeSimpleFrame(connector, STOMP, headers);

    return client._connecting.future;
  }

  _StompClient(this._connector, this._onConnect, this._onDisconnect,
      this._onError, this._onFault) {
    _init();
  }
  void _init() {
    _parser = new FrameParser((Frame frame) {
      final _FrameHandler handler = _frameHandlers[frame.command];
      if (handler != null)
        handler(this, frame);
      else
        _handleFault("Unknown command: ${frame.command}", null);
    }, (error, stackTrace) {
      _handleFault(error, stackTrace);
    });

    _connector
      ..onBytes = (List<int> data) {
        _parser.addBytes(data);
      }
      ..onString = (String data) {
        _parser.addString(data);
      }
      ..onError = (error, stackTrace) {
        _handleFault(error, stackTrace);
      }
      ..onClose = () {
        _disconnected = true;
        _subscribers.clear();
        _receipts.clear();
        if (_onDisconnect != null) _onDisconnect(this);
      };
  }

  void _handleFault(error, stackTrace) {
    if (_onFault != null) {
      _onFault(this, error, stackTrace);
    } else {
      print(stackTrace != null ? "$error\n$stackTrace" : "$error");
    }
  }

  @override
  Future disconnect({String receipt}) {
    _checkSend();
    _disconnected = true;

    Completer completer;
    Map<String, String> headers;

    if (receipt != null) {
      completer = new Completer();
      headers = {"receipt": receipt};
      this.receipt(receipt, (_) {
        _connector.close().then((_) {
          completer.complete();
        });
      });
    }

    writeSimpleFrame(_connector, DISCONNECT, headers);

    return receipt != null
        ? completer.future
        : new Future.delayed(
            const Duration(milliseconds: 10), () => _connector.close());
    //delay the close a bit such that DISCONNECT will be sent successfully
  }

  @override
  void sendBytes(String destination, List<int> message,
      {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(
        _connector, SEND, _headerOfSend(headers, destination), null, message);
  }

  @override
  void sendString(String destination, String message,
      {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(_connector, SEND,
        _headerOfSend(headers, destination, "text/plain"), message);
  }

  @override
  void sendJson(String destination, message, {Map<String, String> headers}) {
    _checkSend();
    writeDataFrame(
        _connector,
        SEND,
        _headerOfSend(headers, destination, "application/json"),
        json.encode(message));
  }

  @override
  Future sendBlob(String destination, Stream<List<int>> message,
      {Map<String, String> headers}) {
    _checkSend();
    _sendingBlob = true;
    return writeStreamFrame(
            _connector, SEND, _headerOfSend(headers, destination), message)
        .whenComplete(() {
      _sendingBlob = false;
    });
  }

  //utilities of send//
  static Map<String, String> _headerOfSend(
      Map<String, String> headers, String destination,
      [String contentType]) {
    return _addContentType(addHeaders(headers, {"destination": destination}),
        (contentType == null ? "text/plain" : contentType));
  }

  static Map<String, String> _addContentType(
      Map<String, String> headers, String contentType) {
    if (headers == null || headers[CONTENT_TYPE] == null) {
      headers = headers != null
          ? new LinkedHashMap.from(headers)
          : new LinkedHashMap();
      headers[CONTENT_TYPE] = contentType;
    }
    return headers;
  }

  void _checkSend() {
    if (_sendingBlob)
      throw new StateError("Previous sending of BLOB not completed yet");
    if (_disconnected) throw new StateError("Disconnected");
  }

  @override
  void subscribeBytes(String id, String destination,
      void onMessage(Map<String, String> headers, List<int> message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders}) {
    _subscribe(new _Subscriber.bytes(id, destination, onMessage, ack, matcher),
        receipt, extraHeaders);
  }

  @override
  void subscribeString(String id, String destination,
      void onMessage(Map<String, String> headers, String message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders}) {
    _subscribe(new _Subscriber.string(id, destination, onMessage, ack, matcher),
        receipt, extraHeaders);
  }

  @override
  void subscribeJson(String id, String destination,
      void onMessage(Map<String, String> headers, message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders}) {
    _subscribe(new _Subscriber.json(id, destination, onMessage, ack, matcher),
        receipt, extraHeaders);
  }

  @override
  void subscribeBlob(String id, String destination,
      void onMessage(Map<String, String> headers, Stream<List<int>> message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders}) {
    _subscribe(new _Subscriber.blob(id, destination, onMessage, ack, matcher),
        receipt, extraHeaders);
  }

  @override
  void unsubscribe(String id) {
    _checkSend();

    final _Subscriber sub = _subscribers[id];
    if (sub != null) {
      _subscribers.remove(id);

      writeSimpleFrame(_connector, UNSUBSCRIBE, {"id": id});
    }
  }

  @override
  void receipt(String receipt, void onReceipt(String receipt)) {
    if (_receipts.containsKey(receipt))
      throw new StateError("Receipt $receipt can't be listened twice");
    _receipts[receipt] = onReceipt;
  }

  @override
  void unreceipt(String receipt) {
    _receipts.remove(receipt);
  }

  void _subscribe(_Subscriber subscriber, String receipt, Map extraHeaders) {
    _checkSend();

    final String id = subscriber.id;
    if (_subscribers.containsKey(id))
      throw new StateError("Subscription $id can't be subscribed twice");

    _subscribers[id] = subscriber;

    Map<String, String> headers = {
      "id": id,
      "destination": subscriber.destination
    };
    final Ack ack = subscriber.ack;
    if (ack != AUTO) headers["ack"] = ack.id;
    if (receipt != null) headers["receipt"] = receipt;
    if (extraHeaders != null) headers = addHeaders(headers, extraHeaders);

    writeSimpleFrame(_connector, SUBSCRIBE, headers);
  }

  @override
  void ack(String id, {String transaction}) {
    _ack(ACK, id, transaction);
  }

  @override
  void nack(String id, {String transaction}) {
    _ack(NACK, id, transaction);
  }

  void _ack(String command, String id, String transaction) {
    _checkSend();

    final Map<String, String> headers = new LinkedHashMap();
    headers["id"] = id;
    if (transaction != null) headers["transaction"] = transaction;
    writeSimpleFrame(_connector, command, headers);
  }

  @override
  void begin(String transaction, {String receipt}) {
    _tx(BEGIN, transaction, receipt);
  }

  @override
  void commit(String transaction, {String receipt}) {
    _tx(COMMIT, transaction, receipt);
  }

  @override
  void abort(String transaction, {String receipt}) {
    _tx(BEGIN, transaction, receipt);
  }

  void _tx(String command, String transaction, String receipt) {
    _checkSend();

    final Map<String, String> headers = new LinkedHashMap();
    headers["transaction"] = transaction;
    if (receipt != null) headers["receipt"] = receipt;
    writeSimpleFrame(_connector, command, headers);
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
      if (_onConnect != null) _onConnect(this, frame.headers);
      connecting.complete(this);
    }
  }

  void _error(Frame frame) {
    final Completer connecting = _connecting;
    if (connecting != null) {
      _connecting = null;
      connecting.completeError(frame.message);
    } else {
      final Map<String, String> headers = frame.headers;
      final String message = headers != null ? headers["message"] : null;
      final String detail = frame.message;
      if (_onError != null)
        _onError(this, message, detail, headers);
      else
        print(message != null
            ? detail != null ? "$message\n$detail" : message
            : detail);
    }
  }

  void _message(Frame frame) {
    final Map<String, String> headers = frame.headers;
    if (headers != null) {
      final String id = headers["subscription"];
      if (id != null) {
        final _Subscriber sub = _subscribers[id];
        if (sub != null && sub.matches(headers)) {
          sub.onFrame(frame).catchError((error, stackTrace) {
            _handleFault(error, stackTrace);
          });
        }
      }
    }
  }

  void _receipt(Frame frame) {
    final Map<String, String> headers = frame.headers;
    if (headers != null) {
      final String id = headers["receipt-id"];
      final _ReceiptCallback callback = _receipts[id];
      if (callback != null) callback(id);
    }
  }
}

typedef void _FrameHandler(_StompClient client, Frame frame);
final Map<String, _FrameHandler> _frameHandlers = {
  CONNECTED: (_StompClient client, Frame frame) {
    client._connected(frame);
  },
  ERROR: (_StompClient client, Frame frame) {
    client._error(frame);
  },
  MESSAGE: (_StompClient client, Frame frame) {
    client._message(frame);
  },
  RECEIPT: (_StompClient client, Frame frame) {
    client._receipt(frame);
  },
};
