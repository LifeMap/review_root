# Plan: ably-pipeline

> 에이블리 데이터 파이프라인 구현

## 1. Overview

| Item | Description |
|------|-------------|
| Feature | ably-pipeline |
| Type | New Feature |
| Priority | High |
| Created | 2026-05-26 |

## 2. Background

### 2.1 Current State
- 29cm 데이터 파이프라인 테스트 스크립트 완성 (`test-29cm-crawl.ts`)
- 무신사 파이프라인 구현 완료 (`musinsa.ts`, `test-musinsa-crawl.ts`)
- 에이블리 크롤러 미구현

### 2.2 Problem
- 에이블리는 여성 패션 버티컬의 핵심 플랫폼 중 하나로, PRD v1.4에서 MVP 지원 플랫폼으로 확정됨
- 에이블리는 모바일 중심 플랫폼(`m.a-bly.com`)으로, 데스크톱 웹 접근 방식과 다를 수 있어 별도 사전 조사가 필요함
- 접근 방식(공개 API 존재 여부, 봇 탐지 강도, 리뷰 데이터 구조)이 아직 조사되지 않음
- 기존 29cm/무신사와 동일한 4단계 파이프라인 구조에 통합해야 함

### 2.3 Why Now
- PRD v1.4 확정으로 에이블리가 MVP 범위에 포함됨
- 무신사 파이프라인 구조가 안정화되어 새로운 플랫폼 추가를 위한 베이스가 마련됨

## 3. Goals

### 3.1 Primary Goals
1. 에이블리 데이터 파이프라인 구현 (`platforms/ably.ts`)
2. 29cm/무신사와 동일한 4단계 구조 적용
3. 에이블리 전용 테스트 스크립트 구현 (`scripts/test-ably-crawl.ts`)
4. 환경변수 `MAX_ABLY_PRODUCTS` 지원

### 3.2 Success Criteria
| Metric | Target |
|--------|--------|
| 스크립트 실행 | 에러 없이 완료 |
| 상품 수집 | MAX_ABLY_PRODUCTS 개수 |
| 리뷰 수집 | 상품당 리뷰 수집 가능 (목표치는 조사 후 확정) |
| AI 분석 | 병렬 처리 (AI_PARALLEL_BATCHES) |
| DB 저장 | products, reviews, review_analyses 테이블 |

## 4. Technical Approach

### 4.1 Pipeline Structure

```
Step 1: 베스트 상품 수집
  ↓
Step 2: 상품별 리뷰 크롤링 + DB 저장
  ↓
Step 3: AI 분석 (OpenAI gpt-4o-mini, 병렬 처리)
  ↓
Step 4: 요약 생성 (product_summaries, size_insights)
```

### 4.2 Key Differences from Musinsa

| Item | Musinsa | Ably |
|------|---------|------|
| 상품 수집 방식 | Playwright 웹 스크래핑 | TBD — 사전 조사 필요 |
| 리뷰 수집 방식 | Playwright 웹 스크래핑 | TBD — 사전 조사 필요 |
| 접속 URL 기준 | 데스크톱 웹 | 모바일 웹(`m.a-bly.com`) — 별도 확인 필요 |
| 봇 탐지 수준 | 중간 | TBD — 사전 조사 필요 |
| 체형 정보 구조 | 텍스트 파싱 ("174cm · 72kg") | TBD — 사전 조사 필요 |
| 속도 (예상) | ~5-10초/상품 | TBD — 사전 조사 필요 |

> **중요**: 에이블리의 실제 접근 방식은 사전 조사(공개 API 유무, DOM 구조, 모바일/데스크톱 접속 정책, robots.txt 정책) 완료 후 이 섹션을 업데이트해야 합니다.

### 4.3 Environment Variables
```bash
MAX_ABLY_PRODUCTS=5      # 수집할 상품 수 (기본값 TBD — 조사 후 결정)
AI_PARALLEL_BATCHES=3    # AI 병렬 처리 수 (공통)
```

## 5. Implementation Plan

### 5.1 Files to Create
- `web/src/features/crawlers/platforms/ably.ts` — 에이블리 크롤러 구현체
- `web/scripts/test-ably-crawl.ts` — 파이프라인 테스트 스크립트

### 5.2 Files to Modify
- `web/src/features/crawlers/registry.ts` — 에이블리 크롤러 등록
- `web/src/features/crawlers/product-discovery.ts` — platformCode 분기 추가

### 5.3 Files to Reference
- `web/scripts/test-29cm-crawl.ts` (REST API 기반 구조 참조)
- `web/scripts/test-musinsa-crawl.ts` (Playwright 기반 구조 참조)
- `web/src/features/crawlers/platforms/musinsa.ts` (크롤러 인터페이스 참조)

### 5.4 Implementation Order
1. 사전 조사: 에이블리 공개 API 여부, 리뷰 페이지 DOM 구조, 모바일/데스크톱 접속 정책, robots.txt 확인
2. 접근 방식 결정 (REST API / Playwright / 하이브리드)
3. `ably.ts` 크롤러 기본 구조 생성
4. Step 1: 베스트 상품 수집 구현
5. Step 2: 리뷰 크롤링 + DB 저장 로직
6. Step 3/4: AI 분석 및 요약 생성 (29cm/무신사와 동일 로직 재사용)
7. `test-ably-crawl.ts` 테스트 스크립트 작성
8. `platforms` 테이블 ably 레코드 확인 (id=5)

## 6. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 모바일 전용 플랫폼 | Playwright User-Agent 설정 필요, 데스크톱 URL 접근 불가 가능성 | 사전 조사에서 데스크톱 접근 가능 여부 확인 |
| 공개 API 미제공 | Playwright 필요, 구현 난이도 상승 | 사전 조사 후 접근 방식 결정, 무신사 구조 재사용 |
| 강한 봇 탐지 | 크롤링 차단 | 사전 조사 후 delay 조정, 프록시 도입 검토 |
| 리뷰 데이터 구조 상이 | 파서 재설계 필요 | 조사 단계에서 응답 구조 샘플 확보 |
| 체형 정보 부재 | 사이즈 인사이트 품질 저하 | 텍스트 파싱 또는 AI 추출로 보완 |
| 로그인 요구 | 인증 처리 복잡도 증가 | 로그인 필요 여부 사전 확인, 필요 시 세션 관리 구현 |

## 7. Timeline

| Phase | Task | Status |
|-------|------|--------|
| Plan | 계획 문서 작성 | ✅ 완료 |
| Research | 사전 조사 (API, DOM, 모바일 정책, robots.txt) | Not Started |
| Design | 상세 설계 문서 | Not Started |
| Do | 구현 | Not Started |
| Check | Gap 분석 | Not Started |
| Report | 완료 보고서 | Not Started |

## 8. References

- [Musinsa Pipeline Plan](./musinsa-pipeline.plan.md)
- [Musinsa Crawler](../../web/src/features/crawlers/platforms/musinsa.ts)
- [29cm Pipeline Test Script](../../web/scripts/test-29cm-crawl.ts)
- [PRD v1.4](../../docs/prd/review_service_prd_v1.4.md) — 8.2 외부 의존성 섹션
- [Tech Architecture](../../docs/architect/review_service_tech_architecture.md) — 4.4 에이블리 섹션
