//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Aug 10, 2013 12:02:54 AM
// Author: tomyeh
part of stomp_impl_util;

class Frame {
  final String command;
  final Map<String, String> headers;
  final List<int> message;

  Frame(this.command, this.headers, this.message);
}
