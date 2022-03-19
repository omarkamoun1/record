import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:dropbox_client/dropbox_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/config.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Fn = void Function();

const theSource = AudioSource.microphone;

class RecorderPage extends StatefulWidget {
  const RecorderPage({Key? key}) : super(key: key);

  @override
  _RecorderState createState() => _RecorderState();
}

class _RecorderState extends State<RecorderPage> {
  String? accessToken;
  bool showInstruction = false;
  final Codec _codec = Codec.aacMP4;
  final String _mPath = 'tau_file.mp4';
  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mplaybackReady = false;
  String globalPath = '';

  Future initDropbox() async {
    await Dropbox.init(dropboxClientId, dropboxKey, dropboxSecret);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('dropboxAccessToken')!;
    setState(() {});
  }

  @override
  void initState() {
    initDropbox();
    _mPlayer!.openPlayer().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });
    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _mPlayer!.closePlayer();
    _mPlayer = null;
    _mRecorder!.closeRecorder();
    _mRecorder = null;
    super.dispose();
  }

  Future<void> openTheRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _mRecorder!.openRecorder();
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    _mRecorderIsInited = true;
  }

  void record() {
    _mRecorder!
        .startRecorder(
      toFile: _mPath,
      codec: _codec,
      audioSource: theSource,
    )
        .then((value) {
      setState(() {});
    });
  }

  void stopRecorder() async {
    await _mRecorder!.stopRecorder().then((value) {
      setState(() {
        _mplaybackReady = true;
      });
    });
  }

  void play() {
    assert(_mPlayerIsInited && _mplaybackReady && _mRecorder!.isStopped && _mPlayer!.isStopped);
    _mPlayer!.startPlayer(
            fromURI: _mPath,
            whenFinished: () {
              setState(() {});
            })
    .then((value) {
      setState(() {});
    });
  }

  void stopPlayer() {
    _mPlayer!.stopPlayer().then((value) {
      setState(() {});
    });
  }

  _Fn? getRecorderFn() {
    if (!_mRecorderIsInited || !_mPlayer!.isStopped) {
      return null;
    }
    return _mRecorder!.isStopped ? record : stopRecorder;
  }

  _Fn? getPlaybackFn() {
    if (!_mPlayerIsInited || !_mplaybackReady || !_mRecorder!.isStopped) {
      return null;
    }
    return _mPlayer!.isStopped ? play : stopPlayer;
  }

  Future authorizeWithAccessToken(String? accessToken) async {
    await Dropbox.authorizeWithAccessToken(accessToken!);
  }

  Future<bool> checkAuthorized(bool authorize) async {
    final token = await Dropbox.getAccessToken();
    if (token != null) {
      if (accessToken == null || accessToken!.isEmpty) {
        accessToken = token;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('dropboxAccessToken', accessToken!);
      }
      return true;
    }
    if (authorize) {
      if (accessToken != null && accessToken!.isNotEmpty) {
        await Dropbox.authorizeWithAccessToken(accessToken!);
        final token = await Dropbox.getAccessToken();
        if (token != null) {
          return true;
        }
      } else {
        await Dropbox.authorize();
      }
    }
    return false;
  }

  Future authorize() async {
    await Dropbox.authorize();
  }

  uploadToDropBox() async {
    if (await checkAuthorized(true)) {
      Directory tempDir = await getTemporaryDirectory();
      await Dropbox.upload(tempDir.path + '/' + _mPath, '/test_record.mp4',
          (uploaded, total) {});
      Fluttertoast.showToast(
          msg: "Record Uploaded To DropBox!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget makeBody() {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 80,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: getRecorderFn(),
                child: Text(_mRecorder!.isRecording ? 'Stop' : 'Record'),
              ),
              const SizedBox(width: 20),
              Text(_mRecorder!.isRecording? 'Recording in progress': 'Recorder is stopped'),
            ]),
          ),
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 80,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: getPlaybackFn(),
                child: Text(_mPlayer!.isPlaying ? 'Stop' : 'Play'),
              ),
              const SizedBox(width: 20),
              Text(_mPlayer!.isPlaying
                  ? 'Playback in progress'
                  : 'Player is stopped'),
            ]),
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
            onPressed: uploadToDropBox,
            style: ElevatedButton.styleFrom(primary: Colors.green),
            child: const Text('Upload To DropBox'),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Center(
          child: Text('DropBox Recorder'),
        ),
      ),
      body: makeBody(),
    );
  }
}
