import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

/// [ReceivePort] listener.
class PortListener {
  final ReceivePort port;

  late final StreamSubscription _subscription;

  PortListener(this.port) {
    _subscription = port.listen(_onData, cancelOnError: true);
  }

  /// Closes this listener and cancels its [StreamSubscription].
  Future<void> close() async {
    await _subscription.cancel();
  }

  final ListQueue<Completer> _waitingQueue = ListQueue();

  final ListQueue _unflushedQueue = ListQueue();

  void _onData(o) {
    if (_waitingQueue.isEmpty) {
      _unflushedQueue.addLast(o);
      return;
    }

    var completer = _waitingQueue.removeFirst();
    if (!completer.isCompleted) {
      completer.complete(o);
    } else {
      _unflushedQueue.addLast(o);
    }
  }

  /// Waits and returns the next event value.
  Future next() {
    if (_unflushedQueue.isNotEmpty) {
      var o = _unflushedQueue.removeFirst();
      return Future.value(o);
    }

    var completer = Completer();
    _waitingQueue.addLast(completer);
    return completer.future;
  }
}
