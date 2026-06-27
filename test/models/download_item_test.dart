import 'package:flutter_test/flutter_test.dart';
import 'package:turboget/models/download_item.dart';

void main() {
  group('DownloadItem', () {
    late DownloadItem downloadItem;

    setUp(() {
      downloadItem = DownloadItem(
        id: 'test_id',
        url: 'https://example.com/file.mp4',
        filename: 'file.mp4',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        totalSize: 1000000, // 1 MB
        downloadedSize: 0,
        status: 'queued',
        progress: 0,
      );
    });

    group('Speed Calculation', () {
      test('should return 0 KB/s when no updates', () {
        expect(downloadItem.formattedSpeed, equals('0 KB/s'));
      });

      test('should calculate speed correctly', () {
        downloadItem.updateSpeed(100000); // 100KB after 1 second
        
        expect(downloadItem.formattedSpeed, equals('100.0 KB/s'));
      });

      test('should format speed in MB/s for large files', () {
        downloadItem.updateSpeed(2000000); // 2MB after 1 second
        
        expect(downloadItem.formattedSpeed, equals('2.0 MB/s'));
      });

      test('should calculate progress percentage', () {
        downloadItem.updateSpeed(500000);
        
        expect(downloadItem.progress, equals(50));
      });
    });

    group('Time Remaining Estimation', () {
      test('should return --:-- when no speed', () {
        expect(downloadItem.estimatedTimeRemaining, equals('--:--'));
      });

      test('should calculate seconds remaining', () {
        downloadItem.totalSize = 100000; // 100KB
        downloadItem.updateSpeed(10000); // 10KB/s
        
        // Should be approximately 9 seconds remaining
        expect(downloadItem.estimatedTimeRemaining, contains('s'));
      });

      test('should format minutes and seconds correctly', () {
        downloadItem.totalSize = 6000000; // 6MB
        downloadItem.updateSpeed(100000); // 100KB/s
        
        // ~60 seconds = 1m 0s
        expect(downloadItem.estimatedTimeRemaining, contains('m'));
      });
    });

    group('Serialization', () {
      test('should serialize to map correctly', () {
        final map = downloadItem.toMap();
        
        expect(map['id'], equals('test_id'));
        expect(map['url'], equals('https://example.com/file.mp4'));
        expect(map['filename'], equals('file.mp4'));
        expect(map['status'], equals('queued'));
      });

      test('should deserialize from map correctly', () {
        final map = {
          'id': 'test_id',
          'url': 'https://example.com/file.mp4',
          'filename': 'file.mp4',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'total_size': 1000000,
          'downloaded_size': 500000,
          'status': 'downloading',
          'progress': 50,
        };

        final item = DownloadItem.fromMap(map);
        
        expect(item.id, equals('test_id'));
        expect(item.url, equals('https://example.com/file.mp4'));
        expect(item.totalSize, equals(1000000));
        expect(item.downloadedSize, equals(500000));
        expect(item.status, equals('downloading'));
      });

      test('should handle null optional fields', () {
        final map = {
          'id': 'test_id',
          'url': 'https://example.com/file.mp4',
          'filename': 'file.mp4',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        };

        final item = DownloadItem.fromMap(map);
        
        expect(item.totalSize, isNull);
        expect(item.downloadedSize, equals(0));
        expect(item.status, equals('queued'));
      });

      test('should serialize and deserialize segments', () {
        final item = DownloadItem(
          id: 'test_id',
          url: 'https://example.com/file.mp4',
          filename: 'file.mp4',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          segments: [
            DownloadSegment(
              id: 1,
              downloadId: 'test_id',
              startByte: 0,
              endByte: 500000,
              downloadedBytes: 250000,
              status: 'downloading',
            ),
          ],
        );

        final map = item.toMap();
        final restored = DownloadItem.fromMap(map);
        
        expect(restored.segments, isNotNull);
        expect(restored.segments!.length, equals(1));
        expect(restored.segments!.first.downloadedBytes, equals(250000));
      });
    });

    group('Status Management', () {
      test('should update status correctly', () {
        downloadItem.status = 'downloading';
        expect(downloadItem.status, equals('downloading'));
      });

      test('should track progress', () {
        downloadItem.progress = 75;
        expect(downloadItem.progress, equals(75));
      });
    });
  });

  group('DownloadSegment', () {
    test('should create segment with default values', () {
      final segment = DownloadSegment(
        downloadId: 'test_id',
        startByte: 0,
        endByte: 1000000,
      );

      expect(segment.downloadedBytes, equals(0));
      expect(segment.status, equals('pending'));
    });

    test('should serialize to map correctly', () {
      final segment = DownloadSegment(
        id: 1,
        downloadId: 'test_id',
        startByte: 0,
        endByte: 1000000,
        downloadedBytes: 500000,
        status: 'downloading',
      );

      final map = segment.toMap();

      expect(map['id'], equals(1));
      expect(map['download_id'], equals('test_id'));
      expect(map['start_byte'], equals(0));
      expect(map['end_byte'], equals(1000000));
      expect(map['downloaded_bytes'], equals(500000));
      expect(map['status'], equals('downloading'));
    });

    test('should deserialize from map correctly', () {
      final map = {
        'id': 1,
        'download_id': 'test_id',
        'start_byte': 0,
        'end_byte': 1000000,
        'downloaded_bytes': 500000,
        'status': 'downloading',
      };

      final segment = DownloadSegment.fromMap(map);

      expect(segment.id, equals(1));
      expect(segment.downloadId, equals('test_id'));
      expect(segment.startByte, equals(0));
      expect(segment.endByte, equals(1000000));
      expect(segment.downloadedBytes, equals(500000));
      expect(segment.status, equals('downloading'));
    });

    test('should calculate download percentage', () {
      final segment = DownloadSegment(
        downloadId: 'test_id',
        startByte: 0,
        endByte: 1000000,
        downloadedBytes: 250000,
      );

      final percentage = (segment.downloadedBytes / (segment.endByte - segment.startByte)) * 100;
      expect(percentage, equals(25.0));
    });
  });
}
