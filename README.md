<table style="border:none; width:100%;">
  <tr style="border:none;">
    <td style="border:none; vertical-align:middle;">
      <img src="https://github.com/user-attachments/assets/17a8e342-ee96-4d39-8cad-01d9b633284e" width="500" height="500" alt="꼬마손 로고">
    </td>
    <td style="border:none; text-align:right; vertical-align:middle;">
      <b>개발자</b> - 한정훈
      <br><br><br>
       <b>프로젝트 기간</b>
       <br>
      2025.10.31 ~ 2025.11.13
    </td>
  </tr>
</table>

<br>

## 1. 서비스 소개

### 주제 : Media-Pipe AI 모델에 기반한 수어 동작의 정확도를 측정하는 수어 학습 플랫폼

- 카메라로 사용자의 수어 동작을 실시간으로 인식하고, AI가 정확도와 자연스러움을 분석하는 기능 제공
- 사용자는 AI 피드백을 통해 자신의 수어 실력을 객관적으로 평가하고 향상시킬 수 있음
- 학습 결과를 시각적으로 확인하고, 개별 동작별 정확도 점수 및 개선 가이드 제공

<br>

## 2. 주요 기능

- 기본 자모음 학습 컨텐츠 무료 제공
- MediaPipe AI 로 실시간 수어 인식 후 예측 및 정확도 표시 기능 구현
- 랭킹 시스템을 통해 성취감과 지속적인 학습을 유도

<br>

## 3. 기술 스택

<table>
  <tr>
    <th>구분</th>
    <th>사용 기술</th>
  </tr>

  <tr>
    <td><b>Frontend</b></td>
    <td>
      <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
      <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white"/>
    </td>
  </tr>

  <tr>
    <td><b>Backend</b></td>
    <td>
      <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white"/>
      <img src="https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white"/>
      <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
    </td>
  </tr>

  <tr>
    <td><b>AI 서버</b></td>
    <td>
      <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=Python&logoColor=white"/>
      <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white"/>
      <img src="https://img.shields.io/badge/MediaPipe-00897B?style=for-the-badge&logo=google&logoColor=white"/>
      <img src="https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white"/>
      <img src="https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white"/>
    </td>
  </tr>

  <tr>
    <td><b>데이터베이스</b></td>
    <td>
      <img src="https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white"/>
    </td>
  </tr>

  <tr>
    <td><b>인증</b></td>
    <td>
      <img src="https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white"/>
      <img src="https://img.shields.io/badge/Google-4285F4?style=for-the-badge&logo=google&logoColor=white"/>
      <img src="https://img.shields.io/badge/Kakao-FFCD00?style=for-the-badge&logo=kakao&logoColor=black"/>
      <img src="https://img.shields.io/badge/Naver-03C75A?style=for-the-badge&logo=naver&logoColor=white"/>
    </td>
  </tr>

  <tr>
    <td><b>협업도구</b></td>
    <td>
      <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=GitHub&logoColor=white"/>
    </td>
  </tr>

</table>

<br>

## 4. 시스템 아키텍쳐

```mermaid
flowchart TD
    subgraph Client["📱 Client"]
        Flutter["Flutter App\n(Dart)"]
    end

    subgraph Auth["🔐 소셜 로그인"]
        Google["Google OAuth"]
        Kakao["Kakao OAuth"]
        Naver["Naver OAuth"]
    end

    subgraph Backend["🖥️ Backend (Node.js)"]
        Express["Express.js REST API"]
        JWT["JWT 인증"]
        Express --> JWT
    end

    subgraph AI["🤖 AI 서버 (Python)"]
        FastAPI["FastAPI"]
        MediaPipe["MediaPipe\n손 랜드마크 추출"]
        TFLite["TFLite 모델\n수어 분류"]
        FastAPI --> MediaPipe --> TFLite
    end

    subgraph DB["🗄️ Database"]
        MySQL["MySQL"]
    end

    Flutter -->|"REST API\n(회원/랭킹/학습결과)"| Express
    Flutter -->|"소셜 로그인"| Google & Kakao & Naver
    Google & Kakao & Naver -->|"토큰 검증"| Express
    Flutter -->|"카메라 프레임 전송"| FastAPI
    FastAPI -->|"수어 예측 결과 반환"| Flutter
    Express <-->|"데이터 저장/조회"| MySQL
```

<br>

## 5. 유스케이스

<img width="869" height="593" alt="image" src="https://github.com/user-attachments/assets/fb9f5902-df6f-4941-ae9e-7c69dba54cd4" />

<br>

## 6. 서비스 흐름도

#### 6-1 회원가입 / 로그인

<img width="912" height="572" alt="image" src="https://github.com/user-attachments/assets/6ad51630-8bca-46e8-a276-9f3b5e0ba180" />

#### 6-2 아이디 / 비밀번호 찾기

<img width="890" height="564" alt="image" src="https://github.com/user-attachments/assets/7f6fda87-622f-460d-b0a8-5f478ebf65ed" />

#### 6-3 메인 / 학습

<img width="945" height="464" alt="image" src="https://github.com/user-attachments/assets/27a7581d-033d-4485-828a-2a37ec06f209" />

<br>

## 7. ER 다이어그램

```mermaid
erDiagram
    tb_member {
        BIGINT id PK
        VARCHAR email UK
        VARCHAR pw
        VARCHAR nickname UK
        INT total_score
        DATETIME created_at
        DATETIME updated_at
    }

    tb_sign_language {
        BIGINT id PK
        VARCHAR meaning
        VARCHAR video_path
    }

    tb_attendance {
        BIGINT id PK
        BIGINT member_id FK
        DATE login_date
    }

    tb_sl_learn {
        BIGINT id PK
        DATE sl_learn_date
        BIGINT sl_id FK
        BIGINT member_id FK
    }

    tb_sl_test {
        BIGINT id PK
        DATE sl_test_date
        VARCHAR choose_answer
        BIGINT member_id FK
        BIGINT sl_id FK
    }

    tb_social_account {
        BIGINT id PK
        VARCHAR provider
        VARCHAR provider_member_id
        VARCHAR provider_email
        BIGINT member_id FK
    }

    tb_feedback {
        BIGINT id PK
        BIGINT member_id FK
        VARCHAR type
        VARCHAR letter
        TEXT message
        TINYINT is_read
        DATETIME created_at
    }

    tb_refresh_token_session {
        CHAR id PK
        BIGINT member_id FK
        DATETIME expires_at
        DATETIME created_at
    }

    tb_email_verification {
        BIGINT id PK
        VARCHAR email
        VARCHAR purpose
        VARCHAR code_hash
        DATETIME expires_at
        DATETIME verified_at
        INT attempt_count
        DATETIME created_at
    }

    tb_member ||--o{ tb_attendance : "출석"
    tb_member ||--o{ tb_sl_learn : "학습"
    tb_member ||--o{ tb_sl_test : "테스트"
    tb_member ||--o{ tb_social_account : "소셜계정"
    tb_member ||--o{ tb_feedback : "피드백"
    tb_member ||--o{ tb_refresh_token_session : "세션"
    tb_sign_language ||--o{ tb_sl_learn : "학습대상"
    tb_sign_language ||--o{ tb_sl_test : "테스트대상"
```

<br>

## 8. 주요 화면 구성

#### 로그인

<img width="1416" height="916" alt="image" src="https://github.com/user-attachments/assets/1cfce9ad-d5fc-43fb-ac0b-32d819e7c2fa" />

#### 메인 화면

<img width="1416" height="919" alt="image" src="https://github.com/user-attachments/assets/86c316e5-0cab-49ea-ac2c-6a7f939c4d13" />

#### 학습하기

<img width="1416" height="917" alt="image" src="https://github.com/user-attachments/assets/b6db8528-067f-459f-b5e2-a78d899076e8" />

#### 테스트

<img width="1415" height="917" alt="image" src="https://github.com/user-attachments/assets/a0193834-f22d-4fdf-ae27-b5d8ca43a494" />

#### 랭킹

<img width="1417" height="914" alt="image" src="https://github.com/user-attachments/assets/baf62303-478b-445e-92cc-797ef1f84b02" />

#### 지난 학습 결과

<img width="1417" height="916" alt="image" src="https://github.com/user-attachments/assets/07bb57f7-d1de-4306-9b96-017e149f1954" />

<br>
