import 'dart:typed_data';

class PlatformMessage {
  final String channel;
  final ByteData data;
  final PlatformMessageResponse response;

  PlatformMessage(this.channel, this.data, this.response);
}

class PlatformMessageResponse {
  void complete(Uint8List data) {}
  void completeEmpty() {}
}
