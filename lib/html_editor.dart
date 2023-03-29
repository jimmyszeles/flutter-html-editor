library html_editor;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_editor/local_server.dart';
import 'package:html_editor/pick_image.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

/// Created by riyadi rb on 2/5/2020.
/// link  : https://github.com/xrb21/flutter-html-editor

typedef void OnClick();

class HtmlEditor extends StatefulWidget {
  final String? value;
  final double height;
  final BoxDecoration? decoration;
  final bool useBottomSheet;
  final String widthImage;
  final bool showBottomToolbar;
  final String? hint;

  HtmlEditor(
      {Key? key,
      this.value,
      this.height = 380,
      this.decoration,
      this.useBottomSheet = true,
      this.widthImage = "100%",
      this.showBottomToolbar = true,
      this.hint})
      : super(key: key);

  @override
  HtmlEditorState createState() => HtmlEditorState();
}

class HtmlEditorState extends State<HtmlEditor> {
  late final WebViewController _controller;
  String text = "";
  final Key _mapKey = UniqueKey();

  int port = 5321;
  late LocalServer localServer;

  @override
  void initState() {
    if (!Platform.isAndroid) {
      initServer();
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (WebResourceError error) {
          print(
              "onWebResourceError: ${error.errorCode} - ${error.description}");
        },
        onPageFinished: (String url) {
          if (widget.hint != null) {
            setHint(widget.hint);
          } else {
            setHint("");
          }

          setFullContainer();
          if (widget.value != null) {
            setText(widget.value!);
          }
        },
      ))
      ..addJavaScriptChannel('GetTextSummernote',
          onMessageReceived: (JavaScriptMessage message) {
        String isi = message.message;
        if (isi.isEmpty ||
            isi == "<p></p>" ||
            isi == "<p><br></p>" ||
            isi == "<p><br/></p>") {
          isi = "";
        }
        setState(() {
          text = isi;
        });
      });

    if (Platform.isAndroid) {
      final filename = 'packages/html_editor/summernote/summernote.html';
      _controller.loadFile("file:///android_asset/flutter_assets/" + filename);
    } else {
      _loadHtmlFromAssets();
    }

    super.initState();
  }

  initServer() {
    localServer = LocalServer(port);
    localServer.start(handleRequest);
  }

  void handleRequest(HttpRequest request) {
    try {
      if (request.method == 'GET' &&
          request.uri.queryParameters['query'] == "getRawTeXHTML") {
      } else {}
    } catch (e) {
      print('Exception in handleRequest: $e');
    }
  }

  @override
  void dispose() {
    if (!Platform.isAndroid) {
      localServer.close();
    }
    super.dispose();
  }

  _loadHtmlFromAssets() async {
    final filePath = 'packages/html_editor/summernote/summernote.html';
    _controller.loadRequest(Uri.parse("http://localhost:$port/$filePath"));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: widget.decoration ??
          BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            border: Border.all(color: Color(0xffececec), width: 1),
          ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: WebViewWidget(
              key: _mapKey,
              controller: _controller,
              gestureRecognizers: [
                Factory(
                    () => VerticalDragGestureRecognizer()..onUpdate = (_) {}),
              ].toSet(),
              // onWebViewCreated: (webViewController) {
              //   _controller = webViewController;
              //
              //   if (Platform.isAndroid) {
              //     final filename =
              //         'packages/html_editor/summernote/summernote.html';
              //     _controller!.loadUrl(
              //         "file:///android_asset/flutter_assets/" + filename);
              //   } else {
              //     _loadHtmlFromAssets();
              //   }
              // },
              // gestureNavigationEnabled: true,
            ),
          ),
          widget.showBottomToolbar
              ? Divider()
              : Container(
                  height: 1,
                ),
          widget.showBottomToolbar
              ? Padding(
                  padding: const EdgeInsets.only(
                      left: 4.0, right: 4, bottom: 8, top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      widgetIcon(Icons.image, "Image", onClick: () {
                        widget.useBottomSheet
                            ? bottomSheetPickImage(context)
                            : dialogPickImage(context);
                      }),
                      widgetIcon(Icons.content_copy, "Copy", onClick: () async {
                        String data = await getText();
                        Clipboard.setData(new ClipboardData(text: data));
                      }),
                      widgetIcon(Icons.content_paste, "Paste",
                          onClick: () async {
                        ClipboardData? data =
                            await Clipboard.getData(Clipboard.kTextPlain);

                        String txtIsi = data?.text!
                                .replaceAll("'", '\\"')
                                .replaceAll('"', '\\"')
                                .replaceAll("[", "\\[")
                                .replaceAll("]", "\\]")
                                .replaceAll("\n", "<br/>")
                                .replaceAll("\n\n", "<br/>")
                                .replaceAll("\r", " ")
                                .replaceAll('\r\n', " ") ??
                            '';
                        String txt =
                            "\$('.note-editable').append( '" + txtIsi + "');";
                        _evaluateJavascript(txt);
                      }),
                    ],
                  ),
                )
              : Container(
                  height: 1,
                )
        ],
      ),
    );
  }

  Future<String> getText() async {
    await _evaluateJavascript(
        "GetTextSummernote.postMessage(document.getElementsByClassName('note-editable')[0].innerHTML);");
    return text;
  }

  setText(String v) async {
    String txtIsi = v
        .replaceAll("'", '\\"')
        .replaceAll('"', '\\"')
        .replaceAll("[", "\\[")
        .replaceAll("]", "\\]")
        .replaceAll("\n", "<br/>")
        .replaceAll("\n\n", "<br/>")
        .replaceAll("\r", " ")
        .replaceAll('\r\n', " ");
    String txt =
        "document.getElementsByClassName('note-editable')[0].innerHTML = '" +
            txtIsi +
            "';";
    _evaluateJavascript(txt);
  }

  setFullContainer() {
    _evaluateJavascript('\$("#summernote").summernote("fullscreen.toggle");');
  }

  setFocus() {
    _evaluateJavascript("\$('#summernote').summernote('focus');");
  }

  setEmpty() {
    _evaluateJavascript("\$('#summernote').summernote('reset');");
  }

  setHint(String? text) {
    String hint = '\$(".note-placeholder").html("$text");';
    _evaluateJavascript(hint);
  }

  Future<void> _evaluateJavascript(String javaScriptString) async {
    await _controller
        .runJavaScript(javaScriptString + (Platform.isIOS ? '123;' : ''));
    return;
  }

  Widget widgetIcon(IconData icon, String title, {OnClick? onClick}) {
    return InkWell(
      onTap: () {
        onClick!();
      },
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: Colors.black38,
            size: 20,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title,
              style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w400),
            ),
          )
        ],
      ),
    );
  }

  dialogPickImage(BuildContext context) {
    return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              padding: const EdgeInsets.all(12),
              height: 120,
              child: PickImage(
                  color: Colors.black45,
                  callbackFile: (file) async {
                    String filename = p.basename(file.path);
                    List<int> imageBytes = await file.readAsBytes();
                    String base64Image =
                        "<img width=\"${widget.widthImage}\" src=\"data:image/png;base64, "
                        "${base64Encode(imageBytes)}\" data-filename=\"$filename\">";

                    String txt =
                        "\$('.note-editable').append( '" + base64Image + "');";
                    _evaluateJavascript(txt);
                  }),
            ),
          );
        });
  }

  bottomSheetPickImage(context) {
    showModalBottomSheet(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: Colors.white,
        context: context,
        builder: (BuildContext bc) {
          return StatefulBuilder(builder: (BuildContext context, setState) {
            return SingleChildScrollView(
                child: Container(
              height: 140,
              width: double.infinity,
              child: PickImage(callbackFile: (file) async {
                String filename = p.basename(file.path);
                List<int> imageBytes = await file.readAsBytes();
                String base64Image = "<img width=\"${widget.widthImage}\" "
                    "src=\"data:image/png;base64, "
                    "${base64Encode(imageBytes)}\" data-filename=\"$filename\">";
                String txt =
                    "\$('.note-editable').append( '" + base64Image + "');";
                _evaluateJavascript(txt);
              }),
            ));
          });
        });
  }
}
