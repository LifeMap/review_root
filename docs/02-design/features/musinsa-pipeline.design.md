# Design: musinsa-pipeline

> 무신사 데이터 파이프라인 테스트 스크립트 상세 설계

## 1. Design Overview

| Item | Description |
|------|-------------|
| Feature | musinsa-pipeline |
| Plan Reference | [musinsa-pipeline.plan.md](../../01-plan/features/musinsa-pipeline.plan.md) |
| Created | 2026-02-03 |
| Status | Design |

## 2. Architecture

### 2.1 Pipeline Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                    test-musinsa-crawl.ts                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │   Step 1    │    │   Step 2    │    │   Step 3    │          │
│  │ Discover    │───▶│ Crawl +     │───▶│ AI Analyze  │          │
│  │ Products    │    │ Save DB     │    │ (Parallel)  │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
│        │                  │                  │                   │
│        ▼                  ▼                  ▼                   │
│   Playwright         Playwright        OpenAI API               │
│   (headless)         (headless)        gpt-4o-mini              │
│                                                                  │
│                           ┌─────────────┐                        │
│                           │   Step 4    │                        │
│                           │ Generate    │                        │
│                           │ Summaries   │                        │
│                           └─────────────┘                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Scripts Layer                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              test-musinsa-crawl.ts (NEW)                │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Features Layer                            │
│  ┌──────────────────────┐  ┌────────────────────────────────┐   │
│  │ crawlers/platforms/  │  │  ai-processing/analyzer.ts     │   │
│  │   musinsa.ts         │  │  - analyzeReviews()            │   │
│  │   - discoverProducts │  │  - calculateDisadvantageScore() │   │
│  │   - crawlReviews     │  └────────────────────────────────┘   │
│  └──────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Services Layer                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   db/schema.ts                           │    │
│  │  - products, productPlatformMappings, platforms          │    │
│  │  - reviews, reviewAnalyses, reviewKeywords               │    │
│  │  - productSummaries, sizeInsights                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Technical Specifications

### 3.1 Environment Variables

```typescript
// .env.local
MAX_MUSINSA_PRODUCTS=5      // 수집할 상품 수
AI_PARALLEL_BATCHES=3       // AI 병렬 처리 수 (공통)
```

### 3.2 Constants

```typescript
const MAX_PRODUCTS = Number(process.env.MAX_MUSINSA_PRODUCTS) || 5;
const AI_BATCH_SIZE = 15;  // 29cm와 동일
const AI_PARALLEL_BATCHES = Number(process.env.AI_PARALLEL_BATCHES) || 3;
```

### 3.3 Database Connection

```typescript
import { drizzle } from 'drizzle-orm/mysql2';
import mysql from 'mysql2/promise';

const DATABASE_URL =
  process.env.DATABASE_URL ??
  'mysql://review_user:review_password@localhost:3306/review_service';

const pool = mysql.createPool({
  uri: DATABASE_URL,
  waitForConnections: true,
  connectionLimit: 5,
});
const db = drizzle(pool, { mode: 'default' });
```

## 4. Implementation Details

### 4.1 Step 1: Discover Products (Playwright)

**MusinsaCrawler.discoverProducts()** 호출

```typescript
// 기존 크롤러 사용
import { MusinsaCrawler } from '@/features/crawlers/platforms/musinsa';

const crawler = new MusinsaCrawler();

// discoverProducts()는 최대 50개 상품 반환
// MAX_PRODUCTS로 슬라이싱
const allProducts = await crawler.discoverProducts();
const discovered = allProducts.slice(0, MAX_PRODUCTS);
```

**주요 차이점 (vs 29cm)**:
- 29cm: `TwentynineCmCrawler({ maxProducts: MAX_PRODUCTS })` 생성자 옵션
- Musinsa: `discoverProducts()`가 50개 고정 반환 → 슬라이싱 필요

### 4.2 Step 2: Crawl Reviews + DB Save

```typescript
for (const p of discovered) {
  // 1. products 테이블 저장/업데이트
  // 2. product_platform_mappings 저장/업데이트
  // 3. crawlReviews() 호출 (Playwright)
  // 4. reviews 테이블 저장 (중복 제외)
}
```

**Musinsa 크롤러 특징**:
- `crawlReviews(externalProductId)`: 상품당 최대 500개 리뷰
- 페이지네이션: 최대 10페이지
- delay: 페이지 간 2초 대기
- 추가 정보: `reviewerHeight`, `reviewerWeight`, `sizeFeedback`

### 4.3 Step 3: AI Analysis (Parallel Processing)

29cm 파이프라인과 **동일한 로직** 사용:

```typescript
// 1. 전체 배치 준비
type BatchData = {
  batchIndex: number;
  reviewRows: { id: number; content: string; rating: number; platformId: number; productId: number }[];
};

// 2. 배치 그룹화 (AI_PARALLEL_BATCHES개씩)
const batchGroups = chunkArray(allBatches, AI_PARALLEL_BATCHES);

// 3. Promise.all() 병렬 실행
for (const group of batchGroups) {
  const groupResults = await Promise.all(
    group.map(async (batch) => {
      const results = await analyzeReviews(input);
      return { batchIndex, reviewRows, results };
    })
  );

  // 4. DB 저장 (순차)
  for (const { reviewRows, results } of groupResults) {
    // review_analyses, review_keywords 저장
  }
}
```

### 4.4 Step 4: Generate Summaries

29cm 파이프라인과 **동일한 로직** 사용:

```typescript
for (const { productId } of productMap) {
  // 1. product_summaries 생성/업데이트
  //    - prosTop3, consTop3 (키워드 집계)
  //    - totalReviewCount, sponsoredCount, genuineCount
  //    - averageDisadvantageScore

  // 2. size_insights 생성
  //    - 사이즈별 구매 비율
  //    - fit 피드백 (small/perfect/large)
  //    - 평균 키/몸무게

  // 3. products.totalReviewCount 업데이트
}
```

## 5. Type Definitions

### 5.1 CrawledProduct (from musinsa.ts)

```typescript
interface CrawledProduct {
  externalId: string;
  name: string;
  brand: string;
  category: string;
  imageUrl: string | null;
  url: string;
  price: number | null;
  originalPrice: number | null;
}
```

### 5.2 CrawledReview (from musinsa.ts)

```typescript
interface CrawledReview {
  externalReviewId: string;
  reviewerName: string;
  content: string;
  rating: number;
  purchaseOption: string | null;
  imageUrls: string[];
  reviewerHeight: number | null;
  reviewerWeight: number | null;
  sizeFeedback: 'small' | 'perfect' | 'large' | null;
  reviewedAt: Date;
}
```

### 5.3 BatchData / BatchResult

```typescript
type BatchData = {
  batchIndex: number;
  reviewRows: {
    id: number;
    content: string;
    rating: number;
    platformId: number;
    productId: number;
  }[];
};

type BatchResult = {
  batchIndex: number;
  reviewRows: BatchData['reviewRows'];
  results: Awaited<ReturnType<typeof analyzeReviews>>;
  error?: string;
};
```

## 6. Error Handling

### 6.1 Playwright Errors

```typescript
// discoverProducts() - 브라우저 자동 종료
try {
  const page = await browser.newPage();
  // ... 크롤링 로직
} finally {
  await browser.close();
}

// crawlReviews() - 동일 패턴
```

### 6.2 AI Analysis Errors

```typescript
// 배치 단위 에러 핸들링
try {
  const results = await analyzeReviews(input);
  return { batchIndex, reviewRows, results };
} catch (error) {
  console.error(`❌ 배치 ${batchIndex + 1} 실패:`, error);
  return { batchIndex, reviewRows, results: [], error: String(error) };
}

// null 체크
const advantageKeywords = result.advantageKeywords ?? [];
const disadvantageKeywords = result.disadvantageKeywords ?? [];
```

## 7. Prerequisites

### 7.1 platforms 테이블

```sql
-- musinsa 레코드 필요
SELECT id, code FROM platforms WHERE code = 'musinsa';

-- 없으면 생성
INSERT INTO platforms (code, name) VALUES ('musinsa', '무신사');
```

### 7.2 Dependencies

```bash
# Playwright 설치 확인
npx playwright install chromium
```

## 8. Implementation Checklist

| # | Task | File | Line Reference |
|---|------|------|----------------|
| 1 | 스크립트 파일 생성 | `web/scripts/test-musinsa-crawl.ts` | - |
| 2 | imports 설정 | - | Line 1-31 (29cm 참조) |
| 3 | 환경변수 설정 | - | `MAX_MUSINSA_PRODUCTS` |
| 4 | chunkArray 유틸 | - | Line 48-55 (29cm 참조) |
| 5 | main() 함수 구조 | - | Line 57-401 (29cm 참조) |
| 6 | platform 확인 로직 | - | `musinsa` 코드 사용 |
| 7 | Step 1: discoverProducts | - | MusinsaCrawler 사용 |
| 8 | Step 2: crawlReviews + DB | - | 29cm와 동일 |
| 9 | Step 3: AI 분석 (병렬) | - | 29cm와 동일 |
| 10 | Step 4: 요약 생성 | - | 29cm와 동일 |

## 9. Expected Output

```
=== 무신사 데이터 파이프라인 테스트 ===

플랫폼: musinsa (id=2)

[1/4] 베스트 상품 Top 5 수집 중...
  → 5개 상품 발견

[2/4] 상품 & 리뷰 DB 저장 중...
  #12345 | 브랜드명 | 상품명
     상품: 신규 등록 (productId=21)
     리뷰: 150개 크롤링 → 150개 신규 저장
  ...

  총 신규 리뷰: 500개

[3/4] AI 리뷰 분석 중 (OpenAI gpt-4o-mini, 병렬 3개)...
  총 34개 배치 준비 완료
  병렬 처리 중: 배치 1~3/34...
  ...
  → 500개 리뷰 AI 분석 완료

[4/4] 상품별 요약 생성 중...
  📦 브랜드명 - 상품명 (productId=21)
     분석: 100건 (광고 2건) | 장점: 핏, 소재 | 단점: 배송
     사이즈: 5종 | 단점점수 평균: 2.5
  ...

=== 파이프라인 완료 ===
상품: 5개 | 리뷰: 500개 | AI분석: 500개
```

## 10. Performance Expectations

| Metric | 29cm (API) | Musinsa (Playwright) |
|--------|------------|----------------------|
| 상품 수집 | ~1초 | ~10초 |
| 리뷰 수집 (상품당) | ~5초 | ~30-60초 |
| AI 분석 | ~1초/리뷰 | ~1초/리뷰 (동일) |
| **총 예상 시간 (5상품)** | ~3분 | ~10-15분 |

## 11. References

- [test-29cm-crawl.ts](../../web/scripts/test-29cm-crawl.ts) - 구조 참조
- [musinsa.ts](../../web/src/features/crawlers/platforms/musinsa.ts) - 크롤러
- [analyzer.ts](../../web/src/features/ai-processing/analyzer.ts) - AI 분석
