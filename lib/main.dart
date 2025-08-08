import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FACEIO Flutter Demo',
      home: FaceioPage(),
    );
  }
}

class FaceioPage extends StatefulWidget {
  @override
  State<FaceioPage> createState() => _FaceioPageState();
}

class _FaceioPageState extends State<FaceioPage> {
  InAppWebViewController? webView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FACEIO Flutter")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            "https://lakshmiprasanna-tech.github.io/faceio-flutter-demo/"
          ),
        ),
        onWebViewCreated: (controller) {
          webView = controller;

          controller.addJavaScriptHandler(
            handlerName: 'faceioMessage',
            callback: (args) {
              final message = args[0];
              debugPrint("Received from FACEIO: $message");

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message.toString()))
              );
            },
          );
        },
      ),
    );
  }
}
