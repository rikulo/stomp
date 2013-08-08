#STOMP Client

Dart [STOMP](http://stomp.github.io/) client.

* [Home](http://rikulo.org)
* [API Reference](http://api.rikulo.org/stomp/latest)
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
    import "package:stomp/vm.dart" show connect;

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
* Bytes: `sendBytes()` and `subscribeBytes()`
* BLOB (huge data): `sendBlob()` and `subscribeBlob()`

Please refer to [StompClient](http://api.rikulo.org/stomp/latest/stomp/StompClient.html) for more information.

###Running on Browser

The same as the above, except import `websocket.dart` instead of `vm.dart`:

    import "package:stomp/stomp.dart";
    import "package:stomp/websocket.dart" show connect;

    //the rest is the same as running on Dart VM

##Limitations

* Support STOMP 1.2 or above
* Support only UTF-8 encoding
