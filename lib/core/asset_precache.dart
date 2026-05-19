import 'package:flutter/material.dart';

/// 앱 공통 에셋 경로다. 로그인·헤더 등에서 동일 문자열을 쓴다.
const String kBabyhandsHandIconAsset = 'assets/images/handicon.png';

/// 자주 쓰는 에셋을 미리 디코드해 [PaintingBinding.imageCache]에 올려
/// 첫 화면 전환 시 깜빡임을 줄인다. 에셋이 없으면 조용히 무시한다.
Future<void> precacheBabyhandsCommonAssets(BuildContext context) {
  return precacheImage(
    const AssetImage(kBabyhandsHandIconAsset),
    context,
  ).catchError((_) {});
}
