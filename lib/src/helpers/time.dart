/// ミリ秒を HH:MM:SS 形式に変換します。秒未満は切り捨てられます。
String millisecondsToHHMMSS(int ms) {
  return secondsToHHMMSS(ms ~/ 1000);
}

/// ミリ秒を M:SS 形式に変換します。分の十の位はスペースでパディングされます。
/// 秒未満は切り捨てられます。
String millisecondsToMSS(int ms) {
  return secondsToMSS(ms ~/ 1000);
}

/// 秒を HH:MM:SS 形式に変換します。
String secondsToHHMMSS(int seconds) {
  final int h = seconds ~/ 3600;
  final int m = (seconds - h * 3600) ~/ 60;
  final int s = seconds % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

/// 秒を M:SS 形式に変換します。分の十の位はスペースでパディングされます。
String secondsToMSS(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, ' ')}:${s.toString().padLeft(2, '0')}';
}
