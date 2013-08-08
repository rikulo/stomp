//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Aug 07, 2013  6:56:09 PM
// Author: tomyeh
library stomp_plugin_ws;

import "stomp.dart" show StompClient;
import "plugin.dart";

/**
 * Initializes [StompClient]. It must be called once before using
 * [StompClient].
 */
void initStompClient() {
  stompConnector = null; //TODO
}
