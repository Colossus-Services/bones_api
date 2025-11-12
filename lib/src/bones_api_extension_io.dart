import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:async_locks/async_locks.dart';
import 'package:reflection_factory/reflection_factory.dart';

/// Provides global concurrency control for file I/O operations.
///
/// This extension uses a shared [Semaphore] to limit the number of
/// simultaneous file reads or writes. It helps prevent
/// `Too many open files` errors and mitigates disk I/O contention
/// or throttling on shared or virtualized storage systems
/// (e.g., cloud VMs or containers).
extension FileLimitExtension on File {
  // Default concurrency limit.
  static int _semaphoreLimit = 50;

  // Global semaphore shared across all File instances.
  static Semaphore _semaphore = Semaphore(_semaphoreLimit);

  /// Returns the current maximum number of concurrent file operations.
  ///
  /// Default: 50
  static int getSemaphoreLimit() => _semaphoreLimit;

  /// Updates the maximum number of concurrent file operations.
  ///
  /// Re-initializes the global semaphore with the new [limit].
  /// Throws an [ArgumentError] if [limit] is zero or negative.
  static void setSemaphoreLimit(int limit) {
    if (limit == _semaphoreLimit) return;
    if (limit <= 0) throw ArgumentError("Invalid limit: $limit");

    _semaphoreLimit = limit;
    _semaphore = Semaphore(limit);
  }

  /// Similar to [File.readAsBytes], but limits concurrency to a
  /// maximum of [_semaphoreLimit] simultaneous reads.
  ///
  /// This helps prevent `Too many open files` errors and reduces
  /// disk I/O contention or throttling on shared or virtualized
  /// storage systems.
  Future<Uint8List> readAsBytesLimited() async {
    await _semaphore.acquire();
    try {
      return await readAsBytes();
    } finally {
      _semaphore.release();
    }
  }

  /// Similar to [File.writeAsBytes], but limits concurrency to a
  /// maximum of [_semaphoreLimit] simultaneous writes.
  ///
  /// This prevents excessive concurrent file access that could
  /// cause I/O bottlenecks or file handle exhaustion.
  Future<File> writeAsBytesLimited(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await _semaphore.acquire();
    try {
      return await writeAsBytes(bytes, mode: mode, flush: flush);
    } finally {
      _semaphore.release();
    }
  }

  /// Similar to [File.stat], but limits concurrency to the current
  /// semaphore limit to reduce excessive parallel I/O operations.
  ///
  /// Helps prevent `Too many open files` errors and mitigates disk
  /// contention when multiple files are accessed simultaneously.
  Future<FileStat> statLimited() async {
    await _semaphore.acquire();
    try {
      return await stat();
    } finally {
      _semaphore.release();
    }
  }

  /// Similar to [File.delete], but limits concurrency to the current
  /// semaphore limit to avoid excessive parallel I/O operations.
  ///
  /// Helps prevent `Too many open files` errors and reduces disk
  /// contention when deleting multiple files concurrently.
  Future<void> deleteLimited({bool recursive = false}) async {
    await _semaphore.acquire();
    try {
      await delete(recursive: recursive);
    } finally {
      _semaphore.release();
    }
  }
}
