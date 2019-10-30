//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:54:51 PM
// Author: tomyeh
library stomp_vm;

import "dart:async";
import "stomp.dart" show StompClient;
import 'package:web_socket_channel/io.dart';
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
 * * [onConnect] - callback when the CONNECT frame is received.
 * * [onError] -- callback when the ERROR frame is received.
 * * [onFault] -- callback when an exception is received.
 */
Future<StompClient> connect(address, {int port: 61626,
    String host,Map<String, String> customHeaders, String login, String passcode, List<int> heartbeat,
    void onConnect(StompClient client, Map<String, String> headers),
    void onDisconnect(StompClient client),
    void onError(StompClient client, String message, String detail, Map<String, String> headers),
    void onFault(StompClient client, error, stackTrace)})
async => connectWith(await IOWebSocketChannel.connect(address),
 host: host,
 customHeaders: customHeaders,
        login: login,
        passcode: passcode,
        heartbeat: heartbeat,
        onConnect: onConnect,
        onDisconnect: onDisconnect,
        onError: onError,
        onFault: onFault);

Future<StompClient> connectWith(IOWebSocketChannel channel,
        {String host,
        Map<String, String> customHeaders,
        String login,
        String passcode,
        List<int> heartbeat,
        void onConnect(StompClient client, Map<String, String> headers),
        void onDisconnect(StompClient client),
        void onError(StompClient client, String message, String detail,
            Map<String, String> headers),
        void onFault(StompClient client, error, stackTrace)})=>
     StompClient.connect(new SocketStompConnector(channel),
      host: host,customHeaders: customHeaders, login: login, passcode: passcode, heartbeat: heartbeat,
      onConnect: onConnect, onDisconnect: onDisconnect,
      onError: onError, onFault: onFault);
