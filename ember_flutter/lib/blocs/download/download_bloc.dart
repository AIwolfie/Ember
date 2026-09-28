import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/database_service.dart';
import '../../services/python_service.dart';
import '../../utils/result.dart';

// Events
abstract class DownloadEvent {}

class DownloadStartEvent extends DownloadEvent {
  final Map<String, String> track;
  DownloadStartEvent(this.track);
}

class DownloadRemoveEvent extends DownloadEvent {
  final String videoId;
  DownloadRemoveEvent(this.videoId);
}

class DownloadLoadAllEvent extends DownloadEvent {}

// States
class DownloadState {
  final Map<String, double>
  progress; // videoId -> progress bounded (0.0 to 1.0)
  final Map<String, String> completed; // videoId -> filePath
  final List<Map<String, dynamic>> downloadedTracks;

  const DownloadState({
    this.progress = const {},
    this.completed = const {},
    this.downloadedTracks = const [],
  });

  bool isDownloaded(String videoId) => completed.containsKey(videoId);
  bool isDownloading(String videoId) => progress.containsKey(videoId);

  DownloadState copyWith({
    Map<String, double>? progress,
    Map<String, String>? completed,
    List<Map<String, dynamic>>? downloadedTracks,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      downloadedTracks: downloadedTracks ?? this.downloadedTracks,
    );
  }
}

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final _dio = Dio();

  DownloadBloc() : super(const DownloadState()) {
    on<DownloadLoadAllEvent>(_onLoadAll);
    on<DownloadStartEvent>(_onStart);
    on<DownloadRemoveEvent>(_onRemove);
    add(DownloadLoadAllEvent());
  }

  Future<void> _onLoadAll(
    DownloadLoadAllEvent event,
    Emitter<DownloadState> emit,
  ) async {
    final downloads = await DatabaseService.instance.getAllDownloads();
    final completedMap = <String, String>{};
    for (var d in downloads) {
      final track = d['trackData'] as Map<String, String>;
      completedMap[track['videoId']!] = d['filePath'] as String;
    }
    emit(state.copyWith(completed: completedMap, downloadedTracks: downloads));
  }

  Future<void> _onStart(
    DownloadStartEvent event,
    Emitter<DownloadState> emit,
  ) async {
    final track = event.track;
    final videoId = track['videoId'];
    if (videoId == null) return;

    if (state.completed.containsKey(videoId) ||
        state.progress.containsKey(videoId)) {
      return; // Already downloading or downloaded
    }

    // Set initial progress
    final newProgress = Map<String, double>.from(state.progress);
    newProgress[videoId] = 0.01;
    emit(state.copyWith(progress: newProgress));

    final res = await PythonService.getStreamUrl(videoId);
    if (res is Success<Map<String, String?>>) {
      final url = res.data['url'];
      if (url == null) {
        _failDownload(videoId);
        return;
      }

      try {
        Directory? dir;
        if (Platform.isAndroid) {
          try {
            final extDirs = await getExternalStorageDirectories(
              type: StorageDirectory.music,
            );
            if (extDirs != null && extDirs.isNotEmpty) {
              dir = extDirs.first;
            }
          } catch (_) {}
        }
        dir ??= await getApplicationDocumentsDirectory();
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final safeTitle =
            track['title']?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '') ?? videoId;
        final filePath = '${dir.path}/$safeTitle.m4a';

        await _dio.download(
          url,
          filePath,
          onReceiveProgress: (rec, total) {
            if (total != -1) {
              // Avoid emitting many state changes here
            }
          },
        );

        await DatabaseService.instance.addDownload(track, filePath);

        final finalProgress = Map<String, double>.from(state.progress);
        finalProgress.remove(videoId);

        final finalCompleted = Map<String, String>.from(state.completed);
        finalCompleted[videoId] = filePath;

        final downloads = await DatabaseService.instance.getAllDownloads();

        // Ensure we invoke emit safely
        if (!isClosed)
          emit(
            state.copyWith(
              progress: finalProgress,
              completed: finalCompleted,
              downloadedTracks: downloads,
            ),
          );
      } catch (e) {
        _failDownload(videoId);
      }
    } else {
      _failDownload(videoId);
    }
  }

  void _failDownload(String videoId) {
    if (isClosed) return;
    final newProgress = Map<String, double>.from(state.progress);
    newProgress.remove(videoId);
    add(DownloadLoadAllEvent()); // flush state safely by reloading dummy
  }

  Future<void> _onRemove(
    DownloadRemoveEvent event,
    Emitter<DownloadState> emit,
  ) async {
    final videoId = event.videoId;

    final dbDownload = await DatabaseService.instance.getDownload(videoId);
    if (dbDownload != null) {
      final file = File(dbDownload['filePath'] as String);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    await DatabaseService.instance.removeDownload(videoId);
    add(DownloadLoadAllEvent());
  }
}
