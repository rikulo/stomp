//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:52:46 PM
// Author: tomyeh
library stomp_plugin;

import "stomp.dart" show StompClient;

/** A STOMP connector for binding with different networking, such as
 * WebSocket and Socket.
 */
class StompConnector {
}
/** The connector used to bind a proper networking, such as socket or WebSocket.
 * The user must initialize it with a proper instance before using [StompClient].
 */
StompConnector stompConnector;
