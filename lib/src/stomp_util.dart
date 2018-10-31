//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Aug 12, 2013  5:16:09 PM
// Author: tomyeh
part of stomp;

const int _SUB_BYTES = 0, _SUB_STRING = 1, _SUB_JSON = 2, _SUB_BLOB = 3;

///The information of a subscriber
class _Subscriber {
  final String id;
  final String destination;
  final Matcher matcher;
  final int type;
  final Function onMessage;
  final Ack ack;

  _Subscriber.bytes(
      this.id,
      this.destination,
      void onMessage(Map<String, String> headers, List<int> message),
      this.ack,
      this.matcher)
      : type = _SUB_BYTES,
        this.onMessage = onMessage;
  _Subscriber.string(
      this.id,
      this.destination,
      void onMessage(Map<String, String> headers, String message),
      this.ack,
      this.matcher)
      : type = _SUB_STRING,
        this.onMessage = onMessage;
  _Subscriber.json(
      this.id,
      this.destination,
      void onMessage(Map<String, String> headers, message),
      this.ack,
      this.matcher)
      : type = _SUB_JSON,
        this.onMessage = onMessage;
  _Subscriber.blob(
      this.id,
      this.destination,
      void onMessage(Map<String, String> headers, Stream<List<int>> message),
      this.ack,
      this.matcher)
      : type = _SUB_BLOB,
        this.onMessage = onMessage;

  bool matches(Map<String, String> headers) =>
      matcher.matches(this.destination, headers["destination"]);

  Future onFrame(Frame frame) => new Future(() {
        //to avoid the callback might cause some effect
        switch (type) {
          case _SUB_BYTES:
            onMessage(frame.headers, frame.messageBytes);
            break;
          case _SUB_STRING:
            onMessage(frame.headers, frame.message);
            break;
          case _SUB_JSON:
            onMessage(frame.headers, json.decode(frame.message));
            break;
          case _SUB_BLOB:
            onMessage(
                frame.headers, new Stream.fromIterable([frame.messageBytes]));
            break;
        }
      });
}

///Handles heart-beat sent back from the server.
void _handleHeartbeat(_StompClient client, String heartbeat) {
  if (heartbeat != null) {
    try {
      final int i = heartbeat.indexOf(',');
      final int sx = int.parse(heartbeat.substring(0, i)),
          sy = int.parse(heartbeat.substring(i + 1));
      client.heartbeat[0] = _calcHeartbeat(client.heartbeat[0], sy);
      client.heartbeat[1] = _calcHeartbeat(client.heartbeat[1], sx);
    } catch (ex) {
      // ignore silently
    }
  }
}

int _calcHeartbeat(int a, int b) => a == 0 || b == 0 ? 0 : max(a, b);
