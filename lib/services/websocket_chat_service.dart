import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketChatService {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Callbacks to communicate with the UI screen
  Function(String chunk, String intent)? onChunkReceived;
  VoidCallback? onDone;
  Function(dynamic error)? onError;

  bool get isConnected => _isConnected;

  /// Connect to the FastAPI backend WebSocket endpoint.
  Future<void> connect(String url) async {
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      debugPrint("WebSocket Connected to: $url");

      _channel!.stream.listen(
        (data) {
          final Map<String, dynamic> response = json.decode(data);

          if (response['done'] == true) {
            onDone?.call();
          } else if (response.containsKey('reply')) {
            final String reply = response['reply'];
            final String intent = response['intent_processed'] ?? 'RAG';
            onChunkReceived?.call(reply, intent);
          }
        },
        onError: (err) {
          debugPrint("WebSocket error: $err");
          _isConnected = false;
          onError?.call(err);
        },
        onDone: () {
          debugPrint("WebSocket connection closed.");
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
      debugPrint("WebSocket connection failed: $e");
      rethrow;
    }
  }

  /// Send user message to FastAPI backend.
  void sendMessage(String message) {
    if (_channel != null && _isConnected) {
      final payload = json.encode({"message": message});
      _channel!.sink.add(payload);
    } else {
      throw Exception("WebSocket is not connected. Call connect() first.");
    }
  }

  /// Close the WebSocket channel.
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
