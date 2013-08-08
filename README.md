#STOMP Client

Dart [STOMP](http://stomp.github.io/) client.

* [Home](http://rikulo.org)
* [Discussion](http://stackoverflow.com/questions/tagged/rikulo)
* [Git Repository](https://github.com/rikulo/stomp)
* [Issues](https://github.com/rikulo/stomp/issues)

##Installation

Add this to your `pubspec.yaml` (or create it):

    dependencies:
      stomp:

Then run the [Pub Package Manager](http://pub.dartlang.org/doc) (comes with the Dart SDK):

    pub install


##Usage

###Running on Dart VM

    import "package:stomp/stomp.dart";
    import "package:stomp/vm_plugin.dart" show connect;

    void main() {
      connect("foo.server.com").then((StompClient stomp) {
        stomp.subscribeString("/foo", (String message) {
          print("Recieve $message");
        });

        stomp.sendString("/foo", "Hi, Stomp");
      });
    }

There are basically a few alternative ways to communicate:

* JSON objects: `sendJson()` and `subscribeJson()`
* Strings: `sendString()` and `subscribeString()`
* Bytes (`List<int>`): `sendBytes()` and `subscribeBytes()`
* BLOB (low-level): `send` and `subscribe`

###Running on Browser

The same as the above, except import `ws_plugin.dart` instead:

    import "package:stomp/stomp.dart";
    import "package:stomp/ws_plugin.dart" show connect;

    //the rest is the same as running on Dart VM

##Limitations

* Support STOMP 1.2 or above
* Support only UTF-8 encoding
