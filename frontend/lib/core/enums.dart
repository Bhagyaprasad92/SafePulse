enum LogLevel { info, warning, critical }

class LogMessage {
  final String text;
  final LogLevel level;
  final DateTime timestamp;

  LogMessage(this.text, {this.level = LogLevel.info}) : timestamp = DateTime.now();
}
