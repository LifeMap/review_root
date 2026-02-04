# Design: parallel-ai-processing

> Plan Reference: [parallel-ai-processing.plan.md](../../01-plan/features/parallel-ai-processing.plan.md)

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Parallel AI Processing Flow                       │
└─────────────────────────────────────────────────────────────────────┘

Input: allNewReviewIds (e.g., 324개)
         │
         ▼
┌─────────────────────────────────────┐
│  Split into batches (15개씩)         │
│  → 22 batches                       │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Group batches by PARALLEL_COUNT    │
│  → 8 groups (3개씩, 마지막 1개)       │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  For each group: Promise.all()                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │ Batch 1  │  │ Batch 2  │  │ Batch 3  │  → 동시 처리           │
│  │ OpenAI   │  │ OpenAI   │  │ OpenAI   │                       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                       │
│       └─────────────┴─────────────┘                             │
│                     │                                            │
│                     ▼                                            │
│              DB 저장 (순차)                                       │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
Output: 324개 review_analyses, review_keywords 저장
```

## 2. Data Structures

### 2.1 Environment Variables

```typescript
// .env.local
AI_PARALLEL_BATCHES=3  // 동시 처리 배치 수 (1-5)
AI_BATCH_SIZE=15       // 배치당 리뷰 수
```

### 2.2 Type Definitions

```typescript
// 기존 타입 (변경 없음)
type AnalysisResult = {
  isSponsored: boolean;
  sponsoredConfidence: number;
  advantageKeywords: string[];
  disadvantageKeywords: string[];
  sentimentScore: number;
  sizeFeedback: 'small' | 'perfect' | 'large' | null;
  summary: string;
};

// 새로운 타입
type BatchInput = {
  batchIndex: number;
  reviews: { id: number; content: string; rating: number; platform: string }[];
};

type BatchResult = {
  batchIndex: number;
  results: AnalysisResult[];
  error?: string;
};
```

## 3. API/Function Specifications

### 3.1 Utility Functions

#### `chunkArray<T>(array: T[], size: number): T[][]`

배열을 지정된 크기로 분할합니다.

```typescript
// Input
chunkArray([1,2,3,4,5,6,7], 3)

// Output
[[1,2,3], [4,5,6], [7]]
```

### 3.2 Core Function Changes

#### 현재: Step 3 AI 분석 (순차)

```typescript
// 현재 코드 (test-29cm-crawl.ts:166-224)
for (let i = 0; i < allNewReviewIds.length; i += AI_BATCH_SIZE) {
  const batchIds = allNewReviewIds.slice(i, i + AI_BATCH_SIZE);
  // ... fetch reviews
  const results = await analyzeReviews(input);  // ← 순차 대기
  // ... save to DB
}
```

#### 개선: Step 3 AI 분석 (병렬)

```typescript
// 개선된 코드
const AI_PARALLEL_BATCHES = Number(process.env.AI_PARALLEL_BATCHES) || 3;

// 1. 전체 배치 준비
const allBatches: BatchInput[] = [];
for (let i = 0; i < allNewReviewIds.length; i += AI_BATCH_SIZE) {
  const batchIds = allNewReviewIds.slice(i, i + AI_BATCH_SIZE);
  const reviewRows = await fetchReviews(batchIds);
  allBatches.push({
    batchIndex: allBatches.length,
    reviews: reviewRows.map(r => ({
      id: r.id,
      content: r.content,
      rating: r.rating,
      platform: platformCodeMap.get(r.platformId) || 'unknown',
    })),
  });
}

// 2. 배치 그룹화 및 병렬 처리
const batchGroups = chunkArray(allBatches, AI_PARALLEL_BATCHES);

for (const group of batchGroups) {
  console.log(`  병렬 처리 중: 배치 ${group[0].batchIndex + 1}~${group[group.length - 1].batchIndex + 1}...`);

  // 병렬 실행
  const groupResults = await Promise.all(
    group.map(async (batch): Promise<BatchResult> => {
      try {
        const results = await analyzeReviews(batch.reviews);
        return { batchIndex: batch.batchIndex, results };
      } catch (error) {
        console.error(`  배치 ${batch.batchIndex + 1} 실패:`, error);
        return { batchIndex: batch.batchIndex, results: [], error: String(error) };
      }
    })
  );

  // 3. 결과 DB 저장 (순차 - 트랜잭션 안정성)
  for (const { batchIndex, results, error } of groupResults) {
    if (error) continue;
    const batch = allBatches[batchIndex];
    for (let j = 0; j < batch.reviews.length; j++) {
      const review = batch.reviews[j];
      const result = results[j];
      if (!result) continue;
      // ... save to review_analyses, review_keywords
    }
  }
}
```

## 4. Implementation Checklist

### 4.1 Files to Modify

| File | Changes |
|------|---------|
| `web/.env.local` | `AI_PARALLEL_BATCHES=3` 추가 |
| `web/scripts/test-29cm-crawl.ts` | Step 3 병렬 처리 로직 적용 |

### 4.2 Step-by-Step Implementation

```
[ ] 1. 환경변수 추가
    - .env.local에 AI_PARALLEL_BATCHES=3 추가

[ ] 2. chunkArray 유틸 함수 추가
    - test-29cm-crawl.ts 상단에 추가

[ ] 3. Step 3 리팩토링
    - 배치 준비 로직 분리
    - Promise.all 병렬 처리 적용
    - 에러 핸들링 추가

[ ] 4. 로그 개선
    - 병렬 처리 진행 상황 출력
    - 실패 배치 표시

[ ] 5. 테스트
    - 324개 리뷰 처리 시간 측정
    - 결과 정확성 검증
```

## 5. Error Handling

### 5.1 Individual Batch Failure

```typescript
// 개별 배치 실패 시 다른 배치에 영향 없음
const groupResults = await Promise.all(
  group.map(async (batch) => {
    try {
      const results = await analyzeReviews(batch.reviews);
      return { batchIndex: batch.batchIndex, results, success: true };
    } catch (error) {
      // 실패 로그만 기록하고 계속 진행
      console.error(`배치 ${batch.batchIndex + 1} 실패: ${error}`);
      return { batchIndex: batch.batchIndex, results: [], success: false };
    }
  })
);

// 실패한 배치 수 집계
const failedCount = groupResults.filter(r => !r.success).length;
if (failedCount > 0) {
  console.warn(`  ⚠️ ${failedCount}개 배치 실패`);
}
```

### 5.2 Rate Limit Handling

```typescript
// OpenAI 429 에러 시 재시도
async function analyzeWithRetry(reviews: any[], retries = 3): Promise<AnalysisResult[]> {
  for (let i = 0; i < retries; i++) {
    try {
      return await analyzeReviews(reviews);
    } catch (error: any) {
      if (error?.status === 429 && i < retries - 1) {
        const delay = Math.pow(2, i) * 1000; // exponential backoff
        console.log(`  Rate limit hit, waiting ${delay}ms...`);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      throw error;
    }
  }
  throw new Error('Max retries exceeded');
}
```

## 6. Performance Expectations

### 6.1 Time Estimation

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| 배치 수 | 22 | 22 | - |
| 동시 처리 | 1 | 3 | 3x |
| 배치당 시간 | ~25초 | ~25초 | - |
| 총 그룹 수 | 22 | 8 | - |
| **예상 총 시간** | **550초** | **200초** | **2.75x** |

### 6.2 Resource Usage

| Resource | Before | After | Note |
|----------|--------|-------|------|
| Memory | ~50MB | ~100MB | 동시 응답 버퍼링 |
| Network | 순차 | 병렬 3x | 대역폭 증가 |
| DB Connections | 1 | 1 | 저장은 순차 |

## 7. Testing Strategy

### 7.1 Functional Test

```bash
# 기본 테스트 (5개 상품)
cd web && export $(grep -v '^#' .env.local | xargs) && \
  time node_modules/.bin/tsx scripts/test-29cm-crawl.ts
```

### 7.2 Verification Points

| Check | Expected | Command |
|-------|----------|---------|
| 처리 시간 | < 4분 | `time` 명령어 |
| 분석 완료 수 | = 리뷰 수 | 로그 확인 |
| DB 저장 | 정상 | MySQL 쿼리 |

```sql
-- 분석 결과 확인
SELECT COUNT(*) FROM review_analyses;
SELECT COUNT(*) FROM review_keywords;
```

## 8. Rollback Plan

병렬 처리에 문제 발생 시:

```typescript
// .env.local에서 병렬 수를 1로 설정하면 기존과 동일
AI_PARALLEL_BATCHES=1
```

## 9. Dependencies

- 신규 패키지 설치 불필요
- 기존 `analyzeReviews()` 함수 변경 없음
- 테스트 스크립트만 수정
