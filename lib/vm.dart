//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:54:51 PM
// Author: tomyeh
library stomp_vm;

import "dart:async";
import "dart:io";

import "stomp.dart" show StompClient;
import "impl/plugin_vm.dart" show SocketStompConnector;

/** Connects a STOMP server, and instantiates a [StompClient]
 * to represent the connection.
 *
 *     import "package:stomp/stomp.dart";
 *     import "package:stomp/vm.dart" show connect;
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
 * * [address] - either be a [String] or an [InternetAddress]. If it is a String,
 * it will perform a[] InternetAddress.lookup] and use the first value in the list.
 */
Future<StompClient> connect(address, {int port: 61626,
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message, String detail, [Map<String, String> headers])})
=> Socket.connect(address, port).then((Socket socket)
  => StompClient.connect(new SocketStompConnector(socket),
    host: host, login: login, passcode: passcode, heartbeat: heartbeat,
    onDisconnect: onDisconnect, onError: onError));
