const Duration kRemoteTimeout = Duration(seconds: 8);

Future<T> remoteOrLocal<T>(
  Future<T> Function() remote,
  T Function() local,
) async {
  try {
    return await remote().timeout(kRemoteTimeout);
  } catch (_) {
    return local();
  }
}

Future<void> writeLocalThenRemote(
  void Function() local,
  Future<void> Function() remote,
) async {
  local();
  try {
    await remote().timeout(kRemoteTimeout);
  } catch (_) {}
}
