//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Aug 09, 2013 11:20:46 AM
// Author: tomyeh
library echo_test;

import "dart:html";
import "dart:async";
import 'package:test/test.dart';

import 'package:stomp/webSocket.dart' show connect;

part "_echo_test.dart";

void main() {
  final address = "ws://localhost:8080";
  testEcho(address)
  .catchError((ex) {
    print("Unable to connect $address\n"
      "Check if the server has been started\n\nCause:\n$ex");
  }, test: (ex) => ex is Event); //an error event
}
