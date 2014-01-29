//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Aug 09, 2013 11:23:38 AM
// Author: tomyeh
part of echo_test;

/** It is part of both echo_vm_test.dart and echo_ws_test.dart
 * so we can test it on both VM and browser.
 */
Future testEcho(address)
=> connect(address, onDisconnect: (_) {
  print("Disconnected");
}).then((client) {
  test("echo test", () {
    final String destination = "/foo";
    final List<String> sends = ["1. apple", "2. orange\nand 2nd line", "3. mango"];
    final List<String> sendExtraHeader = ["123", "abc:", "xyz"];
    final List<String> receives = [], receiveExtraHeader = [];

    client.subscribeString("0", destination,
      (headers, message) {
        //print("<<received: $headers, $message");
        receiveExtraHeader.add(headers["extra"]);
        receives.add(message);
      });

    for (int i = 0; i < sends.length; ++i) {
      final hds = {"extra": sendExtraHeader[i]};
      client.sendString(destination, sends[i], headers: hds);
    }

    return new Future.delayed(const Duration(milliseconds: 200), () {
      expect(receives.length, sends.length);
      for (int i = 0; i < sends.length; ++i) {
        expect(receives[i], sends[i]);
        expect(receiveExtraHeader[i], sendExtraHeader[i]);
      }

      //client.unsubscribe("0"); //optional
      client.disconnect();
    });
  });
});
