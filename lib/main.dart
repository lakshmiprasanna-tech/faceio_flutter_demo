import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


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

  // Static user info for now
  final String staticUserId = "user123";
  final String staticNric = "900101-01-1234";
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
          ? 'No facial ID found for user $staticUserId. Please enroll.'
          : 'Facial ID found for user $staticUserId. Please Authenticate';
    });
  }

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }
  // delete facialId
  Future<void> deleteFacialId(String fid, String key) async {
    print("Delete button clicked, fid: $fid, key: $key");  // Debug print
    final String url =
        "https://api.faceio.net/deletefacialid?fid=$fid&key=$key";
 
    try {
      final response = await http.get(Uri.parse(url));
      print("Response status: ${response.statusCode}");  // Debug print
      print("Response body: ${response.body}");          // Debug print
      if (response.statusCode == 200) {
        print("Facial ID deleted successfully: ${response.body}");
      } else {
        print("Failed to delete Facial ID. Status: ${response.statusCode}");
        print("Response: ${response.body}");
      }
    } catch (e) {
      print("Error deleting Facial ID: $e");
    }
  }
  void _openFaceIOWebView({required bool isEnroll}) async {
    bool granted = await _requestCameraPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera permission is required')));
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
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => FaceIOWebViewPage(
    //       isEnroll: isEnroll,
    //       userId: staticUserId,
    //       nric: staticNric,
    //     ),
    //   ),
    // ).then((_) {
    //   // Reload facialId after returning
    //   _loadFacialId();
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FaceIO Enrollment & Authentication'),
      ),
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
                onPressed: () {
                  deleteFacialId(_facialId!, faceioApiKey);
                },
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
  String _status = "Waiting for FaceIO response...";

  String get url =>
      widget.isEnroll
          ? "https://lakshmiprasanna-tech.github.io/faceio_flutter_demo/enroll.html"
          : "https://lakshmiprasanna-tech.github.io/faceio_flutter_demo/authenticate.html";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEnroll ? 'FaceIO Enroll' : 'FaceIO Authenticate'),
      ),
      body: Column(
        children: [
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useOnDownloadStart: true,
                clearCache: false,
                userAgent: "MyCustomApp/1.0.0 (Flutter)",
                mediaPlaybackRequiresUserGesture: false,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                // Add the handler after controller is ready
                _webViewController.addJavaScriptHandler(
                  handlerName: 'sendFacialId',
                  callback: (args) {
                    String facialId = args.isNotEmpty ? args[0] : '';
                    _saveUserData(widget.userId, widget.nric, facialId);
                    setState(() {
                      _status = "Success! Facial ID: $facialId";
                    });
                    Future.delayed(Duration(seconds: 2), () {
                      if (mounted) Navigator.pop(context, _status);
                    });
                  },
                );
                _webViewController.addJavaScriptHandler(
                  handlerName: 'processComplete',
                  callback: (args) {
                    String message =
                        args.isNotEmpty ? args[0].toString() : 'Process completed';
                    setState(() => _status = message);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) Navigator.pop(context);
                    });
                  },
                );
              },
              onLoadStop: (controller, url) async {
                // Inject user data into the WebView JS context
                String jsInject = """
                  window.flutterUserData = {
                    userId: "${widget.userId}",
                    nric: "${widget.nric}"
                  };
                """;
                await controller.evaluateJavascript(source: jsInject);

                //Call the appropriate FaceIO function
                if (widget.isEnroll) {
                  await controller.evaluateJavascript(source: "enrollNewUser();");
                } else {
                  await controller.evaluateJavascript(source: "authenticateUser();");
                }
              },
              //camera permission for webview page
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onConsoleMessage: (controller, consoleMessage) {
                print("JS Console: ${consoleMessage.message}");
              },
            ),
          ),
        ],   
      ),
    );
  }

  Future<void> _saveUserData(String userId, String nric, String facialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('nric', nric);
    await prefs.setString('facial_id', facialId);
  }
  Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id'),
      'nric': prefs.getString('nric'),
      'facial_id': prefs.getString('facial_id'),
    };
  }
}




