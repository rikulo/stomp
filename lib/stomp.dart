//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:21:16 PM
// Author: tomyeh
library stomp;

import "dart:async";
import "dart:json" as Json;
import "package:meta/meta.dart";

import "plugin.dart" show stompConnector;

part "src/stomp_impl.dart";

const String AUTO = "auto";
const String CLIENT = "client";
const String CLIENT_INDIVIDUAL ="client-individual";

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
   * It is a low-level send command. You can use [sendData], [sendString]
   * and [sendJson] instead, unless you'd like to send a huge amount of data.
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
  Future<StreamSink<List<int>>> send(String destination, {Map<String, String> headers});
  /** Sends an array of bytes.
   *
   * * [message] - the message. It shall be an array of bytes (i.e., only the lowest
   * 8 bits are handled).
   */
  Future sendData(String destination, List<int> message,
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

  Future subscribe(String destination, {String ack: AUTO});
}
