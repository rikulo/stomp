//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Apr 09, 2013  4:50:32 PM
// Author: tomyeh
library test_run_all;

import 'package:test/test.dart';

import 'parser_test.dart' as parser_test;

main() {
  group("parser tests", parser_test.main);
}
