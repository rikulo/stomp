//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Aug 09, 2013 11:20:46 AM
// Author: tomyeh
library echo_test;
import "dart:collection" show LinkedHashMap;

import "dart:async";
import "dart:io";
import 'package:test/test.dart';

import 'package:stomp/vm.dart' show connect;

part "_echo_test.dart";

void main() {
  final address = "ws://192.168.1.2:8088/ws";
  Map<String,String> customHeaders = new LinkedHashMap();
  customHeaders["userid"]="D7t7G8989y3";
  customHeaders["platform"]="mobile";
  testEcho(address: address,headers: customHeaders,heartbeat: [10000,10000])
  .catchError((ex) {
      print("Unable to connect $address\n"
        "Check if the server has been started\n\nCause:\n$ex");
  }, test: (ex) => ex is SocketException);
}
