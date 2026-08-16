# API 공통 표준 (api-standards.md)

> **버전:** v1.0.0  
> **최초 작성:** 2026-05-26  
> **적용 대상:** `app/web/src/app/api/` 하위 모든 Route Handler, `app/web/src/workers/`, `app/web/src/features/queue/` 워커

---

## 목차

1. [개요 및 적용 범위](#1-개요-및-적용-범위)
2. [기술 스택](#2-기술-스택)
3. [디렉터리 구조](#3-디렉터리-구조)
4. [API 라우팅 규약](#4-api-라우팅-규약)
5. [요청/응답 포맷](#5-요청응답-포맷)
6. [검증 (zod)](#6-검증-zod)
7. [DB 접근 (Drizzle ORM)](#7-db-접근-drizzle-orm)
8. [인증/인가](#8-인증인가)
9. [에러 처리](#9-에러-처리)
10. [로깅 / 알림](#10-로깅--알림)
11. [외부 통합](#11-외부-통합)
12. [큐/워커 (BullMQ)](#12-큐워커-bullmq)
13. [테스트 표준](#13-테스트-표준)
14. [성능 표준](#14-성능-표준)
15. [보안 표준](#15-보안-표준)
16. [컨벤션](#16-컨벤션)

---

## 1. 개요 및 적용 범위

이 문서는 **리뷰 모으기 서비스**의 백엔드 API 개발 표준을 정의합니다. `team-twms` 팀의 backend 멤버가 기술 스택 및 패턴을 참조하는 단일 진실 공급원(Single Source of Truth)입니다.

### 적용 범위

| 대상 | 경로 | 설명 |
|------|------|------|
| **REST API** | `app/web/src/app/api/v1/` | Next.js App Router Route Handler |
| **워커** | `app/web/src/workers/` | BullMQ 워커 진입점 (standalone 실행) |
| **큐** | `app/web/src/features/queue/` | 큐 정의, 워커 구현, 타입 |
| **서비스** | `app/web/src/services/` | DB, Redis, Elasticsearch, Logger, Slack |
| **피처** | `app/web/src/features/` | 도메인별 비즈니스 로직 |

### 범위 외

- 프론트엔드 컴포넌트 (`app/web/src/app/` 내 page, layout, components)
- 정적 파일 서빙

---

## 2. 기술 스택

> 현행 (Current): 아래 스택은 현재 코드베이스에서 실제로 사용 중인 확정 스택입니다. 변경 시 이 테이블을 함께 갱신합니다.

| 항목 | 선택 | 버전 | 비고 |
|------|------|------|------|
| **언어** | TypeScript | `^5` (strict mode) | `any` 타입 사용 금지 |
| **런타임** | Node.js | 20 LTS (상세: `infra-standards.md` 참조) | Docker 이미지 기준 |
| **프레임워크** | Next.js (App Router) | `16.1.6` | Turbopack, Route Handler 방식 |
| **ORM** | Drizzle ORM | `^0.45.1` | drizzle-kit `^0.31.8` |
| **DB 드라이버** | mysql2 | `^3.16.2` | promise 기반 |
| **DB** | MySQL | `8.0` | utf8mb4, snake_case 네이밍 |
| **인증** | NextAuth.js + jose | `^5.0.0-beta.30` / `^6.1.3` | JWT HS256, localStorage 저장 |
| **검증** | zod | `^4.3.6` | 모든 입력 검증에 일관 사용 |
| **큐** | BullMQ | `^5.67.2` | 워커는 별도 컨테이너 실행 |
| **Redis 드라이버** | ioredis | `^5.9.2` | Redis 7-alpine |
| **AI** | OpenAI SDK | `^6.17.0` | gpt-4o-mini, JSON 응답 |
| **검색** | @elastic/elasticsearch | `^8.19.1` | Elasticsearch 서버 8.12.0 |
| **암호화** | bcrypt | `^6.0.0` | 비밀번호 해싱 |
| **패키지 매니저** | pnpm | — | `npm` 사용 금지 |
| **린트** | ESLint | `^9` (flat config) | `eslint-config-next` + typescript |
| **외부 수집** | Playwright | `^1.58.1` | 크롤러 기능 |

### 런타임 외부 패키지 선언

`app/web/next.config.ts`에 아래와 같이 선언되어 있습니다. 런타임에 Node.js 네이티브 모듈이 필요한 패키지를 추가할 때 여기에 등록합니다.

```typescript
// app/web/next.config.ts
serverExternalPackages: ["openai", "bullmq", "ioredis"]
```

---

## 3. 디렉터리 구조

```
app/web/src/
├── app/
│   ├── api/
│   │   └── v1/                   # REST API Route Handler (v1)
│   │       ├── auth/             # 인증 (login, register, refresh, ...)
│   │       ├── users/            # 사용자 리소스
│   │       ├── products/         # 상품 리소스
│   │       ├── profiles/         # 사용자 프로필
│   │       ├── settings/         # 서비스 설정 (공개)
│   │       ├── admin/            # 관리자 전용 (미들웨어 보호)
│   │       └── health/           # 헬스체크
│   └── (page, layout, ...)       # 프론트엔드 (이 문서 범위 외)
│
├── features/                     # 도메인별 비즈니스 로직
│   ├── ai-processing/            # OpenAI 리뷰 분석
│   ├── auth/                     # JWT 생성/검증, OAuth
│   ├── crawlers/                 # 플랫폼별 크롤러
│   ├── products/                 # 상품 도메인 로직
│   ├── queue/                    # 큐 정의 + 워커 구현
│   │   ├── queues.ts             # Queue 인스턴스 (lazy Proxy)
│   │   ├── types.ts              # Job 페이로드 타입 (zod 스키마 추가 권장)
│   │   ├── scheduler.ts          # BullMQ 스케줄러
│   │   └── workers/              # 워커 팩토리 함수
│   ├── reviews/                  # 리뷰 도메인 로직
│   └── search/                   # Elasticsearch 검색 로직
│
├── lib/                          # 공통 유틸리티
│   ├── validators.ts             # zod 스키마 정의 (단일 파일, 중앙 관리)
│   ├── rate-limit.ts             # Redis 기반 요청 속도 제한
│   ├── settings.ts               # site_settings DB 조회 헬퍼
│   └── auth-client.ts            # 클라이언트 인증 헬퍼
│
├── services/                     # 인프라 서비스 클라이언트
│   ├── db/
│   │   ├── index.ts              # Drizzle DB 인스턴스 (lazy Proxy)
│   │   └── schema/               # Drizzle 스키마 파일 (테이블별 1 파일)
│   ├── redis/                    # ioredis 연결
│   ├── elasticsearch/            # ES 클라이언트 (global 싱글톤)
│   ├── logger/                   # 파일 로거 (카테고리별 스트림, 로테이션)
│   └── slack/                    # Slack Webhook 알림
│
├── types/
│   └── api.ts                    # ApiResponse, ApiSuccessResponse, ApiErrorResponse 타입
│
├── workers/
│   └── standalone.ts             # 워커 컨테이너 진입점 (tsx로 직접 실행)
│
└── middleware.ts                 # Next.js 미들웨어 (admin 경로 JWT 검증)
```

### 계층별 책임 분리 원칙

| 계층 | 책임 | 금지 사항 |
|------|------|---------|
| **Route Handler** (`app/api/`) | HTTP 요청 파싱, 검증(zod), 응답 직렬화 | 비즈니스 로직 직접 구현 금지 |
| **features/** | 도메인 비즈니스 로직, 워커 구현 | HTTP 컨텍스트(NextRequest/Response) 의존 금지 |
| **services/** | 외부 시스템 연결(DB, Redis, ES, AI) | 비즈니스 규칙 포함 금지 |
| **lib/** | 범용 유틸, 검증 스키마, 헬퍼 | 특정 도메인 로직 포함 금지 |
| **types/** | TypeScript 타입/인터페이스 정의 | 런타임 로직 포함 금지 |

---

## 4. API 라우팅 규약

### 베이스 경로

모든 API 엔드포인트는 `/api/v1/`로 시작합니다.

```
/api/v1/{리소스}/{동적 파라미터}/{중첩 리소스}
```

### 리소스 네이밍

- **복수형 snake_case** 사용
- 계층 구조가 있을 때만 중첩 (최대 2 depth 권장)

```
/api/v1/products            ✅ 복수형
/api/v1/products/[id]       ✅ 동적 파라미터
/api/v1/products/[id]/reviews  ✅ 중첩 (1 depth)
/api/v1/product             ❌ 단수형 금지
/api/v1/getProducts         ❌ 동사 금지
```

### HTTP 메서드별 의미

| 메서드 | 의미 | 성공 상태 코드 | 예시 |
|--------|------|-------------|------|
| `GET` | 리소스 조회 | `200` | `GET /api/v1/products/[id]` |
| `POST` | 리소스 생성 | `201` | `POST /api/v1/auth/register` |
| `PUT` | 리소스 전체 교체 | `200` | `PUT /api/v1/users/me` |
| `PATCH` | 리소스 부분 수정 | `200` | `PATCH /api/v1/users/me/password` |
| `DELETE` | 리소스 삭제 | `200` | `DELETE /api/v1/users/me` |

### 동적 라우트 파라미터 규약

| 파라미터 | 타입 | 사용처 | 파일 위치 |
|---------|------|-------|---------|
| `[id]` | 숫자형 정수 | DB 기본키 | `products/[id]/route.ts` |
| `[slug]` | 문자열 | URL 친화적 식별자 | `profiles/[category]/route.ts` |

동적 파라미터 수신 시 **항상 유효성을 검증**합니다:

```typescript
// app/web/src/app/api/v1/products/[id]/route.ts
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const productId = parseInt(id, 10);
  if (isNaN(productId)) {
    return NextResponse.json(
      { success: false, error: { code: 'INVALID_PARAMETER', message: '유효하지 않은 ID입니다' } },
      { status: 400 },
    );
  }
  // ...
}
```

### `dynamic = 'force-dynamic'` 적용 기준

Next.js의 빌드 타임 정적 최적화를 방지하고 **런타임에 항상 동적 실행**이 필요한 경우에 파일 최상단에 선언합니다.

**적용 조건:**

- BullMQ, ioredis 등 런타임 의존성을 import하는 라우트
- `process.env.*`를 요청마다 새로 읽어야 하는 라우트
- Elasticsearch 연결을 사용하는 라우트

```typescript
// 파일 최상단에 선언 (import 전에 위치)
export const dynamic = 'force-dynamic';

import { NextRequest, NextResponse } from 'next/server';
// ...
```

현행 적용 예시: `app/web/src/app/api/v1/products/search/route.ts`

---

## 5. 요청/응답 포맷

### JSON 키 케이싱

**케이싱 정책 (D1 결정)**: API 요청/응답 JSON 모두 camelCase. DB는 snake_case이며 Drizzle 매핑 시 TypeScript 필드명을 camelCase로 정의함.

| 위치 | 케이싱 | 예시 |
|------|--------|------|
| **API 요청 Body** | `camelCase` | `{ "email": "...", "password": "..." }` |
| **API 응답 Body** | `camelCase` | `{ "accessToken": "..." }` |
| **TypeScript 변수/필드** | `camelCase` | `accessToken`, `userId` |
| **DB 컬럼** | `snake_case` | `user_id`, `created_at` |

> Drizzle ORM 스키마는 DB의 snake_case 컬럼을 TypeScript의 camelCase 필드로 매핑합니다. 변환 레이어 없이 Drizzle 조회 결과를 그대로 반환합니다.

### 표준 성공 응답

현행 (Current): `app/web/src/types/api.ts`의 `ApiSuccessResponse<T>` 타입을 기반으로 합니다.

```typescript
// 단건 조회 / 생성 / 수정
{
  "success": true,
  "data": { /* 리소스 객체 */ }
}

// 목록 조회 (페이지네이션 포함)
{
  "success": true,
  "data": [ /* 리소스 배열 */ ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 142,
    "hasMore": true
  }
}
```

현행 TypeScript 타입 (`app/web/src/types/api.ts`):

```typescript
export type ApiSuccessResponse<T> = {
  success: true;
  data: T;
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    hasMore?: boolean;
  };
};
```

### 표준 에러 응답

현행 (Current): `app/web/src/types/api.ts`의 `ApiErrorResponse` 타입을 기반으로 합니다.

```typescript
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMETER",
    "message": "이메일과 비밀번호를 입력해주세요",
    "field": "email"           // 선택적, 필드 단위 검증 오류 시
  }
}
```

현행 TypeScript 타입:

```typescript
export type ApiErrorResponse = {
  success: false;
  error: {
    code: string;
    message: string;
    field?: string;
  };
};
```

### HTTP 상태 코드

| 시나리오 | 상태 코드 | 에러 코드 예시 |
|---------|----------|-------------|
| 조회/수정/삭제 성공 | `200 OK` | — |
| 생성 성공 | `201 Created` | — |
| 요청 파라미터/바디 검증 오류 | `400 Bad Request` | `INVALID_PARAMETER` |
| 인증 토큰 없음/만료 | `401 Unauthorized` | `UNAUTHORIZED` |
| 권한 부족 | `403 Forbidden` | `FORBIDDEN` |
| 리소스 없음 | `404 Not Found` | `NOT_FOUND` |
| 중복 리소스 | `409 Conflict` | `CONFLICT` |
| 요청 속도 초과 | `429 Too Many Requests` | `RATE_LIMITED` |
| 서버 내부 오류 | `500 Internal Server Error` | `INTERNAL_ERROR` |

### 공통 에러 코드 목록

| 코드 | 설명 | HTTP 상태 |
|------|------|----------|
| `INVALID_PARAMETER` | 요청 파라미터/바디 검증 실패 | 400 |
| `UNAUTHORIZED` | 인증 토큰 없음 또는 만료 | 401 |
| `FORBIDDEN` | 권한 없음 (인증은 됐지만 접근 불가) | 403 |
| `NOT_FOUND` | 리소스 없음 | 404 |
| `CONFLICT` | 중복 리소스 충돌 (이메일 중복 등) | 409 |
| `RATE_LIMITED` | 요청 속도 제한 초과 | 429 |
| `INTERNAL_ERROR` | 서버 내부 오류 | 500 |

### 페이지네이션 규약

현행 (Current): offset 기반 페이지네이션을 사용합니다.

```
GET /api/v1/products/[id]/reviews?page=1&limit=20
```

| 파라미터 | 타입 | 기본값 | 최대값 | 설명 |
|---------|------|-------|-------|------|
| `page` | 정수 | `1` | — | 페이지 번호 (1부터 시작) |
| `limit` | 정수 | `20` | `50` | 페이지당 항목 수 |

offset 계산: `offset = (page - 1) * limit`

응답 meta:

```json
{
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 142,
    "hasMore": true
  }
}
```

> 권장 (Recommendation): 실시간 갱신되는 데이터(리뷰 피드 등)는 중복 노출 문제가 있는 offset 기반 대신 cursor 기반 페이지네이션 도입을 검토하세요.

### 정렬/필터 쿼리 파라미터 규약

현행 (Current): `app/web/src/lib/validators.ts`의 zod 스키마에서 허용 값을 명시적으로 열거합니다.

```
# 정렬 (현행 패턴)
GET /api/v1/products/[id]/reviews?sort=recent
GET /api/v1/products/[id]/reviews?sort=rating_high

# 필터
GET /api/v1/products/[id]/reviews?rating=5&has_images=true&exclude_sponsored=true
```

정렬 값은 zod `enum`으로 제한하며 `default`를 반드시 지정합니다:

```typescript
sort: z.enum(['recent', 'rating_high', 'rating_low', 'disadvantage_detail', 'similar_body'])
  .default('recent'),
```

---

## 6. 검증 (zod)

### 스키마 위치 및 명명 규약

현행 (Current): 모든 입력 검증 스키마는 **단일 파일** `app/web/src/lib/validators.ts`에서 관리합니다.

```typescript
// app/web/src/lib/validators.ts
import { z } from 'zod';

// 도메인별 섹션으로 구분
// Auth
export const registerSchema = z.object({ ... });
export const loginSchema = z.object({ ... });

// Product
export const productSearchSchema = z.object({ ... });

// Review
export const reviewListSchema = z.object({ ... });
```

명명 규약: `{도메인}{동작}Schema` (예: `productSearchSchema`, `reviewListSchema`)

### 라우트 핸들러 표준 검증 패턴

**Body 검증 (POST/PUT/PATCH):**

```typescript
// app/web/src/app/api/v1/auth/login/route.ts 패턴
export async function POST(request: NextRequest) {
  const body = await request.json();
  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      {
        success: false,
        error: { code: 'INVALID_PARAMETER', message: parsed.error.issues[0]?.message || '입력값이 올바르지 않습니다' },
      },
      { status: 400 },
    );
  }
  const { email, password } = parsed.data;
  // ...
}
```

**쿼리 파라미터 검증 (GET):**

```typescript
// app/web/src/app/api/v1/products/search/route.ts 패턴
export async function GET(request: NextRequest) {
  const params = Object.fromEntries(request.nextUrl.searchParams);
  const parsed = productSearchSchema.safeParse(params);
  if (!parsed.success) {
    return NextResponse.json(
      {
        success: false,
        error: { code: 'INVALID_PARAMETER', message: parsed.error.issues[0]?.message || 'Invalid parameters' },
      },
      { status: 400 },
    );
  }
  // ...
}
```

### zod 스키마 작성 규칙

- 숫자형 쿼리 파라미터는 `z.coerce.number()`를 사용합니다 (쿼리 파라미터는 항상 문자열로 수신됨).
- boolean형 쿼리 파라미터는 `z.preprocess`로 `'true'/'false'` 문자열을 변환합니다.
- `default()`를 활용해 선택적 파라미터의 기본값을 명시합니다.
- `parse()` 대신 **항상 `safeParse()`를 사용**합니다 (예외 대신 결과 객체 반환).

```typescript
// 숫자형 쿼리 파라미터 예시
page: z.coerce.number().int().min(1).default(1),
limit: z.coerce.number().int().min(1).max(50).default(20),

// boolean 쿼리 파라미터 예시
has_images: z.preprocess((v) => v === 'true' || v === true, z.boolean()).optional(),
exclude_sponsored: z.preprocess((v) => v !== 'false' && v !== false, z.boolean()).default(true),
```

### 입력 스키마와 응답 스키마 분리

> 권장 (Recommendation): 요청 검증용 스키마와 응답 직렬화 스키마를 분리하세요. 입력 스키마에서 허용된 필드가 의도치 않게 응답에 포함될 수 있습니다. 응답 데이터는 필요한 필드만 명시적으로 `select()`하거나 별도의 응답 타입으로 매핑하세요.

---

## 7. DB 접근 (Drizzle ORM)

### lazy Proxy 패턴으로 DB 인스턴스 가져오기

현행 (Current): DB 연결은 `app/web/src/services/db/index.ts`에서 lazy Proxy로 관리합니다. 빌드 타임에 연결이 초기화되지 않도록 하기 위함입니다.

```typescript
// 올바른 import 방법
import { db } from '@/services/db';

// 사용 예시
const [user] = await db
  .select()
  .from(users)
  .where(eq(users.email, email))
  .limit(1);
```

`getDb()`를 직접 호출하거나 mysql2 Pool을 직접 사용하지 않습니다.

### 스키마 위치 및 파일 규약

현행 (Current): `app/web/src/services/db/schema/` 디렉터리에 **테이블별 1개 파일**로 관리합니다.

```
app/web/src/services/db/schema/
├── index.ts                  # 모든 스키마 재export
├── users.ts
├── reviews.ts
├── review-analyses.ts
├── review-keywords.ts
├── products.ts
├── platforms.ts
└── ...
```

```typescript
// 스키마 import
import { db } from '@/services/db';
import { users, reviews } from '@/services/db/schema';

// index.ts를 통한 일괄 import (서비스 내부에서)
import * as schema from './schema';
```

### 트랜잭션

여러 테이블을 원자적으로 변경해야 할 때 Drizzle 트랜잭션을 사용합니다:

```typescript
await db.transaction(async (tx) => {
  await tx.insert(users).values({ email, passwordHash });
  await tx.insert(userProfiles).values({ userId, ... });
});
```

### 파라미터화 쿼리 강제 (SQL Injection 방지)

Drizzle의 빌더 API를 사용하면 파라미터화 쿼리가 자동으로 적용됩니다. **raw SQL 사용은 금지**합니다. 불가피하게 `sql` 태그를 사용할 경우 반드시 Drizzle의 `sql` 템플릿 리터럴을 통해 값을 바인딩합니다:

```typescript
// 허용: Drizzle sql 태그 (값은 바인딩됨)
conditions.push(sql`JSON_LENGTH(${reviews.imageUrls}) > 0`);

// 금지: 문자열 보간으로 SQL 직접 구성
db.execute(`SELECT * FROM users WHERE id = ${userId}`); // ❌
```

### N+1 문제 회피

```typescript
// ❌ N+1 패턴 (루프 내 개별 쿼리)
for (const review of reviews) {
  const analysis = await db.select().from(reviewAnalyses).where(eq(reviewAnalyses.reviewId, review.id));
}

// ✅ leftJoin으로 한 번에 조회
await db
  .select({ ... })
  .from(reviews)
  .leftJoin(reviewAnalyses, eq(reviews.id, reviewAnalyses.reviewId))
  .where(eq(reviews.productId, productId));

// ✅ 배치 조회 (inArray)
await db.select().from(reviews).where(inArray(reviews.id, reviewIds));
```

### 마이그레이션 흐름

| 단계 | 명령 | 실행 주체 | 설명 |
|------|------|---------|------|
| **스키마 변경** | — | 개발자 | `app/web/src/services/db/schema/*.ts` 수정 |
| **마이그레이션 파일 생성** | `pnpm drizzle-kit generate` | 개발자 로컬 | SQL 마이그레이션 파일 생성 |
| **적용 (로컬)** | `pnpm drizzle-kit migrate` | 개발자 로컬 | 로컬 DB에 즉시 적용 |
| **적용 (운영)** | CI/CD 파이프라인 또는 수동 | 담당자 확인 필요 | 배포 전 DBA 검토 후 적용 |

> 권장 (Recommendation): 운영 DB 마이그레이션은 배포 파이프라인에 통합하거나, DBA 검토 후 적용 시점을 명문화하세요. `docs/infra/ci-cd-standards.md`에 절차를 정의하세요.

---

## 8. 인증/인가

### JWT 토큰 발급 흐름

현행 (Current):

1. 클라이언트가 `POST /api/v1/auth/login` 또는 OAuth 흐름을 통해 인증
2. 서버가 `jose`의 `SignJWT`로 **Access Token** (만료: 30분)과 **Refresh Token** (만료: 7일)을 발급
3. 클라이언트가 토큰을 **localStorage**에 저장
4. 이후 API 호출 시 `Authorization: Bearer <accessToken>` 헤더를 포함

```typescript
// app/web/src/features/auth/lib/jwt.ts
export async function createAccessToken(payload: {
  userId: number;
  email: string;
  role: 'user' | 'admin';
}): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30m')
    .sign(getSecret());
}
```

토큰 페이로드 타입:

```typescript
export type TokenPayload = JWTPayload & {
  userId: number;
  email: string;
  role: 'user' | 'admin';
};
```

### 토큰 저장 위치

| 저장소 | 용도 |
|--------|------|
| **localStorage** | `access_token`, `refresh_token` 저장 |
| **Cookie** | 사용하지 않음 |

> **중요:** JWT를 쿠키에 저장하지 않습니다. 이는 아키텍처 결정(Architecture Decision)이며 변경 시 팀 합의가 필요합니다.

### 서버 측 토큰 검증

**미들웨어 보호 (`app/web/src/middleware.ts`):**

```typescript
// admin 경로 전체를 미들웨어에서 일괄 보호
export const config = {
  matcher: ['/api/v1/admin/:path*'],
};
```

미들웨어에서 `jose`의 `jwtVerify`로 검증 후 `role === 'admin'`을 확인합니다.

**서버 컴포넌트/Route Handler 내 사용자 컨텍스트 조회:**

```typescript
import { getTokenFromHeader } from '@/features/auth/lib/jwt';

// Route Handler 내에서 현재 사용자 조회
const user = await getTokenFromHeader(); // TokenPayload | null
if (!user) {
  return NextResponse.json(
    { success: false, error: { code: 'UNAUTHORIZED', message: '인증이 필요합니다' } },
    { status: 401 },
  );
}
```

### OAuth 제공자

현행 (Current): Google, Apple, Kakao (`POST /api/v1/auth/social`)

### 역할/권한 체크 패턴

현재 역할은 `'user' | 'admin'` 두 가지입니다.

| 역할 | 접근 범위 |
|------|---------|
| `user` | `/api/v1/users/me/*`, `/api/v1/products/*`, `/api/v1/profiles/*` |
| `admin` | `/api/v1/admin/*` (미들웨어로 일괄 보호) |

---

## 9. 에러 처리

### 라우트 핸들러 표준 try/catch 구조

```typescript
export async function GET(request: NextRequest) {
  // 1. 요청 검증 (try 밖에서 처리)
  const params = Object.fromEntries(request.nextUrl.searchParams);
  const parsed = someSchema.safeParse(params);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: { code: 'INVALID_PARAMETER', message: parsed.error.issues[0]?.message || '입력값이 올바르지 않습니다' } },
      { status: 400 },
    );
  }

  try {
    // 2. 비즈니스 로직 실행
    const result = await someFeature(parsed.data);

    // 3. 성공 응답
    return NextResponse.json({ success: true, data: result });
  } catch (error) {
    // 4. 서버 에러 로깅 (사용자에게 상세 내용 노출 금지)
    log.error('[route] 처리 중 오류:', error);
    return NextResponse.json(
      { success: false, error: { code: 'INTERNAL_ERROR', message: '처리 중 오류가 발생했습니다' } },
      { status: 500 },
    );
  }
}
```

### 사용자 노출 에러 vs 내부 로깅 분리

| 항목 | 원칙 |
|------|------|
| **사용자 응답** | 비즈니스 의미 있는 메시지만 포함. 스택 트레이스, DB 에러, 내부 경로 노출 금지 |
| **내부 로깅** | `log.error()`로 전체 에러 객체(스택 포함) 기록 |
| **Slack 알림** | 5xx 오류, 크롤링 실패, 워커 오류 등 운영자 즉시 확인 필요 상황 |

### 4xx/5xx 매핑 가이드

| 상황 | 상태 코드 | 처리 방법 |
|------|----------|---------|
| zod 검증 실패 | `400` | `safeParse` 후 즉시 반환 |
| 인증 토큰 없음/만료 | `401` | `getTokenFromHeader()` null 체크 |
| 관리자 전용 리소스 접근 | `403` | 미들웨어 또는 라우트 내 role 체크 |
| DB에서 리소스 조회 결과 없음 | `404` | `.limit(1)` 결과 배열 길이 체크 |
| 이메일 중복 등 제약 위반 | `409` | DB 에러 코드(`ER_DUP_ENTRY`) 식별 후 반환 |
| Rate Limit 초과 | `429` | `checkRateLimit()` 반환값 확인, `Retry-After` 헤더 포함 |
| 그 외 모든 처리되지 않은 예외 | `500` | catch 블록에서 `log.error()` 후 반환 |

---

## 10. 로깅 / 알림

### Logger 사용 규칙

현행 (Current): `app/web/src/services/logger/index.ts`의 `createLogger`로 네임스페이스별 로거를 생성합니다. `console.log` 직접 사용은 금지합니다.

```typescript
import { createLogger } from '@/services/logger';

// 네임스페이스 형식: '{도메인}:{컴포넌트}' 또는 '{레이어}:{모듈}'
const log = createLogger('worker:ai-processing');
const log = createLogger('api:auth');
const log = createLogger('crawler:travelmate');
```

| 레벨 | 사용 시점 |
|------|---------|
| `log.debug()` | 개발/디버깅 정보. 운영 환경에서는 `LOG_LEVEL` 환경 변수로 억제 |
| `log.info()` | 정상 처리 흐름 (요청 시작/완료, 워커 진행 상황) |
| `log.warn()` | 비정상이지만 계속 진행 가능한 상황 (재시도, 폴백 동작) |
| `log.error()` | 처리 불가 에러, 예외 발생 시. `Error` 객체를 전달하면 스택 트레이스 포함 |

로그 파일은 `logs/` 디렉터리에 일별 로테이션 + gzip 압축, 14일 보관 (`LOG_RETENTION_DAYS` 환경 변수로 조절).

### Slack 알림 기준

현행 (Current): `app/web/src/services/slack/index.ts`의 함수를 사용합니다. 반드시 `SLACK_WEBHOOK_URL` 환경 변수를 설정해야 합니다.

| 상황 | 함수 | 알림 내용 |
|------|------|---------|
| 크롤링 파이프라인 시작 | `notifyCrawlStart(platformCode)` | 플랫폼, 시작 시각 |
| 크롤링 파이프라인 완료 | `notifyCrawlComplete(platformCode, summary)` | 상품/리뷰 수, 완료 시각 |
| 파이프라인 단계 실패 | `notifyCrawlError(stage, platformCode, error)` | 실패 단계, 에러 메시지 |

> 권장 (Recommendation): API 서버의 5xx 오류, 결제 실패(도입 시) 등 운영 임계 이벤트에 대한 Slack 알림 함수를 추가하세요.

### 환경 변수

| 변수명 | 설명 | 기본값 |
|--------|------|-------|
| `LOG_LEVEL` | 최소 로그 레벨 (`debug`/`info`/`warn`/`error`) | `info` |
| `LOG_RETENTION_DAYS` | 로그 파일 보관 기간 (일) | `14` |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | 없으면 알림 비활성화 |

---

## 11. 외부 통합

### OpenAI 호출 패턴

현행 (Current): `app/web/src/features/ai-processing/analyzer.ts`에서 lazy 싱글톤 패턴으로 관리합니다.

```typescript
// 싱글톤 패턴
let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  if (!_openai) {
    _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return _openai;
}
```

| 설정 | 값 | 설명 |
|------|---|------|
| **모델** | `gpt-4o-mini` | 분석 속도/비용 최적화 |
| **temperature** | `0.1` | 일관된 JSON 출력 |
| **응답 형식** | JSON | `response_format: { type: "json_object" }` |
| **재시도** | 최대 3회 | exponential backoff (초기 지연 1초, 배수 2) |
| **배치 처리** | 동시 처리 배치 수 (기본 15). 각 배치는 15개 리뷰를 묶음 | `AI_PARALLEL_BATCHES` 환경 변수로 조절 — 상세는 ai-processing 모듈 참조 |
| **스킵 조건** | 10자 미만 리뷰 | 키워드 매칭만 적용 |

AI API 실패 시 서비스 중단을 방지하기 위해 기본값을 반환합니다:

```typescript
const DEFAULT_RESULT: AnalysisResult = {
  isSponsored: false,
  sponsoredConfidence: 0,
  sponsoredReason: null,
  advantageKeywords: [],
  disadvantageKeywords: [],
  sentimentScore: 0,
  sizeFeedback: null,
  summary: '',
};
```

### Elasticsearch 인덱싱/쿼리 패턴

현행 (Current): `app/web/src/services/elasticsearch/index.ts`의 `esClient`를 전역 싱글톤으로 사용합니다.

```typescript
import { esClient } from '@/services/elasticsearch';

// 검색 쿼리
const result = await esClient.search({
  index: 'products',
  body: { query: { ... } },
});
```

> 권장 (Recommendation): Elasticsearch 인덱스 매핑(mapping), 인덱스명 상수화, 검색 로직 캡슐화는 `app/web/src/features/search/` 또는 `app/web/src/services/elasticsearch/` 내 모듈로 분리하세요.

### S3 업로드 패턴

> 권장 (Recommendation): 파일 업로드 기능 도입 시 `@aws-sdk/client-s3`를 사용하고, 클라이언트 초기화는 lazy 싱글톤 패턴을 따르세요. 환경 변수 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`을 사용합니다. 현재 코드베이스에 S3 통합은 미구현 상태입니다.

### 외부 서비스 장애 대응 (Fallback) 정책

외부 의존성 장애가 서비스 전체 중단으로 이어지지 않도록 각 서비스별 fallback 동작을 정의합니다.

#### 서비스별 장애 대응 정책

| 외부 서비스 | 장애 시 동작 | 사용자 영향 | 구현 위치 |
|---------|------------|---------|---------|
| **OpenAI API** | `DEFAULT_RESULT` 반환 (빈 키워드, `isSponsored: false`, `sentimentScore: 0`) | 광고 필터/요약이 일시적으로 약해짐. 서비스 자체는 정상 동작 | `app/web/src/features/ai-processing/analyzer.ts` (현행 구현됨) |
| **Elasticsearch** | MySQL `LIKE` 쿼리 또는 `MATCH ... AGAINST` 전문 검색으로 폴백 | 검색 정확도·속도 저하, 페이지네이션은 유지 | `app/web/src/services/elasticsearch/` 호출부에 try/catch + fallback 헬퍼 추가 권장 |
| **OAuth 제공자** (Google / Apple / Kakao) | 해당 제공자만 로그인 불가 시 "다른 방법으로 로그인하세요" 안내. 전체 동시 장애 시 점검 페이지 표시 | 신규 가입/소셜 로그인 일부 또는 전체 차단 | NextAuth provider별 에러 처리 + 클라이언트 UI 안내 문구 |
| **Slack Webhook** | `.catch(() => {})` 무음 처리, 알림 실패를 서비스 에러로 전파하지 않음 | 운영 알림 미수신 (서비스 기능 영향 없음) | `app/web/src/services/slack/index.ts` (현행 구현됨) |
| **S3 (이미지 업로드)** | 업로드 재시도 3회 → 실패 시 사용자에게 에러 응답, 글로벌 장애 시 안내 배너 | 이미지 첨부 일시 불가 | 업로드 핸들러 (기능 구현 시 적용) |
| **MySQL (RDS)** | 단일 노드 시 다운타임 발생. RDS Multi-AZ 시 자동 페일오버(약 30초) 후 재연결 | 단일 노드: 서비스 전체 일시 중단 / Multi-AZ: 짧은 중단 후 자동 복구 | Drizzle pool의 `waitForConnections`, `connectionLimit`, `connectTimeout` 설정 검토 |
| **Redis / BullMQ** | 큐 작업 적재 불가, 웹 서버 자체는 정상 동작. BullMQ worker는 reconnect 시도 반복 | 광고 분석, 이메일 등 비동기 백그라운드 작업 지연 발생 | BullMQ 내장 reconnect 활용, Redis 복구 후 대기 중 job 자동 재처리 |

#### 외부 의존성 우선순위 및 SLO

| 서비스 | 중요도 | 허용 다운타임 | 비고 |
|--------|--------|------------|------|
| MySQL | P0 — 필수 | 0 (즉시 복구 필요) | 전체 서비스 기반 |
| Redis / BullMQ | P1 — 높음 | 30분 이내 | 웹은 동작하나 비동기 기능 중단 |
| Elasticsearch | P2 — 중간 | 2시간 이내 | MySQL 폴백으로 검색 기능 유지 |
| OpenAI API | P2 — 중간 | 4시간 이내 | 분석 정확도 저하, 서비스 중단 없음 |
| OAuth 제공자 | P2 — 중간 | 2시간 이내 | 기존 로그인 사용자 영향 없음 |
| S3 | P3 — 낮음 | 4시간 이내 | 이미지 업로드 기능만 영향 |
| Slack Webhook | P4 — 최저 | 해당 없음 | 알림 기능만 영향 |

#### 모니터링: 외부 서비스 실패율 알림

외부 서비스 호출 실패율이 임계치를 초과하면 Slack 알림을 발송합니다.

```typescript
// 권장 패턴: 외부 서비스 호출 시 실패 추적
async function callExternalService<T>(
  serviceName: string,
  fn: () => Promise<T>,
  fallback: T,
): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    log.warn(`[외부 서비스 장애] ${serviceName}: ${(error as Error).message}`);

    // 연속 실패 임계치(예: 5회) 초과 시 Slack 알림
    // 실제 카운터 구현은 Redis 또는 인메모리 카운터 활용
    await notifyExternalServiceError(serviceName, error as Error).catch(() => {});

    return fallback;
  }
}
```

외부 서비스 에러율 모니터링은 `LOG_LEVEL=warn` 이상의 로그를 집계하여 5분 단위로 임계치(에러율 20% 초과 또는 연속 5회 실패)를 체크하는 것을 권장합니다.

---

## 12. 큐/워커 (BullMQ)

### 큐 정의 위치 및 네이밍

현행 (Current): `app/web/src/features/queue/queues.ts`에서 큐 인스턴스를 lazy Proxy로 정의합니다.

```typescript
// app/web/src/features/queue/queues.ts
export const productDiscoveryQueue = createQueue('product-discovery', {
  attempts: 3,
  backoff: { type: 'exponential', delay: 5000 },
});

export const reviewCrawlQueue = createQueue('review-crawl', {
  attempts: 3,
  backoff: { type: 'exponential', delay: 10000 },
});

export const aiProcessingQueue = createQueue('ai-processing', {
  attempts: 2,
  backoff: { type: 'exponential', delay: 15000 },
});

export const summaryGenerationQueue = createQueue('summary-generation', {
  attempts: 2,
  backoff: { type: 'exponential', delay: 10000 },
});
```

큐 이름: `kebab-case`로 작성합니다.

### Job 페이로드 타입

현행 (Current): `app/web/src/features/queue/types.ts`에서 TypeScript 타입으로 정의합니다.

```typescript
// app/web/src/features/queue/types.ts
export type ProductDiscoveryJob = {
  platformCode: string;
  triggeredAt: string;
  triggerType?: 'cron' | 'manual';
};

export type ReviewCrawlJob = {
  platformCode: string;
  productId: number;
  externalProductId: string;
  pipelineRunId?: number;
};
```

> 권장 (Recommendation): Job 페이로드를 zod 스키마로도 정의하여 워커 수신 시 런타임 검증을 추가하세요.

### 워커 구현 패턴

현행 (Current): `app/web/src/features/queue/workers/` 디렉터리에 워커 팩토리 함수를 구현합니다.

```typescript
// app/web/src/features/queue/workers/ai-processing.ts
import { Worker } from 'bullmq';
import { createLogger } from '@/services/logger';
import type { AIProcessingJob } from '../types';

const log = createLogger('worker:ai-processing');

export function createAIProcessingWorker() {
  const worker = new Worker<AIProcessingJob>(
    'ai-processing',
    async (job) => {
      log.info(`Processing ${job.data.reviewIds.length} reviews`);
      // 비즈니스 로직...
    },
    {
      connection: redis,
      concurrency: 5,          // 동시 처리 수
    },
  );

  // 워커 실패 시 Slack 알림
  worker.on('failed', (job, err) => {
    notifyCrawlError('AI 분석', 'batch', err.message).catch(() => {});
  });

  return worker;
}
```

### 워커 컨테이너 실행

현행 (Current): 워커는 Next.js 앱 서버와 **별도 컨테이너**에서 실행됩니다.

```typescript
// app/web/src/workers/standalone.ts (진입점)
// tsx로 직접 실행: npx tsx src/workers/standalone.ts
```

`next.config.ts`의 `serverExternalPackages: ["bullmq", "ioredis"]`는 워커 컨테이너가 이 패키지를 번들링 없이 네이티브로 사용하기 위해 선언됩니다.

### 재시도/백오프 표준값

| 큐 | 최대 재시도 | 초기 지연 | 백오프 타입 |
|----|-----------|---------|-----------|
| `product-discovery` | 3회 | 5,000ms | exponential |
| `review-crawl` | 3회 | 10,000ms | exponential |
| `ai-processing` | 2회 | 15,000ms | exponential |
| `summary-generation` | 2회 | 10,000ms | exponential |

> 권장 (Recommendation): 최대 재시도 초과 시 Dead Letter Queue(DLQ) 패턴을 도입하여 실패 Job을 별도 큐로 격리하고 수동 재처리할 수 있는 관리자 UI 또는 API를 제공하세요.

---

## 13. 테스트 표준

### 단위 테스트

> 권장 (Recommendation): **Vitest**를 단위 테스트 프레임워크로 도입하세요. Next.js/TypeScript 프로젝트와의 호환성이 좋으며 Jest API와 호환됩니다.

```
app/web/src/
├── features/
│   └── ai-processing/
│       ├── analyzer.ts
│       └── analyzer.test.ts   # 같은 디렉터리에 위치
└── lib/
    ├── validators.ts
    └── validators.test.ts
```

테스트 대상 우선순위:
1. `app/web/src/lib/validators.ts` - 모든 zod 스키마 경계값 테스트
2. `app/web/src/features/ai-processing/` - AI 분석 로직, 기본값 반환 로직
3. `app/web/src/features/queue/workers/` - Job 처리 로직 (DB 모킹)

### 통합/계약 테스트

> 권장 (Recommendation): DB 연동 통합 테스트는 Docker Compose로 MySQL 컨테이너를 띄운 상태에서 실행하세요. `app/infra/docker-compose.dev.yml`의 DB 서비스를 테스트 환경에서도 활용할 수 있습니다.

### 헬스체크 엔드포인트

현행 (Current): `GET /api/v1/health`

```typescript
// app/web/src/app/api/v1/health/route.ts
export async function GET() {
  return NextResponse.json({
    success: true,
    data: { status: 'ok', timestamp: new Date().toISOString() },
  });
}
```

> 권장 (Recommendation): DB 연결, Redis 연결, Elasticsearch 연결 상태를 포함하는 확장된 헬스체크로 개선하세요:

```typescript
// 권장 확장 응답 예시
{
  "success": true,
  "data": {
    "status": "ok",
    "timestamp": "2026-05-26T10:00:00.000Z",
    "dependencies": {
      "database": "ok",
      "redis": "ok",
      "elasticsearch": "ok"
    }
  }
}
```

---

## 14. 성능 표준

### 응답 시간 목표

> 권장 (Recommendation): 아래 목표치를 기준으로 모니터링 도구(예: Sentry, Datadog)로 측정하세요.

| API 유형 | p95 목표 | 비고 |
|---------|---------|------|
| 단순 조회 (DB 1회) | < 100ms | 프로필, 설정 조회 |
| 복합 조회 (DB 조인, 필터) | < 300ms | 리뷰 목록, 상품 상세 |
| Elasticsearch 검색 | < 500ms | 상품 검색 |
| AI 분석 (워커) | < 30s/건 | 비동기 큐 처리 |

### 캐싱(Redis) 사용 기준

현행 (Current): Redis는 BullMQ 큐와 Rate Limiting에 사용됩니다.

> 권장 (Recommendation): 아래 데이터에 Redis 캐시를 추가하세요.

| 데이터 | 캐시 키 예시 | TTL | 무효화 시점 |
|--------|------------|-----|-----------|
| `site_settings` | `settings:all` | 5분 | 관리자 수정 시 |
| 상품 요약 | `product_summary:{productId}` | 1시간 | 새 리뷰 분석 완료 시 |
| 인기 검색어 | `popular_keywords` | 30분 | 주기적 갱신 |

### 페이지네이션 강제

대량 데이터를 반환하는 모든 목록 조회 API에는 반드시 페이지네이션을 적용합니다. `limit` 최대값은 `50`으로 제한합니다 (현행: validators.ts에서 `.max(50)` 강제).

### 비동기 오프로드 기준

| 작업 | 처리 방식 | 이유 |
|------|---------|------|
| AI 리뷰 분석 | BullMQ 큐 (`ai-processing`) | 건당 수초 소요 |
| 리뷰 크롤링 | BullMQ 큐 (`review-crawl`) | 외부 HTTP 의존 |
| 상품 요약 생성 | BullMQ 큐 (`summary-generation`) | AI 호출 포함 |
| 검색 로그 기록 | 비동기 `.catch(() => {})` | 응답 차단 불필요 |

---

## 15. 보안 표준

### 입력 검증

- **모든** 외부 입력(요청 Body, 쿼리 파라미터, 경로 파라미터)을 zod로 검증합니다.
- 화이트리스트(허용 값 열거) 방식을 사용합니다. zod의 `.enum()`과 `.max()` 등으로 범위를 제한합니다.
- 검증 전 DB나 외부 서비스를 호출하지 않습니다.

### SQL/NoSQL Injection 방지

- Drizzle ORM 빌더 API를 통해 자동으로 파라미터화 쿼리가 적용됩니다.
- **raw SQL 문자열 보간 금지**: `db.execute(\`... ${userInput} ...\`)` 형태 사용 금지.
- 불가피한 동적 SQL은 Drizzle의 `sql` 태그 템플릿 리터럴로만 작성합니다.

### XSS 방지

- API 서버는 HTML을 반환하지 않습니다. JSON 응답만 반환합니다.
- `Content-Type: application/json` 헤더가 자동으로 설정됩니다 (`NextResponse.json()`).
- 프론트엔드는 React를 사용하므로 JSX에서 자동 이스케이프됩니다.

### 시크릿/민감 정보 관리

- 모든 시크릿(API 키, DB 비밀번호, JWT 시크릿)은 **환경 변수**로 관리합니다.
- `.env` 파일은 커밋하지 않습니다 (`.gitignore` 확인 필수).
- 로그와 에러 응답에 시크릿, 비밀번호 해시, 토큰을 절대 포함하지 않습니다.

| 환경 변수 | 용도 | 필수 여부 |
|---------|------|---------|
| `DATABASE_URL` | MySQL 연결 URL | 필수 |
| `REDIS_URL` | Redis 연결 URL | 필수 |
| `ELASTICSEARCH_URL` | Elasticsearch 노드 URL | 필수 |
| `JWT_SECRET` (또는 `NEXTAUTH_SECRET`) | JWT 서명 키 | 프로덕션 필수 |
| `OPENAI_API_KEY` | OpenAI API 키 | AI 기능 사용 시 필수 |
| `SLACK_WEBHOOK_URL` | Slack 알림 Webhook | 선택 (없으면 알림 비활성화) |
| `AI_PARALLEL_BATCHES` | 동시 처리 배치 수 (기본 15). 각 배치는 15개 리뷰를 묶음 — 상세는 ai-processing 모듈 참조 | 선택 (기본값 15) |

### 요청 속도 제한 (Rate Limiting)

현행 (Current): `app/web/src/lib/rate-limit.ts`에서 Redis Sorted Set 기반으로 구현합니다.

```typescript
// 현행 설정값
export const RATE_LIMITS = {
  login:   { limit: 5,  windowSeconds: 60 },   // 1분에 5회
  search:  { limit: 30, windowSeconds: 60 },   // 1분에 30회
  general: { limit: 60, windowSeconds: 60 },   // 1분에 60회
};
```

새 엔드포인트 추가 시 보안 민감도에 따라 적절한 Rate Limit을 적용합니다.

### CORS

Next.js Route Handler는 기본적으로 Same-Origin으로 동작합니다. 외부 도메인(예: 모바일 앱, 파트너 서비스)에서 API를 호출해야 할 경우 `next.config.ts`의 `headers()` 설정으로 CORS를 명시적으로 구성하고 허용 오리진을 최소한으로 제한합니다.

---

## 16. 컨벤션

### TypeScript 코딩 규칙

현행 (Current): `app/web/tsconfig.json`에서 strict mode가 활성화되어 있습니다.

| 항목 | 규칙 | 예시 |
|------|------|------|
| **변수/함수** | `camelCase` | `getUserById`, `productId` |
| **타입/인터페이스** | `PascalCase` | `TokenPayload`, `ApiResponse` |
| **컴포넌트** | `PascalCase` | `ProductCard`, `ReviewList` |
| **상수** | `UPPER_SNAKE_CASE` | `MAX_RETRIES`, `RATE_LIMITS` |
| **타입 선언** | `type` 우선 | `type TokenPayload = {...}` |
| **인터페이스** | `interface` 사용 지양 | `interface`는 확장이 필요한 경우에만 |
| **enum** | 사용 금지 | 문자열 리터럴 유니온 사용: `'user' \| 'admin'` |
| **any 타입** | 사용 금지 | `unknown` 후 타입 가드 사용 |
| **console.log** | 사용 금지 | `createLogger()`의 `log.info()` 등 사용 |

> **예외 1건**: `app/web/src/services/db/index.ts`의 lazy Proxy 초기화에서 `any` 사용 (이유: mysql2 Pool 타입이 패키지 내부에 두 개의 중복 선언이 존재하여 Drizzle 인스턴스의 정확한 타입 지정 시 TS2322 충돌 발생). ESLint `no-explicit-any` 예외 처리됨.

### 파일 명명 규칙

| 파일 유형 | 네이밍 | 예시 |
|---------|--------|------|
| Route Handler | `route.ts` (고정) | `app/api/v1/auth/login/route.ts` |
| 피처 모듈 | `kebab-case.ts` | `ai-processing/analyzer.ts` |
| 타입 파일 | `kebab-case.ts` | `types/api.ts` |
| 스키마 파일 | `kebab-case.ts` | `db/schema/review-analyses.ts` |
| 유틸 파일 | `kebab-case.ts` | `lib/rate-limit.ts` |

### Import Alias

현행 (Current): `@/*`는 `app/web/src/*`를 가리킵니다.

```typescript
// 올바른 import (alias 사용)
import { db } from '@/services/db';
import { loginSchema } from '@/lib/validators';
import type { ApiResponse } from '@/types/api';

// 금지 (상대 경로 깊이 3 이상)
import { db } from '../../../services/db'; // ❌
```

### 빌드 전 로컬 검증 (워크플로 규칙)

현행 (Current): `app/CLAUDE.md` 및 프로젝트 메모리에 명시된 규칙입니다.

```bash
# push 전 로컬에서 순서대로 실행
pnpm typecheck   # TypeScript 타입 체크
pnpm lint        # ESLint 검사
pnpm test        # 테스트 (도입 후)
pnpm build       # 빌드 오류 확인 (app/web/ 디렉터리에서)
```

빌드가 실패하면 커밋/푸시를 중단하고 에러를 수정한 후 다시 시도합니다.

### 커밋/PR 흐름

`docs/infra/ci-cd-standards.md`를 참조합니다.

---

*마지막 수정: 2026-05-26 | 버전: v1.0.0*
