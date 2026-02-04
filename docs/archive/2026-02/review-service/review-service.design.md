# Review Service MVP Design Document

> **Summary**: 리뷰 모으기 서비스 MVP 기술 설계 — Next.js + MySQL + BullMQ + OpenAI
>
> **Project**: reviews (리뷰 모으기 서비스)
> **Version**: 0.1.0
> **Date**: 2026-02-01
> **Status**: Draft
> **Planning Doc**: [review-service.plan.md](../../01-plan/features/review-service.plan.md)

---

## 1. Overview

### 1.1 Design Goals

- Phase별 독립 구현 가능한 모듈화 구조
- DB 스키마(init.sql)와 API 명세(API_PARAMETER_GUIDE.md)를 그대로 활용
- 크롤러를 플랫폼 인터페이스로 추상화하여 플랫폼 추가 용이
- BullMQ 파이프라인으로 크롤링 → AI 가공 비동기 처리

### 1.2 Design Principles

- 기존 DBA 문서의 테이블/컬럼명을 변경 없이 Drizzle 스키마로 매핑
- API 응답 형식은 API_PARAMETER_GUIDE.md 준수
- 플랫폼별 크롤러는 공통 인터페이스로 추상화
- Server Components 우선, 클라이언트 상태 최소화

---

## 2. Architecture

### 2.1 Component Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        Next.js App                           │
│  ┌───────────┐  ┌──────────────┐  ┌───────────────────┐     │
│  │ App Router │  │  API Routes  │  │ BullMQ Workers    │     │
│  │ (SSR/RSC) │  │  /api/v1/*   │  │ (별도 프로세스)      │     │
│  └─────┬─────┘  └──────┬───────┘  └────────┬──────────┘     │
│        │               │                   │                 │
│  ┌─────┴───────────────┴───────────────────┴──────────┐     │
│  │                  Features Layer                      │     │
│  │  auth │ products │ reviews │ crawlers │ ai-processing│     │
│  └─────────────────────┬───────────────────────────────┘     │
│                        │                                     │
│  ┌─────────────────────┴───────────────────────────────┐     │
│  │                  Services Layer                      │     │
│  │  db (Drizzle) │ redis (ioredis) │ elasticsearch     │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
         │                │                    │
    ┌────┴────┐    ┌──────┴──────┐    ┌───────┴──────┐
    │  MySQL  │    │    Redis    │    │Elasticsearch │
    │  8.0    │    │  (BullMQ)  │    │   8.12       │
    └─────────┘    └─────────────┘    └──────────────┘
```

### 2.2 Data Flow

#### 크롤링 파이프라인

```
[node-cron / BullMQ Repeatable]
  │ 매일 02:00
  ▼
[product-discovery Queue]
  │ 플랫폼별 인기상품 수집
  ▼
[review-crawl Queue]
  │ 상품별 리뷰 크롤링 (Worker 5~10개)
  │ → 중복 체크 (Redis Set)
  │ → MySQL 원본 저장
  ▼
[ai-processing Queue]
  │ 배치 10~20개
  │ → OpenAI gpt-4o-mini
  │ → 광고성 판별, 키워드, 감성, 사이즈 피드백, 요약
  ▼
[MySQL + Elasticsearch 저장]
```

#### 사용자 요청 흐름

```
Browser → Next.js SSR/RSC → API Route → MySQL/ES → Response
                                │
                          (인증 필요 시)
                          NextAuth.js JWT 검증
```

### 2.3 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| next | 15.x | Framework |
| next-auth | 5.x | 인증 (소셜 로그인) |
| drizzle-orm | latest | MySQL ORM |
| drizzle-kit | latest | 마이그레이션 도구 |
| mysql2 | latest | MySQL 드라이버 |
| bullmq | latest | 작업 큐 |
| ioredis | latest | Redis 클라이언트 |
| @elastic/elasticsearch | 8.x | ES 클라이언트 |
| playwright | latest | 무신사/네이버 크롤러 |
| openai | latest | AI 리뷰 분석 |
| zod | latest | 입력 검증 |
| bcrypt | latest | 비밀번호 해싱 |
| tailwindcss | 4.x | 스타일링 |

---

## 3. Data Model

### 3.1 DB 스키마

기존 `docs/dba/init.sql`의 11개 테이블을 Drizzle 스키마로 그대로 매핑한다. 테이블 구조를 변경하지 않는다.

| 테이블 | Drizzle 스키마 파일 | 용도 |
|--------|-------------------|------|
| users | `src/services/db/schema/users.ts` | 사용자 |
| user_profiles | `src/services/db/schema/user-profiles.ts` | 체형 프로필 |
| platforms | `src/services/db/schema/platforms.ts` | 플랫폼 |
| products | `src/services/db/schema/products.ts` | 상품 |
| product_platform_mappings | `src/services/db/schema/product-platform-mappings.ts` | 가격 비교 |
| reviews | `src/services/db/schema/reviews.ts` | 리뷰 |
| review_analyses | `src/services/db/schema/review-analyses.ts` | AI 분석 결과 |
| review_keywords | `src/services/db/schema/review-keywords.ts` | 키워드 |
| product_summaries | `src/services/db/schema/product-summaries.ts` | 리뷰 요약 |
| size_insights | `src/services/db/schema/size-insights.ts` | 사이즈 인사이트 |
| recent_views | `src/services/db/schema/recent-views.ts` | 최근 본 상품 |

### 3.2 Entity Relationships

```
[users] 1──N [user_profiles]
[users] 1──N [recent_views]
[platforms] 1──N [product_platform_mappings]
[platforms] 1──N [reviews]
[products] 1──N [product_platform_mappings]
[products] 1──N [reviews]
[products] 1──1 [product_summaries]
[products] 1──N [size_insights]
[products] 1──N [recent_views]
[reviews] 1──1 [review_analyses]
[reviews] 1──N [review_keywords]
```

---

## 4. API Specification

API 상세는 `docs/dba/API_PARAMETER_GUIDE.md` 문서를 따른다. 아래는 엔드포인트 요약.

### 4.1 Endpoint List

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/api/v1/auth/register` | 이메일 회원가입 | - |
| POST | `/api/v1/auth/social` | 소셜 로그인 | - |
| POST | `/api/v1/auth/login` | 이메일 로그인 | - |
| POST | `/api/v1/auth/verify-email` | 이메일 인증 | - |
| POST | `/api/v1/auth/forgot-password` | 비밀번호 찾기 | - |
| POST | `/api/v1/auth/reset-password` | 비밀번호 재설정 | - |
| POST | `/api/v1/auth/refresh` | 토큰 갱신 | Refresh Token |
| GET | `/api/v1/profiles/{category}` | 프로필 조회 | Required |
| PUT | `/api/v1/profiles/fashion` | 패션 프로필 등록/수정 | Required |
| GET | `/api/v1/products/search` | 상품 검색 | Optional |
| GET | `/api/v1/products/{id}` | 상품 상세 | Optional |
| GET | `/api/v1/products/{id}/reviews` | 리뷰 목록 | Optional |
| GET | `/api/v1/products/{id}/prices` | 가격 비교 | - |
| GET | `/api/v1/products/{id}/summary` | 리뷰 요약 | - |
| GET | `/api/v1/products/{id}/size-insights` | 사이즈 인사이트 | Optional |
| GET | `/api/v1/users/me/recent-views` | 최근 본 상품 | Required |
| POST | `/api/v1/users/me/recent-views` | 최근 본 상품 기록 | Required |

### 4.2 Error Response Format

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

### 4.3 Authentication

- Access Token: JWT, 30분 만료, HttpOnly Cookie
- Refresh Token: 7일 만료, HttpOnly Cookie
- Rate Limiting: 로그인 5회/분, 검색 30회/분, 일반 60회/분

---

## 5. Crawler Design

### 5.1 Platform Interface

```typescript
type CrawlerResult = {
  products: CrawledProduct[]
  reviews: CrawledReview[]
}

type PlatformCrawler = {
  platformCode: string
  discoverProducts(): Promise<CrawledProduct[]>
  crawlReviews(externalProductId: string): Promise<CrawledReview[]>
}
```

### 5.2 Platform Implementations

| 플랫폼 | 파일 | 방식 | 비고 |
|--------|------|------|------|
| 29cm | `src/features/crawlers/platforms/twentynine-cm.ts` | REST API | Base: `https://review-api.29cm.co.kr` |
| 무신사 | `src/features/crawlers/platforms/musinsa.ts` | Playwright | DOM 파싱, JS 렌더링 필요 |
| 네이버 | `src/features/crawlers/platforms/naver.ts` | Playwright | 봇 탐지 강함 |

### 5.3 29cm API Endpoints

| API | URL | 용도 |
|-----|-----|------|
| 리뷰 목록 | `/api/v4/reviews?itemId={id}&page=0&size=20&sort=BEST` | 리뷰 데이터 |
| 리뷰 개수 | `/api/v4/reviews/count?itemId={id}` | 총 리뷰 수 |
| 포토 리뷰 | `/api/v4/reviews/photo?itemId={id}&page=0&size=6` | 사진 리뷰 |

---

## 6. AI Processing Design

### 6.1 OpenAI Batch Processing

```typescript
type AIAnalysisInput = {
  reviewId: number
  content: string
  rating: number
  platform: string
}

type AIAnalysisOutput = {
  isSponsored: boolean
  sponsoredConfidence: number
  disadvantageScore: number
  disadvantageKeywords: string[]
  advantageKeywords: string[]
  sentimentScore: number
  sizeFeedback: 'small' | 'perfect' | 'large' | null
  summary: string
}
```

### 6.2 Processing Rules

- 배치 크기: 10~20개 리뷰
- 모델: gpt-4o-mini
- 광고성 키워드 패턴: "협찬", "제공", "체험단", "광고", "소정의 원고료"
- 단점 상세도 점수: `(키워드 수 × 10) + (단점 문자 수 × 0.5)`
- 리뷰 10자 미만: AI 분석 스킵, 키워드 매칭만 적용

---

## 7. BullMQ Queue Design

### 7.1 Queue Definitions

| Queue | Concurrency | Retry | Purpose |
|-------|-------------|-------|---------|
| `product-discovery` | 1 | 3회 | 플랫폼별 인기상품 수집 |
| `review-crawl` | 5 | 3회, exponential backoff | 상품별 리뷰 크롤링 |
| `ai-processing` | 3 | 2회 | OpenAI 리뷰 분석 |
| `summary-generation` | 1 | 2회 | 상품 요약/인사이트 갱신 |

### 7.2 Job Data Schemas

```typescript
// product-discovery
type ProductDiscoveryJob = {
  platformCode: string
  triggeredAt: string
}

// review-crawl
type ReviewCrawlJob = {
  platformCode: string
  productId: number
  externalProductId: string
}

// ai-processing
type AIProcessingJob = {
  reviewIds: number[]  // 배치 (10~20개)
}

// summary-generation
type SummaryGenerationJob = {
  productId: number
}
```

### 7.3 Scheduler

```typescript
// node-cron 또는 BullMQ Repeatable Jobs
// 매일 02:00 KST
// 1. 각 플랫폼별 product-discovery 작업 추가
// 2. product-discovery 완료 시 → review-crawl 작업 생성
// 3. review-crawl 완료 시 → ai-processing 작업 생성
// 4. ai-processing 완료 시 → summary-generation 작업 생성
```

---

## 8. UI/UX Design

### 8.1 Screen List & Routes

| Screen | Route | Auth | Component |
|--------|-------|------|-----------|
| S-001 메인 홈 | `/` | - | `src/app/(main)/page.tsx` |
| S-002 검색 결과 | `/search?keyword=...` | - | `src/app/(main)/search/page.tsx` |
| S-003 상품 상세 | `/products/[id]` | - | `src/app/(main)/products/[id]/page.tsx` |
| S-004 회원가입 | `/signup` | - | `src/app/(auth)/signup/page.tsx` |
| S-005 로그인 | `/login` | - | `src/app/(auth)/login/page.tsx` |
| S-006 마이페이지 | `/mypage` | Required | `src/app/(user)/mypage/page.tsx` |
| S-007 프로필 설정 | `/mypage/profile` | Required | `src/app/(user)/mypage/profile/page.tsx` |
| S-008 비밀번호 찾기 | `/forgot-password` | - | `src/app/(auth)/forgot-password/page.tsx` |

### 8.2 상품 상세 (S-003) 섹션 구조

PRD 5.2의 화면 구성을 그대로 구현:

1. **상품 정보** — 이미지, 브랜드, 상품명, 평균 평점, 리뷰 수
2. **가격 비교** — 플랫폼별 가격, 최저가 하이라이트, 구매 링크
3. **리뷰 요약** — 장점 Top 3, 단점 Top 3 (언급 빈도)
4. **사이즈 인사이트** — 추천 사이즈, 사이즈별 구매 비율, 피드백 분포
5. **리뷰 목록** — 정렬/필터 바 + 리뷰 카드 목록 + 무한 스크롤

### 8.3 Component Structure

| Component | Location | Responsibility |
|-----------|----------|----------------|
| `ProductHeader` | `src/features/products/components/` | 상품 이미지, 이름, 브랜드, 평점 |
| `PriceComparison` | `src/features/products/components/` | 가격 비교 테이블 |
| `ReviewSummary` | `src/features/reviews/components/` | 장단점 Top 3 |
| `SizeInsight` | `src/features/reviews/components/` | 사이즈 추천, 차트 |
| `ReviewList` | `src/features/reviews/components/` | 리뷰 목록 + 필터/정렬 |
| `ReviewCard` | `src/features/reviews/components/` | 개별 리뷰 카드 |
| `ReviewFilter` | `src/features/reviews/components/` | 필터/정렬 바 |
| `SignupForm` | `src/features/auth/components/` | 회원가입 폼 |
| `LoginForm` | `src/features/auth/components/` | 로그인 폼 |
| `SocialLoginButtons` | `src/features/auth/components/` | 소셜 로그인 버튼 |
| `ProfileForm` | `src/features/auth/components/` | 체형 프로필 폼 |
| `SearchBar` | `src/features/products/components/` | 검색 입력 |

---

## 9. Security

PRD 7.3 기반:

- [x] 비밀번호: bcrypt (cost 12)
- [x] 체형 정보: AES-256-GCM 암호화
- [x] JWT: Access 30분 + Refresh 7일, HttpOnly + Secure + SameSite=Strict
- [x] Rate Limiting: 로그인 5/분, 검색 30/분, 일반 60/분
- [x] XSS 방어: HTML 이스케이프
- [x] SQL Injection 방지: Drizzle ORM (parameterized query)
- [x] CSRF: SameSite Cookie
- [x] 리뷰어 닉네임 마스킹: 수집 시점 처리

---

## 10. Error Handling

### 10.1 Error Codes

| Code | HTTP Status | Message | Handling |
|------|-------------|---------|----------|
| `INVALID_PARAMETER` | 400 | 입력값 오류 | Zod 검증 에러 반환 |
| `UNAUTHORIZED` | 401 | 인증 필요 | 로그인 페이지 리다이렉트 |
| `EMAIL_NOT_VERIFIED` | 403 | 이메일 미인증 | 인증 메일 재발송 안내 |
| `NOT_FOUND` | 404 | 리소스 없음 | 404 페이지 |
| `DUPLICATE_EMAIL` | 409 | 이메일 중복 | 중복 안내 메시지 |
| `RATE_LIMITED` | 429 | 요청 초과 | 재시도 안내 |
| `INTERNAL_ERROR` | 500 | 서버 오류 | 로그 + Sentry |
| `CRAWL_FAILED` | 500 | 크롤링 실패 | 재시도 큐 + 알림 |
| `AI_PROCESSING_FAILED` | 500 | AI 가공 실패 | 재시도 큐 + 알림 |

---

## 11. Monorepo Structure & Future Separation

### 11.1 MVP (현재)

```
reviews/
├── web/          # Next.js (프론트엔드 + API Routes 통합)
├── workers/      # BullMQ 워커 (별도 프로세스)
├── infra/        # Docker Compose, init.sql, .env.example
└── docs/         # 프로젝트 문서
```

MVP 단계에서는 `web/` 안에서 Next.js API Routes로 프론트엔드와 백엔드를 함께 운영한다.
`features/`와 `services/` 레이어를 분리해 두어, 비즈니스 로직이 Next.js에 직접 의존하지 않도록 한다.

### 11.2 Post-MVP 분리 계획

트래픽 증가 또는 팀 분리 시 아래 구조로 전환:

```
reviews/
├── web/          # Next.js (프론트엔드 only, API 호출)
├── api/          # Express/Fastify (REST API 서버)
├── workers/      # BullMQ 워커
├── packages/     # 공유 코드
│   ├── db/       # Drizzle 스키마 + 커넥션
│   ├── types/    # 공유 타입
│   └── lib/      # crypto, validators 등
├── infra/        # Docker Compose, k8s manifests
└── docs/
```

**분리 시 핵심 변경점:**
- `web/src/app/api/` → `api/src/routes/`로 이동
- `web/src/services/`, `web/src/lib/` → `packages/`로 추출
- `web/`은 API 서버를 `fetch`로 호출하는 클라이언트 역할만 담당

### 11.3 현재 File Structure (web/)

```
web/
├── .env.local
├── src/
│   ├── app/
│   │   ├── (auth)/
│   │   │   ├── signup/page.tsx
│   │   │   ├── login/page.tsx
│   │   │   └── forgot-password/page.tsx
│   │   ├── (main)/
│   │   │   ├── page.tsx                     # 메인 홈
│   │   │   ├── search/page.tsx              # 검색 결과
│   │   │   └── products/[id]/page.tsx       # 상품 상세
│   │   ├── (user)/
│   │   │   └── mypage/
│   │   │       ├── page.tsx                 # 마이페이지
│   │   │       └── profile/page.tsx         # 프로필 설정
│   │   ├── api/v1/
│   │   │   ├── auth/
│   │   │   │   ├── register/route.ts
│   │   │   │   ├── login/route.ts
│   │   │   │   ├── social/route.ts
│   │   │   │   ├── verify-email/route.ts
│   │   │   │   ├── forgot-password/route.ts
│   │   │   │   ├── reset-password/route.ts
│   │   │   │   └── refresh/route.ts
│   │   │   ├── profiles/
│   │   │   │   ├── [category]/route.ts
│   │   │   │   └── fashion/route.ts
│   │   │   ├── products/
│   │   │   │   ├── search/route.ts
│   │   │   │   └── [id]/
│   │   │   │       ├── route.ts             # 상품 상세
│   │   │   │       ├── reviews/route.ts
│   │   │   │       ├── prices/route.ts
│   │   │   │       ├── summary/route.ts
│   │   │   │       └── size-insights/route.ts
│   │   │   └── users/me/
│   │   │       └── recent-views/route.ts
│   │   └── layout.tsx
│   ├── features/
│   │   ├── auth/
│   │   │   ├── components/                  # SignupForm, LoginForm, SocialLoginButtons, ProfileForm
│   │   │   ├── actions/                     # Server Actions
│   │   │   └── lib/                         # bcrypt, jwt, email, unique-code
│   │   ├── products/
│   │   │   ├── components/                  # ProductHeader, PriceComparison, SearchBar
│   │   │   └── actions/
│   │   ├── reviews/
│   │   │   ├── components/                  # ReviewList, ReviewCard, ReviewFilter, ReviewSummary, SizeInsight
│   │   │   └── actions/
│   │   ├── crawlers/
│   │   │   ├── platforms/
│   │   │   │   ├── twentynine-cm.ts
│   │   │   │   ├── musinsa.ts
│   │   │   │   └── naver.ts
│   │   │   ├── types.ts                     # PlatformCrawler interface
│   │   │   └── registry.ts                  # crawler lookup by platformCode
│   │   ├── ai-processing/
│   │   │   ├── analyzer.ts                  # OpenAI 호출
│   │   │   └── prompts.ts                   # 프롬프트 템플릿
│   │   └── queue/
│   │       ├── queues.ts                    # Queue definitions
│   │       ├── workers/
│   │       │   ├── product-discovery.ts
│   │       │   ├── review-crawl.ts
│   │       │   ├── ai-processing.ts
│   │       │   └── summary-generation.ts
│   │       └── scheduler.ts                 # node-cron 설정
│   ├── services/
│   │   ├── db/
│   │   │   ├── index.ts                     # Drizzle 커넥션
│   │   │   └── schema/                      # 11개 테이블 스키마
│   │   ├── redis/
│   │   │   └── index.ts                     # ioredis 커넥션
│   │   └── elasticsearch/
│   │       └── index.ts                     # ES 클라이언트
│   ├── lib/
│   │   ├── crypto.ts                        # AES-256-GCM 암호화
│   │   ├── rate-limit.ts                    # Rate Limiting
│   │   └── validators.ts                    # Zod 스키마
│   └── types/
│       ├── api.ts                           # API 응답 타입
│       ├── crawler.ts                       # 크롤러 타입
│       └── review.ts                        # 리뷰 관련 타입
workers/
├── src/
│   └── start.ts                             # BullMQ 워커 엔트리포인트

infra/
├── docker-compose.yml
├── init.sql                                 # DB 초기화 (docs/dba/init.sql 복사)
└── .env.example
```

### 11.2 Implementation Order (Phase별)

#### Phase 1: 프로젝트 초기화 + 인프라

```
1. [ ] docker-compose.yml (MySQL 8.0, Redis 7, ES 8.12)
2. [ ] pnpm create next-app (App Router, TypeScript, Tailwind)
3. [ ] 의존성 설치 (drizzle-orm, mysql2, ioredis, bullmq 등)
4. [ ] .env.local 템플릿 생성
5. [ ] docker compose up → init.sql 자동 실행 확인
```

#### Phase 2: DB 연결 + API 구조

```
1. [ ] src/services/db/ — Drizzle 커넥션 + 스키마 11개
2. [ ] src/services/redis/ — ioredis 커넥션
3. [ ] src/services/elasticsearch/ — ES 클라이언트
4. [ ] src/lib/validators.ts — Zod 공통 스키마
5. [ ] src/types/ — 공유 타입 정의
6. [ ] API Route 기본 구조 (health check)
```

#### Phase 3: 인증

```
1. [ ] NextAuth.js 설정 (Google, Apple, Kakao)
2. [ ] POST /api/v1/auth/register — bcrypt 해싱, unique code 발급
3. [ ] POST /api/v1/auth/login — JWT 발급, HttpOnly Cookie
4. [ ] POST /api/v1/auth/verify-email — 이메일 인증
5. [ ] POST /api/v1/auth/forgot-password + reset-password
6. [ ] PUT /api/v1/profiles/fashion — 체형 프로필 CRUD
7. [ ] src/lib/crypto.ts — AES-256-GCM (체형 정보 암호화)
8. [ ] src/lib/rate-limit.ts — Redis 기반 Rate Limiting
```

#### Phase 4: 29cm 크롤러

```
1. [ ] src/features/crawlers/types.ts — PlatformCrawler 인터페이스
2. [ ] src/features/crawlers/platforms/twentynine-cm.ts
3. [ ] 수동 실행 스크립트 (크롤링 테스트)
4. [ ] MySQL에 products, reviews 저장 확인
```

#### Phase 5: BullMQ + AI 가공

```
1. [ ] src/features/queue/queues.ts — 4개 큐 정의
2. [ ] workers/ — 4개 워커 구현
3. [ ] src/features/queue/scheduler.ts — node-cron
4. [ ] src/features/ai-processing/ — OpenAI 분석
5. [ ] review_analyses, review_keywords 저장 확인
6. [ ] product_summaries, size_insights 갱신 확인
```

#### Phase 6: 무신사 크롤러

```
1. [ ] src/features/crawlers/platforms/musinsa.ts — Playwright
2. [ ] 체형 정보 텍스트 파싱 ("174cm · 72kg")
3. [ ] review-crawl 큐에 통합
```

#### Phase 7: 네이버 스마트스토어 크롤러

```
1. [ ] src/features/crawlers/platforms/naver.ts — Playwright
2. [ ] 봇 탐지 대응 (stealth, 요청 간격)
3. [ ] review-crawl 큐에 통합
```

#### Phase 8: 프론트엔드 + 검색

```
1. [ ] Elasticsearch 인덱스 생성 + 데이터 동기화
2. [ ] S-001 메인 홈 (검색바, 인기 상품)
3. [ ] S-002 검색 결과 (상품 카드 목록)
4. [ ] S-003 상품 상세 (가격비교, 요약, 인사이트, 리뷰목록)
5. [ ] S-004 회원가입 + S-005 로그인 + S-008 비밀번호 찾기
6. [ ] S-006 마이페이지 + S-007 프로필 설정
7. [ ] 모바일 반응형 적용
```

#### Phase 9: 관리자 + 마무리

```
1. [ ] 관리자 페이지 (크롤링 상태, 통계)
2. [ ] 최근 본 상품 기능
3. [ ] 통합 테스트 (주요 사용자 시나리오)
4. [ ] 성능 확인 (API 응답 시간)
```

---

## 12. Test Plan

### 12.1 Test Scope

| Type | Target | Tool |
|------|--------|------|
| Unit | 크롤러 파싱, AI 분석 로직, 유사 체형 계산 | Vitest |
| Integration | API Routes (인증, 리뷰, 검색) | Vitest + fetch |
| E2E | 회원가입 → 프로필 설정 → 검색 → 리뷰 조회 | Playwright |

### 12.2 Key Test Cases

- [ ] 회원가입 → 이메일 인증 → 로그인 → JWT 발급
- [ ] 29cm API 크롤링 → MySQL 저장 → AI 분석 → 요약 생성
- [ ] 리뷰 목록 API: 광고성 제외 + 단점상세순 정렬
- [ ] 유사 체형 리뷰 조회 (distance < 5)
- [ ] 가격 비교 API: 최저가 하이라이트
- [ ] Rate Limiting: 로그인 6회 시 429

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-02-01 | Initial draft — Plan + PRD v1.2 + DBA 문서 기반 |
