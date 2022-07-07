typedef InstanceInfoExtractor<O, I> = I Function(O o);

/// Tracks an instance with a info relationship.
///
/// Uses [Expando].
class InstanceTracker<O extends Object, I extends Object> {
  /// Name of this instance tracker.
  final String name;

  /// The info extractor.
  final InstanceInfoExtractor<O, I> instanceInfoExtractor;

  final Expando<I> _instancesInfo;

  InstanceTracker(this.name, this.instanceInfoExtractor)
      : _instancesInfo = Expando(name);

  /// Extract the info of instance [o].
  I extractInfo(O o) => instanceInfoExtractor(o);

  /// Returns `true` if instance [o] is tracked.
  bool isTrackedInstance(O o) => getTrackedInstanceInfo(o) != null;

  /// returns the [o] info, if tracked.
  I? getTrackedInstanceInfo(O o) {
    var trackedInfo = _instancesInfo[o];
    return trackedInfo;
  }

  /// Tracks instance [o]
  O trackInstance(O o) {
    var info = extractInfo(o);

    _instancesInfo[o] = info;

    return o;
  }

  /// Untracks instance [o].
  void untrackInstance(O? o) {
    if (o == null) return;

    _instancesInfo[o] = null;
  }

  /// Same as [trackInstance] with a nullable [o].
  O? trackInstanceNullable(O? o) {
    return o != null ? trackInstance(o) : null;
  }

  /// Tracks instances [os].
  List<O> trackInstances(Iterable<O> os) {
    return os.map((o) => trackInstance(o)).toList();
  }

  /// Same as [trackInstanceNullable] with a nullable [os].
  List<O?> trackInstancesNullable(Iterable<O?> os) {
    return os.map((o) => trackInstanceNullable(o)).toList();
  }

  /// Untrack instances [os].
  void untrackInstances(Iterable<O?> os) {
    for (var o in os) {
      untrackInstance(o);
    }
  }
}
