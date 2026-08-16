# 로컬 개발 환경 설정

개발자 PC에서 리뷰 모으기 서비스 전체 스택을 실행하는 방법을 안내합니다.
Docker Compose를 사용해 MySQL, Redis, Elasticsearch, Next.js 앱, BullMQ 워커를 모두 로컬에서 구동합니다.

---

## 목차

1. [사전 요구사항](#1-사전-요구사항)
2. [최초 셋업 절차](#2-최초-셋업-절차)
3. [서비스 포트 매핑](#3-서비스-포트-매핑)
4. [DB 초기화](#4-db-초기화)
5. [자주 쓰는 명령어](#5-자주-쓰는-명령어)

---

## 1. 사전 요구사항

| 도구 | 버전 | 확인 명령어 |
|------|------|-------------|
| Docker Desktop | 최신 안정 버전 | `docker --version` |
| Docker Compose | v2.x (Docker Desktop 포함) | `docker compose version` |
| Node.js | 20 LTS (상세: `infra-standards.md` 참조) | `node --version` |
| pnpm | 최신 버전 | `pnpm --version` |

### pnpm 설치 (corepack 사용)

```bash
# Node.js 16.13+ 에서는 corepack이 기본 포함됨
corepack enable
corepack prepare pnpm@latest --activate

# 설치 확인
pnpm --version
```

### Docker Desktop 메모리 설정

Elasticsearch는 기본적으로 512MB 이상의 메모리를 사용합니다.
Docker Desktop > Settings > Resources에서 메모리를 **최소 4GB** 이상으로 설정하세요.

---

## 2. 최초 셋업 절차

### 1단계: 저장소 클론

```bash
git clone <repo-url>
cd reviews/app
```

### 2단계: 환경변수 파일 작성

```bash
cd infra
cp .env.example .env
```

`.env` 파일을 열어 실제 값을 입력합니다.

```bash
# 필수 변경 항목 (예시값으로 시작해도 로컬 구동 가능)
MYSQL_ROOT_PASSWORD=localrootpass
MYSQL_USER=review_user
MYSQL_PASSWORD=localpass
MYSQL_DATABASE=review_service

JWT_SECRET=local-jwt-secret-at-least-32-chars-long
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=local-nextauth-secret

ENCRYPTION_KEY=local-aes-256-key-must-be-32bytes!

# 외부 서비스는 실제 키 필요
OPENAI_API_KEY=sk-...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

주의: `.env` 파일은 절대 git에 커밋하지 않습니다.

### 3단계: 의존성 설치

```bash
# 프로젝트 루트(app/)에서
pnpm install
```

또는 웹 앱 디렉터리에서:

```bash
cd web
pnpm install
```

### 4단계: 인프라 서비스 기동

```bash
# app/infra/ 디렉터리에서 실행
cd infra
docker compose -f docker-compose.dev.yml up -d
```

처음 실행 시 이미지 풀(Pull)과 빌드에 수 분이 소요됩니다.
Elasticsearch는 기동에 30~60초가 필요합니다.

서비스 상태 확인:

```bash
docker compose -f docker-compose.dev.yml ps
```

모든 서비스의 `STATUS`가 `Up (healthy)` 상태인지 확인합니다.

### 5단계: 헬스체크 확인

```bash
curl http://localhost:3000/api/v1/health
```

HTTP 200 응답이 오면 정상입니다.

---

## 3. 서비스 포트 매핑

| 서비스 | 컨테이너명 | 로컬 포트 | 컨테이너 포트 | 비고 |
|--------|------------|-----------|---------------|------|
| MySQL 8.0 | `review-mysql` | 3306 | 3306 | utf8mb4, mysql_native_password |
| Redis 7 | `review-redis` | 6379 | 6379 | BullMQ 백엔드 |
| Elasticsearch 8.12.0 | `review-elasticsearch` | 9200 | 9200 | 단일노드, xpack 비활성화 |
| Next.js 앱 | `review-web` | 3000 | 3000 | Next.js standalone |
| BullMQ 워커 | `review-workers` | 없음 | 없음 | 외부 포트 없음 |

### 서비스별 접속 확인

```bash
# MySQL 접속 테스트
docker exec -it review-mysql mysql -u review_user -p review_service

# Redis 접속 테스트
docker exec -it review-redis redis-cli ping
# 응답: PONG

# Elasticsearch 클러스터 상태 확인
curl http://localhost:9200/_cluster/health?pretty

# Next.js 헬스체크
curl http://localhost:3000/api/v1/health
```

---

## 4. DB 초기화

### 자동 초기화

`docker-compose.dev.yml`에 초기화 스크립트가 마운트되어 있습니다.

```yaml
volumes:
  - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
```

MySQL 컨테이너가 처음 생성될 때 `app/infra/init.sql`이 자동으로 실행됩니다.

### 수동 초기화 (볼륨 초기화 후 재실행)

```bash
# 볼륨 포함 전체 정리
docker compose -f docker-compose.dev.yml down -v

# 재시작 (init.sql 자동 실행됨)
docker compose -f docker-compose.dev.yml up -d
```

### SQL 파일로 직접 적용

```bash
# init.sql 수동 실행
docker exec -i review-mysql mysql \
  -u root -p${MYSQL_ROOT_PASSWORD} review_service \
  < ./init.sql
```

### DB 스키마 확인

```bash
docker exec -it review-mysql mysql \
  -u review_user -p${MYSQL_PASSWORD} review_service \
  -e "SHOW TABLES;"
```

---

## 5. 자주 쓰는 명령어

### 서비스 관리

```bash
# 모든 서비스 시작 (백그라운드)
docker compose -f docker-compose.dev.yml up -d

# 모든 서비스 정지
docker compose -f docker-compose.dev.yml down

# 볼륨 포함 완전 삭제 (DB 데이터 초기화)
docker compose -f docker-compose.dev.yml down -v

# 서비스 상태 확인
docker compose -f docker-compose.dev.yml ps

# 특정 서비스만 재시작
docker compose -f docker-compose.dev.yml restart web
docker compose -f docker-compose.dev.yml restart workers
```

### 이미지 재빌드

```bash
# web 이미지 재빌드 후 재시작
docker compose -f docker-compose.dev.yml build web
docker compose -f docker-compose.dev.yml up -d web

# 캐시 없이 전체 재빌드
docker compose -f docker-compose.dev.yml build --no-cache
```

### 로그 확인

```bash
# 모든 서비스 로그 (실시간)
docker compose -f docker-compose.dev.yml logs -f

# 특정 서비스 로그
docker logs -f review-web
docker logs -f review-workers
docker logs -f review-mysql

# 최근 N줄
docker logs --tail 100 review-web
```

### Next.js 개발 서버 (컨테이너 없이 실행)

인프라 서비스(MySQL, Redis, ES)는 Docker로 실행하고, Next.js만 로컬에서 실행하는 방법입니다.
빠른 핫리로드가 필요할 때 유용합니다.

```bash
# 인프라 서비스만 시작 (web, workers 제외)
docker compose -f docker-compose.dev.yml up -d mysql redis elasticsearch

# web 디렉터리에서 Next.js 개발 서버 실행
cd web
pnpm dev
```

`app/web/.env.local` 또는 `app/web/.env` 파일에 로컬 접속 URL을 설정합니다:

```bash
DATABASE_URL=mysql://review_user:localpass@localhost:3306/review_service
REDIS_URL=redis://localhost:6379
ELASTICSEARCH_URL=http://localhost:9200
```

### 디스크 정리

```bash
# 사용하지 않는 이미지/컨테이너/네트워크 정리
docker system prune -f

# 볼륨 포함 전체 정리 (주의: DB 데이터 삭제됨)
docker system prune -af --volumes
```

### pnpm 명령어

```bash
# 타입 체크
cd app/web && pnpm typecheck

# 린트
cd app/web && pnpm lint

# 테스트
cd app/web && pnpm test

# 빌드 (push 전 로컬에서 반드시 실행)
cd app/web && pnpm build
```

### 트러블슈팅

**Elasticsearch 기동 실패 시:**

```bash
# 가상 메모리 설정 (Linux/macOS)
docker exec -it review-elasticsearch sysctl -w vm.max_map_count=262144

# 컨테이너 재시작
docker compose -f docker-compose.dev.yml restart elasticsearch
```

**포트 충돌 시:**

```bash
# 사용 중인 포트 확인 (macOS)
lsof -i :3306
lsof -i :6379
lsof -i :9200
lsof -i :3000
```

**컨테이너가 healthy 상태가 되지 않을 때:**

```bash
# 헬스체크 상세 확인
docker inspect review-web | grep -A 10 '"Health"'

# 컨테이너 내부 접속
docker exec -it review-web sh
```
