import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to control rosbag playback via Docker container
class RosbagPlayerService extends ChangeNotifier {
  static final RosbagPlayerService _instance = RosbagPlayerService._internal();
  factory RosbagPlayerService() => _instance;
  RosbagPlayerService._internal();

  // Playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _currentFile = '';
  String get currentFile => _currentFile;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  String _lastError = '';
  String get lastError => _lastError;

  // Process reference for stopping
  Process? _playProcess;

  // Docker container name
  static const String _containerName = 'mevi-rosbag-player';

  // Rosbag directories
  static const String _containerRosbagDir = '/rosbags';
  static const String _containerTempDir = '/tmp/uploaded_rosbags';

  /// Check if Docker container is running
  Future<bool> isContainerRunning() async {
    try {
      final result = await Process.run('docker', [
        'ps',
        '--filter',
        'name=$_containerName',
        '--filter',
        'status=running',
        '-q',
      ]);
      return result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      debugPrint('Error checking container: $e');
      return false;
    }
  }

  /// Check if rosbag is currently playing in container
  Future<bool> isRosbagPlaying() async {
    try {
      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        'pgrep -f "rosbag play"',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error checking rosbag status: $e');
      return false;
    }
  }

  /// Force stop all rosbag processes in container
  Future<void> forceStopAll() async {
    try {
      await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        'pkill -f "rosbag play" || true',
      ]);
      _isPlaying = false;
      _currentFile = '';
      _statusMessage = 'All rosbag processes stopped';
      notifyListeners();
      debugPrint('🛑 Force stopped all rosbag processes');
    } catch (e) {
      debugPrint('Error force stopping rosbag: $e');
    }
  }

  /// Cleanup on app shutdown
  Future<void> cleanup() async {
    debugPrint('🧹 Cleaning up RosbagPlayerService...');
    await forceStopAll();
  }

  /// Ensure temp directory exists in container
  Future<void> _ensureTempDirExists() async {
    try {
      await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        'mkdir -p $_containerTempDir && chmod 777 $_containerTempDir',
      ]);
    } catch (e) {
      debugPrint('Error creating temp dir: $e');
    }
  }

  /// Initialize service and check existing rosbag status
  Future<void> initialize() async {
    debugPrint('🎬 Initializing RosbagPlayerService...');
    final isRunning = await isContainerRunning();
    if (!isRunning) {
      debugPrint('⚠️ Docker container not running');
      _statusMessage = 'Docker container not running';
      notifyListeners();
      return;
    }

    // Check if rosbag is already playing
    final isPlaying = await isRosbagPlaying();
    if (isPlaying) {
      debugPrint('⚠️ Rosbag already playing - stopping...');
      await forceStopAll();
    }
    await _ensureTempDirExists();
    debugPrint('✅ RosbagPlayerService initialized');
  }
  // Path to docker-compose file (relative to Flutter project root)
  static const String _dockerComposeDir = '/home/yume/Documents/Davin/Belajar/flutter/dashboard-mevi/deployment';
  static const String _dockerComposeFile = 'docker-compose.rosbag.yml';

  /// Start Docker container using docker-compose
  Future<bool> _startContainer({
    required String rosbagFile,
    bool loop = true,
    double rate = 1.0,
  }) async {
    try {
      debugPrint('🐳 Starting Docker container with rosbag: $rosbagFile');
      _statusMessage = 'Starting Docker container...';
      notifyListeners();

      // Use docker-compose to start container with environment variables
      final result = await Process.run(
        'docker-compose',
        ['-f', _dockerComposeFile, 'up', '-d', 'rosbag-player'],
        workingDirectory: _dockerComposeDir,
        environment: {
          ...Platform.environment,
          'ROSBAG_FILE': rosbagFile,
          'LOOP': loop.toString(),
          'RATE': rate.toString(),
        },
      );

      if (result.exitCode == 0) {
        debugPrint('✅ Docker container started');
        // Wait for container to be ready
        await Future.delayed(const Duration(seconds: 2));
        return true;
      } else {
        debugPrint('❌ Failed to start container: ${result.stderr}');
        _lastError = result.stderr.toString();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error starting container: $e');
      _lastError = e.toString();
      return false;
    }
  }

  /// Restart Docker container with new rosbag file
  Future<bool> _restartContainerWithRosbag({
    required String rosbagFile,
    bool loop = true,
    double rate = 1.0,
  }) async {
    try {
      debugPrint('🔄 Restarting container with new rosbag: $rosbagFile');
      _statusMessage = 'Restarting with new rosbag...';
      notifyListeners();

      // Stop existing container
      await Process.run(
        'docker-compose',
        ['-f', _dockerComposeFile, 'stop', 'rosbag-player'],
        workingDirectory: _dockerComposeDir,
      );

      // Remove container to apply new environment
      await Process.run(
        'docker-compose',
        ['-f', _dockerComposeFile, 'rm', '-f', 'rosbag-player'],
        workingDirectory: _dockerComposeDir,
      );

      // Start with new environment
      return await _startContainer(
        rosbagFile: rosbagFile,
        loop: loop,
        rate: rate,
      );
    } catch (e) {
      debugPrint('❌ Error restarting container: $e');
      _lastError = e.toString();
      return false;
    }
  }

  /// Start rosbag playback
  Future<bool> play({
    required String rosbagFile,
    bool loop = false,
    double rate = 1.0,
  }) async {
    _isLoading = true;
    _lastError = '';
    _statusMessage = 'Starting playback...';
    notifyListeners();

    try {
      // Extract filename from path
      String filename = rosbagFile;
      if (rosbagFile.contains('/')) {
        filename = rosbagFile.split('/').last;
      }

      // Check if container is running
      final containerRunning = await isContainerRunning();
      
      if (!containerRunning) {
        // Auto-start container with the rosbag file
        debugPrint('🐳 Container not running, starting...');
        final started = await _startContainer(
          rosbagFile: filename,
          loop: loop,
          rate: rate,
        );
        
        if (!started) {
          _lastError = 'Failed to start Docker container: $_lastError';
          _isLoading = false;
          _statusMessage = 'Failed to start container';
          notifyListeners();
          return false;
        }
        
        // Container started with rosbag - it auto-plays from docker-compose command
        _isPlaying = true;
        _currentFile = filename;
        _statusMessage = 'Playing: $filename';
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Container is running, restart it with new rosbag
      debugPrint('🔄 Container running, restarting with new rosbag...');
      final restarted = await _restartContainerWithRosbag(
        rosbagFile: filename,
        loop: loop,
        rate: rate,
      );

      if (restarted) {
        _isPlaying = true;
        _currentFile = filename;
        _statusMessage = 'Playing: $filename';
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to restart container: $_lastError';
        _statusMessage = 'Failed to restart';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      _statusMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop rosbag playback
  Future<bool> stop() async {
    _isLoading = true;
    _statusMessage = 'Stopping playback...';
    notifyListeners();

    try {
      // Stop container using docker-compose
      final result = await Process.run(
        'docker-compose',
        ['-f', _dockerComposeFile, 'stop', 'rosbag-player'],
        workingDirectory: _dockerComposeDir,
      );

      if (result.exitCode == 0) {
        debugPrint('✅ Rosbag player stopped');
      } else {
        debugPrint('⚠️ Stop command returned: ${result.stderr}');
      }

      _isPlaying = false;
      _currentFile = '';
      _statusMessage = 'Stopped';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Pause rosbag playback (press space in rosbag)
  Future<bool> pause() async {
    // Note: rosbag play doesn't have a programmatic pause
    // Would need to use rosbag play with --pause flag and signals
    // For now, just stop
    return await stop();
  }

  /// List available rosbag files from host filesystem
  /// This is more reliable than Docker exec since container may be stopped
  Future<List<String>> listRosbagFiles() async {
    try {
      // Try multiple possible rosbag directories
      final possiblePaths = [
        // Relative to current working directory
        'deployment/rosbags',
        // Absolute paths
        '/home/yume/Documents/Davin/Belajar/flutter/dashboard-mevi/deployment/rosbags',
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final files = await dir
              .list()
              .where((entity) => entity is File && entity.path.endsWith('.bag'))
              .map((entity) => entity.path.split('/').last)
              .toList();
          
          if (files.isNotEmpty) {
            debugPrint('📁 Found ${files.length} rosbag files in $path');
            return files;
          }
        }
      }

      // Fallback: try Docker exec if host filesystem didn't work
      debugPrint('⚠️ Host filesystem lookup failed, trying Docker...');
      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        '(ls $_containerRosbagDir/*.bag 2>/dev/null; ls $_containerTempDir/*.bag 2>/dev/null) | xargs -n1 basename | sort -u',
      ]);

      if (result.exitCode == 0) {
        final files = result.stdout
            .toString()
            .trim()
            .split('\n')
            .where((f) => f.isNotEmpty && f.endsWith('.bag'))
            .toList();
        return files;
      }
      return [];
    } catch (e) {
      debugPrint('Error listing rosbags: $e');
      return [];
    }
  }

  /// Get info about a rosbag file
  Future<String> getRosbagInfo(String filename) async {
    try {
      // Try to find the file in both directories
      final checkMounted = await Process.run('docker', [
        'exec',
        _containerName,
        'test',
        '-f',
        '$_containerRosbagDir/$filename',
      ]);

      final checkTemp = await Process.run('docker', [
        'exec',
        _containerName,
        'test',
        '-f',
        '$_containerTempDir/$filename',
      ]);

      String rosbagPath;
      if (checkMounted.exitCode == 0) {
        rosbagPath = '$_containerRosbagDir/$filename';
      } else if (checkTemp.exitCode == 0) {
        rosbagPath = '$_containerTempDir/$filename';
      } else {
        return 'Error: File not found in container';
      }

      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        'source /opt/ros/noetic/setup.bash && rosbag info $rosbagPath',
      ]);

      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Check if a specific rosbag file exists
  Future<bool> rosbagExists(String filename) async {
    final files = await listRosbagFiles();
    return files.contains(filename);
  }

  /// Copy rosbag file from host to container
  /// Returns true if successful
  Future<bool> copyRosbagToContainer(String hostPath) async {
    try {
      final file = File(hostPath);
      if (!await file.exists()) {
        _lastError = 'File not found: $hostPath';
        return false;
      }

      final filename = hostPath.split('/').last;

      // Ensure temp directory exists
      await _ensureTempDirExists();

      // Copy file to container's temp directory (writable)
      final result = await Process.run('docker', [
        'cp',
        hostPath,
        '$_containerName:$_containerTempDir/$filename',
      ]);

      if (result.exitCode == 0) {
        debugPrint('✅ Copied $filename to container temp directory');
        return true;
      } else {
        _lastError = 'Failed to copy: ${result.stderr}';
        debugPrint('❌ Copy failed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ Error copying file: $e');
      return false;
    }
  }

  /// List files in container's /rosbags directory with details
  /// Returns list of maps with filename, size, and date
  Future<List<Map<String, String>>> listRosbagFilesDetailed() async {
    try {
      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        '(ls -lh $_containerRosbagDir/*.bag 2>/dev/null; ls -lh $_containerTempDir/*.bag 2>/dev/null) || echo ""',
      ]);

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final lines = result.stdout.toString().trim().split('\n');
        final files = <Map<String, String>>[];

        for (final line in lines) {
          if (line.isEmpty) continue;
          // Parse ls -lh output: permissions user group size month day time filename
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 9) {
            final filename = parts.last.split('/').last;
            final size = parts[4];
            final date = '${parts[5]} ${parts[6]} ${parts[7]}';

            files.add({
              'filename': filename,
              'size': size,
              'date': date,
              'path': parts.last,
            });
          }
        }
        return files;
      }
      return [];
    } catch (e) {
      debugPrint('Error listing detailed rosbags: $e');
      return [];
    }
  }

  /// Execute command inside container and return output
  Future<String> execInContainer(String command) async {
    try {
      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        command,
      ]);

      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error: ${result.stderr}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Browse directories inside container
  Future<List<String>> listContainerDirectory(String path) async {
    try {
      final result = await Process.run('docker', [
        'exec',
        _containerName,
        'bash',
        '-c',
        'ls -1 "$path" 2>/dev/null || echo ""',
      ]);

      if (result.exitCode == 0) {
        return result.stdout
            .toString()
            .trim()
            .split('\n')
            .where((f) => f.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error listing directory: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _playProcess?.kill();
    super.dispose();
  }
}
