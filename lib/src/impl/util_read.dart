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
  String command;
  Map<String, String> headers;
  String string;
  List<int> bytes;

  ///Retrieve the content length from the header; null means not available
  int get _contentLength {
    if (headers != null) {
      final String val = headers[CONTENT_LENGTH];
      if (val != null)
        try {
          return int.parse(val);
        } catch (ex) {
        }
    }
    return null;
  }
}

typedef void _OnFrame(Frame frame);
typedef void _OnError(String message);

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

  FrameParser(void onFrame(Frame frame), void onError(String message)):
    _onFrame = onFrame, _onError = onError;

  ///Adds an array of bytes (when the caller receives it)
  void addBytes(List<int> bytes) {
    if (bytes != null)
      try {
        if (_state == _BODY)
          _addBodyFrag(null, bytes);
        else
          _addHeaderFrag(decodeUtf8(bytes));
      } catch (ex) {
        _errorFound(ex);
      }
  }
  ///Adds a [String] (when the caller receives it)
  void addString(String string) {
    if (string != null)
      try {
        if(_state == _BODY)
          _addBodyFrag(string);
        else
          _addHeaderFrag(string);
      } catch (ex) {
        _errorFound(ex);
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

    for (int pre = 0;;) { //for each line
      final String line = string.substring(pre, i++);
      if (_state == _COMMAND) {
        _frame.command = line;
        _state = _HEADER;
      } else if (line.isEmpty) {
        _state = _BODY;
        _bodylen = _frame._contentLength;
        if (i < string.length)
          _addBodyFrag(string.substring(i));
        return;
      } else {
        final int k = line.indexOf(':');
        final String name = k >= 0 ? line.substring(0, k): line,
          value = k >= 0 ? line.substring(k + 1): "";
        if (_frame.headers == null)
          _frame.headers = new LinkedHashMap();
        _frame.headers[_unescape(name)] = _unescape(value);
      }

      i = string.indexOf('\n', pre = i);
      if (i < 0) {
        if (pre < string.length)
          _strbuf.write(string.substring(pre));
        return; //no more
      }
    }
  }
  //one of [string] and [bytes] must be non-null
  void _addBodyFrag(String string, [List<int> bytes]) {
    //handle in bytes if _bodylen is specified
    if (_bodylen != null && bytes == null)
      bytes = encodeUtf8(string);

    if (bytes != null) { //use bytes
      if (!_strbuf.isEmpty) {
        assert(_bytebuf.isEmpty);
        _bytebuf = encodeUtf8(_strbuf.toString());
        _strbuf.clear();
      }

      if (_bodylen != null) {
        //Note: EOF still required
        if (_bodylen + 1 <= _bytebuf.length + bytes.length) {
          _frameBytes(bytes, _bodylen - _bytebuf.length);
          return;
        }
      } else { //scan 0
        for (int i = 0, len = bytes.length; i < len; ++i)
          if (bytes[i] == 0) { //EOF
            _frameBytes(bytes, i - 1);
            return;
          }
      }
      _bytebuf.addAll(bytes);
        //Note: make copy since bytes might be resued by caller
      return;
    }

    //use string
    if (!_bytebuf.isEmpty) {
      assert(_strbuf.isEmpty);
      _strbuf = new StringBuffer(decodeUtf8(_bytebuf));
      _bytebuf = [];
    }

    for (int i = 0, len = string.length; i < len; ++i)
      if (string[i] == _EOF) {
        final String s = string.substring(0, i);
        _frame.string = _strbuf.isEmpty ? s: _strbuf.toString() + s;
        _strbuf.clear();
        if (++i < len)
          _strbuf.write(string.substring(i));

        _frameFound();
        return;
      }

    _strbuf.write(string);
  }
  void _frameBytes(List<int> bytes, int len) {
    final List<int> curr = bytes.sublist(0, len);
    _frame.bytes = _bytebuf.isEmpty ? curr: _bytebuf..addAll(curr);
    if (bytes[len] == 0) //EOF
      ++len;
    _bytebuf = len < bytes.length ? bytes.sublist(len): [];

    _frameFound();
  }
  void _frameFound() {
    final Frame frame = _frame;
    _frame = new Frame();
    _bodylen = null;
    _onFrame(frame);
  }
  void _errorFound(error) {
    _strbuf.clear();
    if (!_bytebuf.isEmpty)
      _bytebuf = [];
    _frame = new Frame();
    _bodylen = null;

    _onError(error != null ? error.toString(): "Unknown");
  }
}

String _unescape(String value) {
  StringBuffer buf;
  int pre = 0;
  for (int i = 0, len = value.length; i < len; ++i) {
    final String cc = value[i];
    if (cc == '\\') {
      final int j = i + 1;
      if (j < len) {
        String esc;
        switch (value[j]) {
          case 'r': esc = '\r'; break;
          case 'n': esc = '\n'; break;
          case 'c': esc = ':'; break;
          case '\\': esc = '\\'; break;
        }

        if (esc != null) {
          if (buf == null)
            buf = new StringBuffer();
          buf..write(value.substring(pre, i))..write(esc);
          i = j;
          pre = j + 1;
        }
      }
    } else if (cc == '\r') { //ignore 0x0d
      if (buf == null)
        buf = new StringBuffer();
      buf.write(value.substring(pre, i));
      pre = i + 1;
    }
  }
  return buf != null ? (buf..write(value.substring(pre))).toString(): value;
}
