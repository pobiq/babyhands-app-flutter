/// 지문자 학습 화면에서 사용하는 글자별 학습 자료 정의다.
class LetterLearningResource {
  const LetterLearningResource({
    required this.letter,
    required this.name,
    required this.group,
    required this.guide,
    required this.tips,
  });

  final String letter;
  final String name;
  final LetterGroup group;
  final String guide;
  final List<String> tips;
}

/// 지문자 목록을 자음/모음으로 구분하기 위한 값이다.
enum LetterGroup { consonant, vowel }

/// MVP에서 학습 대상으로 확정한 한글 지문자 전체 목록이다.
class LetterCatalog {
  const LetterCatalog._();

  static const List<LetterLearningResource> resources = [
    LetterLearningResource(
      letter: '\u3131',
      name: '기역',
      group: LetterGroup.consonant,
      guide: '검지를 옆으로 굽혀 ㄱ 형태를 만든다.',
      tips: ['손목을 세운다', '검지 끝을 또렷하게 보인다'],
    ),
    LetterLearningResource(
      letter: '\u3134',
      name: '니은',
      group: LetterGroup.consonant,
      guide: '검지와 중지를 펴서 ㄴ 방향을 만든다.',
      tips: ['두 손가락 간격을 유지한다', '손바닥이 카메라를 향하게 한다'],
    ),
    LetterLearningResource(
      letter: '\u3137',
      name: '디귿',
      group: LetterGroup.consonant,
      guide: '엄지와 검지를 벌려 ㄷ의 열린 모양을 만든다.',
      tips: ['엄지를 너무 접지 않는다', '손 모양을 화면 중앙에 둔다'],
    ),
    LetterLearningResource(
      letter: '\u3139',
      name: '리을',
      group: LetterGroup.consonant,
      guide: '손가락을 꺾어 ㄹ의 꺾인 흐름을 표현한다.',
      tips: ['손가락 관절을 분명히 접는다', '천천히 자세를 고정한다'],
    ),
    LetterLearningResource(
      letter: '\u3141',
      name: '미음',
      group: LetterGroup.consonant,
      guide: '손가락을 모아 네모난 ㅁ 형태를 만든다.',
      tips: ['손바닥을 평평하게 편다', '손끝이 화면 밖으로 나가지 않게 한다'],
    ),
    LetterLearningResource(
      letter: '\u3142',
      name: '비읍',
      group: LetterGroup.consonant,
      guide: '손가락을 세워 ㅂ의 두 기둥처럼 보이게 한다.',
      tips: ['검지와 중지를 나란히 둔다', '손목 흔들림을 줄인다'],
    ),
    LetterLearningResource(
      letter: '\u3145',
      name: '시옷',
      group: LetterGroup.consonant,
      guide: '두 손가락을 사선으로 모아 ㅅ 형태를 만든다.',
      tips: ['손가락 끝을 모은다', '손등 그림자를 줄인다'],
    ),
    LetterLearningResource(
      letter: '\u3147',
      name: '이응',
      group: LetterGroup.consonant,
      guide: '엄지와 검지로 동그라미를 만든다.',
      tips: ['원 모양을 닫는다', '나머지 손가락은 편하게 둔다'],
    ),
    LetterLearningResource(
      letter: '\u3148',
      name: '지읒',
      group: LetterGroup.consonant,
      guide: '손가락을 꺾어 ㅈ의 위아래 방향을 만든다.',
      tips: ['검지를 또렷하게 세운다', '손을 너무 기울이지 않는다'],
    ),
    LetterLearningResource(
      letter: '\u314A',
      name: '치읓',
      group: LetterGroup.consonant,
      guide: 'ㅈ 모양에서 획 하나를 더한 느낌으로 손가락을 편다.',
      tips: ['중지를 함께 보인다', '손가락이 겹치지 않게 한다'],
    ),
    LetterLearningResource(
      letter: '\u314B',
      name: '키읔',
      group: LetterGroup.consonant,
      guide: 'ㄱ 모양을 크게 만들고 손목 각도를 분명히 한다.',
      tips: ['검지를 길게 편다', '엄지 위치를 고정한다'],
    ),
    LetterLearningResource(
      letter: '\u314C',
      name: '티읕',
      group: LetterGroup.consonant,
      guide: 'ㄷ 모양에 가로 획을 더한 자세를 만든다.',
      tips: ['손바닥을 정면에 둔다', '손끝 높이를 맞춘다'],
    ),
    LetterLearningResource(
      letter: '\u314D',
      name: '피읖',
      group: LetterGroup.consonant,
      guide: 'ㅂ 모양을 더 넓게 벌려 ㅍ 형태를 표현한다.',
      tips: ['손가락 간격을 넓힌다', '손목을 화면 중앙에 둔다'],
    ),
    LetterLearningResource(
      letter: '\u314E',
      name: '히읗',
      group: LetterGroup.consonant,
      guide: 'ㅇ 모양 위에 획을 더하듯 손가락을 둔다.',
      tips: ['원 모양을 유지한다', '검지 위치를 또렷하게 한다'],
    ),
    LetterLearningResource(
      letter: '\u314F',
      name: '아',
      group: LetterGroup.vowel,
      guide: '손을 세우고 엄지를 옆으로 뻗어 ㅏ 방향을 만든다.',
      tips: ['엄지를 수평으로 편다', '손바닥을 정면에 둔다'],
    ),
    LetterLearningResource(
      letter: '\u3151',
      name: '야',
      group: LetterGroup.vowel,
      guide: 'ㅏ 자세에서 손가락 방향을 한 번 더 강조한다.',
      tips: ['엄지와 검지를 분리한다', '손을 흔들지 않는다'],
    ),
    LetterLearningResource(
      letter: '\u3153',
      name: '어',
      group: LetterGroup.vowel,
      guide: '손을 세우고 엄지를 반대 방향으로 뻗어 ㅓ 방향을 만든다.',
      tips: ['엄지 방향을 확인한다', '손등이 과하게 돌아가지 않게 한다'],
    ),
    LetterLearningResource(
      letter: '\u3155',
      name: '여',
      group: LetterGroup.vowel,
      guide: 'ㅓ 자세에서 손가락 방향을 한 번 더 강조한다.',
      tips: ['손목 각도를 유지한다', '엄지 끝을 화면에 보인다'],
    ),
    LetterLearningResource(
      letter: '\u3157',
      name: '오',
      group: LetterGroup.vowel,
      guide: '손가락을 위로 세워 ㅗ 방향을 만든다.',
      tips: ['손끝을 위로 향한다', '팔꿈치 움직임을 줄인다'],
    ),
    LetterLearningResource(
      letter: '\u315B',
      name: '요',
      group: LetterGroup.vowel,
      guide: 'ㅗ 자세에서 위쪽 방향을 더 분명히 보여준다.',
      tips: ['손끝 높이를 유지한다', '카메라와 거리를 맞춘다'],
    ),
    LetterLearningResource(
      letter: '\u315C',
      name: '우',
      group: LetterGroup.vowel,
      guide: '손가락을 아래쪽으로 두어 ㅜ 방향을 만든다.',
      tips: ['손목을 낮춘다', '손가락이 가려지지 않게 한다'],
    ),
    LetterLearningResource(
      letter: '\u3160',
      name: '유',
      group: LetterGroup.vowel,
      guide: 'ㅜ 자세에서 아래쪽 방향을 더 분명히 보여준다.',
      tips: ['손끝 방향을 유지한다', '카메라 중앙에 맞춘다'],
    ),
    LetterLearningResource(
      letter: '\u3161',
      name: '으',
      group: LetterGroup.vowel,
      guide: '손을 수평으로 두어 ㅡ 방향을 만든다.',
      tips: ['손가락을 나란히 둔다', '수평선을 유지한다'],
    ),
    LetterLearningResource(
      letter: '\u3163',
      name: '이',
      group: LetterGroup.vowel,
      guide: '손을 수직으로 세워 ㅣ 방향을 만든다.',
      tips: ['손가락을 곧게 편다', '손바닥을 정면에 둔다'],
    ),
    LetterLearningResource(
      letter: '\u3150',
      name: '애',
      group: LetterGroup.vowel,
      guide: 'ㅏ 자세에 가로 획을 더하는 느낌으로 손 모양을 만든다.',
      tips: ['손가락 간격을 일정하게 둔다', '엄지 방향을 유지한다'],
    ),
    LetterLearningResource(
      letter: '\u3152',
      name: '얘',
      group: LetterGroup.vowel,
      guide: 'ㅑ 자세에 가로 획을 더해 ㅒ 형태를 분명히 한다.',
      tips: ['두 방향을 동시에 보여준다', '손목을 고정한다'],
    ),
    LetterLearningResource(
      letter: '\u3154',
      name: '에',
      group: LetterGroup.vowel,
      guide: 'ㅓ 자세에 가로 획을 더하는 느낌으로 손 모양을 만든다.',
      tips: ['엄지 방향을 반대로 유지한다', '손등 회전을 줄인다'],
    ),
    LetterLearningResource(
      letter: '\u3156',
      name: '예',
      group: LetterGroup.vowel,
      guide: 'ㅕ 자세에 가로 획을 더해 ㅖ 형태를 또렷하게 만든다.',
      tips: ['손끝 위치를 일정하게 둔다', '두 획의 방향을 분리한다'],
    ),
    LetterLearningResource(
      letter: '\u3158',
      name: '와',
      group: LetterGroup.vowel,
      guide: 'ㅗ와 ㅏ 동작을 이어서 ㅘ의 결합 형태를 만든다.',
      tips: ['위쪽 방향을 먼저 잡는다', '옆 방향 전환을 분명히 한다'],
    ),
    LetterLearningResource(
      letter: '\u3159',
      name: '왜',
      group: LetterGroup.vowel,
      guide: 'ㅗ와 ㅐ 동작을 결합해 ㅙ 형태를 표현한다.',
      tips: ['결합 동작을 천천히 만든다', '손가락 간격을 유지한다'],
    ),
    LetterLearningResource(
      letter: '\u315A',
      name: '외',
      group: LetterGroup.vowel,
      guide: 'ㅗ와 ㅣ 동작을 합쳐 ㅚ의 합성 모양을 만든다.',
      tips: ['위쪽 축을 유지한다', '수직선 표현을 또렷하게 한다'],
    ),
    LetterLearningResource(
      letter: '\u315D',
      name: '워',
      group: LetterGroup.vowel,
      guide: 'ㅜ와 ㅓ 동작을 이어 ㅝ의 결합 형태를 만든다.',
      tips: ['아래쪽 방향을 먼저 잡는다', '반대 방향 전환을 분명히 한다'],
    ),
    LetterLearningResource(
      letter: '\u315E',
      name: '웨',
      group: LetterGroup.vowel,
      guide: 'ㅜ와 ㅔ 동작을 결합해 ㅞ 형태를 표현한다.',
      tips: ['아래쪽 축을 유지한다', '가로 획을 분명히 보여준다'],
    ),
    LetterLearningResource(
      letter: '\u315F',
      name: '위',
      group: LetterGroup.vowel,
      guide: 'ㅜ와 ㅣ 동작을 합쳐 ㅟ의 결합 모양을 만든다.',
      tips: ['아래 방향을 유지한다', '수직선 표현을 또렷하게 한다'],
    ),
    LetterLearningResource(
      letter: '\u3162',
      name: '의',
      group: LetterGroup.vowel,
      guide: 'ㅡ와 ㅣ 동작을 연결해 ㅢ의 합성 형태를 만든다.',
      tips: ['수평선을 먼저 고정한다', '수직선 전환을 자연스럽게 한다'],
    ),
  ];

  static List<String> get consonants => [
    for (final resource in resources)
      if (resource.group == LetterGroup.consonant) resource.letter,
  ];

  static List<String> get vowels => [
    for (final resource in resources)
      if (resource.group == LetterGroup.vowel) resource.letter,
  ];

  static LetterLearningResource find(String letter) {
    return resources.firstWhere((resource) => resource.letter == letter);
  }
}
