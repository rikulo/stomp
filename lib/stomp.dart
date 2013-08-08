//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:21:16 PM
// Author: tomyeh
library stomp;

import "dart:async";
import "dart:json" as Json;
import "package:meta/meta.dart";

import "plugin.dart" show stompConnector;

part "src/stomp_impl.dart";

///The ACK mode.
class Ack {
  final String id;
  const Ack._(this.id);
  String toString() => id;
}
const Ack AUTO = const Ack._("auto");
const Ack CLIENT = const Ack._("client");
const Ack CLIENT_INDIVIDUAL = const Ack._("client-individual");

/**
 * A STOMP client.
 */
abstract class StompClient {
  /** A session identifier that uniquely identifies the session.
   * It is null if the server doesn't support it.
   */
  String get session;
  ///The information about the STOMP server, such as `messa/1.0.0`.
  String get server;
  /** The heart beat. A two-element array. The first element is
   * the smallest number of milliseconds that the server can do.
   * The second element is the desired number of milliseconds the
   * server would like to get.
   */
  List<int> get heartbeat;

  /** Connects the STOMP server.
   */
  static Future<StompClient> connect(address, {int port: 61626,
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message)}) {

  }

  /** Disconnects.
   */
  Future disconnect({String receipt});

  /** Sends a message by writing the encoded bytes into [StreamSink].
   * It is a low-level send command. You can use [sendBytes], [sendString]
   * and [sendJson] instead for easy handling,
   * unless you'd like to send a huge amount of data (without storing them
   * in memory first).
   *
   *     stomp.send("/foo").then((StreamSink<List<int>> body) {
   *       body.add(byes);
   *       body.addStream(anotherByteStream);
   *     });
   *
   *  **Notes of implementing the `then` callback**
   *
   * * Since STOMP is text-based messaging protocol, the bytes being written can't
   * contain the NULL octet (i.e., value 0). For example, you can encode as base64.
   * * If the callback doesn't complete at the return, it shall return a Future object
   * to indicate when it completes.
   * * The callback shall not call `close()`. It will be called automatically.
   */
  Future<StreamSink<List<int>>> send(String destination,
      {Map<String, String> headers});
  /** Sends an array of bytes.
   *
   * * [message] - the message. It shall be an array of bytes (i.e., only the lowest
   * 8 bits are handled).
   */
  Future sendBytes(String destination, List<int> message,
      {Map<String, String> headers});
  /** Sends a String-typed message.
   *
   *     stomp.send("/foo", "Hi, there");
   *
   * * [message] - the message.
   */
  Future sendString(String destination, String message,
      {Map<String, String> headers});
  /** Sends a JSON message.
   *
   *     stomp.send("/foo", {"type": 1, "data": ["abc"]});
   *
   * * [message] - the message. It must be a JSON object (including null).
   * In other words, it must be able to *jsonized* into a JSON string.
   */
  Future sendJson(String destination, message,
      {Map<String, String> headers});

  /** Subscribes for listening to a given destination.
   * Like [send], it is a low-level subscribe command. You can use [subscribeBytes],
   * [subscribeString] and [subscribeJson] instead for easy handling,
   * unless you'd like to receive a huge amount of data (without storing them in
   * memory first).
   *
   *     stomp.subscribe("/foo/blob", onData: (Stream<List<int>> stream) {
   *       stream.listen((List<int> data) {
   *         //handle data
   *       }, onDone: () {
   *         //handle done
   *       });
   *     })
   */
  Future subscribe(String destination,
      void onData(Map<String, String> headers, Stream<List<int>> data),
      {Ack ack: AUTO});
  /** Subscribes for listening to the bytes sent to a given destination.
   */
  Future subscribeBytes(String destination,
      void onData(Map<String, String> headers, List<int> data),
      {Ack ack: AUTO});
  /** Subscribes for listening to String-typed messages sent to a given destination.
   */
  Future subscribeString(String destination,
      void onData(Map<String, String> headers, String data),
      {Ack ack: AUTO});
  /** Subscribes for listening to JSON objects sent to a given destination.
   */
  Future subscribeJson(String destination,
      void onData(Map<String, String> headers, data),
      {Ack ack: AUTO});
}
