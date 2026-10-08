import 'dart:async';
import 'dart:io';

String friendlyError(Object error, {String fallback = 'تعذر تنفيذ العملية. حاول مرة أخرى.'}) {
  final serverMessage = functionErrorMessage(error);
  if (serverMessage != null) return serverMessage;

  if (error is SocketException) {
    return 'لا يمكن الاتصال بالخادم. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
  }
  if (error is TimeoutException) {
    return 'انتهت مهلة الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.';
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('socketfailed') ||
      raw.contains('failed host lookup') ||
      raw.contains('host lookup') ||
      raw.contains('no address associated with hostname') ||
      raw.contains('errno = 7') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('connection closed') ||
      raw.contains('clientexception')) {
    return 'لا يمكن الاتصال بالخادم. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
  }
  if (raw.contains('timed out') || raw.contains('timeout')) {
    return 'انتهت مهلة الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.';
  }
  if (raw.contains('failed to fetch') || raw.contains('function fetch')) {
    return 'تعذر الوصول إلى خدمة الخادم حالياً. تحقق من الإنترنت ثم حاول مرة أخرى.';
  }
  if (error is FormatException) {
    return 'وصلت استجابة غير صالحة من الخادم. حاول مرة أخرى.';
  }

  final text = error.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '').trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

String? functionErrorMessage(Object error) {
  try {
    final dynamic e = error;
    final details = e.details;
    if (details is Map) {
      final message = details['error']?.toString();
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
  } catch (_) {}
  return null;
}
