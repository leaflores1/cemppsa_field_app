const List<String> _connectivityErrorNeedles = <String>[
  'socketexception',
  'network is unreachable',
  'failed host lookup',
  'connection failed',
  'connection refused',
  'connection reset',
  'connection timed out',
  'timed out',
  'timeoutexception',
  'clientexception',
];

bool isConnectivityFailure({
  int? statusCode,
  String? message,
}) {
  final text = (message ?? '').toLowerCase();
  if (text.isNotEmpty) {
    return _connectivityErrorNeedles.any(text.contains);
  }

  return statusCode == null;
}
