# 리뷰 모으기 서비스 - 기술 아키텍처

> 멀티 플랫폼 리뷰 수집 및 체형 기반 개인화 서비스

---

## 1. 서비스 개요

### 핵심 가치
여러 커머스 플랫폼의 리뷰를 한 곳에 모아, 사용자 체형과 유사한 리뷰를 우선 제공하여 구매 결정 지원

### 수익 모델
제휴 마케팅 (Affiliate)

### MVP 범위

| 항목 | 내용 |
|------|------|
| 대상 플랫폼 | 29cm, 무신사 |
| 대상 상품 | 플랫폼당 인기상품 Top 10 |
| 크롤링 주기 | 1회/일 |

---

## 2. 기술 스택

| 레이어 | 기술 | 용도 |
|--------|------|------|
| Frontend | Next.js | 웹 인터페이스 |
| API Server | Next.js API Routes | REST API |
| 작업 큐 | BullMQ + Redis | 비동기 작업 처리 |
| 스케줄러 | node-cron 또는 BullMQ Repeatable Jobs | 정기 실행 |
| 크롤러 | Playwright | 브라우저 자동화 |
| 프록시 | Bright Data / FloppyData (필요시) | IP 로테이션 |
| AI 가공 | OpenAI API (gpt-4o-mini) | 리뷰 분석 |
| Primary DB | MySQL | 원본 데이터 저장 |
| Search Engine | Elasticsearch | 검색 및 필터링 |
| Cache | Redis | 중복 체크, 프록시 점수 |
| 모니터링 | Sentry + Slack | 에러 추적, 알림 |

---

## 3. 시스템 아키텍처

### 3.1 데이터 파이프라인

```
[스케줄러] → [상품 수집 큐] → [리뷰 크롤링 큐] → [AI 가공 큐] → [저장소]
     │              │                │                │            │
   02:00        product-         review-crawl      ai-processing   MySQL
   매일          discovery                                      Elasticsearch
```

### 3.2 파이프라인 단계별 상세

#### 1단계: 스케줄러
- 실행 주기: 매일 02:00
- 역할: product-discovery 큐에 작업 추가
- 구현: node-cron 또는 BullMQ Repeatable Jobs

#### 2단계: 상품 수집 (Product Discovery)
- 입력: 스케줄러 트리거
- 처리: 플랫폼별 인기상품 API/페이지 크롤링
- 출력: 상품 ID 목록 → review-crawl 큐에 개별 작업 추가

#### 3단계: 리뷰 크롤링 (Review Crawl)
- 병렬 처리: Worker 5~10개 동시 실행
- Worker 동작 순서:
  1. 큐에서 작업 가져오기 (선착순)
  2. 플랫폼별 크롤러 선택 (29cm: API, 무신사: Playwright)
  3. 리뷰 데이터 수집 (페이지네이션)
  4. 중복 체크 (Redis Set)
  5. MySQL에 원본 저장
  6. ai-processing 큐에 작업 추가
- 재시도: 3회, exponential backoff
- 프록시: 실패 시 자동 교체

#### 4단계: AI 가공 (AI Processing)
- 배치 처리: 10~20개 리뷰 묶어서 처리
- 가공 항목: 체형 정규화, 키워드 추출, 사이즈 피드백 분류, 감성 점수, 한줄 요약
- 저장: MySQL (review_analysis) + Elasticsearch 인덱싱

#### 5단계: 저장소
- MySQL: 원본 리뷰, AI 가공 결과, 크롤링 이력
- Elasticsearch: 검색 인덱스
- Redis: 중복 체크, 프록시 점수, 큐 데이터

### 3.3 Worker 개념

| 항목 | 설명 |
|------|------|
| 정의 | 큐에서 작업을 꺼내서 실행하는 독립적인 Node.js 프로세스 |
| 동작 | 큐 구독 → 작업 가져오기 → 실행 → 완료/실패 보고 → 대기 (무한 루프) |
| concurrency | Worker 1개가 동시에 처리 가능한 작업 수 |
| 예시 | Worker 2개 × concurrency 3 = 총 6개 작업 병렬 실행 |

### 3.4 큐 구조

```
Queue: review-crawl (단일 큐, 플랫폼 구분 없음)
┌─────────────────────────────────────────────────┐
│ Job 1: {platform: "29cm", productId: "3450770"} │
│ Job 2: {platform: "무신사", productId: "5453617"}│
│ Job 3: {platform: "29cm", productId: "3450771"} │
│ ...                                             │
└─────────────────────────────────────────────────┘
        │       │       │       │
        ▼       ▼       ▼       ▼
    Worker 1  Worker 2  Worker 3  Worker 4
```

---

## 4. 플랫폼별 크롤링 전략

### 4.1 29cm

| 항목 | 내용 |
|------|------|
| 접근 방식 | 공개 REST API (인증 불필요) |
| 난이도 | 낮음 |
| 프록시 필요 | 낮음 |

#### API 엔드포인트

| API | URL | 용도 |
|-----|-----|------|
| 리뷰 목록 | `/api/v4/reviews?itemId={id}&page=0&size=20&sort=BEST` | 핵심 리뷰 데이터 |
| 리뷰 개수 | `/api/v4/reviews/count?itemId={id}` | 총 리뷰 수 |
| 포토 리뷰 | `/api/v4/reviews/photo?itemId={id}&page=0&size=6` | 사진 리뷰만 |
| 리뷰 번들 | `/api/v4/review-bundle?itemId={id}&itemGroupId={groupId}` | 요약 정보 |

- Base URL: `https://review-api.29cm.co.kr`
- 체형 정보: 구조화된 배열 형태 `["163cm", "62kg"]`

### 4.2 무신사

| 항목 | 내용 |
|------|------|
| 접근 방식 | DOM 파싱 (Playwright) |
| 난이도 | 중간 |
| 프록시 필요 | 중간 |

- 체형 정보: 텍스트 파싱 필요 ("174cm · 72kg")
- JavaScript 렌더링 필요

---

## 5. 데이터베이스 스키마

### 5.1 주요 테이블

#### products (상품)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| platform | VARCHAR(20) | 플랫폼명 |
| platform_product_id | VARCHAR(50) | 플랫폼 내 상품 ID |
| name | VARCHAR(255) | 상품명 |
| brand | VARCHAR(100) | 브랜드명 |
| category | VARCHAR(100) | 카테고리 |
| price | INT | 가격 |
| image_url | TEXT | 이미지 URL |
| created_at | DATETIME | 생성일 |
| updated_at | DATETIME | 수정일 |

#### reviews (리뷰 원본)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| product_id | BIGINT | FK → products |
| platform_review_id | VARCHAR(50) | 플랫폼 내 리뷰 ID |
| content | TEXT | 리뷰 본문 |
| rating | TINYINT | 평점 |
| option_value | VARCHAR(100) | 구매 옵션 (사이즈 등) |
| user_height | SMALLINT | 키 (정규화 후, cm) |
| user_weight | SMALLINT | 몸무게 (정규화 후, kg) |
| images | JSON | 이미지 URL 배열 |
| review_date | DATE | 리뷰 작성일 |
| created_at | DATETIME | 수집일 |

#### review_analysis (AI 가공 결과)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| review_id | BIGINT | FK → reviews |
| keywords | JSON | 추출된 키워드 |
| sentiment | FLOAT | 감성 점수 (-1 ~ 1) |
| size_feedback | ENUM | 'small', 'fit', 'large' |
| summary | VARCHAR(200) | 한줄 요약 |
| processed_at | DATETIME | 가공 완료 시간 |

#### crawl_logs (크롤링 이력)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| product_id | BIGINT | FK → products |
| status | ENUM | 'success', 'fail', 'partial' |
| reviews_collected | INT | 수집된 리뷰 수 |
| errors | TEXT | 에러 메시지 |
| started_at | DATETIME | 시작 시간 |
| completed_at | DATETIME | 완료 시간 |

### 5.2 권장 인덱스

| 테이블 | 인덱스 |
|--------|--------|
| reviews | (product_id, created_at) |
| reviews | (platform, platform_review_id) UNIQUE |
| reviews | (user_height, user_weight) |
| review_analysis | (review_id) |

---

## 6. 개인화 전략

### 6.1 체형 유사도 매칭 (MVP)

#### 유사도 공식

```
유사도 = 1 - (|내키 - 리뷰어키|/20 + |내몸무게 - 리뷰어몸무게|/15) / 2
```

- 유사도 70% 이상: "비슷한 체형" 배지 부여
- 키 허용 오차: ±10cm (가중치 20)
- 몸무게 허용 오차: ±7.5kg (가중치 15)

### 6.2 추가 개인화 아이디어 (향후)

| 카테고리 | 아이디어 |
|----------|----------|
| 프로필 기반 | 평소 사이즈, 체형 고민, 스타일 선호, 연령대 |
| 행동 기반 | 구매 이력 학습, 찜/관심 분석, 리뷰 반응 학습 |
| 컨텍스트 기반 | 계절/날씨 연동, 용도별 필터 |
| 소셜/비교 | 유사 유저 클러스터, 사이즈 컨센서스, 브랜드별 사이즈 편차 |
| AI 활용 | 맞춤 요약, 핏 예측, 질문 응답, 감성 분석 |

---

## 7. AI 가공 파이프라인

### 7.1 가공 항목

| 항목 | 설명 | 방식 |
|------|------|------|
| 체형 정규화 | "163cm", "62kg" → 숫자 추출 | 정규식 + AI fallback |
| 키워드 추출 | 핏, 소재, 색감 등 | OpenAI API |
| 사이즈 피드백 | small / fit / large | OpenAI API |
| 감성 점수 | -1 ~ 1 | OpenAI API |
| 한줄 요약 | 리뷰 핵심 요약 | OpenAI API |

### 7.2 배치 처리

- 배치 크기: 10~20개 리뷰
- 모델: gpt-4o-mini (비용 효율)
- 예상 비용: ~$10~50/월 (MVP 기준)

---

## 8. 프록시 전략

### 8.1 프록시 동작 원리

```
EC2 → 프록시 서버 → 커머스 플랫폼
```

- 커머스 플랫폼에는 프록시 IP만 노출
- 매 요청마다 다른 프록시 사용 (로테이션)

### 8.2 프록시 종류

| 종류 | 탐지 가능성 | 가격 | 용도 |
|------|-------------|------|------|
| Datacenter | 높음 | ~$0.5~1/GB | 관대한 사이트 |
| Residential | 낮음 | ~$1~10/GB | 엄격한 사이트 |
| Mobile | 매우 낮음 | 매우 비쌈 | 최후 수단 |

### 8.3 서비스 비교

#### IP 풀 규모

| 서비스 | Datacenter | Residential | Mobile | 총 IP |
|--------|------------|-------------|--------|-------|
| Bright Data | 1.6M+ | 150M+ | 7M+ | 150M+ |
| Oxylabs | 2M+ | 100M+ | 20M+ | 100M+ |
| Decodo | 500K+ | 115M+ | 10M+ | 125M+ |
| FloppyData | 미공개 | 65M+ | 미공개 | 65M+ |

#### 가격 비교 (GB당)

| 서비스 | Datacenter | Residential | Mobile |
|--------|------------|-------------|--------|
| Bright Data | $0.07~0.08 | $5.04~10.50 | $14.4+ |
| Oxylabs | $0.44 | $4~8 | $9 |
| Decodo | - | $3.50~4.90 | $8 |
| FloppyData | $0.60~0.90 | $1~2.95 | $1~2.95 |

#### 종합 비교

| 항목 | Bright Data | Oxylabs | Decodo | FloppyData |
|------|-------------|---------|--------|------------|
| 가격 | 비쌈 | 중간 | 저렴 | 최저가 |
| IP 풀 규모 | 최대 | 대형 | 대형 | 중형 |
| 안정성/신뢰도 | 최상 | 상 | 중상 | 미검증 |
| 최소 결제 | $14~499/월 | $49~50/월 | $10~12.50/월 | 없음 (PAYG) |
| 업력 | 10년+ | 8년+ | 7년+ | 2년~ |

### 8.4 MVP 전략

1. 프록시 없이 시작 (29cm API는 프록시 불필요)
2. 차단 시 FloppyData로 테스트 (~$3~9/월)
3. 품질 이슈 시 Decodo 또는 Oxylabs로 전환

### 8.5 프록시 풀 관리

- 성공 → 점수 +1
- 실패 → 점수 -5
- 점수 0 이하 → 30분 휴식

---

## 9. AWS 인프라

### 9.1 MVP 권장 구성

```
EC2 t3.medium (4GB RAM, 월 ~$30)
├── scheduler (node-cron)
├── worker (BullMQ)
├── redis (Docker)
└── elasticsearch (Docker)
```

### 9.2 메모리 사용 계획

| 컴포넌트 | 메모리 |
|----------|--------|
| 스케줄러 | ~50MB |
| Worker (Playwright 포함) | ~800MB |
| Redis | ~100MB |
| Elasticsearch | ~1GB |
| **합계** | ~2GB |

### 9.3 확장 옵션

| 옵션 | 구성 | 월 비용 |
|------|------|---------|
| A. 통합 | EC2 1대 | ~$30 |
| B. EC2 분리 | Worker/Redis/ES 각각 분리 | ~$53 |
| C. 관리형 | EC2 + ElastiCache + OpenSearch | ~$52 |

### 9.4 데이터 증가 대응

#### MySQL

1. 인덱스 최적화
2. Read Replica 추가
3. 파티셔닝 (날짜 기준)
4. 오래된 데이터 아카이빙 (S3)
5. 샤딩 또는 Aurora

#### Elasticsearch

1. 샤드 수 조정
2. 인덱스 롤오버 (월별)
3. Hot-Warm 노드 분리
4. 오래된 인덱스 삭제/압축

#### 아카이빙 전략

| 저장소 | 보관 기간 |
|--------|-----------|
| MySQL | 최근 3개월 → 이후 S3 |
| Elasticsearch | 최근 6개월 → 이후 삭제 |

---

## 10. 검색 서비스 Flow

### 10.1 상품 검색

```
유저 → API → Elasticsearch (상품명 매칭) → 응답
```

### 10.2 리뷰 목록

```
유저 → API → Elasticsearch (체형 유사도 정렬) → MySQL (추가 데이터) → 응답
```

#### 응답 데이터

- 리뷰 요약 (총 개수, 평균 평점, 사이즈 조언)
- 리뷰 목록 (체형 유사도 순)
- 비슷한 체형 배지

### 10.3 필터/정렬

- Elasticsearch 쿼리로 처리
- 키 범위, 사진 유무, 평점 등

### 10.4 구매 링크

1. 클릭 로그 저장 (MySQL)
2. 제휴 링크로 리다이렉트

---

## 11. AI 사이즈 추천 로드맵

### Phase 1: 규칙 기반 (MVP)

| 항목 | 내용 |
|------|------|
| 방식 | 유사 체형 리뷰 필터링 → 사이즈 선택 집계 → 사이즈 피드백 집계 |
| 비용 | $0 |
| 정확도 | 중 |

### Phase 2: LLM 기반

| 항목 | 내용 |
|------|------|
| 방식 | 유사 체형 리뷰 30개 조회 → OpenAI API로 분석 및 추천 |
| 비용 | ~$10~50/월 |
| 정확도 | 중상 |

### Phase 3: ML 모델

| 항목 | 내용 |
|------|------|
| 학습 파이프라인 | MySQL → Feature Engineering → Model Training → S3 |
| 추론 파이프라인 | Feature 생성 → ML 모델 → 사이즈별 확률 분포 |
| Feature | height, weight, brand, category, avg_size_feedback 등 |
| 인프라 | SageMaker 또는 EC2 |
| 비용 | ~$50~100/월 |
| 정확도 | 상 |

---

## 12. 모니터링

### 알림 조건

| 지표 | 알림 조건 |
|------|-----------|
| 크롤링 성공률 | < 80% |
| 큐 적체 | > 1000개 대기 |
| AI 가공 실패 | 연속 5회 |
| 프록시 소진 | 가용 프록시 < 10개 |

---

## 13. 핵심 결정 사항 요약

| 항목 | 결정 |
|------|------|
| MVP 인프라 | EC2 t3.medium 1대 통합 구성 |
| 크롤링 | 29cm API + 무신사 Playwright |
| 개인화 | 체형 유사도 매칭 우선 |
| AI 가공 | OpenAI gpt-4o-mini 배치 처리 |
| 프록시 | 필요시 단계적 도입 (FloppyData → Decodo) |
| 사이즈 추천 | 규칙 기반 → LLM → ML 순차 발전 |

---

*문서 작성일: 2026-01-28*
