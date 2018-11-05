//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Aug 10, 2013  9:38:08 PM
// Author: tomyeh
library parser_test;

import "dart:convert" show utf8;
import 'package:test/test.dart';
import 'package:stomp/impl/util.dart';

List<Frame> frames;
List<String> errors;
void onFrame(Frame frame) {
  frames.add(frame);
}
void onError(error, stackTrace) {
  errors.add(error);
}

/** Test of [FrameParser].
 */
void main() {
  const String P1 = """
STOMP
accept-version:1.2""";
  const String P2 = ",1.1\n";
  const String P3 = """
foo\\c:escape\\\\

""";
  const String EOF = "\x00";

  test("simple frame", () {
    _testFrame1((FrameParser parser) {
      parser.addString(P1 + P2 + P3 + EOF);
    });
  });

  test("two for one frame", () {
    _testFrame1((FrameParser parser) {
      parser.addString(P1);
      parser.addString(P2);
      parser.addString(P3);
      parser.addString(EOF);
    });
  });

  test("simple byte frame", () {
    _testFrame1((FrameParser parser) {
      parser.addBytes(utf8.encode(P1 + P2 + P3 + EOF));
    });
  });

  test("three for one byte frame", () {
    _testFrame1((FrameParser parser) {
      parser.addBytes(utf8.encode(P1));
      parser.addBytes(utf8.encode(P2));
      parser.addBytes(utf8.encode(P3));
      parser.addBytes([0]);
    });
  });

  test("content-length", () {
    final String content = "abcdef";
    _testFrame1((FrameParser parser) {
      parser.addString(P1 + P2);
      parser.addString("content-length:${content.length}\n");
      parser.addString(P3 + content.substring(0, 1));
      parser.addString(content.substring(1) + EOF + "ANOTHER COMMAND");
    }, content);
  });
}

void _testFrame1(void apply(FrameParser parser), [String content]) {
  frames = [];
  final FrameParser parser = new FrameParser(onFrame);
  apply(parser);

  expect(frames.length, 1);
  final Frame frame = frames[0];
  expect(frame.command, "STOMP");
  expect(frame.headers.length, content != null ? 3: 2);
  expect(frame.headers["foo:"], "escape\\");
  if (frame.string != null) {
    expect(frame.string, "");
  } else if (content == null) {
    expect(frame.bytes.isEmpty, isTrue);
  } else {
    expect(frame.bytes.length, content.length);
    expect(utf8.decode(frame.bytes), content);
  }
}
