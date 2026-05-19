import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 앱 전역 로거 싱글톤이다.
/// 모바일·데스크톱에서는 debug 레벨까지 콘솔에 출력한다.
/// Flutter 웹은 브라우저 개발자 도구 콘솔로 그대로 노출되므로 기본적으로 로그를 끈다.
final appLogger = Logger(
  level: kIsWeb ? Level.off : Level.debug,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 6,
    lineLength: 80,
    colors: !kIsWeb,
    printEmojis: false,
  ),
);
