# 프론트엔드 표준 (Frontend Standards)

> **적용 대상**: `app/web/` — 리뷰 모으기 서비스 (ReviewHunt) 프론트엔드
>
> **관리 주체**: `team-twms` 의 `frontend` 멤버
>
> **현행 (Current):** 코드베이스에서 확인된 사실
> **권장 (Recommendation):** 아직 구현되지 않았지만 채택을 권장하는 사항

---

## 목차

1. [개요 및 적용 범위](#1-개요-및-적용-범위)
2. [기술 스택](#2-기술-스택)
3. [디렉터리 구조 및 책임 분리](#3-디렉터리-구조-및-책임-분리)
4. [App Router 구조 표준](#4-app-router-구조-표준)
5. [컴포넌트 작성 표준](#5-컴포넌트-작성-표준)
6. [스타일링 표준 (Tailwind 4)](#6-스타일링-표준-tailwind-4)
7. [데이터 페칭 표준](#7-데이터-페칭-표준)
8. [상태 관리 정책](#8-상태-관리-정책)
9. [폼 처리 표준](#9-폼-처리-표준)
10. [인증 흐름](#10-인증-흐름)
11. [API 통신 규약](#11-api-통신-규약)
12. [이미지/리소스](#12-이미지리소스)
13. [국제화/접근성](#13-국제화접근성)
14. [성능 표준](#14-성능-표준)
15. [테스트 표준 (Playwright)](#15-테스트-표준-playwright)
16. [로깅/모니터링](#16-로깅모니터링)
17. [빌드/배포](#17-빌드배포)
18. [컨벤션](#18-컨벤션)

---

## 1. 개요 및 적용 범위

### 서비스 개요

리뷰 모으기 서비스(ReviewHunt)는 여러 쇼핑몰의 리뷰를 수집·분석하여, 광고성 리뷰를 걸러내고 체형 기반 개인화 인사이트를 제공하는 패션 리뷰 검색 서비스입니다.

### 적용 범위

| 대상 | 경로 | 설명 |
|------|------|------|
| 프론트엔드 소스 | `app/web/src/` | 전체 Next.js 애플리케이션 소스 |
| App Router 페이지 | `app/web/src/app/` | 페이지, 레이아웃, API 라우트 |
| 공용 컴포넌트 | `app/web/src/components/` | 전역 재사용 컴포넌트 |
| 기능 모듈 | `app/web/src/features/` | 도메인별 기능 단위 |
| 유틸리티 | `app/web/src/lib/` | 클라이언트 유틸 (인증, 검증 등) |

### 범위 외

- 백엔드 서버 로직 (`services/`, `workers/`는 서버 전용)
- DB 스키마 설계 (`docs/dba/` 참조)
- 인프라/배포 설정 (`docs/infra/` 참조)

---

## 2. 기술 스택

> 현행 (Current): `app/web/package.json`, `tsconfig.json`, `next.config.ts` 기준

| 항목 | 선택 | 버전 | 비고 |
|------|------|------|------|
| 언어 | TypeScript | `^5` | strict mode, target ES2017 |
| 프레임워크 | Next.js | `16.1.6` | App Router, standalone 출력 |
| 런타임 | React / React DOM | `19.2.3` | — |
| 렌더링 전략 | CSR + SSR 혼합 | — | 페이지별 결정 (섹션 4 참조) |
| 스타일링 | Tailwind CSS | `^4` | `@tailwindcss/postcss` 플러그인 |
| UI 컴포넌트 라이브러리 | 자체 구현 | — | shadcn/ui 미사용, `src/components/` 직접 관리 |
| 차트 | Recharts | `^3.7.0` | 관리자 대시보드용 |
| 상태 관리 | React 내장 | — | Redux/Zustand 미사용 |
| 서버 상태 | 네이티브 `fetch` | — | TanStack Query 미도입 (도입 검토 가능, 섹션 8 참조) |
| 폼 관리 | Controlled Component | — | react-hook-form 미사용 |
| 유효성 검증 | Zod | `^4.3.6` | `src/lib/validators.ts` |
| 인증 | NextAuth.js | `^5.0.0-beta.30` | JWT + localStorage |
| OAuth 제공자 | Google, Apple, Kakao | — | — |
| 라우팅 | Next.js App Router | 내장 | 동적 라우트 `[id]` 사용 |
| 테스트 | Playwright | `^1.58.1` | E2E + 크롤링 겸용 |
| 빌드 도구 | Turbopack | Next.js 내장 | `next.config.ts` turbopack 옵션 사용 |
| 패키지 매니저 | pnpm | — | `pnpm-lock.yaml` 기준 |
| 린터 | ESLint | `^9` | flat config (`eslint.config.mjs`) |
| 린터 프리셋 | eslint-config-next | `16.1.6` | core-web-vitals + typescript |
| 폰트 | Geist (Google Fonts) | — | `next/font/google` 로드 |
| ORM (서버 전용) | Drizzle ORM | `^0.45.1` | 서버 컴포넌트/API 라우트 전용 |

### 서버 전용 패키지 (클라이언트 번들 제외 대상)

`next.config.ts`의 `serverExternalPackages`에 등록된 패키지는 클라이언트 번들에 포함되지 않습니다.

```typescript
// app/web/next.config.ts
serverExternalPackages: ["openai", "bullmq", "ioredis"]
```

`@elastic/elasticsearch`, `mysql2`, `bcrypt`, `drizzle-orm`도 서버 전용으로 취급합니다. 클라이언트 컴포넌트(`'use client'`)에서 직접 import하지 마세요.

---

## 3. 디렉터리 구조 및 책임 분리

```
app/web/src/
├── app/                  # App Router: 페이지, 레이아웃, API 라우트
│   ├── (auth)/           # 라우트 그룹: 인증 페이지 (로그인, 회원가입, 비밀번호 찾기)
│   ├── (main)/           # 라우트 그룹: 메인 서비스 (홈, 검색, 상품, 어드민)
│   ├── (user)/           # 라우트 그룹: 사용자 영역 (마이페이지)
│   ├── api/              # API 라우트 (/api/v1/...)
│   ├── globals.css       # 전역 CSS (Tailwind import + 커스텀 애니메이션)
│   └── layout.tsx        # 루트 레이아웃 (html, body, 폰트)
│
├── components/           # 전역 재사용 컴포넌트 (도메인 무관)
│   ├── Header.tsx
│   └── Footer.tsx
│
├── features/             # 기능 모듈 (도메인별 캡슐화)
│   ├── auth/             # 인증 (LoginForm, SignupForm, ProfileForm, SocialLoginButtons)
│   ├── ai-processing/    # AI 분석 처리
│   ├── crawlers/         # 크롤러 관련 UI
│   ├── products/         # 상품 (ProductHeader, PriceComparison, SearchBar)
│   ├── queue/            # 큐 관리 UI
│   ├── reviews/          # 리뷰 (ReviewCard, ReviewFilter, ReviewList, ReviewSummary, SizeInsight)
│   └── search/           # 검색 로직 및 컴포넌트
│
├── lib/                  # 클라이언트/공통 유틸리티 (순수 함수, 클라이언트 API 래퍼)
│   ├── auth-client.ts    # 토큰 관리 + authFetch 래퍼
│   ├── validators.ts     # Zod 스키마 (auth, profile, product search, review list)
│   ├── crypto.ts         # 암호화 유틸
│   ├── rate-limit.ts     # API 요청 제한 유틸
│   ├── crawler-utils.ts  # 크롤러 공통 유틸
│   └── settings.ts       # 앱 설정 상수
│
├── services/             # 서버 전용 싱글턴 (DB, Redis, Elasticsearch, Logger, Slack)
│   ├── db/               # Drizzle ORM 인스턴스 (lazy Proxy 패턴)
│   ├── elasticsearch/    # ES 클라이언트
│   ├── redis/            # BullMQ + ioredis
│   ├── logger/           # 서버 로거
│   ├── slack/            # Slack 알림
│   └── openai/           # OpenAI 클라이언트 (lazy 싱글톤)
│
├── middleware.ts          # API 라우트 보호 (Authorization 헤더 검증, /api/v1/admin/* 전용)
├── types/                 # 전역 TypeScript 타입
│   └── api.ts             # ApiResponse, ApiSuccessResponse, ApiErrorResponse
└── workers/               # 워커 프로세스 엔트리포인트 (서버 전용)
```

### app vs features vs components — 차이 명확화

| 위치 | 기준 | 예시 |
|------|------|------|
| `app/` | **라우팅 단위**. Next.js가 직접 인식하는 page, layout, API 라우트. 페이지 단위 비즈니스 조합 | `app/(main)/products/[id]/page.tsx` |
| `components/` | **도메인 무관** 전역 재사용 UI. 어떤 페이지에서도 사용 가능한 레이아웃 요소 | `Header.tsx`, `Footer.tsx` |
| `features/<domain>/` | **도메인 한정** 기능 캡슐화. 컴포넌트(UI), 액션(서버 액션/API 호출 래퍼), 로직을 한 곳에 묶음 | `features/reviews/components/ReviewCard.tsx` |
| `lib/` | 도메인 없이 **순수 유틸**. 인증 래퍼, 검증 스키마, 암호화 등 사이드이펙트 없는 함수 | `lib/auth-client.ts`, `lib/validators.ts` |
| `services/` | **서버 런타임 전용** 싱글턴. 클라이언트 컴포넌트에서 절대 import 금지 | `services/db/`, `services/redis/` |

---

## 4. App Router 구조 표준

### 4-1. 라우트 그룹 규약

현행 (Current): 3개의 라우트 그룹이 존재합니다.

| 그룹 | 경로 | 목적 |
|------|------|------|
| `(auth)` | `/login`, `/signup`, `/forgot-password` | 인증 전용 레이아웃 (중앙 정렬, 카드 형태) |
| `(main)` | `/`, `/search`, `/products/[id]`, `/admin/*` | 메인 서비스 레이아웃 |
| `(user)` | `/mypage`, `/mypage/profile`, `/mypage/settings`, `/mypage/recent` | 로그인 사용자 전용 레이아웃 |

라우트 그룹 디렉터리명은 URL에 포함되지 않습니다. 같은 레이아웃을 공유하는 페이지를 묶을 때만 사용합니다. 레이아웃 공유 목적 없이 임의로 그룹을 만들지 마세요.

### 4-2. 파일 컨벤션

| 파일명 | 역할 |
|--------|------|
| `layout.tsx` | 해당 세그먼트 및 하위 라우트에 공유되는 UI 래퍼. 네비게이션, 사이드바 등 |
| `page.tsx` | 실제 페이지 UI. 해당 경로 접근 시 렌더링 |
| `loading.tsx` | 페이지 로딩 중 표시할 Suspense 폴백 UI (스켈레톤 등) |
| `error.tsx` | 런타임 에러 발생 시 표시할 에러 바운더리 UI |
| `not-found.tsx` | `notFound()` 호출 또는 404 시 표시할 UI |
| `route.ts` | API 엔드포인트 (HTTP 핸들러 export) |

권장 (Recommendation): 데이터 페칭이 있는 모든 page.tsx 옆에 `loading.tsx`를 함께 작성하여 Suspense 폴백을 제공하세요.

### 4-3. 동적 라우트 명명

| 패턴 | 예시 경로 | 용도 |
|------|---------|------|
| `[id]` | `/products/[id]/page.tsx` | 정수 ID 기반 단건 조회 |
| `[slug]` | 향후 도입 예정 | 문자열 식별자 (SEO 친화적 URL) |
| `[...slug]` | 향후 도입 예정 | 가변 깊이 경로 (캐치올 라우트) |

현행 (Current): `[id]` 패턴만 사용 중입니다 (`/products/[id]`).

```typescript
// app/web/src/app/(main)/products/[id]/page.tsx
type Props = { params: Promise<{ id: string }> };

export default async function ProductDetailPage({ params }: Props) {
  const { id } = await params;
  const productId = parseInt(id, 10);
  if (isNaN(productId)) notFound();
  // ...
}
```

`params`는 Next.js 15+에서 `Promise`로 변경되었으므로 반드시 `await params`로 접근합니다.

### 4-4. 메타데이터 정의

정적 메타데이터는 `export const metadata`, 동적 메타데이터는 `export async function generateMetadata`를 사용합니다.

```typescript
// 정적 (루트 layout.tsx)
export const metadata: Metadata = {
  title: "리뷰 모으기 - 진짜 리뷰만 모아보세요",
  description: "여러 쇼핑몰의 리뷰를 한 곳에서 비교하고, 광고 리뷰를 걸러내세요.",
};

// 동적 (상품 상세 페이지 예시)
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const product = await fetchProduct(id);
  return {
    title: `${product.name} 리뷰 | 리뷰 모으기`,
    description: `${product.brand} ${product.name}의 실제 구매 리뷰를 확인하세요.`,
  };
}
```

### 4-5. Server Component vs Client Component 결정 기준

App Router에서 모든 컴포넌트는 기본적으로 Server Component입니다. `'use client'` 지시어는 **필요한 경우에만** 추가합니다.

| 기준 | Server Component | Client Component (`'use client'`) |
|------|-----------------|----------------------------------|
| **데이터 페칭** | DB 직접 접근, 서버 사이드 fetch | 클라이언트 상태 기반 동적 fetch |
| **브라우저 API** | 사용 불가 | `window`, `localStorage`, `document` 사용 시 필수 |
| **React 훅** | `useState`, `useEffect` 불가 | 훅 사용 시 필수 |
| **이벤트 핸들러** | `onClick` 등 불가 | 인터랙티브 UI (폼 제출, 버튼 클릭 등) |
| **서버 패키지** | Drizzle, ioredis 등 직접 사용 가능 | 서버 패키지 import 금지 |
| **번들 크기** | 번들에 미포함 (서버에서 실행) | 클라이언트 번들 포함 |

현행 (Current): `Header.tsx`, `Footer.tsx`, 인증 페이지, 홈 페이지, 검색 페이지는 `'use client'`입니다. 상품 상세 페이지(`/products/[id]/page.tsx`)는 Server Component로 DB를 직접 조회합니다.

```typescript
// Server Component 예시: DB 직접 접근
// app/web/src/app/(main)/products/[id]/page.tsx (파일 상단에 'use client' 없음)
import { db } from '@/services/db';

export default async function ProductDetailPage({ params }: Props) {
  const [product] = await db.select().from(products).where(eq(products.id, productId));
  if (!product) notFound();
  // ...
}
```

---

## 5. 컴포넌트 작성 표준

### 5-1. 함수형 컴포넌트 + TypeScript type Props

```typescript
// app/web/src/features/reviews/components/ReviewCard.tsx
type Props = {
  id: number;
  content: string;
  rating: number;
  reviewerName: string;
  purchaseOption: string | null;
  imageUrls: string | string[];
  reviewerHeight: number | null;
  reviewerWeight: number | null;
  sizeFeedback: string | null;
  reviewedAt: string;
  isSponsored: boolean | null;
};

export default function ReviewCard(props: Props) {
  // ...
}
```

- `interface` 대신 `type` 사용 (CLAUDE.md 컨벤션)
- Props 타입명은 `XxxProps` 또는 단순 `Props` (파일 내 단일 컴포넌트 시 `Props`도 허용)
- 함수 컴포넌트 반환 타입(`JSX.Element`, `React.ReactNode`)은 명시하지 않아도 되지만, 명시할 경우 `React.ReactNode`를 권장

### 5-2. 파일명 및 export 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 파일명 | kebab-case | `review-card.tsx`, `auth-client.ts` |
| 컴포넌트 export | PascalCase default export | `export default function ReviewCard` |
| 유틸 함수 export | camelCase named export | `export function authFetch` |
| 타입 export | PascalCase named export | `export type ApiResponse<T>` |

현행 (Current): 컴포넌트 파일 중 `ReviewCard.tsx`, `Header.tsx`처럼 PascalCase 파일명도 혼재합니다. 신규 파일은 kebab-case를 원칙으로 하고, 기존 파일은 점진적으로 통일합니다.

### 5-3. 컴포넌트 위치 결정 기준

| 위치 | 기준 |
|------|------|
| `src/components/` | 어떤 도메인에도 속하지 않는 전역 레이아웃/UI 요소 (`Header`, `Footer`, 버튼, 모달 등) |
| `src/features/<feature>/components/` | 특정 도메인에서만 사용하는 컴포넌트 (`ReviewCard`, `LoginForm`, `ProductHeader` 등) |

컴포넌트가 2개 이상의 feature에서 사용된다면 `src/components/`로 이동합니다.

### 5-4. 컴포넌트 계층 (Atomic Design 적용 가이드)

현재 프로젝트는 완전한 Atomic Design 계층을 강제하지 않지만, 복잡도가 증가할 경우 아래 계층을 기준으로 분리합니다.

| 계층 | 설명 | 현행 예시 |
|------|------|---------|
| Atoms | 최소 단위 UI (버튼, 입력, 뱃지 등) | `<button>`, `<input>` (현재 inline) |
| Molecules | Atom 조합 (폼 필드, 검색바 등) | `SearchBar.tsx` |
| Organisms | 독립 기능 단위 | `ReviewCard.tsx`, `ReviewList.tsx`, `Header.tsx` |
| Templates | 페이지 레이아웃 구조 | `(auth)/layout.tsx`, `(main)/layout.tsx` |
| Pages | 실제 페이지, 데이터 연결 | `page.tsx` 파일들 |

---

## 6. 스타일링 표준 (Tailwind 4)

### 6-1. 기본 원칙

현행 (Current): Tailwind CSS 4 + PostCSS(`@tailwindcss/postcss`) 조합을 사용합니다. 별도 `tailwind.config.js` 파일은 없고, `globals.css`에서 `@import "tailwindcss"` 및 `@theme` 블록으로 설정합니다.

```css
/* app/web/src/app/globals.css */
@import "tailwindcss";

:root {
  --background: #ffffff;
  --foreground: #171717;
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --font-sans: var(--font-geist-sans);
  --font-mono: var(--font-geist-mono);
}
```

- **유틸리티 우선**: Tailwind 클래스를 직접 조합하여 스타일링합니다.
- **임의 값(arbitrary value) 사용 자제**: `bg-[#0a0a0a]`, `text-[15px]`처럼 임의 값이 반복될 경우 CSS 변수 또는 `@theme` 토큰으로 추출하는 것을 권장합니다.
- **클래스 inline 작성**: 별도 CSS 파일 대신 컴포넌트 JSX 내에서 클래스 작성을 원칙으로 합니다.

### 6-2. 디자인 토큰

현행 (Current): 다음 CSS 변수가 `globals.css`에 선언되어 있습니다.

| 변수 | 라이트 | 다크 |
|------|--------|------|
| `--background` | `#ffffff` | `#0a0a0a` |
| `--foreground` | `#171717` | `#ededed` |
| `--font-sans` | Geist Sans | — |
| `--font-mono` | Geist Mono | — |

권장 (Recommendation): 반복적으로 사용되는 UI 색상(`#1a1a1a`, `#2a2a2a`, `#3a3a3a` 계열)은 `@theme` 블록에 토큰으로 추출하여 하드코딩된 임의 값을 줄이세요.

```css
/* globals.css @theme 블록 확장 예시 */
@theme inline {
  --color-surface-1: #1a1a1a;
  --color-surface-2: #2a2a2a;
  --color-border: #2a2a2a;
  --color-border-hover: #3a3a3a;
}
```

### 6-3. 반응형 브레이크포인트

Tailwind 4 기본 브레이크포인트를 사용합니다 (변경 없음).

| 접두사 | 최소 너비 | 대상 기기 |
|--------|---------|---------|
| (없음) | 0px | 모바일 (기본값) |
| `sm:` | 640px | 소형 태블릿 이상 |
| `md:` | 768px | 태블릿 이상 |
| `lg:` | 1024px | 소형 데스크톱 이상 |
| `xl:` | 1280px | 데스크톱 |
| `2xl:` | 1536px | 대형 데스크톱 |

**모바일 우선**: 기본 클래스는 모바일 기준으로 작성하고, 큰 화면에서 덮어쓰는 방식을 사용합니다.

```tsx
// 예시: 모바일 우선 반응형
<h1 className="text-[40px] md:text-[48px] font-bold text-white">
  진짜 리뷰만 모아보세요
</h1>
```

### 6-4. 다크 모드

현행 (Current): `globals.css`에서 `@media (prefers-color-scheme: dark)` 미디어 쿼리로 CSS 변수를 재정의합니다. 실제 페이지 배경은 `bg-[#0a0a0a]`를 직접 지정하여 다크 테마로 고정된 상태입니다.

권장 (Recommendation): 추후 라이트/다크 전환 기능 도입 시 Tailwind `class` 전략(`dark:` 접두사)과 `html` 요소의 `class="dark"` 토글 방식을 사용하세요. CSS 변수는 의미론적 이름(`--background`, `--foreground`)을 유지하여 하드코딩된 색상 값을 최소화합니다.

### 6-5. 조건부 클래스

권장 (Recommendation): 조건부 클래스 조합에는 `clsx` 또는 `tailwind-merge`를 사용하세요. 현재 미설치 상태이므로 도입을 권장합니다.

```typescript
// 권장: clsx 사용
import clsx from 'clsx';

const className = clsx(
  'px-4 py-3 rounded-xl',
  isActive && 'bg-blue-600 text-white',
  isDisabled && 'opacity-50 cursor-not-allowed',
);
```

현행 (Current): 조건부 클래스는 삼항 연산자로 처리합니다.

```tsx
// 현행 패턴
<span className={
  props.sizeFeedback === 'small' ? 'text-blue-500' :
  props.sizeFeedback === 'large' ? 'text-red-500' : 'text-green-500'
}>
```

### 6-6. 커스텀 애니메이션

현행 (Current): `globals.css`에 `@keyframes`와 커스텀 유틸리티 클래스가 정의되어 있습니다.

| 클래스 | 설명 |
|--------|------|
| `.animate-fadeIn` | 0.2s fade in |
| `.animate-slideUp` | 0.3s slide up + fade in |
| `.animate-keyword-roll` | 인기 검색어 롤링 (0.4s) |

---

## 7. 데이터 페칭 표준

### 7-1. Server Component에서 fetch (SSR)

현행 (Current): Server Component에서는 DB를 직접 접근하거나, 내부 API를 `fetch`로 호출합니다. Next.js의 Request Memoization이 적용되어 같은 요청은 단일 렌더링 사이클 내에서 중복 실행되지 않습니다.

```typescript
// Server Component — DB 직접 접근
import { db } from '@/services/db';
import { products } from '@/services/db/schema';

export default async function ProductDetailPage({ params }: Props) {
  const [product] = await db
    .select()
    .from(products)
    .where(eq(products.id, productId))
    .limit(1);

  if (!product) notFound();
}
```

권장 (Recommendation): 서버 컴포넌트의 `fetch` 캐싱 정책을 명시하세요.

```typescript
// 캐싱 없음 (동적 데이터)
const res = await fetch('/api/v1/...', { cache: 'no-store' });

// 일정 시간 캐싱 (준정적 데이터)
const res = await fetch('/api/v1/...', { next: { revalidate: 60 } });
```

런타임 의존성을 가진 API 라우트(`services/`, `openai` 등 import)에는 반드시 `export const dynamic = 'force-dynamic'`을 선언합니다.

```typescript
// app/web/src/app/api/v1/products/search/route.ts
export const dynamic = 'force-dynamic';
```

### 7-2. Client Component에서 fetch

현행 (Current): 클라이언트 컴포넌트에서는 `useEffect` + `fetch` 패턴 또는 `lib/auth-client.ts`의 `authFetch`를 사용합니다.

```typescript
// 인증 불필요 API 호출 (공개 엔드포인트)
useEffect(() => {
  fetch('/api/v1/settings/popular-keywords')
    .then((r) => r.json())
    .then((d) => { if (d?.success) setPopularKeywords(d.data); });
}, []);

// 인증 필요 API 호출 — authFetch 사용 필수
import { authFetch } from '@/lib/auth-client';

useEffect(() => {
  authFetch('/api/v1/users/me')
    .then((r) => r.json())
    .then((d) => { if (d?.success) setUser(d.data); });
}, []);
```

인증이 필요한 모든 클라이언트 fetch는 반드시 `authFetch`를 사용합니다. 직접 `fetch`에 `Authorization` 헤더를 수동으로 추가하지 마세요.

### 7-3. Zod를 이용한 안전 파싱

권장 (Recommendation): API 응답을 Zod로 파싱하여 런타임 타입 안정성을 높이세요.

```typescript
import { z } from 'zod';

const productSchema = z.object({
  id: z.number(),
  name: z.string(),
  brand: z.string(),
  averageRating: z.number().nullable(),
});

const res = await fetch('/api/v1/products/search?keyword=...');
const raw = await res.json();

if (raw.success) {
  const parsed = z.array(productSchema).safeParse(raw.data);
  if (parsed.success) {
    setProducts(parsed.data);
  }
}
```

### 7-4. 에러 처리 패턴

API 응답의 `success` 필드로 성공/실패를 분기합니다. 에러 시 `error.message`를 사용자에게 표시합니다.

```typescript
const data = await res.json();
if (data.success) {
  // 성공 처리
} else {
  setError(data.error?.message || '오류가 발생했습니다');
}
```

권장 (Recommendation): `error.tsx`(에러 바운더리)를 페이지 단위로 작성하여 Server Component 에러를 처리하세요.

### 7-5. 로딩 상태 UX

현행 (Current): `loading` 상태 변수(`useState<boolean>`)로 버튼 비활성화, 텍스트 변경(`'처리 중...'`)을 구현합니다.

권장 (Recommendation): 데이터 목록 로딩 시 스켈레톤(Skeleton) UI를 제공하고, Next.js `loading.tsx`와 `<Suspense>` 폴백을 활용하여 UX를 개선하세요.

---

## 8. 상태 관리 정책

### 8-1. 현행 정책

현행 (Current): 전역 상태 라이브러리(Redux, Zustand, Jotai 등)를 사용하지 않습니다. 모든 상태는 React 내장 기능으로 처리합니다.

| 상태 유형 | 도구 | 예시 |
|---------|------|------|
| 로컬 컴포넌트 상태 | `useState` | 검색 입력값, 메뉴 open/close, 에러 메시지 |
| 복잡한 로컬 상태 | `useReducer` | 복잡한 폼 상태 (현재 미사용, 필요 시 도입) |
| 컴포넌트 간 공유 | `Context API` | 필요 시 도입 (현재 미사용) |
| URL 상태 | `useSearchParams` / `useRouter` | 검색어(`?keyword=`), 페이지네이션 |
| 서버 상태 캐싱 | 없음 (직접 fetch) | 사용자 정보, 상품 목록 |

### 8-2. 서버 상태 관리

현행 (Current): 서버 상태(API 데이터)는 `useEffect` + `useState`로 관리합니다. 캐싱, 중복 요청 제거, 재시도 로직이 없습니다.

권장 (Recommendation): 클라이언트 사이드 서버 상태 요구사항이 증가하면(목록 페이지네이션, 캐싱, 낙관적 업데이트 등) **TanStack Query(React Query) v5** 도입을 검토하세요. 도입 조건: 동일 API를 여러 컴포넌트에서 호출하거나, 자동 재시도/캐시 무효화가 필요한 경우.

#### TanStack Query 점진 도입 전략

현행 `useEffect + fetch` 패턴을 점진적으로 TanStack Query로 교체하기 위한 단계별 절차입니다.

**도입 트리거 (재확인)**

아래 조건 중 하나라도 해당되면 TanStack Query 도입을 시작합니다.

- 동일 API 엔드포인트를 3개 이상의 컴포넌트가 독립적으로 호출하는 케이스 발생
- 목록 데이터의 낙관적 업데이트(Optimistic Update) 또는 자동 캐시 무효화가 필요한 기능 개발 시작

**단계별 도입 절차**

Step 1. 패키지 설치

```bash
# app/web/ 디렉터리에서 실행
pnpm add @tanstack/react-query
pnpm add -D @tanstack/react-query-devtools  # 개발 환경 전용
```

Step 2. 루트 레이아웃에 `QueryClientProvider` 추가

```typescript
// app/web/src/app/layout.tsx
'use client';
import { QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { queryClient } from '@/lib/query-client';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <QueryClientProvider client={queryClient}>
          {children}
          {process.env.NODE_ENV === 'development' && (
            <ReactQueryDevtools initialIsOpen={false} />
          )}
        </QueryClientProvider>
      </body>
    </html>
  );
}
```

Step 3. `lib/query-client.ts` 신설

```typescript
// app/web/src/lib/query-client.ts
import { QueryClient } from '@tanstack/react-query';

// QueryClient는 전역 단일 인스턴스 — 컴포넌트 내에서 new QueryClient() 금지
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,       // 1분: 데이터를 fresh로 취급하는 시간
      gcTime: 5 * 60_000,      // 5분: 캐시 유지 시간 (구 cacheTime)
      retry: 1,                 // 네트워크 에러 시 1회 재시도
      retryDelay: 1_000,
      // 4xx 에러는 재시도하지 않음
      retryOn: (failureCount, error) => {
        if (error instanceof Response && error.status >= 400 && error.status < 500) {
          return false;
        }
        return failureCount < 1;
      },
    },
  },
});
```

Step 4. 신규 기능 개발 시 TanStack Query 사용 강제

신규 클라이언트 데이터 페칭은 `useEffect + fetch` 대신 `useQuery` / `useMutation`으로 작성합니다. 기존 코드 수정 없이 새 파일에만 적용해도 됩니다.

Step 5. 기존 화면 점진 마이그레이션

도입 트리거 조건을 충족하는 화면부터 우선 마이그레이션합니다. 단순 1회 조회 화면(관리자 설정 페이지 등)은 마이그레이션하지 않아도 됩니다.

**`authFetch` 통합 예시**

```typescript
// app/web/src/features/products/hooks/use-product.ts
import { useQuery } from '@tanstack/react-query';
import { authFetch } from '@/lib/auth-client';

// authFetch가 인증 헤더 자동 주입 + 401 시 refresh → retry 담당
export function useProduct(productId: number) {
  return useQuery({
    queryKey: ['product', productId],
    queryFn: async () => {
      const res = await authFetch(`/api/v1/products/${productId}`);
      const data = await res.json();
      if (!data.success) throw new Error(data.error?.message);
      return data.data;
    },
    enabled: productId > 0,
  });
}
```

**권장 기본값 요약**

| 설정 | 권장값 | 이유 |
|------|--------|------|
| `staleTime` | `60_000` (1분) | 잦은 refetch 방지, 목록 페이지 UX 개선 |
| `gcTime` | `5 * 60_000` (5분) | 컴포넌트 언마운트 후 캐시 유지 |
| `retry` | `1` | 네트워크 불안정 대응, 과도한 재시도 방지 |
| 4xx retry | `false` | 클라이언트 오류는 재시도해도 동일한 결과 |
| SSR dehydrate | 초기에는 미사용 | 클라이언트 전용으로 시작, SSR 필요 시 별도 결정 |

**금지 사항**

- `useEffect + useState + fetch`와 TanStack Query를 같은 화면에서 동일 데이터에 혼용 금지 (데이터 소스 이중화 발생)
- 컴포넌트 내부에서 `new QueryClient()` 금지 — 전역 단일 인스턴스만 사용

**제거 시점**

모든 비(非)1회성 조회 화면이 TanStack Query로 마이그레이션 완료되면, ESLint 커스텀 룰로 `useEffect + fetch` 조합의 신규 작성을 금지합니다.

```javascript
// eslint 커스텀 룰 예시 (추후 적용)
// "no-effect-fetch": "error" — useEffect 내에서 fetch 호출 패턴 탐지
```

---

### 8-3. 전역 상태가 필요한 경우

권장 (Recommendation): 전역 상태(사용자 세션, 테마 등)가 필요해지면 **Zustand**를 우선 검토하세요. 번들 크기가 작고 보일러플레이트가 적습니다.

---

## 9. 폼 처리 표준

### 9-1. 현행 방식 — Controlled Component + Zod

현행 (Current): react-hook-form을 사용하지 않습니다. 각 입력 필드를 `useState`로 제어하는 Controlled Component 방식을 사용합니다.

```typescript
// app/web/src/app/(auth)/login/page.tsx
const [email, setEmail] = useState('');
const [password, setPassword] = useState('');
const [error, setError] = useState('');
const [loading, setLoading] = useState(false);

async function handleSubmit(e: React.FormEvent) {
  e.preventDefault();
  setError('');
  setLoading(true);
  // ...
}
```

### 9-2. 제출 흐름

```
1. e.preventDefault()로 기본 동작 차단
2. (선택) Zod safeParse로 클라이언트 검증
3. setLoading(true) — 버튼 비활성화
4. fetch / authFetch로 API 호출
5. 응답 data.success 분기
   - 성공: 라우트 이동 또는 UI 업데이트
   - 실패: setError(data.error?.message) 로 에러 표시
6. setLoading(false)
```

### 9-3. 에러 메시지 노출 컨벤션

```tsx
{error && (
  <div className="w-full mb-4 px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-xl text-sm text-red-400 text-center">
    {error}
  </div>
)}
```

- 에러 메시지는 폼 상단에 인라인 배너로 표시합니다.
- 필드별 에러는 해당 입력 아래에 `text-red-400 text-xs` 클래스로 표시합니다.
- 에러 메시지는 백엔드 응답(`data.error.message`) 또는 Zod 에러 메시지를 사용합니다.

### 9-4. 폼 라이브러리 도입 검토

권장 (Recommendation): 폼 필드 수가 5개 이상이거나, 복잡한 유효성 검증(비동기 검증, 의존 필드 등)이 필요한 경우 **React Hook Form + Zod** 조합 도입을 검토하세요.

---

## 10. 인증 흐름

### 10-1. 토큰 저장 (Architecture Decision)

현행 (Current): JWT 토큰을 `localStorage`에 저장합니다. 쿠키를 사용하지 않습니다. (CLAUDE.md 인증 방식 Architecture Decision 참조)

| 키 | 저장소 | 용도 |
|----|--------|------|
| `access_token` | `localStorage` | API 호출 인증 |
| `refresh_token` | `localStorage` | Access token 갱신 |

```typescript
// app/web/src/lib/auth-client.ts
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';

export function setTokens(accessToken: string, refreshToken: string) {
  localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
}

export function clearTokens() {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}
```

### 10-2. authFetch — 인증 래퍼

현행 (Current): `lib/auth-client.ts`의 `authFetch`는 모든 인증 fetch를 감쌉니다.

동작 순서:
1. `localStorage`에서 access token 읽어 `Authorization: Bearer <token>` 헤더 주입
2. 응답이 `401`이고 refresh token이 있으면 `/api/v1/auth/refresh` 호출
3. Refresh 성공 시 새 토큰을 저장하고 원래 요청 재시도
4. Refresh 실패 시 `clearTokens()` 호출 (세션 만료 처리)

### 10-3. 토큰 파싱

```typescript
export function getCurrentUser(): TokenPayload | null {
  const token = getAccessToken();
  if (!token) return null;
  return parseToken(token); // JWT payload base64 디코딩
}

export type TokenPayload = {
  userId: number;
  email: string;
  role: 'user' | 'admin';
};
```

### 10-4. 보호 라우트 — 이중 가드

현행 (Current): 미들웨어와 클라이언트 레이아웃의 이중 보호 전략을 사용합니다.

| 계층 | 위치 | 보호 대상 |
|------|------|---------|
| 서버 미들웨어 | `src/middleware.ts` | `/api/v1/admin/*` — Authorization 헤더 검증 + admin role 확인 |
| 클라이언트 레이아웃 | `app/(main)/admin/layout.tsx` 등 | 페이지 접근 시 토큰 확인 후 리다이렉트 |

```typescript
// src/middleware.ts — API 라우트 보호
export const config = {
  matcher: ['/api/v1/admin/:path*'],
};
```

### 10-5. OAuth 소셜 로그인

현행 (Current): NextAuth.js 5.0.0-beta.30 + Google, Apple, Kakao 제공자를 사용합니다. 소셜 로그인 후에도 동일하게 JWT를 localStorage에 저장하는 흐름을 따릅니다.

---

## 11. API 통신 규약

### 11-1. 요청/응답 JSON camelCase

API 요청·응답 JSON은 camelCase. 별도 변환 레이어 없음. snake_case는 DB 영역에서만 사용.

```typescript
// 요청 본문 — camelCase
body: JSON.stringify({ email, password })
body: JSON.stringify({ refreshToken: getRefreshToken() })
```

현행 (Current): 클라이언트 코드에서 API 응답 필드를 그대로 사용합니다 (`d.data.accessToken`, `product.imageUrl` 등).

### 11-2. API 응답 타입

현행 (Current): `src/types/api.ts`에 공통 응답 타입이 정의되어 있습니다.

```typescript
// app/web/src/types/api.ts
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

export type ApiErrorResponse = {
  success: false;
  error: {
    code: string;
    message: string;
    field?: string;
  };
};

export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;
```

모든 API 라우트의 반환 타입 주석에 `ApiResponse<T>` 제네릭을 사용하세요.

### 11-3. 에러 응답 매핑

| HTTP 상태 | error.code | 설명 |
|----------|-----------|------|
| 400 | `INVALID_PARAMETER` | 요청 파라미터 검증 실패 |
| 401 | `UNAUTHORIZED` | 인증 필요 |
| 403 | `FORBIDDEN` | 권한 없음 (admin 전용) |
| 404 | `NOT_FOUND` | 리소스 없음 |
| 429 | `RATE_LIMITED` | 요청 횟수 초과 |
| 500 | `INTERNAL_ERROR` | 서버 에러 |

### 11-4. API 라우트 경로 규칙

| 경로 패턴 | 용도 |
|----------|------|
| `/api/v1/auth/*` | 인증 (login, register, refresh, logout 등) |
| `/api/v1/users/*` | 사용자 정보 |
| `/api/v1/products/*` | 상품 조회 및 검색 |
| `/api/v1/profiles/*` | 사용자 패션 프로필 |
| `/api/v1/settings/*` | 서비스 설정 (인기 검색어 등) |
| `/api/v1/admin/*` | 관리자 전용 (미들웨어 보호) |

---

## 12. 이미지/리소스

### 12-1. Next.js Image 컴포넌트

권장 (Recommendation): 외부 이미지 및 최적화가 필요한 이미지는 `<img>` 대신 Next.js `<Image>` 컴포넌트를 사용하세요.

```tsx
import Image from 'next/image';

<Image
  src={product.imageUrl}
  alt={product.name}
  width={400}
  height={400}
  className="object-cover"
  loading="lazy"
/>
```

현행 (Current): 리뷰 카드 내 이미지는 일반 `<img>` 태그를 사용합니다. 점진적으로 `<Image>`로 교체하는 것을 권장합니다.

### 12-2. 외부 도메인 등록

**현행 (Current):** `next.config.ts`에 `images` 설정 없음 (도메인 외부 이미지 미사용 또는 unoptimized 상태).

**권장 (Recommendation):** 외부 도메인 이미지를 `<Image>` 컴포넌트로 사용할 경우 `next.config.ts`의 `images.remotePatterns`에 도메인을 등록하세요.

```typescript
// next.config.ts
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '*.kakaocdn.net' },
      { protocol: 'https', hostname: '*.zigzag.kr' },
      // 크롤링 대상 쇼핑몰 CDN 도메인 추가
    ],
  },
};
```

### 12-3. SVG 처리

- 단순 아이콘: JSX 인라인 SVG로 작성합니다 (현행 패턴).
- 반복 사용 아이콘: `components/icons/` 디렉터리에 SVG 컴포넌트로 추출합니다.
- 외부 SVG 에셋: `public/` 디렉터리에 저장하고 경로로 참조합니다.

### 12-4. 정적 에셋

`public/` 디렉터리에 위치하며 `/` 경로로 접근합니다. `public/images/`, `public/icons/` 등 용도별 하위 폴더를 사용합니다.

---

## 13. 국제화/접근성

### 13-1. 국제화 (i18n)

현행 (Current): 단일 언어(한국어) 서비스입니다. i18n 라이브러리를 사용하지 않습니다.

권장 (Recommendation): 향후 다국어 지원이 필요해지면 **next-intl**을 도입하세요. 현재부터 UI 문자열을 컴포넌트에 하드코딩하는 것은 허용하되, 추후 추출이 쉽도록 문자열을 인라인 리터럴로 명확히 작성하세요.

```typescript
// 루트 layout.tsx — 현재 한국어 고정
<html lang="ko">
```

### 13-2. 접근성 (Accessibility)

목표: WCAG 2.1 AA 준수

| 항목 | 기준 | 적용 방법 |
|------|------|---------|
| 시맨틱 HTML | 의미론적 태그 사용 | `<header>`, `<main>`, `<nav>`, `<button>`, `<form>`, `<label>` |
| 색상 대비 | 텍스트 4.5:1, 대형 텍스트 3:1 | gray-400(`#9ca3af`) on black — 현행 확인 필요 |
| 키보드 내비게이션 | 모든 인터랙티브 요소 Tab 접근 가능 | `<button>` 대신 `<div onClick>` 사용 금지 |
| 포커스 인디케이터 | 시각적으로 명확한 포커스 표시 | Tailwind `focus:outline-none` 단독 사용 금지 (`focus-visible:` 활용) |
| alt 텍스트 | 이미지에 의미 있는 alt 제공 | `<Image alt={product.name}>` |
| ARIA | 필요한 경우 aria-* 속성 추가 | 동적 콘텐츠(`aria-live`), 모달(`aria-modal`, `role="dialog"`) |
| 에러 메시지 | 스크린 리더에서 인식 가능 | `role="alert"` 또는 `aria-live="polite"` 사용 |

```tsx
// 에러 배너 접근성 예시
{error && (
  <div role="alert" className="...">
    {error}
  </div>
)}
```

---

## 14. 성능 표준

### 14-1. 코드 분할

현행 (Current): Next.js App Router가 라우트 단위로 자동 코드 분할을 수행합니다.

권장 (Recommendation): 무거운 클라이언트 컴포넌트(차트, 에디터 등)는 `next/dynamic`으로 지연 로딩하세요.

```typescript
import dynamic from 'next/dynamic';

const AdminChart = dynamic(() => import('@/features/admin/components/AdminChart'), {
  loading: () => <div className="h-64 bg-[#1a1a1a] animate-pulse rounded-xl" />,
  ssr: false,
});
```

### 14-2. 이미지 최적화

- Next.js `<Image>` 컴포넌트로 자동 WebP 변환, lazy loading, 사이즈 최적화를 활용합니다.
- `priority` prop은 LCP(Largest Contentful Paint) 대상 이미지(히어로, 대표 상품 이미지)에만 적용합니다.

### 14-3. 메모이제이션

| 도구 | 사용 시점 |
|------|---------|
| `React.memo` | 부모 리렌더링 시 불필요하게 재렌더링되는 순수 컴포넌트 |
| `useMemo` | 비용이 큰 계산 결과 캐싱 (목록 필터링, 집계 등) |
| `useCallback` | 자식 컴포넌트에 전달하는 콜백 함수 안정화 |

과도한 메모이제이션은 오히려 성능을 저하시킵니다. 프로파일링으로 실제 병목을 확인한 후 적용하세요.

### 14-4. 가상화

권장 (Recommendation): 리뷰 목록처럼 100개 이상의 아이템을 렌더링하는 경우 **react-virtual** 또는 **@tanstack/react-virtual**로 가상 스크롤(Virtualization)을 적용하세요.

### 14-5. 번들 분석

권장 (Recommendation): `@next/bundle-analyzer`를 개발 의존성으로 설치하고, 번들 크기 증가 시 주기적으로 분석하세요.

```bash
ANALYZE=true pnpm build
```

### 14-6. Core Web Vitals 목표

| 지표 | 목표 | 설명 |
|------|------|------|
| LCP | < 2.5s | Largest Contentful Paint — 주요 콘텐츠 로딩 |
| INP | < 200ms | Interaction to Next Paint — 인터랙션 응답성 |
| CLS | < 0.1 | Cumulative Layout Shift — 레이아웃 안정성 |

---

## 15. 테스트 표준 (Playwright)

### 15-1. 테스트 위치

현행 (Current): Playwright는 크롤러(`features/crawlers/`)와 E2E 테스트 겸용으로 사용됩니다. 별도의 전용 테스트 디렉터리는 현재 미확인 상태입니다.

권장 (Recommendation): E2E 테스트는 `app/web/e2e/` 디렉터리에 위치시키고, `playwright.config.ts`를 `app/web/` 루트에 작성하세요.

```
app/web/
├── e2e/                      # E2E 테스트 (권장 위치)
│   ├── auth.spec.ts          # 인증 흐름 테스트
│   ├── search.spec.ts        # 검색 기능 테스트
│   ├── product-detail.spec.ts
│   └── fixtures/
│       └── auth.json         # storageState (인증 상태 저장)
└── playwright.config.ts
```

### 15-2. 시나리오 작성 컨벤션

권장 (Recommendation): 페이지 객체 패턴(Page Object Model)을 사용하여 테스트 유지보수성을 높이세요.

```typescript
// e2e/pages/search-page.ts
export class SearchPage {
  constructor(private readonly page: Page) {}

  async goto() {
    await this.page.goto('/');
  }

  async search(keyword: string) {
    await this.page.fill('input[type="search"]', keyword);
    await this.page.press('input[type="search"]', 'Enter');
  }

  async getResultCount() {
    return this.page.locator('[data-testid="search-result-item"]').count();
  }
}
```

### 15-3. 인증이 필요한 시나리오

Playwright의 `storageState`를 활용하여 로그인 상태를 재사용합니다.

```typescript
// e2e/fixtures/auth.setup.ts
test('로그인 상태 저장', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[type="email"]', process.env.TEST_EMAIL!);
  await page.fill('input[type="password"]', process.env.TEST_PASSWORD!);
  await page.click('button[type="submit"]');
  await page.waitForURL('/');
  await page.context().storageState({ path: 'e2e/fixtures/auth.json' });
});

// playwright.config.ts
use: {
  storageState: 'e2e/fixtures/auth.json',
}
```

### 15-4. 테스트 참조

**frontend-tester** 멤버는 이 문서의 15절을 참조하여 E2E 테스트 시나리오를 작성하고, Playwright를 실행합니다. 인증 흐름, 검색, 상품 상세, 관리자 기능이 주요 테스트 대상입니다.

---

## 16. 로깅/모니터링

### 16-1. 클라이언트 에러 추적

현행 (Current): 클라이언트 에러 추적 라이브러리는 감지되지 않습니다. 서버 사이드는 `services/logger/`와 Slack 알림을 사용합니다.

권장 (Recommendation): 프로덕션 환경에서 클라이언트 에러 추적을 위해 **Sentry**를 도입하세요.

```bash
pnpm add @sentry/nextjs
```

```typescript
// sentry.client.config.ts
import * as Sentry from "@sentry/nextjs";
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
});
```

### 16-2. console 사용 금지

현행 (Current): CLAUDE.md에서 `console.log` 직접 사용을 금지합니다. 서버 코드는 `services/logger/`를 사용합니다.

| 환경 | 허용 |
|------|------|
| 개발 중 디버깅 | `console.log` 임시 허용 (커밋 전 반드시 제거) |
| 프로덕션 코드 | `console.log`, `console.error` 직접 사용 금지 |
| 서버 코드 | `services/logger/` 전용 로거 사용 |
| 클라이언트 에러 | Sentry(권장) 또는 별도 에러 핸들러 |

---

## 17. 빌드/배포

### 17-1. 개발 명령어

| 명령어 | 설명 |
|--------|------|
| `pnpm dev` | Turbopack으로 개발 서버 실행 |
| `pnpm build` | 프로덕션 빌드 (`output: 'standalone'`) |
| `pnpm start` | 프로덕션 빌드 실행 |
| `pnpm lint` | ESLint 실행 |

작업 디렉터리: `app/web/`

```bash
cd app/web
pnpm dev     # 개발 서버
pnpm build   # 빌드 (타입 체크 포함)
```

### 17-2. 빌드 전 체크 (필수)

현행 (Current): CLAUDE.md 워크플로 룰에 따라 **git push 전 `pnpm build`를 로컬에서 반드시 실행**합니다.

```bash
# 반드시 app/web/ 디렉터리에서 실행
pnpm build

# 빌드 성공 확인 후 push
git push
```

TypeScript 에러, import 오류, 서버/클라이언트 경계 위반은 빌드 시 감지됩니다.

### 17-3. 환경 변수

| 접두사 | 노출 대상 | 예시 |
|--------|---------|------|
| `NEXT_PUBLIC_` | 브라우저(클라이언트) | `NEXT_PUBLIC_SENTRY_DSN` |
| (없음) | 서버 전용 | `JWT_SECRET`, `DATABASE_URL`, `OPENAI_API_KEY` |

클라이언트에 노출되면 안 되는 값에 `NEXT_PUBLIC_` 접두사를 붙이지 마세요.

### 17-4. 빌드 출력

현행 (Current): `output: 'standalone'`으로 설정되어 있습니다. `.next/standalone/`에 최소 런타임만 포함된 독립 실행 가능한 빌드가 생성됩니다. Docker 기반 배포에 적합합니다.

배포 세부 흐름은 `docs/infra/ci-cd-standards.md`를 참조하세요.

---

## 18. 컨벤션

### 18-1. TypeScript 규칙

| 규칙 | 상세 |
|------|------|
| strict mode | `tsconfig.json`의 `"strict": true` — 반드시 준수 |
| `any` 금지 | `any` 타입 사용 절대 금지 (CLAUDE.md) |
| `// @ts-ignore` 금지 | `// @ts-expect-error` + 사유 주석은 허용 |
| `type` 우선 | `interface` 대신 `type` 사용 |
| `enum` 금지 | 문자열 리터럴 유니온 사용 |
| 반환 타입 | 복잡한 함수는 반환 타입 명시 권장 |
| `null` vs `undefined` | 명시적 구분. API 응답의 `null`은 `null`로 유지 |

```typescript
// 금지
type Status = 'active' | 'inactive';  // OK
enum Status { Active = 'active', Inactive = 'inactive' }  // 금지

// 허용
// @ts-expect-error — 외부 라이브러리 타입 불일치 (이슈 #123 해결 전 임시)
const result = externalLib.method();
```

### 18-2. 명명 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 변수, 함수 | camelCase | `accessToken`, `authFetch`, `handleSubmit` |
| 컴포넌트, 클래스, 타입 | PascalCase | `ReviewCard`, `ApiResponse`, `TokenPayload` |
| 상수 | SCREAMING_SNAKE_CASE (선택) 또는 camelCase | `ACCESS_TOKEN_KEY`, `MAX_RETRY_COUNT` |
| 파일명 | kebab-case | `auth-client.ts`, `review-card.tsx` |
| 디렉터리명 | kebab-case | `ai-processing/`, `rate-limit/` |
| DB 컬럼/테이블 | snake_case | `user_id`, `created_at`, `users` |
| API 요청/응답 | camelCase | `accessToken`, `refreshToken` |
| TypeScript 코드 | camelCase | `accessToken`, `refreshToken` |

### 18-3. import 순서 (권장)

```typescript
// 1. Node.js 내장 모듈
import path from 'path';

// 2. 외부 패키지 (node_modules)
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

// 3. @/services — 서버 싱글턴
import { db } from '@/services/db';

// 4. @/lib — 유틸리티
import { authFetch, clearTokens } from '@/lib/auth-client';
import { productSearchSchema } from '@/lib/validators';

// 5. @/components — 전역 컴포넌트
import Header from '@/components/Header';

// 6. @/features — 기능 모듈
import ReviewCard from '@/features/reviews/components/ReviewCard';

// 7. @/types — 타입
import type { ApiResponse } from '@/types/api';

// 8. 상대 경로
import './styles.css';
```

### 18-4. import alias

현행 (Current): `tsconfig.json`의 `paths` 설정으로 `@/*`가 `src/*`로 매핑됩니다.

```typescript
// 올바른 import (alias 사용)
import { authFetch } from '@/lib/auth-client';
import Header from '@/components/Header';

// 금지 (상대 경로 장거리 이동)
import { authFetch } from '../../../lib/auth-client';
```

`src/` 하위 어디서든 `@/`로 절대 경로 참조를 사용하세요. 동일 디렉터리 또는 인접 파일 참조는 상대 경로(`./`, `../`)도 허용합니다.

### 18-5. 절대 금지 목록

| 금지 사항 | 대안 |
|---------|------|
| `any` 타입 | 구체적 타입 또는 `unknown` 후 타입 가드 |
| `// @ts-ignore` | `// @ts-expect-error` + 사유 주석 |
| `console.log` (프로덕션) | 서버: `services/logger/`, 클라이언트: Sentry(권장) |
| `enum` | 문자열 리터럴 유니온 |
| `interface` 대신 남용 | `type` 우선 |
| `<img>` (외부 이미지) | `<Image>` from `next/image` |
| 서버 패키지 클라이언트 import | 클라이언트 컴포넌트에서 `services/`, `drizzle`, `ioredis` import 금지 |
| 하드코딩된 토큰/비밀값 | 환경 변수 사용 |
| 쿠키에 JWT 저장 | `localStorage` 사용 (Architecture Decision) |

---

*최종 업데이트: 2026-05-26*

*이 문서는 코드베이스의 현행 패턴과 팀의 권장 사항을 반영한 단일 참조 문서입니다. 변경 사항은 CHANGELOG.md에 기록하세요.*
