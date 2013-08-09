//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:21:16 PM
// Author: tomyeh
library stomp;

import "dart:async";
import "dart:json" as Json;
import "dart:collection" show LinkedHashMap;
import "package:meta/meta.dart";

import "impl/plugin.dart" show StompConnector;
import "impl/util.dart";

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

  /** Connects a STOMP server, and instantiates a [StompClient]
   * to represent the connection.
   *
   * **Notice:** Instead of invoking this method,
   * you can invoke [VM's connect](../stomp_vm.html#connect) if running on Dart VM
   * (non-browser).
   * Or, invoke [WebSocket's connect](../stomp_websocket.html#connect) if
   * running on a browser.
   */
  static Future<StompClient> connect(StompConnector connector, {
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message)}) {
    if (connector == null)
      throw new ArgumentError("Required: connector. Use stomp_vm's connect() instead.");

    return _StompClient.connect(connector, host, login, passcode, heartbeat,
      onDisconnect, onError);
  }

  /** Disconnects. After disconnected, this object can not be used any more.
   */
  Future disconnect({String receipt});

  /** Sends an array of bytes.
   *
   * * [message] - the message. It shall be an array of bytes (i.e., only the lowest
   * 8 bits are meaningful, aka, octets).
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
  /** Sends a message read from a given [Stream].
   * It saves the memory use since the message is *piping* from [Stream]
   * to the network directly.
   *
   * **Notes**
   *
   * * Though it is typed List<int>, it is actually an array of bytes (i.e.,
   * only the lowest 8 bits are meaningful, aka, octets).
   * * Since STOMP is text-based messaging protocol, the message being written can't
   * contain the NULL octet (i.e., value 0). For example, you can encode as base64.
   * * Unlike other send methods, [sendBlob] won't set the content-length header.
   * If you know the length in advance, you can pass it into [headers].
   */
  Future sendBlob(String destination, Stream<List<int>> message,
      {Map<String, String> headers});

  /** Subscribes for listening a given destination; assuming the message
   * are an array of bytes (aka., octets).
   *
   *     stomp.subscribe("/foo", (List<int> message) {
   *       //handle message (an array of octets)
   *     });
   */
  Future subscribeBytes(String destination,
      void onMessage(Map<String, String> headers, List<int> message),
      {Ack ack: AUTO});
  /** Subscribes for listening a given destination; assuming the message
   * are a String.
   *
   *     stomp.subscribe("/foo", (String message) {
   *       //handle message
   *     });
   */
  Future subscribeString(String destination,
      void onMessage(Map<String, String> headers, String message),
      {Ack ack: AUTO});
  /** Subscribes for listening a given destination; assuming the message
   * are a JSON object.
   *
   *     stomp.subscribe("/foo", (message) {
   *       //handle message (it is a JSON object decoded from a JSON string)
   *     });
   */
  Future subscribeJson(String destination,
      void onMessage(Map<String, String> headers, message),
      {Ack ack: AUTO});
  /** Subscribes for listening to a given destination.
   * Like [sendBlob], it is useful if you'd like to receive a huge amount of
   * message (without storing them in memory first).
   *
   *     stomp.subscribe("/foo/blob", (Stream<List<int>> stream) {
   *       stream.listen((List<int> message) {
   *         //handle message
   *       }, onDone: () {
   *         //handle done
   *       });
   *     })
   */
  Future subscribeBlob(String destination,
      void onMessage(Map<String, String> headers, Stream<List<int>> message),
      {Ack ack: AUTO});
}
