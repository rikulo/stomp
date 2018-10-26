//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Aug 10, 2013 12:02:54 AM
// Author: tomyeh
part of stomp_impl_util;

/** A STOMP frame.
 *
 * Depending on [STOMPConnector], one of [bytes] and [string] might be
 * not null.
 */
class Frame {
  ///The command.
  String command;

  ///The header.
  Map<String, String> headers;

  ///The content if it is string-typed
  String string;

  ///The content if it is bytes-typed
  List<int> bytes;

  ///Returns the String-typed message of this frame (never null).
  ///It will detect if string or bytes is not null and pick up the right one.
  String get message =>
      string != null ? string : bytes != null ? utf8.decode(bytes) : "";

  ///Returns the byte-array message of this frame (never null).
  ///It will detect if string or bytes is not null and pick up the right one.
  List<int> get messageBytes =>
      bytes != null ? bytes : string != null ? utf8.encode(string) : [];

  ///Retrieve the content length from the header; null means not available
  int get contentLength {
    if (headers != null) {
      final String val = headers[CONTENT_LENGTH];
      if (val != null)
        try {
          return int.parse(val);
        } catch (ex) {}
    }
    return null;
  }
}

typedef void _OnFrame(Frame frame);
typedef void _OnError(error, stackTrace);

const String _EOF = '\x00';

///State of expecting command
const int _COMMAND = 0;

///State of expecting header
const int _HEADER = 1;

///State of expecting body
const int _BODY = 2;

/** The STOMP frame parser.
 *
 * ##How it is used
 *
 * 1. Instantiates one [FrameParser] instead for each connection.
 * 2. When bytes is received, invoke [addBytes].
 * 3. When a string is received, invoke [addString].
 * 4. The `onFrame` callback is called when a frame is received and parsed.
 * 5. The `onError` callback is called when an error occurs during receiving and parsing.
 */
class FrameParser {
  final _OnFrame _onFrame;
  final _OnError _onError;

  ///The current frame
  Frame _frame = new Frame();

  ///The body length of the current frame if content-length is received
  int _bodylen;

  ///The state
  int _state = _COMMAND;

  List<int> _bytebuf = [];
  StringBuffer _strbuf = new StringBuffer();

  FrameParser(void onFrame(Frame frame), [void onError(error, stackTrace)])
      : _onFrame = onFrame,
        _onError = onError;

  ///Adds an array of bytes (when the caller receives it)
  void addBytes(List<int> bytes) {
    if (bytes != null)
      try {
        if (_state == _BODY)
          _addBodyFrag(null, bytes);
        else
          _addHeaderFrag(utf8.decode(bytes));
      } catch (ex, st) {
        _errorFound(ex, st);
      }
  }

  ///Adds a [String] (when the caller receives it)
  void addString(String string) {
    if (string != null)
      try {
        if (_state == _BODY)
          _addBodyFrag(string);
        else
          _addHeaderFrag(string);
      } catch (ex, st) {
        _errorFound(ex, st);
      }
  }

  void _addHeaderFrag(String string) {
    int i = string.indexOf('\n');
    if (i < 0) {
      _strbuf.write(string);
      return;
    }

    if (!_strbuf.isEmpty) {
      i += _strbuf.length;
      string = (_strbuf..write(string)).toString();
      _strbuf.clear();
    }

    for (int pre = 0;;) {
      //for each line
      final int end = i > pre && string[i - 1] == '\r' ? i - 1 : i;
      final String line = string.substring(pre, end);
      pre = ++i;

      if (_state == _COMMAND) {
        if (!line.isEmpty) {
          //skip heartbeat
          _frame.command = line;
          _state = _HEADER;
        }
      } else if (line.isEmpty) {
        _state = _BODY;
        _bodylen = _frame.contentLength;
        if (i < string.length) _addBodyFrag(string.substring(i));
        return;
      } else {
        final int k = line.indexOf(':');
        final String name = k >= 0 ? line.substring(0, k) : line,
            value = k >= 0 ? line.substring(k + 1) : "";
        if (_frame.headers == null) _frame.headers = new LinkedHashMap();

        final String unescapedName = _unescape(name);
        if (!_frame.headers.containsKey(unescapedName)) {
          // There can be repeated entries in headers.
          // Using first one according to spec.
          // See "Repeated Header Entries".
          _frame.headers[unescapedName] = _unescape(value);
        }
      }

      i = string.indexOf('\n', pre);
      if (i < 0) {
        if (pre < string.length) _strbuf.write(string.substring(pre));
        return; //no more
      }
    }
  }

  //one of [string] and [bytes] must be non-null
  void _addBodyFrag(String string, [List<int> bytes]) {
    //handle in bytes if _bodylen is specified
    if (_bodylen != null && bytes == null) bytes = utf8.encode(string);

    if (bytes != null) {
      //use bytes
      if (!_strbuf.isEmpty) {
        assert(_bytebuf.isEmpty);
        _bytebuf = utf8.encode(_strbuf.toString());
        _strbuf.clear();
      }

      if (_bodylen != null) {
        //Note: EOF still required
        if (_bodylen + 1 <= _bytebuf.length + bytes.length) {
          _frameBytes(bytes, _bodylen - _bytebuf.length);
          return;
        }
      } else {
        //scan 0
        for (int i = 0, len = bytes.length; i < len; ++i)
          if (bytes[i] == 0) {
            //EOF
            _frameBytes(bytes, i);
            return;
          }
      }
      _bytebuf.addAll(bytes);
      //Note: make copy since bytes might be reused by caller
      return;
    }

    //use string
    if (!_bytebuf.isEmpty) {
      assert(_strbuf.isEmpty);
      _strbuf = new StringBuffer(utf8.decode(_bytebuf));
      _bytebuf = [];
    }

    for (int i = 0, len = string.length; i < len; ++i)
      if (string[i] == _EOF) {
        final String s = string.substring(0, i);
        _frame.string = _strbuf.isEmpty ? s : _strbuf.toString() + s;
        _strbuf.clear();
        if (++i < len) _strbuf.write(string.substring(i));

        _frameFound();
        return;
      }

    _strbuf.write(string);
  }

  void _frameBytes(List<int> bytes, int len) {
    final List<int> curr = bytes.sublist(0, len);
    if (_bytebuf.isEmpty)
      _frame.bytes = curr;
    else
      (_frame.bytes = _bytebuf).addAll(curr);
    if (bytes[len] == 0) //EOF
      ++len;
    _bytebuf = len < bytes.length ? bytes.sublist(len) : [];
    _frameFound();
  }

  void _frameFound() {
    final Frame frame = _frame;
    _frame = new Frame();
    _bodylen = null;
    _state = _COMMAND;
    _onFrame(frame);

    if (!_bytebuf.isEmpty) {
      final List<int> bytes = _bytebuf;
      _bytebuf = [];
      addBytes(bytes);
    }
    if (!_strbuf.isEmpty) {
      final String string = _strbuf.toString();
      _strbuf.clear();
      addString(string);
    }
  }

  void _errorFound(error, stackTrace) {
    _strbuf.clear();
    if (!_bytebuf.isEmpty) _bytebuf = [];
    _frame = new Frame();
    _bodylen = null;

    if (_onError != null)
      _onError(error, stackTrace);
    else
      print("$error\n$stackTrace");
  }
}

String _unescape(String value) {
  StringBuffer buf;
  int pre = 0;
  for (int i = 0, len = value.length; i < len; ++i) {
    if (value[i] == '\\') {
      final int j = i + 1;
      if (j < len) {
        String esc;
        switch (value[j]) {
          case 'r':
            esc = '\r';
            break;
          case 'n':
            esc = '\n';
            break;
          case 'c':
            esc = ':';
            break;
          case '\\':
            esc = '\\';
            break;
        }

        if (esc != null) {
          if (buf == null) buf = new StringBuffer();
          buf..write(value.substring(pre, i))..write(esc);
          i = j;
          pre = j + 1;
        }
      }
    }
  }
  return buf != null ? (buf..write(value.substring(pre))).toString() : value;
}
