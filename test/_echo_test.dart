//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Aug 09, 2013 11:23:38 AM
// Author: tomyeh
part of echo_test;

/** It is part of both echo_vm_test.dart and echo_ws_test.dart
 * so we can test it on both VM and browser.
 */
Future test(address)
=> connect(address).then((StompClient stomp) {

});
