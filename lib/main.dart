import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

const String uploadURL = "https://vajdafest.ddns.net:5001/profile/upload";

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Upload Demo',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: ImageCapture(),
    );
  }
}

class ImageCapture extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ImageCaptureState();
}

class _ImageCaptureState extends State<ImageCapture> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _imageFile;

  Future<void> _pickImage(ImageSource source) async {
    File selected = File((await _imagePicker.pickImage(source: source))!.path);

    setState(() {
      _imageFile = selected;
    });
  }

  Future<void> _cropImage() async {
    File? cropped = await ImageCropper.cropImage(
      sourcePath: _imageFile!.path,
      // aspectRatio:
      // maxWidth:
      // maxHeight:
    );

    setState(() {
      _imageFile = cropped ?? _imageFile;
    });
  }

  void _clear() {
    setState(() {
      _imageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.photo_camera),
              onPressed: () => _pickImage(ImageSource.camera)
            ),
            IconButton(
                icon: Icon(Icons.photo_library),
                onPressed: () => _pickImage(ImageSource.gallery)
            ),
          ],
        ),
      ),
      body: ListView(
        children: <Widget>[
          if (_imageFile != null) ...[
            Image.file(_imageFile!),

            Row(
              children: <Widget>[
                TextButton(
                    child: Icon(Icons.crop),
                    onPressed: _cropImage),
                TextButton(
                    child: Icon(Icons.refresh),
                    onPressed: _clear),

              ],
            ),

            UploadScreen(file: _imageFile!),
          ]
        ],
      ),
    );
  }
}

class UploadItem {
  final String id;
  final String tag;
  final MediaType type;
  final int progress;
  final UploadTaskStatus status;

  UploadItem({
    required this.id,
    required this.tag,
    required this.type,
    this.progress = 0,
    this.status = UploadTaskStatus.undefined,
  });

  UploadItem copyWith({required UploadTaskStatus status, required int progress}) => UploadItem(
      id: this.id,
      tag: this.tag,
      type: this.type,
      status: status,
      progress: progress);

  bool isCompleted() =>
      this.status == UploadTaskStatus.canceled ||
          this.status == UploadTaskStatus.complete ||
          this.status == UploadTaskStatus.failed;
}

enum MediaType { Image, Video }

class UploadScreen extends StatefulWidget {
  final File file;

  UploadScreen({Key? key, required this.file}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  FlutterUploader uploader = FlutterUploader();
  late StreamSubscription _progressSubscription;
  late StreamSubscription _resultSubscription;
  UploadItem? uploadItem;
  int progressPercent = 0;

  @override
  void initState() {
    super.initState();
    _progressSubscription = uploader.progress.listen((progress) {
      print("progress: ${progress.progress} , tag: ${progress.tag}");
      setState(() {
        progressPercent = progress.progress;
      });
    });
    _resultSubscription = uploader.result.listen((result) {
      print(
          "id: ${result.taskId}, status: ${result.status}, response: ${result.response}, statusCode: ${result.statusCode}, tag: ${result.tag}, headers: ${result.headers}");
      log("status: " + result.status.toString());
      setState(() {
        uploadItem = null;
        progressPercent = 0;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _progressSubscription.cancel();
    _resultSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (uploadItem != null) {
      final progress = progressPercent.toDouble() / 100;
      return Column(children: [
        LinearProgressIndicator(value: progress, color: Colors.black,minHeight: 20,),
        IconButton(
          icon: Icon(Icons.cancel),
          onPressed: () => cancelUpload(uploadItem!.id),
        )
      ],);
    } else {
        return TextButton.icon(
            icon: Icon(Icons.cloud_upload),
            label: Text('upload'),
            onPressed: _startUpload,
        );
    }
  }

  Future cancelUpload(String id) async {
    await uploader.cancel(taskId: id);
    setState(() {
      uploadItem = null;
      progressPercent = 0;
    });
  }

  Future<void> _startUpload() async {
    final tag = "1";

    var fileItem = FileItem(
      filename: basename(widget.file.path),
      savedDir: dirname(widget.file.path),
      fieldname: "file",
    );

    var taskId = await uploader.enqueueBinary(
      url: uploadURL,
      file: fileItem,
      method: UploadMethod.POST,
      tag: tag,
      showNotification: true,
      headers: {"className": "11.B", "taskId": "5546"},
    );

    setState(() {
        uploadItem = UploadItem(
          id: taskId,
          tag: tag,
          type: MediaType.Image,
          status: UploadTaskStatus.enqueued,
        );
    });
  }
}
