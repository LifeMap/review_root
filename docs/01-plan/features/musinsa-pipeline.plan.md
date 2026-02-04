# Plan: musinsa-pipeline

> 무신사 데이터 파이프라인 테스트 스크립트 구현

## 1. Overview

| Item | Description |
|------|-------------|
| Feature | musinsa-pipeline |
| Type | New Feature |
| Priority | High |
| Created | 2026-02-03 |

## 2. Background

### 2.1 Current State
- 29cm 데이터 파이프라인 테스트 스크립트 완성 (`test-29cm-crawl.ts`)
- 무신사 크롤러 구현 완료 (`musinsa.ts`) - Playwright 기반
- 무신사 테스트 스크립트 미존재

### 2.2 Problem
- 무신사 크롤러를 테스트할 스크립트가 없음
- 29cm와 동일한 파이프라인 구조로 통합 테스트 필요
- Playwright 기반 크롤링의 안정성 검증 필요

## 3. Goals

### 3.1 Primary Goals
1. 무신사 데이터 파이프라인 테스트 스크립트 구현 (`test-musinsa-crawl.ts`)
2. 29cm 파이프라인과 동일한 4단계 구조 적용
3. 환경변수 `MAX_MUSINSA_PRODUCTS` 지원

### 3.2 Success Criteria
| Metric | Target |
|--------|--------|
| 스크립트 실행 | 에러 없이 완료 |
| 상품 수집 | MAX_MUSINSA_PRODUCTS 개수 |
| 리뷰 수집 | 상품당 최대 500개 |
| AI 분석 | 병렬 처리 (AI_PARALLEL_BATCHES) |
| DB 저장 | products, reviews, review_analyses 테이블 |

## 4. Technical Approach

### 4.1 Pipeline Structure

```
Step 1: 베스트 상품 수집 (Playwright)
  ↓
Step 2: 상품별 리뷰 크롤링 + DB 저장
  ↓
Step 3: AI 분석 (OpenAI gpt-4o-mini, 병렬 처리)
  ↓
Step 4: 요약 생성 (product_summaries, size_insights)
```

### 4.2 Key Differences from 29cm

| Item | 29cm | Musinsa |
|------|------|---------|
| 상품 수집 | REST API | Playwright 웹 스크래핑 |
| 리뷰 수집 | REST API | Playwright 웹 스크래핑 |
| 속도 | ~1초/상품 | ~5-10초/상품 |
| 안정성 | 높음 | DOM 변경에 취약 |

### 4.3 Environment Variables
```bash
MAX_MUSINSA_PRODUCTS=5    # 수집할 상품 수
AI_PARALLEL_BATCHES=3     # AI 병렬 처리 수 (공통)
```

## 5. Implementation Plan

### 5.1 Files to Create
- `web/scripts/test-musinsa-crawl.ts`

### 5.2 Files to Reference
- `web/scripts/test-29cm-crawl.ts` (구조 참조)
- `web/src/features/crawlers/platforms/musinsa.ts` (크롤러)

### 5.3 Implementation Order
1. 테스트 스크립트 기본 구조 생성
2. Step 1: discoverProducts() 연동
3. Step 2: crawlReviews() + DB 저장 로직
4. Step 3: AI 분석 (병렬 처리 - 29cm와 동일)
5. Step 4: 요약 생성 (29cm와 동일)
6. platforms 테이블 musinsa 레코드 확인

## 6. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DOM 구조 변경 | 크롤링 실패 | 셀렉터 fallback 처리, 에러 핸들링 |
| Playwright 타임아웃 | 테스트 실패 | 타임아웃 값 조정, 재시도 로직 |
| 무신사 IP 차단 | 크롤링 불가 | delay 증가, 요청 빈도 조절 |

## 7. Timeline

| Phase | Task | Status |
|-------|------|--------|
| Plan | 계획 문서 작성 | ✅ 완료 |
| Design | 상세 설계 문서 | ⏳ 대기 |
| Do | 구현 | ⏳ 대기 |
| Check | Gap 분석 | ⏳ 대기 |
| Report | 완료 보고서 | ⏳ 대기 |

## 8. References

- [29cm Pipeline Test Script](../../web/scripts/test-29cm-crawl.ts)
- [Musinsa Crawler](../../web/src/features/crawlers/platforms/musinsa.ts)
- [parallel-ai-processing Archive](../archive/2026-02/parallel-ai-processing/)
