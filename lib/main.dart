import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

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
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission denied")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FACEIO Flutter")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            "https://lakshmiprasanna-tech.github.io/faceio_flutter_demo/",
          ),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          // onPermissionRequest: true, // important!
        ),
        onWebViewCreated: (controller) {
          webView = controller;

          controller.addJavaScriptHandler(
            handlerName: 'faceioMessage',
            callback: (args) {
              final message = args[0];
              debugPrint("Received from FACEIO: $message");

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message.toString())),
              );
            },
          );
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
      ),
    );
  }
}
