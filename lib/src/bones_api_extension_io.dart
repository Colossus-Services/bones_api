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
  static final _fileLimited = FileLimited.global;

  /// Returns the current maximum number of concurrent file operations.
  ///
  /// Default: 50
  ///
  /// See [FileLimited.global]
  static int getSemaphoreLimit() => _fileLimited.getSemaphoreLimit();

  /// Updates the maximum number of concurrent file operations.
  ///
  /// Re-initializes the global semaphore with the new [limit].
  /// Throws an [ArgumentError] if [limit] is zero or negative.
  ///
  /// See [FileLimited.global]
  static void setSemaphoreLimit(int limit) =>
      _fileLimited.setSemaphoreLimit(limit);

  /// Similar to [File.readAsBytes], but limits concurrency to a
  /// maximum of [_semaphoreLimit] simultaneous reads.
  ///
  /// This helps prevent `Too many open files` errors and reduces
  /// disk I/O contention or throttling on shared or virtualized
  /// storage systems.
  ///
  /// See [FileLimited.global]
  Future<Uint8List> readAsBytesLimited() => _fileLimited.readAsBytes(this);

  /// Similar to [File.writeAsBytes], but limits concurrency to a
  /// maximum of [_semaphoreLimit] simultaneous writes.
  ///
  /// This prevents excessive concurrent file access that could
  /// cause I/O bottlenecks or file handle exhaustion.
  ///
  /// See [FileLimited.global]
  Future<File> writeAsBytesLimited(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _fileLimited.writeAsBytes(this, bytes, mode: mode, flush: flush);

  /// Similar to [File.stat], but limits concurrency to the current
  /// semaphore limit to reduce excessive parallel I/O operations.
  ///
  /// Helps prevent `Too many open files` errors and mitigates disk
  /// contention when multiple files are accessed simultaneously.
  ///
  /// See [FileLimited.global]
  Future<FileStat> statLimited() => _fileLimited.stat(this);

  /// Similar to [File.delete], but limits concurrency to the current
  /// semaphore limit to avoid excessive parallel I/O operations.
  ///
  /// Helps prevent `Too many open files` errors and reduces disk
  /// contention when deleting multiple files concurrently.
  ///
  /// See [FileLimited.global]
  Future<void> deleteLimited({bool recursive = false}) =>
      _fileLimited.delete(this, recursive: recursive);

  /// Similar to [File.exists], but respects the current semaphore limit to
  /// prevent excessive parallel filesystem checks.
  ///
  /// Helps avoid `Too many open files` errors and ensures consistent I/O
  /// throttling when scanning large directory trees or checking many files
  /// concurrently.
  Future<void> exists() => _fileLimited.exists(this);
}

/// A concurrency guard for file system operations.
///
/// This class wraps common `dart:io` file APIs with a shared semaphore to avoid
/// excessive parallel access, preventing `Too many open files` errors and
/// reducing I/O contention — especially on SSDs, NFS/S3-backed storage,
/// CI machines, or containerized environments.
///
/// The semaphore applies globally to all operations performed through this
/// instance.
///
/// Default concurrency limit: 50.
class FileLimited {
  /// A shared singleton instance of [FileLimited].
  ///
  /// Useful when the same concurrency control should apply across the entire
  /// application or subsystem, ensuring all file operations are throttled
  /// consistently under a unified semaphore.
  ///
  /// Intended for shared usage rather than per-component instantiation.
  static final global = FileLimited(name: '[GLOBAL]');

  /// Default semaphore limit across all operations.
  static const int defaultSemaphoreLimit = 50;

  /// Instance identifier used for debugging or logging purposes.
  final String? name;

  /// Global semaphore enforcing the concurrency limit.
  Semaphore _semaphore;
  int _semaphoreLimit;

  FileLimited({this.name, int semaphoreLimit = defaultSemaphoreLimit})
    : _semaphore = Semaphore(semaphoreLimit),
      _semaphoreLimit = semaphoreLimit;

  /// Returns the current concurrency limit for file operations.
  int getSemaphoreLimit() => _semaphoreLimit;

  /// Updates the maximum concurrency level for file operations.
  ///
  /// If [limit] is unchanged, the call is ignored.
  /// Throws [ArgumentError] if [limit] is zero or negative.
  ///
  /// Changing the limit resets the internal semaphore.
  void setSemaphoreLimit(int limit) {
    if (limit == _semaphoreLimit) return;

    if (limit <= 0) throw ArgumentError('Invalid limit: $limit');

    _semaphore = Semaphore(limit);
    _semaphoreLimit = limit;
  }

  /// Reads all bytes from [file] with controlled concurrency.
  ///
  /// Works like [File.readAsBytes], but enforces the semaphore limit to avoid
  /// file handle exhaustion or disk saturation under parallel load.
  Future<Uint8List> readAsBytes(File file) async {
    await _semaphore.acquire();
    try {
      return await file.readAsBytes();
    } finally {
      _semaphore.release();
    }
  }

  /// Writes [bytes] to [file] with controlled concurrency.
  ///
  /// Works like [File.writeAsBytes], but uses the semaphore to avoid excessive
  /// parallel writes that could trigger system throttling or failures.
  Future<File> writeAsBytes(
    File file,
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await _semaphore.acquire();
    try {
      return await file.writeAsBytes(bytes, mode: mode, flush: flush);
    } finally {
      _semaphore.release();
    }
  }

  /// Retrieves metadata for [file] with concurrency control.
  ///
  /// Wraps [File.stat] and is useful when scanning many files in parallel.
  Future<FileStat> stat(File file) async {
    await _semaphore.acquire();
    try {
      return await file.stat();
    } finally {
      _semaphore.release();
    }
  }

  /// Deletes [file] under the current concurrency limit.
  ///
  /// Useful when removing many files at once to avoid overwhelming the file
  /// system. Wraps [File.delete].
  Future<void> delete(File file, {bool recursive = false}) async {
    await _semaphore.acquire();
    try {
      await file.delete(recursive: recursive);
    } finally {
      _semaphore.release();
    }
  }

  /// Checks whether the given [file] exists, using the current concurrency limit.
  ///
  /// Wraps [File.exists] to prevent excessive parallel file system queries,
  /// which can trigger filesystem throttling or `Too many open files` errors
  /// when scanning large directory trees.
  Future<bool> exists(File file) async {
    await _semaphore.acquire();
    try {
      return await file.exists();
    } finally {
      _semaphore.release();
    }
  }

  @override
  String toString() =>
      'FileLimited{name: $name, semaphoreLimit: $_semaphoreLimit}';
}
