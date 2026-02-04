# Plan: parallel-ai-processing

## 1. Overview

| Item | Description |
|------|-------------|
| **Feature Name** | Parallel AI Processing |
| **Goal** | AI 리뷰 분석 시간을 병렬 처리로 단축 (9분 → 3분 목표) |
| **Priority** | High |
| **Estimated Effort** | Small (1-2 hours) |

## 2. Background & Problem

### Current State
- 29cm 파이프라인에서 324개 리뷰 분석에 **9분 54초** 소요
- 전체 파이프라인 시간의 **90% 이상**이 AI 분석에 집중
- 현재 순차 처리: 1배치 완료 → 다음 배치 시작

### Problem
```
현재 처리 방식 (순차):
Batch 1 ──25초──> Batch 2 ──25초──> Batch 3 ──25초──> ...
                총 소요: 22배치 × 25초 = 550초 (약 9분)
```

### Root Cause
- `analyzeReviews()` 함수가 순차적으로 호출됨
- OpenAI API Rate Limit을 고려하지 않은 보수적 구현
- 병렬 처리 로직 미구현

## 3. Solution

### Approach: Promise.all 기반 병렬 처리

```
개선된 처리 방식 (병렬 3개):
Batch 1 ──┐
Batch 2 ──┼──25초──> Batch 4 ──┐
Batch 3 ──┘          Batch 5 ──┼──25초──> ...
                     Batch 6 ──┘
                총 소요: 22배치 ÷ 3 × 25초 = 약 183초 (약 3분)
```

### Key Changes

| 영역 | 변경 사항 |
|------|----------|
| **analyzer.ts** | `analyzeReviewsBatch()` - 병렬 처리 래퍼 함수 추가 |
| **test script** | 병렬 배치 처리 로직으로 변경 |
| **환경 변수** | `AI_PARALLEL_BATCHES` - 동시 처리 배치 수 (기본값: 3) |

## 4. Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | 병렬 배치 수를 환경변수로 설정 가능 | Must |
| FR-2 | OpenAI Rate Limit (RPM) 초과 방지 | Must |
| FR-3 | 개별 배치 실패 시 다른 배치에 영향 없음 | Should |
| FR-4 | 진행 상황 로그 출력 | Should |

### Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1 | 324개 리뷰 분석 시간 | < 4분 |
| NFR-2 | 에러율 | < 1% |
| NFR-3 | 메모리 사용량 증가 | < 50% |

## 5. Constraints

### OpenAI Rate Limits (gpt-4o-mini)

| Tier | RPM (Requests/Min) | TPM (Tokens/Min) |
|------|-------------------|------------------|
| Tier 1 | 500 | 200,000 |
| Tier 2 | 5,000 | 2,000,000 |

- 현재 배치 크기 15개, 배치당 약 2,000 토큰
- 병렬 3개 = 분당 약 7-8회 요청 → Rate Limit 여유 충분

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Rate Limit 초과 | 병렬 수 제한 (기본 3개), 실패 시 재시도 |
| 메모리 초과 | 배치 그룹 단위로 처리 후 DB 저장 |
| 네트워크 불안정 | 개별 배치 실패 허용, 로그 기록 |

## 6. Scope

### In Scope
- [x] `analyzeReviewsBatch()` 병렬 처리 함수 구현
- [x] 테스트 스크립트 병렬 처리 적용
- [x] `AI_PARALLEL_BATCHES` 환경변수 추가
- [x] 에러 핸들링 및 로그 개선

### Out of Scope
- OpenAI Batch API (비동기) 적용
- 다른 AI 모델 지원
- 리뷰 캐싱 시스템

## 7. Success Metrics

| Metric | Current | Target | Method |
|--------|---------|--------|--------|
| 324개 리뷰 처리 시간 | 9분 54초 | < 4분 | 테스트 스크립트 실행 |
| 처리 성공률 | 100% | > 99% | 에러 로그 확인 |

## 8. Implementation Order

1. **환경변수 추가** - `.env.local`에 `AI_PARALLEL_BATCHES=3`
2. **병렬 처리 유틸 함수** - `chunkArray()`, `processInParallel()`
3. **테스트 스크립트 수정** - Step 3 AI 분석 부분 병렬화
4. **테스트 및 검증** - 시간 측정, 에러 확인

## 9. Appendix

### Related Files

| File | Purpose |
|------|---------|
| `web/src/features/ai-processing/analyzer.ts` | AI 분석 핵심 로직 |
| `web/scripts/test-29cm-crawl.ts` | 파이프라인 테스트 스크립트 |
| `web/.env.local` | 환경변수 설정 |

### References
- [OpenAI Rate Limits](https://platform.openai.com/docs/guides/rate-limits)
- Previous Pipeline Test: 5 products, 324 reviews, 9:54 elapsed
