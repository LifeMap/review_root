# 데이터베이스 문서 (DBA Docs)

리뷰 모으기 서비스의 데이터베이스 설계 및 관리 문서입니다.

---

## 📋 문서 목록

### 핵심 문서

| 문서명 | 설명 | 버전 |
|--------|------|------|
| [v1.0.0_initial-database-design.md](v1.0.0_initial-database-design.md) | **초기 데이터베이스 설계 상세 문서** | v1.0.0 |
| [init.sql](init.sql) | **실행 가능한 DDL 스크립트** | v1.0.0 |
| [CHANGELOG.md](CHANGELOG.md) | 데이터베이스 변경 이력 | - |

### 참고 문서

| 문서명 | 설명 |
|--------|------|
| [ERD.md](ERD.md) | Entity Relationship Diagram (Mermaid 형식) |
| [API_PARAMETER_GUIDE.md](API_PARAMETER_GUIDE.md) | API 엔드포인트별 매개변수 가이드 |

---

## 🚀 빠른 시작

### 1. 데이터베이스 생성 및 초기화

```bash
# MySQL 접속
mysql -u root -p

# DDL 실행
source /path/to/init.sql
```

또는

```bash
# 명령줄에서 직접 실행
mysql -u root -p < init.sql
```

### 2. 초기 데이터 확인

```sql
USE review_service;

-- 플랫폼 데이터 확인
SELECT * FROM platforms;

-- 테이블 목록 확인
SHOW TABLES;

-- 테이블 구조 확인 (예: users)
DESC users;
```

---

## 📊 데이터베이스 구조 개요

### 주요 테이블 (11개)

| 테이블명 | 설명 | 레코드 수 (예상, 6개월) |
|----------|------|------------------------|
| `users` | 사용자 계정 | ~1,000 |
| `user_profiles` | 사용자 프로필 (카테고리별) | ~1,000 |
| `platforms` | 쇼핑 플랫폼 | 3 (고정) |
| `products` | 상품 정보 | ~30 |
| `product_platform_mappings` | 상품-플랫폼 매핑 (가격 비교) | ~90 |
| `reviews` | 리뷰 정보 | ~4,680 |
| `review_analyses` | 리뷰 AI 분석 결과 | ~4,680 |
| `review_keywords` | 리뷰 키워드 | ~23,400 |
| `product_summaries` | 상품 리뷰 요약 | ~30 |
| `size_insights` | 사이즈 인사이트 (패션) | ~150 |
| `recent_views` | 최근 본 상품 | ~10,000 |

### ERD 다이어그램

[ERD.md](ERD.md)에서 Mermaid 형식의 상세 다이어그램을 확인하세요.

**주요 관계:**
- `users` → `user_profiles` (1:N, CASCADE)
- `products` → `reviews` (1:N, CASCADE)
- `reviews` → `review_analyses` (1:1, CASCADE)
- `products` → `product_platform_mappings` (1:N, CASCADE)

---

## 🔑 주요 설계 원칙

### 1. 확장성 (Scalability)
- 멀티 카테고리 지원: `user_profiles`, `products` 테이블에 카테고리별 컬럼 사전 정의
- 파티셔닝 준비: 대용량 데이터 대비 파티셔닝 전략 문서화

### 2. 정규화 (Normalization)
- 3NF 준수: 데이터 중복 최소화
- Denormalization 선택적 적용: 성능 향상을 위해 `products.average_rating`, `product_summaries` 등 사전 집계

### 3. 성능 (Performance)
- **FULLTEXT 인덱스**: 상품 검색 (`products.name`, `products.brand`)
- **복합 인덱스**: 사용자별 최근 조회 (`recent_views.user_id`, `viewed_at DESC`)
- **선택적 인덱스**: 광고성 필터 (`review_analyses.is_sponsored`), 평점 필터 (`reviews.rating`)

### 4. 보안 (Security)
- 비밀번호: bcrypt 해싱 (cost 12)
- 개인정보 암호화: 체형 정보 AES-256-GCM
- 리뷰어 마스킹: 닉네임 가운데 글자 마스킹 ("홍길동" → "홍*동")

---

## 📐 네이밍 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 테이블명 | snake_case, 복수형 | `users`, `product_reviews` |
| 컬럼명 | snake_case | `user_id`, `created_at` |
| 외래키 | `{참조테이블}_id` | `user_id`, `product_id` |
| 인덱스 | `idx_{테이블}_{컬럼}` | `idx_reviews_product_id` |
| 유니크 인덱스 | `uk_{테이블}_{컬럼}` | `uk_users_email` |
| 외래키 제약 | `fk_{테이블}_{참조테이블}` | `fk_reviews_product` |

---

## 🛠️ 개발 환경 설정

### MySQL 설정 권장사항

```sql
-- InnoDB 버퍼 풀 사이즈 (서버 메모리의 70-80%)
SET GLOBAL innodb_buffer_pool_size = 2147483648; -- 2GB

-- FULLTEXT 인덱스 ngram 토큰 사이즈 (한글 검색)
SET GLOBAL ngram_token_size = 2;

-- 타임존 설정
SET GLOBAL time_zone = '+09:00'; -- Asia/Seoul

-- 문자셋 확인
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';
```

### 사용자 계정 생성

```sql
-- 읽기 전용 계정
CREATE USER 'app_read'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT ON review_service.* TO 'app_read'@'%';

-- 읽기/쓰기 계정
CREATE USER 'app_write'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE ON review_service.* TO 'app_write'@'%';

-- 크롤러 전용 계정
CREATE USER 'crawler'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE ON review_service.products TO 'crawler'@'%';
GRANT SELECT, INSERT, UPDATE ON review_service.reviews TO 'crawler'@'%';
GRANT SELECT, INSERT, UPDATE ON review_service.product_platform_mappings TO 'crawler'@'%';

FLUSH PRIVILEGES;
```

---

## 📝 주요 쿼리 예시

### 1. 상품 상세 페이지 데이터 조회

```sql
-- 상품 정보
SELECT p.*, p.average_rating, p.total_review_count
FROM products p
WHERE p.id = 123;

-- 플랫폼별 가격 비교
SELECT ppm.platform_id, pl.name, ppm.price, ppm.url, ppm.is_available
FROM product_platform_mappings ppm
JOIN platforms pl ON ppm.platform_id = pl.id
WHERE ppm.product_id = 123
ORDER BY ppm.price ASC;

-- 리뷰 요약
SELECT pros_top3, cons_top3, total_review_count
FROM product_summaries
WHERE product_id = 123;
```

### 2. 리뷰 목록 조회 (광고성 제외 + 단점 상세순)

```sql
SELECT r.*, ra.disadvantage_score, ra.is_sponsored
FROM reviews r
JOIN review_analyses ra ON r.id = ra.review_id
WHERE r.product_id = 123
  AND ra.is_sponsored = FALSE
ORDER BY ra.disadvantage_score DESC
LIMIT 20 OFFSET 0;
```

### 3. 유사 체형 리뷰 조회 (165cm, 55kg 기준)

```sql
SELECT r.*,
  SQRT(POW((r.reviewer_height - 165)/10, 2) + POW((r.reviewer_weight - 55)/5, 2)) AS similarity_distance
FROM reviews r
WHERE r.product_id = 123
  AND r.reviewer_height IS NOT NULL
  AND r.reviewer_weight IS NOT NULL
HAVING similarity_distance < 5
ORDER BY similarity_distance ASC
LIMIT 20;
```

---

## 🔄 마이그레이션 가이드

### 테이블 생성 순서

1. `users`
2. `user_profiles`
3. `platforms`
4. `products`
5. `product_platform_mappings`
6. `product_summaries`
7. `size_insights`
8. `reviews`
9. `review_analyses`
10. `review_keywords`
11. `recent_views`

### 백업 및 복구

```bash
# 전체 백업
mysqldump -u root -p review_service > backup_$(date +%Y%m%d).sql

# 특정 테이블만 백업
mysqldump -u root -p review_service users user_profiles > backup_users_$(date +%Y%m%d).sql

# 복구
mysql -u root -p review_service < backup_20260130.sql
```

---

## 🚧 향후 확장 계획

### v1.1 (출시 후 1개월)
- `user_favorites` 테이블: 찜하기 기능

### v1.2 (출시 후 2개월)
- `price_alerts` 테이블: 가격 알림 기능

### v2.0 (출시 후 6개월)
- 카테고리 확장: 뷰티, 가전, 식품
- `user_profiles` 테이블의 카테고리별 컬럼 활성화
- 카테고리별 인사이트 테이블 추가

### v3.0 (출시 후 12개월)
- 사용자 리뷰 작성 기능
- 커뮤니티 기능

---

## 📚 참고 문서

### 내부 문서
- [PRD (Product Requirements Document)](../prd/review_service_prd.md)
- [v1.0.0 초기 데이터베이스 설계](v1.0.0_initial-database-design.md)

### 외부 참고
- [MySQL 8.0 Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [InnoDB FULLTEXT Index](https://dev.mysql.com/doc/refman/8.0/en/innodb-fulltext-index.html)

---

## 🤝 기여 가이드

### 스키마 변경 프로세스

1. **설계 검토**: `/docs/dba/` 디렉토리의 기존 문서 확인
2. **변경안 작성**: 새로운 버전 문서 생성 (예: `v1.1.0_add-favorites.md`)
3. **DDL 작성**: `init.sql` 업데이트 또는 마이그레이션 SQL 작성
4. **CHANGELOG 업데이트**: `CHANGELOG.md`에 변경 이력 추가
5. **API 가이드 업데이트**: `API_PARAMETER_GUIDE.md`에 새 API 매개변수 추가
6. **ERD 업데이트**: `ERD.md`의 Mermaid 다이어그램 수정

### 문서 작성 규칙

- **버전 형식**: `v{MAJOR}.{MINOR}.{PATCH}` (예: v1.0.0, v1.1.0)
- **파일명**: `v{버전}_{설명}.md` (예: `v1.1.0_add-favorites.md`)
- **언어**: 문서 내용은 한국어, SQL 코드는 영어
- **날짜 형식**: YYYY-MM-DD

---

## ⚠️ 중요 알림

### DDL 실행 책임

**모든 DDL 스크립트 실행은 사용자의 책임입니다.**

- 프로덕션 환경에서 실행 전 반드시 백업 수행
- 스테이징 환경에서 사전 테스트 필수
- 마이그레이션 시 데이터 정합성 검증

### 보안 주의사항

- 데이터베이스 접속 정보를 코드에 하드코딩하지 마세요
- 환경변수 또는 비밀 관리 시스템 사용 권장
- 프로덕션 계정과 개발 계정 분리
- 정기적인 비밀번호 변경

---

## 📞 문의

데이터베이스 관련 문의사항은 DBA 팀에게 연락하세요.

---

**Last Updated**: 2026-01-30
**Version**: v1.0.0
