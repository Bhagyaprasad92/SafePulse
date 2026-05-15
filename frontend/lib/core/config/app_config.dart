class AppConfig {
  // For local development (Android Emulator):
  // static const String _localUrl = 'http://10.0.2.2:5001';
  
  // For local development (iOS Simulator):
  // static const String _localUrl = 'http://localhost:5001';
  
  // For real device on same network:
  static const String _localUrl = 'http://YOUR_LOCAL_IP:5002';
  // (Replace with your computer's local IP if it changes)
  
  // For production (deployed backend):
  // static const String _localUrl = 'http://YOUR_SERVER_IP:5002';
  

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: _localUrl, 
  );

  static const String routeSuggestEndpoint = '/api/routes/suggest';
  static String get routeSuggestUrl => '$baseUrl$routeSuggestEndpoint';

  static String get realtimeUrl {
    final uri = Uri.parse(baseUrl);
    return uri
        .replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '/ws/tracking',
          query: '',
        )
        .toString();
  }
}
