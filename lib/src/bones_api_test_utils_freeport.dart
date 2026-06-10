import 'dart:math' show Random;

import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

final Set<int> _initFreePorts = <int>{};

@override
Future<int> resolveFreePort(int port) {
  var startPort = port - 100;
  var endPort = port + 100;

  var initPort = _randomPort(startPort, endPort);
  var initPortAttempt = 0;

  while (++initPortAttempt < 200 && _initFreePorts.contains(initPort)) {
    initPort = _randomPort(startPort, endPort);
  }

  _initFreePorts.add(initPort);

  return getFreeListenPort(
    ports: [initPort],
    startPort: startPort,
    endPort: endPort,
  ).then((freePort) => freePort ?? port);
}

var _rand = Random();

int _randomPort(int startPort, int endPort) {
  var range = endPort - startPort;
  return startPort + _rand.nextInt(range);
}
