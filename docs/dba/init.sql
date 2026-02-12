-- ============================================================================
-- 리뷰 모으기 서비스 - 초기 데이터베이스 스키마
-- ============================================================================
-- 버전: v1.0.0
-- 작성일: 2026-01-30
-- 설명: 리뷰 모으기 서비스 MVP(v1.0) 초기 데이터베이스 스키마
-- 참고: docs/dba/v1.0.0_initial-database-design.md
-- ============================================================================

-- 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS review_service
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE review_service;

-- ============================================================================
-- 1. users (사용자)
-- ============================================================================

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '사용자 ID',
  email VARCHAR(255) NOT NULL COMMENT '이메일 주소',
  password_hash VARCHAR(255) NULL COMMENT '비밀번호 해시 (bcrypt, 소셜 로그인 시 NULL)',
  unique_code CHAR(8) NOT NULL COMMENT '사용자 고유 코드 (A-Z0-9 랜덤 8자리)',
  provider ENUM('email', 'google', 'apple', 'kakao') NOT NULL DEFAULT 'email' COMMENT '로그인 제공자',
  provider_id VARCHAR(255) NULL COMMENT '소셜 로그인 제공자 ID',
  email_verified BOOLEAN NOT NULL DEFAULT FALSE COMMENT '이메일 인증 여부',
  email_verification_token VARCHAR(255) NULL COMMENT '이메일 인증 토큰',
  email_verification_expires_at DATETIME NULL COMMENT '이메일 인증 토큰 만료 시각',
  password_reset_token VARCHAR(255) NULL COMMENT '비밀번호 재설정 토큰',
  password_reset_expires_at DATETIME NULL COMMENT '비밀번호 재설정 토큰 만료 시각',
  last_login_at DATETIME NULL COMMENT '마지막 로그인 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',
  deleted_at DATETIME NULL COMMENT '삭제 시각 (soft delete)',

  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  UNIQUE KEY uk_users_unique_code (unique_code),
  UNIQUE KEY uk_users_provider_id (provider, provider_id),
  INDEX idx_users_email_verified (email_verified),
  INDEX idx_users_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='사용자';

-- ============================================================================
-- 2. user_profiles (사용자 프로필)
-- ============================================================================

CREATE TABLE user_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '프로필 ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '사용자 ID',
  category ENUM('fashion', 'beauty', 'electronics', 'food') NOT NULL DEFAULT 'fashion' COMMENT '카테고리',

  -- 패션 프로필 (v1.0)
  height SMALLINT UNSIGNED NULL COMMENT '키 (cm, 100-220)',
  weight SMALLINT UNSIGNED NULL COMMENT '몸무게 (kg, 30-200)',
  usual_size VARCHAR(10) NULL COMMENT '평소 사이즈 (XXS~XXXXXL)',
  body_shape VARCHAR(50) NULL COMMENT '체형 특징',
  foot_size SMALLINT UNSIGNED NULL COMMENT '발 사이즈 (mm, 160-350)',
  foot_width ENUM('narrow', 'normal', 'wide') NULL COMMENT '발볼 (좁음/보통/넓음)',
  foot_arch ENUM('low', 'normal', 'high') NULL COMMENT '발등 (낮음/보통/높음)',

  -- 뷰티 프로필 (v2.0+)
  skin_type ENUM('dry', 'oily', 'combination', 'sensitive') NULL COMMENT '피부타입',
  skin_tone VARCHAR(50) NULL COMMENT '피부톤',
  skin_concerns VARCHAR(255) NULL COMMENT '피부고민 (JSON 배열)',

  -- 가전 프로필 (v2.0+)
  housing_type ENUM('apartment', 'house', 'studio', 'officetel') NULL COMMENT '주거형태',
  family_size TINYINT UNSIGNED NULL COMMENT '가구원수',
  usage_environment VARCHAR(255) NULL COMMENT '사용환경 (JSON)',

  -- 식품 프로필 (v2.0+)
  allergies VARCHAR(255) NULL COMMENT '알러지 정보 (JSON 배열)',
  diet_type VARCHAR(50) NULL COMMENT '식단 유형 (vegan, keto 등)',
  family_composition VARCHAR(100) NULL COMMENT '가족 구성',

  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_user_profiles_user_category (user_id, category),
  INDEX idx_user_profiles_category (category),
  CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='사용자 프로필 (카테고리별)';

-- ============================================================================
-- 3. platforms (플랫폼)
-- ============================================================================

CREATE TABLE platforms (
  id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '플랫폼 ID',
  code VARCHAR(50) NOT NULL COMMENT '플랫폼 코드 (29cm, musinsa, naver)',
  logo_url VARCHAR(255) NULL COMMENT '로고 파일 경로',
  name VARCHAR(100) NOT NULL COMMENT '플랫폼 이름',
  url VARCHAR(255) NOT NULL COMMENT '플랫폼 URL',
  is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT '활성화 여부',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_platforms_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='쇼핑 플랫폼';

-- ============================================================================
-- 4. products (상품)
-- ============================================================================

CREATE TABLE products (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '상품 ID',
  name VARCHAR(500) NOT NULL COMMENT '상품명',
  brand VARCHAR(200) NOT NULL COMMENT '브랜드명',
  category ENUM('fashion', 'beauty', 'electronics', 'food') NOT NULL DEFAULT 'fashion' COMMENT '카테고리',
  sub_category VARCHAR(100) NULL COMMENT '서브 카테고리 (상의, 하의 등)',
  image_url VARCHAR(500) NULL COMMENT '상품 이미지 URL',
  description TEXT NULL COMMENT '상품 설명',
  average_rating DECIMAL(3,2) NULL COMMENT '평균 평점 (0.00-5.00)',
  total_review_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '전체 리뷰 수',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  INDEX idx_products_category (category),
  INDEX idx_products_brand (brand),
  INDEX idx_products_name (name(100)),
  INDEX idx_products_average_rating (average_rating),
  FULLTEXT INDEX ft_products_name_brand (name, brand)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='상품';

-- ============================================================================
-- 5. product_platform_mappings (상품-플랫폼 매핑)
-- ============================================================================

CREATE TABLE product_platform_mappings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '매핑 ID',
  product_id BIGINT UNSIGNED NOT NULL COMMENT '상품 ID',
  platform_id TINYINT UNSIGNED NOT NULL COMMENT '플랫폼 ID',
  external_id VARCHAR(255) NOT NULL COMMENT '외부 플랫폼 상품 ID',
  url VARCHAR(500) NOT NULL COMMENT '상품 페이지 URL',
  price INT UNSIGNED NULL COMMENT '가격 (원)',
  original_price INT UNSIGNED NULL COMMENT '정가 (원)',
  discount_rate TINYINT UNSIGNED NULL COMMENT '할인율 (%)',
  is_available BOOLEAN NOT NULL DEFAULT TRUE COMMENT '구매 가능 여부',
  stock_status ENUM('in_stock', 'low_stock', 'out_of_stock') NOT NULL DEFAULT 'in_stock' COMMENT '재고 상태',
  price_updated_at DATETIME NULL COMMENT '가격 갱신 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_product_platform_mappings (product_id, platform_id),
  INDEX idx_product_platform_mappings_platform (platform_id),
  INDEX idx_product_platform_mappings_price (price),
  INDEX idx_product_platform_mappings_updated (price_updated_at),
  CONSTRAINT fk_product_platform_mappings_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_product_platform_mappings_platform FOREIGN KEY (platform_id) REFERENCES platforms(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='상품-플랫폼 매핑 (가격 비교)';

-- ============================================================================
-- 6. reviews (리뷰)
-- ============================================================================

CREATE TABLE reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '리뷰 ID',
  product_id BIGINT UNSIGNED NOT NULL COMMENT '상품 ID',
  platform_id TINYINT UNSIGNED NOT NULL COMMENT '플랫폼 ID',
  external_review_id VARCHAR(255) NOT NULL COMMENT '외부 플랫폼 리뷰 ID',
  reviewer_name VARCHAR(100) NOT NULL COMMENT '리뷰어 이름 (마스킹 처리)',
  content TEXT NOT NULL COMMENT '리뷰 내용',
  rating TINYINT UNSIGNED NOT NULL COMMENT '평점 (1-5)',
  purchase_option VARCHAR(255) NULL COMMENT '구매 옵션 (사이즈, 색상 등)',
  has_images BOOLEAN NOT NULL DEFAULT FALSE COMMENT '이미지 포함 여부',
  image_urls TEXT NULL COMMENT '리뷰 이미지 URL (JSON 배열)',

  -- 패션 카테고리 추가 정보
  reviewer_height SMALLINT UNSIGNED NULL COMMENT '리뷰어 키 (cm)',
  reviewer_weight SMALLINT UNSIGNED NULL COMMENT '리뷰어 몸무게 (kg)',
  size_feedback ENUM('small', 'perfect', 'large') NULL COMMENT '사이즈 피드백',

  reviewed_at DATETIME NOT NULL COMMENT '리뷰 작성일',
  collected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '수집 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_reviews_platform_external (platform_id, external_review_id),
  INDEX idx_reviews_product (product_id),
  INDEX idx_reviews_rating (rating),
  INDEX idx_reviews_reviewed_at (reviewed_at),
  INDEX idx_reviews_has_images (has_images),
  INDEX idx_reviews_size_feedback (size_feedback),
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_platform FOREIGN KEY (platform_id) REFERENCES platforms(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='리뷰';

-- ============================================================================
-- 7. review_analyses (리뷰 분석)
-- ============================================================================

CREATE TABLE review_analyses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '분석 ID',
  review_id BIGINT UNSIGNED NOT NULL COMMENT '리뷰 ID',
  is_sponsored BOOLEAN NOT NULL DEFAULT FALSE COMMENT '광고성 여부',
  sponsored_confidence DECIMAL(5,4) NULL COMMENT '광고성 판별 신뢰도 (0.0000-1.0000)',
  disadvantage_score INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '단점 상세도 점수',
  disadvantage_keywords TEXT NULL COMMENT '단점 키워드 (JSON 배열)',
  advantage_keywords TEXT NULL COMMENT '장점 키워드 (JSON 배열)',
  sentiment_score DECIMAL(5,4) NULL COMMENT '감성 점수 (-1.0000~1.0000)',
  analyzed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '분석 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_review_analyses_review (review_id),
  INDEX idx_review_analyses_sponsored (is_sponsored),
  INDEX idx_review_analyses_disadvantage_score (disadvantage_score),
  CONSTRAINT fk_review_analyses_review FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='리뷰 분석';

-- ============================================================================
-- 8. review_keywords (리뷰 키워드)
-- ============================================================================

CREATE TABLE review_keywords (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '키워드 ID',
  review_id BIGINT UNSIGNED NOT NULL COMMENT '리뷰 ID',
  keyword VARCHAR(100) NOT NULL COMMENT '키워드',
  type ENUM('advantage', 'disadvantage', 'neutral') NOT NULL COMMENT '키워드 타입',
  frequency TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '리뷰 내 언급 횟수',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',

  PRIMARY KEY (id),
  INDEX idx_review_keywords_review (review_id),
  INDEX idx_review_keywords_keyword (keyword),
  INDEX idx_review_keywords_type (type),
  CONSTRAINT fk_review_keywords_review FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='리뷰 키워드';

-- ============================================================================
-- 9. product_summaries (상품 요약)
-- ============================================================================

CREATE TABLE product_summaries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '요약 ID',
  product_id BIGINT UNSIGNED NOT NULL COMMENT '상품 ID',
  pros_top3 TEXT NOT NULL COMMENT '장점 Top 3 (JSON 배열: [{keyword, count}])',
  cons_top3 TEXT NOT NULL COMMENT '단점 Top 3 (JSON 배열: [{keyword, count}])',
  total_review_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '분석 대상 리뷰 수',
  sponsored_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '광고성 리뷰 수',
  genuine_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '진성 리뷰 수',
  average_disadvantage_score DECIMAL(8,2) NULL COMMENT '평균 단점 상세도 점수',
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '요약 생성 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_product_summaries_product (product_id),
  INDEX idx_product_summaries_generated_at (generated_at),
  CONSTRAINT fk_product_summaries_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='상품 리뷰 요약';

-- ============================================================================
-- 10. size_insights (사이즈 인사이트)
-- ============================================================================

CREATE TABLE size_insights (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '인사이트 ID',
  product_id BIGINT UNSIGNED NOT NULL COMMENT '상품 ID',
  size VARCHAR(10) NOT NULL COMMENT '사이즈 (S, M, L 등)',
  purchase_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '해당 사이즈 구매 건수',
  purchase_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '구매 비율 (%, 0.00-100.00)',
  fit_small_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '작음 피드백 수',
  fit_perfect_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '적당 피드백 수',
  fit_large_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '큼 피드백 수',
  fit_small_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '작음 비율 (%)',
  fit_perfect_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '적당 비율 (%)',
  fit_large_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '큼 비율 (%)',
  average_height DECIMAL(5,2) NULL COMMENT '평균 키 (cm)',
  average_weight DECIMAL(5,2) NULL COMMENT '평균 몸무게 (kg)',
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',

  PRIMARY KEY (id),
  UNIQUE KEY uk_size_insights_product_size (product_id, size),
  INDEX idx_size_insights_generated_at (generated_at),
  CONSTRAINT fk_size_insights_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='사이즈 인사이트 (패션)';

-- ============================================================================
-- 11. recent_views (최근 본 상품)
-- ============================================================================

CREATE TABLE recent_views (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '조회 이력 ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '사용자 ID',
  product_id BIGINT UNSIGNED NOT NULL COMMENT '상품 ID',
  viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '조회 시각',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',

  PRIMARY KEY (id),
  INDEX idx_recent_views_user_viewed (user_id, viewed_at DESC),
  INDEX idx_recent_views_product (product_id),
  CONSTRAINT fk_recent_views_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_recent_views_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='최근 본 상품';

-- ============================================================================
-- 초기 데이터 삽입
-- ============================================================================

-- 플랫폼 데이터
INSERT INTO platforms (code, name, url, is_active) VALUES
('29cm', '29CM', 'https://www.29cm.co.kr', TRUE),
('musinsa', '무신사', 'https://www.musinsa.com', TRUE),
('naver', '네이버 스마트스토어', 'https://smartstore.naver.com', TRUE);

-- ============================================================================
-- 완료
-- ============================================================================

-- 테이블 생성 확인
SELECT
  TABLE_NAME AS '테이블명',
  TABLE_ROWS AS '예상 행 수',
  TABLE_COLLATION AS '콜레이션'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'review_service'
ORDER BY TABLE_NAME;
