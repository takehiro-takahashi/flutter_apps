import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker_saver/image_picker_saver.dart';
import 'package:simple_permissions/simple_permissions.dart';

List<CameraDescription> cameras;

Future<Null> main() async {
  try {
    cameras = await availableCameras();
    await requestPermission();
  } on CameraException catch (e) {
    print(e);
  }

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController controller;
  String imagePath;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: const Text('Camera example'),
      ),
      body: new Column(
        children: <Widget>[
          new Expanded(
            child: new Container(
              child: new Padding(
                padding: const EdgeInsets.all(1.0),
                child: new Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ),
          _captureIconWidget(),
          new Padding(
            padding: const EdgeInsets.all(5.0),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                _cameraTogglesRowWidget(),
                _thumbnailWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // camera preview widget
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return new AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: new CameraPreview(controller),
      );
    }
  }

  // thumbnail widget
  Widget _thumbnailWidget() {
    return new Expanded(
      child: new Align(
        alignment: Alignment.centerRight,
        child: imagePath == null
            ? null
            : new SizedBox(
          child: new Image.file(new File(imagePath)),
          width: 64.0,
          height: 64.0,
        ),
      ),
    );
  }

  // camera icon widget
  Widget _captureIconWidget() {
    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        new IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null &&
              controller.value.isInitialized
              ? onTakePictureButtonPressed
              : null,
        ),
      ],
    );
  }

  // camera switch in or out
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return const Text('No camera fount');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          new SizedBox(
            width: 90.0,
            child: new RadioListTile<CameraDescription>(
              title: new Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              value: cameraDescription,
              groupValue: controller?.description,
              onChanged: onNewCameraSelected,
            ),
          ),
        );
      }
    }

    return new Row(children: toggles,);
  }

  // toggle
  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = new CameraController(CameraDescription(), ResolutionPreset.high);

    controller.addListener(() {
      if (mounted) setState(() {
        //
      });
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      print(e);
    }

    if (mounted) {
      setState(() {
        //
      });
    }
  }

  // when called touch camera icon
  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
        });
      }
    });
  }

  // タイムスタンプを返す関数
  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  // カメラで撮影した画像を保存する関数
  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      return null;
    }

    Directory dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory(); // 外部ストレージに保存
    } else if (Platform.isIOS) {
      dir = await getTemporaryDirectory(); // 一時ディレクトリに保存
    } else {
      return null;
    }

    final String dirPath = '${dir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e){
      print(e);
      return null;
    }

    if (Platform.isIOS) {
      String tmpPath = filePath;
      var savedFile = File.fromUri(Uri.file(tmpPath));
      filePath = await ImagePickerSaver.saveFile(fileData: savedFile.readAsBytesSync());
    }

    return filePath;

  }
}

// return camera icon function
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw new ArgumentError('Unkown lens direction');
}

// do permission function
requestPermission() async {
  if (Platform.isAndroid && !await SimplePermissions.checkPermission(Permission.WriteExternalStorage)) {
    SimplePermissions.requestPermission(Permission.WriteExternalStorage);
  } else if (Platform.isIOS && !await SimplePermissions.checkPermission(Permission.PhotoLibrary)) {
    SimplePermissions.requestPermission(Permission.PhotoLibrary);
  }
}
