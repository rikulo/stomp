//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:21:16 PM
// Author: tomyeh
library stomp;

import "dart:async";
import "dart:convert";
import "dart:math" show max;
import "dart:collection" show HashMap, LinkedHashMap;
import "package:quiver/pattern.dart" as qp show Glob;

import "impl/plugin.dart" show StompConnector;
import "impl/util.dart";

part "src/stomp_impl.dart";
part "src/stomp_util.dart";

///The ACK mode.
class Ack {
  final String id;
  const Ack._(this.id);
}

const Ack AUTO = const Ack._("auto");
const Ack CLIENT = const Ack._("client");
const Ack CLIENT_INDIVIDUAL = const Ack._("client-individual");

//headers//
const String CONTENT_TYPE = "content-type";
const String CONTENT_LENGTH = "content-length";

///Destination matcher.
abstract class Matcher {
  bool matches(String pattern, String destination);
}

///The default matcher for case-sensitive exact match.
const Matcher exact = const _ExactMatcher();

///The matcher for the glob match.
const Matcher glob = const _GlobMatcher();

///The matcher for matching regular expression.
const Matcher regExp = const _RegExpMatcher();

///The matcher that will ignore the destination, i.e., matches all
///kind of destinations.
const Matcher all = const _AllMatcher();

/**
 * A STOMP client.
 */
abstract class StompClient {
  /** A session identifier that uniquely identifies the session.
   * It is null if the server doesn't support it.
   */
  String get session;

  ///The information about the STOMP server, such as `ripple/1.0.0`.
  String get server;
  /** The heart beat. A two-element array. The first element is
   * the smallest number of milliseconds that the server can do.
   * The second element is the desired number of milliseconds the
   * server would like to get.
   */
  List<int> get heartbeat;

  ///Whether it is disconnected from the server.
  bool get isDisconnected;

  /** Connects a STOMP server, and instantiates a [StompClient]
   * to represent the connection.
   *
   * **Notice:** Instead of invoking this method,
   * you can invoke [VM's connect](../stomp_vm.html#connect) if running on Dart VM
   * (non-browser).
   * Or, invoke [WebSocket's connect](../stomp_websocket.html#connect) if
   * running on a browser.
   */
  static Future<StompClient> connect(StompConnector connector,
      {String host,
      String login,
      String passcode,
      List<int> heartbeat,
      void onConnect(StompClient client, Map<String, String> headers),
      void onDisconnect(StompClient client),
      void onError(StompClient client, String message, String detail,
          Map<String, String> headers),
      void onFault(StompClient client, error, stackTrace)}) {
    if (connector == null)
      throw new ArgumentError(
          "Required: connector. Use stomp_vm's connect() instead.");

    return _StompClient.connect(connector, host, login, passcode, heartbeat,
        onConnect, onDisconnect, onError, onFault);
  }

  /** Disconnects. After disconnected, this object can not be used any more.
   */
  Future disconnect({String receipt});

  /** Sends an array of bytes.
   *
   * Note: it sets the content-length header automatically if not specified.
   *
   * * [message] - the message. It shall be an array of bytes (i.e., only the lowest
   * 8 bits are meaningful, aka, octets).
   */
  void sendBytes(String destination, List<int> message,
      {Map<String, String> headers});
  /** Sends a String-typed message.
   *
   *     stomp.send("/foo", "Hi, there");
   *
   * Note: it sets the content-length and content-type header automatically
   * if not specified (default content-type: text/plain).
   *
   * * [message] - the message.
   */
  void sendString(String destination, String message,
      {Map<String, String> headers});
  /** Sends a JSON message.
   *
   *     stomp.send("/foo", {"type": 1, "data": ["abc"]});
   *
   * Note: it sets the content-length and content-type header automatically
   * if not specified (default content-type: application/json).
   *
   * * [message] - the message. It must be a JSON object (including null).
   * In other words, it must be able to *jsonized* into a JSON string.
   */
  void sendJson(String destination, message, {Map<String, String> headers});
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
   * * The return [Future] instance indicated when the message has been sent.
   * It is important to note than before it completes, you can send other
   * messages. Otherwise, an exception is thrown.
   */
  Future sendBlob(String destination, Stream<List<int>> message,
      {Map<String, String> headers});

  /** Subscribes for listening a given destination; assuming the message
   * are an array of bytes (aka., octets).
   *
   *     stomp.subscribe("/foo", (List<int> message) {
   *       //handle message (an array of octets)
   *     });
   *
   * * [id] - specifies the id of the subscription. It must be unique
   * for each [StompClient] (until [unsubscribe] is called).
   * * [destination] - specifies the destination to subscribe.
   * * [matcher] - matches [destination] with the message's destination.
   * If omitted, [exact] is assumed.
   * * [extraHeaders] - additional headers to be sent while subscribing.
   * If you'd like to specify a regular expression in [destination],
   * you can use [regExp]. For GLOB pattern, use [glob].
   * If you'd like to ignore the destination, use [all].
   */
  void subscribeBytes(String id, String destination,
      void onMessage(Map<String, String> headers, List<int> message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders});
  /** Subscribes for listening a given destination; assuming the message
   * are a String.
   *
   *     stomp.subscribe("/foo", (String message) {
   *       //handle message
   *     });
   *
   * * [id] - specifies the id of the subscription. It must be unique
   * for each [StompClient] (until [unsubscribe] is called).
   * * [destination] - specifies the destination to subscribe.
   * * [matcher] - matches [destination] with the message's destination.
   * If omitted, [exact] is assumed.
   * * [extraHeaders] - additional headers to be sent while subscribing.
   * If you'd like to specify a regular expression in [destination],
   * you can use [regExp]. For GLOB pattern, use [glob].
   * If you'd like to ignore the destination, use [all].
   */
  void subscribeString(String id, String destination,
      void onMessage(Map<String, String> headers, String message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders});
  /** Subscribes for listening a given destination; assuming the message
   * are a JSON object.
   *
   *     stomp.subscribe("/foo", (message) {
   *       //handle message (it is a JSON object decoded from a JSON string)
   *     });
   *
   * * [id] - specifies the id of the subscription. It must be unique
   * for each [StompClient] (until [unsubscribe] is called).
   * * [destination] - specifies the destination to subscribe.
   * * [matcher] - matches [destination] with the message's destination.
   * If omitted, [exact] is assumed.
   * * [extraHeaders] - additional headers to be sent while subscribing.
   * If you'd like to specify a regular expression in [destination],
   * you can use [regExp]. For GLOB pattern, use [glob].
   * If you'd like to ignore the destination, use [all].
   */
  void subscribeJson(String id, String destination,
      void onMessage(Map<String, String> headers, message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders});
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
   *     });
   *
   * * [id] - specifies the id of the subscription, an arbitrary string.
   * It must be unique for each [StompClient] (until [unsubscribe] is called).
   * * [destination] - specifies the destination to subscribe.
   * * [matcher] - matches [destination] with the message's destination.
   * * [extraHeaders] - additional headers to be sent while subscribing.
   * If omitted, [exact] is assumed.
   * If you'd like to specify a regular expression in [destination],
   * you can use [regExp]. For GLOB pattern, use [glob].
   * If you'd like to ignore the destination, use [all].
   */
  void subscribeBlob(String id, String destination,
      void onMessage(Map<String, String> headers, Stream<List<int>> message),
      {Ack ack: AUTO,
      String receipt,
      Matcher matcher: exact,
      Map extraHeaders});

  /** Unsubscribes.
   *
   * * [id] - specifies the id of the subscription.
   */
  void unsubscribe(String id);

  /** Adds a listener called when the RECEIPT frame of the given receipt-id
   * is received.
   *
   * You can register any number of listeners as long as [id] is different.
   *
   * * [receipt] - specifies the receipt. It must match the receipt header
   * of the frame sent to the server.
   */
  void receipt(String receipt, void onReceipt(String receipt));
  /** Removes the listener added by [receipt].
   */
  void unreceipt(String receipt);

  /** Acknowledges the consumption of a message.
   *
   * * [id] - the acknowledge id. It can be the ack header of
   * the `onMessage` callback of [subscribeBytes], [subscribeString]...
   * * [transaction] - indicates the message acknowledgment is part
   * of the named transaction.
   */
  void ack(String id, {String transaction});
  /** The opposite of [ack].
   */
  void nack(String id, {String transaction});

  /** Starts a transaction.
   * Transactions in this case apply to sending and acknowledging.
   *
   * * [transaction] - specifies the name (aka., id) of the transaction.
   * It shall match the transaction argument of [commit] and [abort].
   */
  void begin(String transaction, {String receipt});
  /** Commits a transaction.
   */
  void commit(String transaction, {String receipt});
  /** Aborts a transaction.
   */
  void abort(String transaction, {String receipt});
}
