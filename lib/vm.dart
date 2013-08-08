//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:54:51 PM
// Author: tomyeh
library stomp_vm;

import "stomp.dart" show StompClient;
import "impl/plugin.dart";

/**
 * Initializes [StompClient]. It must be called once before using
 * [StompClient].
 *
 * Notice it is called automatically by [connect], so you don't
 * need to use this method if you're using [connect].
 */
void initConnector() {
  if (stompConnector == null)
    stompConnector = new _StompConnector();
}

/** Connects a STOMP server, and instantiates a [StompClient]
 * to represent the connection.
 *
 * It invokes [initConnector]
 */
Future<StompClient> connect(address, {int port: 61626,
    String host, String login, String passcode, List<int> heartbeat,
    void onDisconnect(),
    void onError(String message)}) {

  initConnector();
  return StompClient.connect(address, port: port,
    host: host, login: login, passcode: passcode, heartbeat,
    onDisconnect: onDisconnect, onError: onError);
}

///The implementation
class _StompConnector implements StompConnector {
}
