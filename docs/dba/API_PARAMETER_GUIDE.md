# API 매개변수 가이드

이 문서는 데이터베이스 스키마를 기반으로 각 API 엔드포인트에 필요한 매개변수를 정의합니다.

---

## 목차

1. [회원 관리 API](#1-회원-관리-api)
2. [프로필 관리 API](#2-프로필-관리-api)
3. [상품 검색 API](#3-상품-검색-api)
4. [리뷰 조회 API](#4-리뷰-조회-api)
5. [가격 비교 API](#5-가격-비교-api)
6. [리뷰 요약 API](#6-리뷰-요약-api)
7. [사이즈 인사이트 API](#7-사이즈-인사이트-api)

---

## 1. 회원 관리 API

### 1.1 회원가입 (POST /api/v1/auth/register)

#### 필수 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| email | string | 최대 255자, 이메일 형식 | 이메일 주소 |
| password | string | 최소 8자, 영문+숫자 조합 | 비밀번호 |

#### 선택 매개변수

없음

#### 유효성 검증 규칙

- `email`: RFC 5321 표준 이메일 형식, 중복 불가 (DB: UNIQUE KEY)
- `password`: 최소 8자 이상, 영문 + 숫자 조합 필수

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "user_id": 1,
    "email": "user@example.com",
    "unique_code": "A1B2C3D4",
    "email_verified": false
  }
}
```

---

### 1.2 소셜 로그인 (POST /api/v1/auth/social)

#### 필수 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| provider | string | ENUM('google', 'apple', 'kakao') | 소셜 로그인 제공자 |
| provider_id | string | 최대 255자 | 제공자별 사용자 고유 ID |
| email | string | 최대 255자, 이메일 형식 | 이메일 주소 |

#### 선택 매개변수

없음

#### 유효성 검증 규칙

- `provider`: 'google', 'apple', 'kakao' 중 하나
- `provider_id` + `provider` 조합은 고유해야 함 (DB: UNIQUE KEY)
- 동일 이메일로 다른 provider 등록 시 에러 반환

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "user_id": 2,
    "email": "user@gmail.com",
    "unique_code": "X7Y8Z9W0",
    "provider": "google",
    "is_new_user": true
  }
}
```

---

### 1.3 로그인 (POST /api/v1/auth/login)

#### 필수 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| email | string | 최대 255자, 이메일 형식 | 이메일 주소 |
| password | string | - | 비밀번호 |

#### 선택 매개변수

없음

#### 유효성 검증 규칙

- `email_verified = TRUE` 확인 (미인증 시 에러)
- bcrypt 해시 비교 검증

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "dGhpc2lzYXJlZnJlc2h0b2tlbg...",
    "expires_in": 1800
  }
}
```

---

## 2. 프로필 관리 API

### 2.1 체형 프로필 등록/수정 (PUT /api/v1/profiles/fashion)

#### 필수 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| height | integer | 100-220 | 키 (cm) |
| weight | integer | 30-200 | 몸무게 (kg) |

#### 선택 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 기본값 | 설명 |
|---------|-----------|---------|--------|------|
| usual_size | string | 최대 10자 (XXS~XXXXXL) | null | 평소 사이즈 |
| body_shape | string | 최대 50자 | null | 체형 특징 |
| foot_size | integer | 160-350 | null | 발 사이즈 (mm) |
| foot_width | string | ENUM('narrow', 'normal', 'wide') | null | 발볼 |
| foot_arch | string | ENUM('low', 'normal', 'high') | null | 발등 |

#### 유효성 검증 규칙

- `height`: 100 이상 220 이하 정수
- `weight`: 30 이상 200 이하 정수
- `foot_size`: 160 이상 350 이하 정수
- `foot_width`, `foot_arch`: ENUM 값만 허용
- `user_id` + `category='fashion'` 조합은 고유 (DB: UNIQUE KEY) → 업데이트 또는 신규 생성

#### 요청 예시

```json
{
  "height": 165,
  "weight": 55,
  "usual_size": "M",
  "body_shape": "보통 체형",
  "foot_size": 245,
  "foot_width": "normal",
  "foot_arch": "normal"
}
```

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "profile_id": 1,
    "user_id": 1,
    "category": "fashion",
    "height": 165,
    "weight": 55,
    "usual_size": "M"
  }
}
```

---

### 2.2 프로필 조회 (GET /api/v1/profiles/{category})

#### 경로 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| category | string | ENUM('fashion', 'beauty', 'electronics', 'food') | 카테고리 |

#### 쿼리 매개변수

없음

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "profile_id": 1,
    "category": "fashion",
    "height": 165,
    "weight": 55,
    "usual_size": "M",
    "body_shape": "보통 체형",
    "foot_size": 245,
    "foot_width": "normal",
    "foot_arch": "normal"
  }
}
```

---

## 3. 상품 검색 API

### 3.1 상품 검색 (GET /api/v1/products/search)

#### 필수 매개변수

없음 (키워드 또는 URL 중 하나는 필수)

#### 선택 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 기본값 | 설명 |
|---------|-----------|---------|--------|------|
| keyword | string | 최대 200자 | null | 검색 키워드 |
| url | string | 최대 500자, URL 형식 | null | 상품 URL (빠른 검색) |
| category | string | ENUM('fashion', 'beauty', 'electronics', 'food') | null | 카테고리 필터 |
| brand | string | 최대 200자 | null | 브랜드 필터 |
| min_rating | decimal | 0.00-5.00 | null | 최소 평점 |
| page | integer | 최소 1 | 1 | 페이지 번호 |
| limit | integer | 1-100 | 20 | 페이지당 결과 수 |

#### 유효성 검증 규칙

- `keyword` 또는 `url` 중 하나는 반드시 제공
- `category`: DB ENUM 값과 일치
- `min_rating`: 0.00 ~ 5.00 범위
- `page`: 최소 1
- `limit`: 1 ~ 100 범위

#### 쿼리 예시

```
GET /api/v1/products/search?keyword=나이키+에어맥스&category=fashion&page=1&limit=20
```

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "total_count": 5,
    "page": 1,
    "limit": 20,
    "products": [
      {
        "product_id": 1,
        "name": "나이키 에어맥스 90",
        "brand": "Nike",
        "category": "fashion",
        "image_url": "https://...",
        "average_rating": 4.52,
        "total_review_count": 156,
        "lowest_price": 42000,
        "platforms": ["29cm", "무신사", "네이버"]
      }
    ]
  }
}
```

---

## 4. 리뷰 조회 API

### 4.1 상품 리뷰 목록 (GET /api/v1/products/{product_id}/reviews)

#### 경로 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| product_id | integer | BIGINT UNSIGNED | 상품 ID |

#### 선택 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 기본값 | 설명 |
|---------|-----------|---------|--------|------|
| exclude_sponsored | boolean | true/false | true | 광고성 리뷰 제외 여부 |
| platform | string | 플랫폼 코드 (29cm, musinsa, naver) | null | 플랫폼 필터 |
| rating | integer | 1-5 | null | 평점 필터 (해당 평점 이상) |
| has_images | boolean | true/false | null | 사진 리뷰만 조회 |
| size_feedback | string | ENUM('small', 'perfect', 'large') | null | 사이즈 피드백 필터 |
| similar_body | boolean | true/false | false | 유사 체형 리뷰만 조회 (로그인 + 프로필 등록 필요) |
| sort | string | ENUM('disadvantage', 'latest', 'rating_desc', 'rating_asc') | 'disadvantage' | 정렬 기준 |
| page | integer | 최소 1 | 1 | 페이지 번호 |
| limit | integer | 1-100 | 20 | 페이지당 결과 수 |

#### 유효성 검증 규칙

- `product_id`: 존재하는 상품 ID인지 확인
- `exclude_sponsored`: 기본값 true (진성 리뷰 우선)
- `similar_body = true` 시 사용자 로그인 및 프로필 등록 확인
- `rating`: 1~5 범위
- `sort`:
  - 'disadvantage': 단점 상세도 점수 높은 순 (기본값)
  - 'latest': 최신순
  - 'rating_desc': 평점 높은순
  - 'rating_asc': 평점 낮은순

#### 쿼리 예시

```
GET /api/v1/products/123/reviews?exclude_sponsored=true&sort=disadvantage&has_images=true&page=1&limit=20
```

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "total_count": 87,
    "page": 1,
    "limit": 20,
    "filters_applied": {
      "exclude_sponsored": true,
      "has_images": true
    },
    "reviews": [
      {
        "review_id": 1,
        "product_id": 123,
        "platform": "29cm",
        "reviewer_name": "홍*동",
        "content": "디자인은 정말 예쁜데 보풀이 좀 생겨요...",
        "rating": 4,
        "purchase_option": "M, 블랙",
        "has_images": true,
        "image_urls": ["https://..."],
        "reviewer_height": 165,
        "reviewer_weight": 55,
        "size_feedback": "perfect",
        "is_similar_body": true,
        "reviewed_at": "2026-01-25T10:30:00Z",
        "analysis": {
          "is_sponsored": false,
          "disadvantage_score": 85,
          "sentiment_score": 0.65
        }
      }
    ]
  }
}
```

---

## 5. 가격 비교 API

### 5.1 상품 가격 비교 (GET /api/v1/products/{product_id}/prices)

#### 경로 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| product_id | integer | BIGINT UNSIGNED | 상품 ID |

#### 쿼리 매개변수

없음

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "product_id": 123,
    "product_name": "로에일 오버핏 코트",
    "price_updated_at": "2026-01-30T03:00:00Z",
    "platforms": [
      {
        "platform_id": 2,
        "platform_name": "무신사",
        "platform_code": "musinsa",
        "price": 42000,
        "original_price": 59000,
        "discount_rate": 29,
        "is_available": true,
        "stock_status": "in_stock",
        "url": "https://www.musinsa.com/...",
        "is_lowest": true
      },
      {
        "platform_id": 3,
        "platform_name": "네이버",
        "platform_code": "naver",
        "price": 44000,
        "original_price": 59000,
        "discount_rate": 25,
        "is_available": true,
        "stock_status": "in_stock",
        "url": "https://smartstore.naver.com/...",
        "is_lowest": false
      },
      {
        "platform_id": 1,
        "platform_name": "29CM",
        "platform_code": "29cm",
        "price": 45000,
        "original_price": 59000,
        "discount_rate": 24,
        "is_available": true,
        "stock_status": "low_stock",
        "url": "https://www.29cm.co.kr/...",
        "is_lowest": false
      }
    ]
  }
}
```

---

## 6. 리뷰 요약 API

### 6.1 상품 리뷰 요약 (GET /api/v1/products/{product_id}/summary)

#### 경로 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| product_id | integer | BIGINT UNSIGNED | 상품 ID |

#### 쿼리 매개변수

없음

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "product_id": 123,
    "total_review_count": 156,
    "sponsored_count": 23,
    "genuine_count": 133,
    "average_disadvantage_score": 45.72,
    "pros_top3": [
      {
        "keyword": "디자인 예쁨",
        "count": 45
      },
      {
        "keyword": "가성비 좋음",
        "count": 32
      },
      {
        "keyword": "색감 좋음",
        "count": 28
      }
    ],
    "cons_top3": [
      {
        "keyword": "보풀 생김",
        "count": 23
      },
      {
        "keyword": "사이즈 작음",
        "count": 18
      },
      {
        "keyword": "배송 느림",
        "count": 12
      }
    ],
    "generated_at": "2026-01-30T03:00:00Z"
  }
}
```

---

## 7. 사이즈 인사이트 API

### 7.1 사이즈 인사이트 조회 (GET /api/v1/products/{product_id}/size-insights)

#### 경로 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| product_id | integer | BIGINT UNSIGNED | 상품 ID |

#### 선택 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 기본값 | 설명 |
|---------|-----------|---------|--------|------|
| personalized | boolean | true/false | true | 사용자 맞춤 추천 (로그인 + 프로필 등록 시) |

#### 유효성 검증 규칙

- `product_id`: 존재하는 상품 ID인지 확인
- `category = 'fashion'`인 상품만 지원 (다른 카테고리 시 에러)
- `personalized = true` 시 사용자 로그인 및 체형 프로필 등록 확인

#### 응답 예시 (비로그인 또는 personalized=false)

```json
{
  "success": true,
  "data": {
    "product_id": 123,
    "category": "fashion",
    "personalized": false,
    "generated_at": "2026-01-30T03:00:00Z",
    "size_distribution": [
      {
        "size": "S",
        "purchase_count": 15,
        "purchase_rate": 10.00,
        "fit_small_rate": 20.00,
        "fit_perfect_rate": 60.00,
        "fit_large_rate": 20.00,
        "average_height": 160.5,
        "average_weight": 50.2
      },
      {
        "size": "M",
        "purchase_count": 90,
        "purchase_rate": 60.00,
        "fit_small_rate": 15.00,
        "fit_perfect_rate": 70.00,
        "fit_large_rate": 15.00,
        "average_height": 165.3,
        "average_weight": 55.8
      },
      {
        "size": "L",
        "purchase_count": 45,
        "purchase_rate": 30.00,
        "fit_small_rate": 10.00,
        "fit_perfect_rate": 65.00,
        "fit_large_rate": 25.00,
        "average_height": 170.2,
        "average_weight": 62.5
      }
    ]
  }
}
```

#### 응답 예시 (로그인 + 프로필 등록 + personalized=true)

```json
{
  "success": true,
  "data": {
    "product_id": 123,
    "category": "fashion",
    "personalized": true,
    "user_profile": {
      "height": 165,
      "weight": 55
    },
    "recommendation": {
      "recommended_size": "M",
      "confidence": "high",
      "similar_body_count": 23,
      "similar_body_rate": 80.00,
      "message": "비슷한 체형 80%가 M 사이즈를 선택했습니다"
    },
    "generated_at": "2026-01-30T03:00:00Z",
    "size_distribution": [
      {
        "size": "M",
        "purchase_count": 90,
        "purchase_rate": 60.00,
        "fit_small_rate": 15.00,
        "fit_perfect_rate": 70.00,
        "fit_large_rate": 15.00,
        "average_height": 165.3,
        "average_weight": 55.8,
        "is_recommended": true
      },
      {
        "size": "L",
        "purchase_count": 45,
        "purchase_rate": 30.00,
        "fit_small_rate": 10.00,
        "fit_perfect_rate": 65.00,
        "fit_large_rate": 25.00,
        "average_height": 170.2,
        "average_weight": 62.5,
        "is_recommended": false
      }
    ]
  }
}
```

#### 신뢰도 계산 기준

| 유사 체형 리뷰 수 | 신뢰도 |
|------------------|-------|
| 0-2개 | low |
| 3-9개 | medium |
| 10개 이상 | high |

---

## 8. 최근 본 상품 API

### 8.1 최근 본 상품 조회 (GET /api/v1/users/me/recent-views)

#### 쿼리 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 기본값 | 설명 |
|---------|-----------|---------|--------|------|
| limit | integer | 1-50 | 10 | 조회 개수 |

#### 유효성 검증 규칙

- 로그인 필수
- `limit`: 1 ~ 50 범위

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "total_count": 5,
    "recent_views": [
      {
        "product_id": 123,
        "name": "로에일 오버핏 코트",
        "brand": "로에일",
        "image_url": "https://...",
        "average_rating": 4.52,
        "lowest_price": 42000,
        "viewed_at": "2026-01-30T15:30:00Z"
      },
      {
        "product_id": 456,
        "name": "나이키 에어맥스 90",
        "brand": "Nike",
        "image_url": "https://...",
        "average_rating": 4.71,
        "lowest_price": 89000,
        "viewed_at": "2026-01-30T14:20:00Z"
      }
    ]
  }
}
```

---

### 8.2 최근 본 상품 기록 (POST /api/v1/users/me/recent-views)

#### 필수 매개변수

| 매개변수 | 데이터 타입 | 제약조건 | 설명 |
|---------|-----------|---------|------|
| product_id | integer | BIGINT UNSIGNED | 상품 ID |

#### 유효성 검증 규칙

- 로그인 필수
- `product_id`: 존재하는 상품 ID인지 확인
- 중복 허용 (동일 상품 재조회 시 새로운 레코드 생성)

#### 요청 예시

```json
{
  "product_id": 123
}
```

#### 응답 예시

```json
{
  "success": true,
  "data": {
    "recent_view_id": 1001,
    "product_id": 123,
    "viewed_at": "2026-01-30T15:30:00Z"
  }
}
```

---

## 9. 공통 규칙

### 9.1 인증 헤더

모든 인증이 필요한 API는 다음 헤더 필요:

```
Authorization: Bearer {access_token}
```

### 9.2 에러 응답 형식

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMETER",
    "message": "height는 100 이상 220 이하의 정수여야 합니다",
    "field": "height"
  }
}
```

### 9.3 페이지네이션 공통 규칙

- `page`: 최소 1 (기본값 1)
- `limit`: 1~100 (기본값 20)
- 응답에 `total_count`, `page`, `limit` 포함

### 9.4 데이터베이스 컬럼 매핑

| API 매개변수 | DB 컬럼 | 테이블 |
|-------------|---------|--------|
| email | email | users |
| height | height | user_profiles |
| weight | weight | user_profiles |
| exclude_sponsored | is_sponsored (NOT) | review_analyses |
| sort=disadvantage | disadvantage_score DESC | review_analyses |
| similar_body | SQRT(...) < 5 | reviews |

---

## 10. 부록: SQL 쿼리 예시

### 유사 체형 리뷰 조회 (similar_body=true)

```sql
-- 사용자 프로필: height=165, weight=55 기준
SELECT r.*,
  SQRT(POW((r.reviewer_height - 165)/10, 2) + POW((r.reviewer_weight - 55)/5, 2)) AS similarity_distance
FROM reviews r
JOIN review_analyses ra ON r.id = ra.review_id
WHERE r.product_id = 123
  AND r.reviewer_height IS NOT NULL
  AND r.reviewer_weight IS NOT NULL
  AND ra.is_sponsored = FALSE
HAVING similarity_distance < 5
ORDER BY similarity_distance ASC
LIMIT 20;
```

### 광고성 제외 + 단점 상세순 정렬

```sql
SELECT r.*, ra.disadvantage_score, ra.is_sponsored
FROM reviews r
JOIN review_analyses ra ON r.id = ra.review_id
WHERE r.product_id = 123
  AND ra.is_sponsored = FALSE
ORDER BY ra.disadvantage_score DESC
LIMIT 20 OFFSET 0;
```

### 가격 비교 (최저가 순)

```sql
SELECT ppm.*, pl.name AS platform_name, pl.code AS platform_code
FROM product_platform_mappings ppm
JOIN platforms pl ON ppm.platform_id = pl.id
WHERE ppm.product_id = 123
  AND ppm.is_available = TRUE
ORDER BY ppm.price ASC;
```

---

**문서 끝**
