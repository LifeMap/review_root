# Review Service MVP Planning Document

> **Summary**: 멀티 플랫폼 리뷰 수집 및 체형 기반 개인화 리뷰 서비스 MVP 구현
>
> **Project**: reviews (리뷰 모으기 서비스)
> **Version**: 0.1.0
> **PRD Version**: v1.2 (2026-01-30)
> **Date**: 2026-02-01
> **Status**: Draft

---

## 1. Overview

### 1.1 Purpose

여러 커머스 플랫폼(29cm, 무신사, 네이버 스마트스토어)에 분산된 리뷰를 통합 수집하고, 광고성 리뷰를 필터링하며, 체형 유사도 등의 데이터를 기반으로 리뷰를 개인화하여 구매 결정을 돕는 서비스를 구현한다.

### 1.2 Background

- 리뷰가 여러 플랫폼에 흩어져 있어 비교가 어려움
- 광고성 리뷰를 구분하기 어려움
- 체형이 비슷한 사람의 리뷰 등 개인화된 리뷰를 찾기 어려움
- 플랫폼별 가격 비교가 번거로움

### 1.3 Related Documents

- PRD: [docs/prd/review_service_prd.md](../../prd/review_service_prd.md)
- Architecture: [docs/architect/review_service_tech_architecture.md](../../architect/review_service_tech_architecture.md)
- DB Design: [docs/dba/README.md](../../dba/README.md)

---

## 2. Scope

### 2.1 In Scope (MVP v1.0)

PRD 기능 목록 (P0~P2) 기준:

**인프라**
- [ ] Docker Compose로 로컬 인프라 구성 (MySQL, Redis, Elasticsearch)
- [ ] Next.js 프로젝트 초기화 (App Router, TypeScript)
- [ ] DB 스키마 적용 (init.sql — 11개 테이블)

**회원 (P0)**
- [ ] 이메일/비밀번호 회원가입 (8자 이상, 영문+숫자)
- [ ] 소셜 로그인 (Google, Apple, Kakao)
- [ ] 이메일 인증, Unique Code 발급 (A-Z0-9 8자리)
- [ ] 로그인 상태 유지 (7일), 비밀번호 찾기
- [ ] 체형 프로필 관리 (키, 몸무게, 평소 사이즈, 발 사이즈/형태)

**크롤링 파이프라인**
- [ ] 29cm 리뷰 크롤러 (공개 REST API)
- [ ] 무신사 리뷰 크롤러 (Playwright DOM 파싱)
- [ ] 네이버 스마트스토어 크롤러
- [ ] BullMQ 파이프라인 (스케줄러 → 상품 수집 → 리뷰 크롤링 → AI 가공)

**AI 분석**
- [ ] OpenAI 리뷰 분석 (광고성 판별, 키워드 추출, 감성 점수, 사이즈 피드백, 한줄 요약)
- [ ] 단점 상세도 점수 산정 ((키워드 수 × 10) + (단점 문자 수 × 0.5))

**API (P0)**
- [ ] 상품 검색 API (Elasticsearch)
- [ ] 상품 상세 API (리뷰 요약, 가격 비교)
- [ ] 리뷰 목록 API (정렬: 단점상세순/유사체형순/최신순/평점순, 필터: 광고성/플랫폼/평점/사진/사이즈피드백/체형범위)
- [ ] 가격 비교 API (플랫폼별 가격, 최저가 하이라이트)
- [ ] 사이즈 인사이트 API (유사 체형 사이즈 추천, 신뢰도)

**프론트엔드 (8개 화면)**
- [ ] S-001 메인 홈 (P0)
- [ ] S-002 검색 결과 (P0)
- [ ] S-003 상품 상세 (P0) — 가격 비교, 리뷰 요약, 사이즈 인사이트, 리뷰 목록
- [ ] S-004 회원가입 (P0)
- [ ] S-005 로그인 (P0)
- [ ] S-006 마이페이지 (P1)
- [ ] S-007 프로필 설정 (P0)
- [ ] S-008 비밀번호 찾기 (P1)

**기타**
- [ ] 최근 본 상품 (P2)
- [ ] 시스템 관리자 페이지 (P2)

### 2.2 Out of Scope

- 찜하기 (v1.1)
- 가격 알림, 어필리에이트 연동 (v1.2)
- 뷰티/가전/식품 카테고리 (v2.0)
- ML 기반 사이즈 추천 (Phase 3)
- 프록시 서버 연동 (차단 시 단계적 도입)
- AWS 배포 (로컬 개발 우선)
- 모바일 네이티브 앱

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Source |
|----|-------------|----------|--------|
| FR-01 | 이메일/비밀번호 회원가입 + 소셜 로그인 (Google, Apple, Kakao) | P0 | F-001 |
| FR-02 | 이메일 인증 + Unique Code 발급 | P0 | F-001 |
| FR-03 | 체형 프로필 관리 (키, 몸무게, 사이즈, 발 사이즈/형태) | P0 | F-002 |
| FR-04 | 광고성 리뷰 AI 감지 + 필터 토글 (기본 제외) | P0 | F-003 |
| FR-05 | 단점 중심 정렬 + 단점 상세도 점수 | P0 | F-004 |
| FR-06 | 플랫폼별 가격 비교 + 최저가 하이라이트 + 구매 링크 | P0 | F-005 |
| FR-07 | 리뷰 요약 — 장점/단점 Top 3 (언급 빈도) | P0 | F-006 |
| FR-08 | 사이즈 인사이트 — 유사 체형 사이즈 추천 + 신뢰도 | P1 | F-007 |
| FR-09 | 상품 검색 (키워드, URL 검색) | P0 | PRD 4.1 |
| FR-10 | 리뷰 필터 (플랫폼, 평점, 사진, 사이즈 피드백, 체형 범위) | P1 | PRD 4.3 |
| FR-11 | 29cm + 무신사 + 네이버 스마트스토어 크롤러 | P0 | PRD 1.5 |
| FR-12 | BullMQ 작업 큐 파이프라인 | P0 | Arch 3.1 |
| FR-13 | 최근 본 상품 | P2 | PRD 4.1 |
| FR-14 | 시스템 관리자 페이지 | P2 | PRD 4.1 |

### 3.2 Non-Functional Requirements

| Category | Criteria | Source |
|----------|----------|--------|
| Performance | 리뷰 목록 API < 500ms (필터 미적용), < 1s (필터 적용) | PRD 7.1 |
| Performance | 검색 API < 1s, 가격 비교 API < 500ms | PRD 7.1 |
| Performance | FCP < 1.5s, TTI < 3s (4G 기준) | PRD 7.1 |
| Security | bcrypt 해싱 (cost 12), AES-256-GCM 체형 암호화 | PRD 7.3 |
| Security | Access Token 30분, Refresh Token 7일, HttpOnly Cookie | PRD 7.3 |
| Security | Rate Limiting — 로그인 5회/분, 검색 30회/분, 일반 60회/분 | PRD 7.3 |
| Security | CSRF 방어, XSS 방어 (HTML 이스케이프), SQL Injection 방지 (ORM) | PRD 7.3 |
| Reliability | 리뷰 수집 성공률 95% | PRD 7.1 |
| Cost | AI 가공 월 $50 이하 (gpt-4o-mini) | Arch 7.2 |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] Docker Compose로 로컬 환경 원커맨드 실행
- [ ] 회원가입/로그인/프로필 설정 동작
- [ ] 29cm + 무신사 + 네이버에서 리뷰 수집 동작
- [ ] 수집된 리뷰를 AI로 분석하여 DB 저장 (광고성 판별 포함)
- [ ] 웹에서 상품 검색 → 상품 상세 (가격 비교, 리뷰 요약, 리뷰 목록) 동작
- [ ] 광고성 리뷰 필터, 단점 상세순 정렬 동작
- [ ] 체형 프로필 등록 시 유사 체형 리뷰 우선 표시 + 사이즈 인사이트

### 4.2 Quality Criteria

- [ ] TypeScript strict mode, zero lint errors
- [ ] 빌드 성공
- [ ] 보안 요구사항 충족 (bcrypt, JWT, HttpOnly Cookie, Rate Limiting)
- [ ] 광고성 리뷰 분류 정확도 80% 이상

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 무신사 크롤링 차단 | High | Medium | 요청 간격 조절, User-Agent 로테이션, 프록시 단계적 도입 |
| 네이버 스마트스토어 봇 탐지 | High | High | 봇 탐지 강함 — Playwright stealth, 프록시 필수 가능성 |
| 29cm API 변경/중단 | High | Low | API 응답 모니터링, fallback 크롤링 준비 |
| OpenAI 비용 초과 | Medium | Low | 배치 처리 (10~20개), gpt-4o-mini, 토큰 모니터링 |
| Elasticsearch 메모리 부족 | Medium | Medium | Docker 메모리 512MB 제한, 로컬 환경 최적화 |
| 소셜 로그인 연동 복잡도 | Medium | Medium | NextAuth.js 활용, OAuth 2.0 표준 준수 |

---

## 6. Architecture Considerations

### 6.1 Project Level Selection

| Level | Characteristics | Selected |
|-------|-----------------|:--------:|
| **Starter** | Simple structure | ☐ |
| **Dynamic** | Feature-based modules, services layer | ☑ |
| **Enterprise** | Strict layer separation, DI | ☐ |

Dynamic 선택 이유: 인증, 크롤러, 큐, AI 가공 등 여러 서비스 레이어가 필요하지만, MVP 규모에 Enterprise는 과도

### 6.2 Key Architectural Decisions

| Decision | Selected | Rationale |
|----------|----------|-----------|
| Framework | Next.js (App Router) | SSR + API Routes 통합, 아키텍처 문서 기준 |
| Auth | NextAuth.js | 소셜 로그인 (Google/Apple/Kakao) 통합, JWT 기반 |
| DB ORM | Drizzle ORM | 타입 안전, 경량, MySQL 지원 |
| Queue | BullMQ | 아키텍처 문서 기준, Redis 기반 |
| Styling | Tailwind CSS | 빠른 UI 구현, 모바일 반응형 |
| State Mgmt | React Server Components 우선 | Next.js App Router 기본 패턴 |
| API Client | fetch (내장) | 외부 의존성 최소화 |
| Testing | Vitest | 빠른 실행, TypeScript 네이티브 |
| Validation | Zod | 서버/클라이언트 공유 스키마 검증 |

### 6.3 Folder Structure

```
src/
  app/                    # Next.js App Router
    (auth)/               # 회원가입, 로그인, 비밀번호 찾기
    (main)/               # 메인홈, 검색결과, 상품상세
    (user)/               # 마이페이지, 프로필설정
    (admin)/              # 관리자 페이지
    api/                  # API Routes
      auth/               # 인증 API
      products/           # 상품 API
      reviews/            # 리뷰 API
      crawl/              # 크롤링 트리거 API
  features/               # 기능별 모듈
    auth/                 # 인증 (회원가입, 로그인, 소셜)
    products/             # 상품 관련
    reviews/              # 리뷰 관련 (필터, 정렬, 요약)
    crawlers/             # 크롤러
      platforms/          # 29cm, 무신사, 네이버
    ai-processing/        # AI 가공 (광고성 판별, 키워드, 감성, 요약)
    queue/                # BullMQ 워커, 큐 정의
    search/               # Elasticsearch 검색
  services/               # 공통 서비스
    db/                   # Drizzle 스키마, 커넥션
    redis/                # Redis 클라이언트
    elasticsearch/        # ES 클라이언트
  lib/                    # 유틸리티 (crypto, validation 등)
  types/                  # 공유 타입
```

---

## 7. Convention Prerequisites

### 7.1 Existing Project Conventions

- [x] `CLAUDE.md` has coding conventions section
- [ ] ESLint configuration
- [ ] Prettier configuration
- [ ] TypeScript configuration (`tsconfig.json`)

### 7.2 Environment Variables Needed

| Variable | Purpose | Scope |
|----------|---------|-------|
| `DATABASE_URL` | MySQL 연결 | Server |
| `REDIS_URL` | Redis 연결 | Server |
| `ELASTICSEARCH_URL` | ES 연결 | Server |
| `OPENAI_API_KEY` | OpenAI API | Server |
| `NEXTAUTH_SECRET` | NextAuth 시크릿 | Server |
| `NEXTAUTH_URL` | NextAuth 콜백 URL | Server |
| `GOOGLE_CLIENT_ID` | Google OAuth | Server |
| `GOOGLE_CLIENT_SECRET` | Google OAuth | Server |
| `APPLE_CLIENT_ID` | Apple OAuth | Server |
| `APPLE_CLIENT_SECRET` | Apple OAuth | Server |
| `KAKAO_CLIENT_ID` | Kakao OAuth | Server |
| `KAKAO_CLIENT_SECRET` | Kakao OAuth | Server |
| `ENCRYPTION_KEY` | 체형 정보 AES-256-GCM 키 | Server |
| `SMTP_HOST` | 이메일 인증 발송 | Server |
| `SMTP_USER` | 이메일 인증 발송 | Server |
| `SMTP_PASS` | 이메일 인증 발송 | Server |

---

## 8. Implementation Order

MVP를 9단계로 나누어 구현:

| Phase | 내용 | 의존성 | PRD 기능 |
|-------|------|--------|----------|
| **Phase 1** | 프로젝트 초기화 + Docker Compose + DB 스키마 | 없음 | - |
| **Phase 2** | DB 연결 (Drizzle) + 기본 API Routes 구조 | Phase 1 | - |
| **Phase 3** | 인증 — 회원가입/로그인/소셜/이메일인증/프로필 | Phase 2 | F-001, F-002 |
| **Phase 4** | 29cm 크롤러 (공개 API, 가장 쉬움) | Phase 2 | F-011 일부 |
| **Phase 5** | BullMQ 파이프라인 + OpenAI 리뷰 분석 | Phase 4 | F-003~F-007, F-012 |
| **Phase 6** | 무신사 크롤러 (Playwright) | Phase 5 | F-011 일부 |
| **Phase 7** | 네이버 스마트스토어 크롤러 | Phase 5 | F-011 일부 |
| **Phase 8** | 프론트엔드 전체 (8개 화면) + ES 검색 | Phase 3, 5 | S-001~S-008, F-008~F-010 |
| **Phase 9** | 관리자 페이지 + 최근 본 상품 + 통합 테스트 | Phase 8 | F-013, F-014 |

---

## 9. Next Steps

1. [ ] Design 문서 작성 (`/pdca design review-service`)
2. [ ] Phase 1부터 구현 시작

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-02-01 | Initial draft |
| 0.2 | 2026-02-01 | PRD v1.2 기반 전면 재작성 — 플랫폼 3개, 인증/보안/화면 요구사항 반영 |
