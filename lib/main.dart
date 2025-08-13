import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

void main() {
  runApp(FaceIODemoApp());
}

class FaceIODemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceIO Demo',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _facialId;
  String _status = 'Loading...';

  final String staticUserId = "user789";
  final String staticNric = "500000-01-1234";
  final String faceioApiKey = "37b1ae3e2f64b229614e4ab2797416ba";

  @override
  void initState() {
    super.initState();
    _loadFacialId();
  }

  Future<void> _loadFacialId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _facialId = prefs.getString('facial_id');
      _status = _facialId == null
          ? 'No facial ID found. Please enroll.'
          : 'Facial ID found. Please authenticate.';
    });
  }

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  Future<void> deleteFacialId(String fid, String key) async {
    final String url = "https://api.faceio.net/deletefacialid?fid=$fid&key=$key";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Facial ID deleted successfully: ${response.body}");
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('facial_id');
        _loadFacialId();
      } else {
        print("Failed to delete Facial ID: ${response.body}");
      }
    } catch (e) {
      print("Error deleting Facial ID: $e");
    }
  }

  void _openFaceIOWebView({required bool isEnroll}) async {
    if (!await _requestCameraPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceIOWebViewPage(
          isEnroll: isEnroll,
          userId: staticUserId,
          nric: staticNric,
        ),
      ),
    );

    _loadFacialId();

    if (result != null && result is String) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FaceIO Enrollment & Authentication')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status),
            SizedBox(height: 30),
            if (_facialId == null)
              ElevatedButton(
                onPressed: () => _openFaceIOWebView(isEnroll: true),
                child: Text('Enroll'),
              )
            else
              ElevatedButton(
                onPressed: () => _openFaceIOWebView(isEnroll: false),
                child: Text('Authenticate'),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _facialId == null
                  ? null
                  : () => deleteFacialId(_facialId!, faceioApiKey),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: Text('Delete Facial ID'),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceIOWebViewPage extends StatefulWidget {
  final bool isEnroll;
  final String userId;
  final String nric;

  FaceIOWebViewPage({
    required this.isEnroll,
    required this.userId,
    required this.nric,
  });

  @override
  _FaceIOWebViewPageState createState() => _FaceIOWebViewPageState();
}

class _FaceIOWebViewPageState extends State<FaceIOWebViewPage> {
  late InAppWebViewController _webViewController;

  String get url => widget.isEnroll
      ? "https://lakshmiprasanna-tech.github.io/faceio_flutter_demo/enroll.html"
      : "https://lakshmiprasanna-tech.github.io/faceio_flutter_demo/authenticate.html";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEnroll ? 'FaceIO Enroll' : 'FaceIO Authenticate'),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;

          // Enrollment handler
          _webViewController.addJavaScriptHandler(
            handlerName: 'sendFacialId',
            callback: (args) async {
              final result = args.first;
              if (result['success'] == true) {
                 final payload = result['payload'];
                 final userId = payload['userId'] ?? '';
                 final nric = payload['nric'] ?? '';
                 final facialId = payload['facialId'] ?? '';
                log("Enrollment Success. Payload: ${result['payload']}");

                // Save user data
                await _saveUserData(userId, nric, facialId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enrollment successful")),
                );
                Navigator.pop(context, result['facialId']);
              } else {
                log("Enrollment Failed: ${result['error']}");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Enrollment failed: ${result['error']}")),
                );
              }
            },
          );

          // Authentication handler
          _webViewController.addJavaScriptHandler(
            handlerName: 'processComplete',
            callback: (args) async {
              if (args.isEmpty || args[0] is! Map) return;

              final data = Map<String, dynamic>.from(args[0]);
              final success = data['success'] ?? false;
              final payload =
                  Map<String, dynamic>.from(data['payload'] ?? {});

              final prefs = await SharedPreferences.getInstance();
              final storedUserId = prefs.getString('user_id');
              final storedNric = prefs.getString('nric');

              String statusMessage;
              if (success &&
                  payload['userId'] == storedUserId &&
                  payload['nric'] == storedNric) {
                statusMessage = "Authentication successful for $storedUserId";
              } else {
                statusMessage = "Authentication failed: user mismatch";
              }

              Navigator.pop(context, statusMessage);
            },
          );
        },
        onLoadStop: (controller, url) async {
          String jsInject = """
            window.flutterUserData = {
              userId: "${widget.userId}",
              nric: "${widget.nric}"
            };
          """;
          await controller.evaluateJavascript(source: jsInject);

          if (widget.isEnroll) {
            await controller.evaluateJavascript(source: "enrollNewUser();");
          } else {
            await controller.evaluateJavascript(source: "authenticateUser();");
          }
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        onConsoleMessage: (controller, consoleMessage) {
          log("JS Console: ${consoleMessage.message}");
        },
      ),
    );
  }

  Future<void> _saveUserData(
      String userId, String nric, String facialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('nric', nric);
    await prefs.setString('facial_id', facialId);
  }
}
