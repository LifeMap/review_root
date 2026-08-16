# CI/CD 표준

리뷰 모으기 서비스의 배포 파이프라인 표준입니다.

---

## 목차

1. [브랜치 전략](#1-브랜치-전략)
2. [로컬 빌드 필수 규칙](#2-로컬-빌드-필수-규칙)
3. [GitHub Actions 워크플로](#3-github-actions-워크플로)
4. [헬스체크 엔드포인트 규약](#4-헬스체크-엔드포인트-규약)
5. [배포 실패 시 롤백 절차](#5-배포-실패-시-롤백-절차)

---

## 1. 브랜치 전략

### 브랜치 구성

| 브랜치 | 목적 | 배포 대상 |
|--------|------|-----------|
| `main` | 운영 릴리즈 | 운영(prod) 서버 |
| `dev` | 통합 테스트, QA | 개발(dev) 서버 |
| `feature/*` | 기능 개발 | 없음 (로컬만) |
| `fix/*` | 버그 수정 | 없음 (로컬만) |

### 기본 워크플로

```
feature/foo 브랜치 생성
    │
    ├── 로컬에서 개발
    ├── pnpm typecheck
    ├── pnpm lint
    ├── pnpm test
    └── pnpm build  ← 반드시 로컬에서 성공 확인
            │
            ▼
    dev 브랜치로 Pull Request / Merge
            │
            ▼
    GitHub Actions: deploy-dev.yml 자동 실행
            │
            ▼
    QA/테스트 통과
            │
            ▼
    main 브랜치로 Pull Request / Merge
            │
            ▼
    GitHub Actions: deploy-prod.yml 자동 실행
```

### 브랜치 보호 규칙 (권장)

권장: GitHub 저장소 설정에서 다음 브랜치 보호 규칙을 적용하는 것을 권장합니다.

| 브랜치 | 규칙 |
|--------|------|
| `main` | PR 필수, 직접 push 금지, 1명 이상 리뷰 승인 필요 |
| `dev` | PR 권장 |

---

## 2. 로컬 빌드 필수 규칙

**dev 또는 main 브랜치에 push하기 전에 반드시 로컬에서 `pnpm build`를 성공적으로 완료해야 합니다.**

이 규칙은 프로젝트 워크플로 규칙(`CLAUDE.md`)에 명시된 필수 사항입니다.

### 빌드 전 체크리스트

```bash
# app/web/ 디렉터리에서 순서대로 실행
cd app/web

# 1. 타입 체크 (TypeScript 오류 없음 확인)
pnpm typecheck

# 2. 린트 (코드 스타일 검사)
pnpm lint

# 3. 테스트 (테스트가 있는 경우)
pnpm test

# 4. 빌드 (Next.js standalone 빌드 성공 확인)
pnpm build
```

빌드 성공 시:
```
✓ Compiled successfully
✓ Linting and checking validity of types
Route (app) ...
```

### 빌드가 실패하는 주요 원인

| 원인 | 해결 방법 |
|------|-----------|
| TypeScript 타입 오류 | `pnpm typecheck` 결과 확인 후 타입 수정 |
| 런타임 환경변수 빌드 타임 사용 | `export const dynamic = 'force-dynamic'` 추가 |
| 서버 전용 모듈 클라이언트에서 import | 모듈 분리 또는 `serverExternalPackages` 확인 |
| `next.config.ts` 설정 오류 | 설정 파일 검토 |

### next.config.ts 주요 설정

```typescript
// app/web/next.config.ts
const nextConfig = {
  output: 'standalone',  // Docker 이미지 최적화
  serverExternalPackages: ['openai', 'bullmq', 'ioredis'],  // 서버 전용 패키지
};
```

---

## 3. GitHub Actions 워크플로

### deploy-dev.yml 단계별 설명

파일 위치: `app/.github/workflows/deploy-dev.yml`
트리거: `dev` 브랜치 push

| 단계 | 이름 | 설명 |
|------|------|------|
| 1 | Checkout code | 저장소 코드 체크아웃 |
| 2 | Setup SSH key | GitHub Secret에서 SSH PEM 키 설정, known_hosts 등록 |
| 3 | Create .env.dev | GitHub Secret `DEV_ENV`를 `infra/scripts/.env.dev` 파일로 저장 |
| 4 | Clean up disk space | dev 서버 SSH 접속 → `docker system prune -af` 실행 |
| 5 | Sync code to server | rsync로 코드 동기화 (node_modules, .next, .git 제외) |
| 6 | Build and restart services | SSH로 서버 접속 → `.env` 복사 → docker compose down/build/up |
| 7 | Health check | `GET /api/v1/health` HTTP 200 확인 |

```yaml
# 핵심 단계 요약
- name: Sync code to server
  run: |
    rsync -avz --delete \
      --exclude 'node_modules' \
      --exclude '.next' \
      --exclude '.git' \
      --exclude '*.log' \
      -e "ssh -i ~/.ssh/deploy.pem" \
      ./ "$USER@$HOST:/home/$USER/app/"

- name: Build and restart services
  run: |
    ssh -i ~/.ssh/deploy.pem "$USER@$HOST" << 'EOF'
    cd ~/app/infra
    cp scripts/.env.dev .env
    docker compose -f docker-compose.dev.yml down || true
    docker compose -f docker-compose.dev.yml build --no-cache
    docker compose -f docker-compose.dev.yml up -d
    sleep 30
    EOF
```

### deploy-prod.yml 단계별 설명

파일 위치: `app/.github/workflows/deploy-prod.yml`
트리거: `main` 브랜치 push

dev와 동일한 흐름이지만 다음이 다릅니다:

| 항목 | dev | prod |
|------|-----|------|
| 트리거 브랜치 | `dev` | `main` |
| SSH Secret | `DEV_SSH_KEY` | `PROD_SSH_KEY` |
| 호스트 Secret | `DEV_HOST` | `PROD_HOST` |
| 사용자 Secret | `DEV_USER` | `PROD_USER` |
| 환경 Secret | `DEV_ENV` | `PROD_ENV` |
| 환경 파일명 | `.env.dev` | `.env.prod` |
| Compose 파일 | `docker-compose.dev.yml` | `docker-compose.prod.yml` |
| 빌드 옵션 | `build --no-cache` | `build` (디스크 정리 스텝 없음) |

### 필요한 GitHub Secrets 전체 목록

GitHub 저장소 > Settings > Secrets and variables > Actions에 등록:

| Secret명 | 용도 |
|----------|------|
| `DEV_SSH_KEY` | dev 서버 PEM 키 |
| `DEV_HOST` | dev 서버 IP/도메인 |
| `DEV_USER` | dev 서버 SSH 사용자 |
| `DEV_ENV` | dev 환경변수 파일 전체 내용 |
| `PROD_SSH_KEY` | prod 서버 PEM 키 |
| `PROD_HOST` | prod 서버 IP/도메인 |
| `PROD_USER` | prod 서버 SSH 사용자 |
| `PROD_ENV` | prod 환경변수 파일 전체 내용 |

---

## 4. 헬스체크 엔드포인트 규약

### 엔드포인트 스펙

```
GET /api/v1/health
```

| 항목 | 값 |
|------|-----|
| 메서드 | GET |
| 인증 | 불필요 |
| 성공 응답 | HTTP 200 |
| 실패 응답 | HTTP 5xx 또는 타임아웃 |

### 활용처

| 활용 | 설정 위치 |
|------|-----------|
| Docker Compose healthcheck | `docker-compose.dev.yml` web 서비스 |
| GitHub Actions 배포 검증 | `deploy-dev.yml`, `deploy-prod.yml` 마지막 단계 |
| 운영 모니터링 cron | 서버의 헬스체크 스크립트 |

### Docker Compose healthcheck 설정

```yaml
# app/infra/docker-compose.dev.yml
web:
  healthcheck:
    test: ['CMD-SHELL', 'wget -qO- http://localhost:3000/api/v1/health || exit 1']
    interval: 15s
    timeout: 10s
    retries: 5
    start_period: 30s  # 초기 기동 시간 허용
```

### GitHub Actions 헬스체크 스크립트

```bash
# deploy-dev.yml / deploy-prod.yml 공통
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:3000/api/v1/health")
if [ "$STATUS" = "200" ]; then
  echo "Health check passed!"
else
  echo "Health check failed with status: $STATUS"
  exit 1  # 워크플로 실패 처리
fi
```

### 헬스체크 응답 형식

**현행 (Current):** `GET /api/v1/health` 응답은 단순 형식입니다 (`app/web/src/app/api/v1/health/route.ts` 기준).

```json
{
  "success": true,
  "data": { "status": "ok", "timestamp": "2026-05-26T00:00:00.000Z" }
}
```

**권장 (Recommendation):** DB·Redis·Elasticsearch 연결 상태를 포함하는 확장 형식으로 개선하세요. 키 이름은 `dependencies`로 통일합니다 (api-standards.md §13과 일치).

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "timestamp": "2026-05-26T00:00:00.000Z",
    "dependencies": {
      "database": "ok",
      "redis": "ok",
      "elasticsearch": "ok"
    }
  }
}
```

---

## DB 마이그레이션 및 롤백 절차

배포 파이프라인에서 코드 변경과 DB 스키마 변경은 항상 함께 진행됩니다. 아래 절차를 통해 마이그레이션을 안전하게 적용하고 실패 시 복구합니다.

### 도구 및 마이그레이션 파일 위치

| 항목 | 값 |
|------|-----|
| 마이그레이션 도구 | drizzle-kit `0.31.8` |
| 스키마 정의 위치 | `app/web/src/services/db/schema/` |
| 마이그레이션 파일 위치 | `app/web/drizzle/` (drizzle.config.ts의 `out: './drizzle'` 설정 기준) |
| drizzle 설정 파일 | `app/web/drizzle.config.ts` |

### 마이그레이션 생성 및 적용 명령어

```bash
# 마이그레이션 파일 생성 (스키마 변경 후 실행)
# 실행 위치: app/web/
pnpm exec drizzle-kit generate

# 마이그레이션 적용 (로컬/개발 환경)
pnpm exec drizzle-kit migrate

# 마이그레이션 현황 확인
pnpm exec drizzle-kit studio  # 브라우저 기반 스키마 뷰어
```

### 배포 흐름에서 마이그레이션 적용 시점

마이그레이션은 **앱 컨테이너 기동 직전** 1회 실행해야 합니다. 아래 두 가지 방식 중 하나를 선택합니다.

**권장: 별도 단계로 분리 (배포 파이프라인)**

```yaml
# deploy-prod.yml 또는 deploy-dev.yml — 마이그레이션 단계 추가 예시
- name: Run DB migration
  run: |
    ssh -i ~/.ssh/deploy.pem "$USER@$HOST" << 'EOF'
    cd ~/app/web
    # 환경변수 로드 후 마이그레이션 적용
    export $(cat ../infra/.env | xargs)
    pnpm exec drizzle-kit migrate
    # 마이그레이션 실패 시 이 단계에서 exit code != 0 → 배포 중단
    EOF
```

마이그레이션 단계가 실패하면 GitHub Actions 워크플로가 중단되어 이후 컨테이너 기동 단계가 실행되지 않습니다.

**대안: 웹 컨테이너 entrypoint에서 1회 실행**

```dockerfile
# Dockerfile 또는 docker-compose entrypoint 예시
ENTRYPOINT ["sh", "-c", "pnpm exec drizzle-kit migrate && node server.js"]
```

이 방식은 롤백이 어려우므로 운영 환경에서는 별도 단계 방식을 권장합니다.

### 롤백 방법

drizzle-kit에는 자동 down 마이그레이션 기능이 없습니다. 운영 환경은 **forward-only 원칙**을 따릅니다.

**일반 롤백 절차 (forward-only)**

1. 직전 마이그레이션의 변경을 역방향으로 되돌리는 새 마이그레이션 파일을 작성합니다.
2. `pnpm exec drizzle-kit generate`로 해당 마이그레이션을 파일로 생성합니다.
3. 리뷰 후 배포 파이프라인으로 적용합니다.

**데이터 손실이 발생할 수 있는 변경 처리 (expand/contract 패턴)**

| 단계 | 설명 | 예시 |
|------|------|------|
| Expand | 새 컬럼/구조를 기존에 추가 (NOT NULL 없이) | `ALTER TABLE ... ADD COLUMN new_col VARCHAR(255) NULL` |
| Migrate data | 앱 코드에서 양쪽 구조를 동시에 지원 | 신·구 컬럼 모두 읽기/쓰기 |
| Contract | 구 컬럼 제거 | `ALTER TABLE ... DROP COLUMN old_col` |

NOT NULL 추가, 컬럼 삭제, 컬럼 타입 변경 등 위험한 변경은 반드시 이 패턴으로 3단계에 걸쳐 진행합니다.

**긴급 롤백 (마지막 수단)**

```sql
-- 1. 직접 SQL로 변경 역적용
ALTER TABLE ... DROP COLUMN ...; -- 또는 원래 상태로 복구

-- 2. drizzle_migrations 테이블에서 해당 마이그레이션 row 삭제
-- (drizzle-kit이 이미 적용된 것으로 인식하지 않도록 초기화)
DELETE FROM __drizzle_migrations WHERE hash = '<마이그레이션-해시>';
```

이 방법은 drizzle-kit의 마이그레이션 이력과 실제 DB 스키마가 불일치하게 됩니다. 적용 후 반드시 `drizzle-kit generate`로 현재 스키마 상태를 재동기화하세요.

### 배포 전 사전 점검 체크리스트

```
[ ] 운영 DB 백업이 최근 24시간 이내로 존재하는가
[ ] 변경 영향도 분석: 영향받는 테이블, 예상 Lock 시간, 데이터 볼륨 확인
[ ] NOT NULL 추가, 컬럼 삭제, 타입 변경 등 위험 변경 → expand/contract 패턴 적용했는가
[ ] 다운타임이 필요한 변경인가 (필요 시 유지보수 모드 계획 수립)
[ ] 마이그레이션 파일을 로컬/개발 환경에서 먼저 검증했는가
[ ] 롤백 SQL을 사전에 준비했는가
```

### 변경 유형별 위험도 및 권장 절차

| 변경 유형 | 위험도 | 권장 절차 |
|---------|--------|---------|
| 새 테이블 추가 | Safe | 일반 마이그레이션 |
| NULL 허용 컬럼 추가 | Safe | 일반 마이그레이션 |
| 인덱스 추가 | Safe | 일반 마이그레이션 (대용량 테이블은 `ALGORITHM=INPLACE` 옵션 고려) |
| NOT NULL 컬럼 추가 (기본값 없음) | Risky | expand/contract 패턴 — 먼저 NULL로 추가 후 데이터 채우고 NOT NULL 적용 |
| 컬럼 타입 변경 | Risky | expand/contract 패턴 — 신 컬럼 추가 후 데이터 이전, 구 컬럼 삭제 |
| 컬럼 삭제 | Destructive | expand/contract 패턴 — 앱에서 참조 제거 후 별도 배포에서 삭제 |
| 테이블 삭제 | Destructive | 데이터 백업 확인 후 별도 배포, 30일 이상 유예 권장 |
| 외래키 추가 | Risky | 기존 데이터 정합성 검증 후 적용, 대용량은 Lock 주의 |

---

## 5. 배포 실패 시 롤백 절차

### 자동 실패 감지

GitHub Actions 헬스체크가 실패하면 워크플로가 `exit 1`로 종료되어 GitHub Actions 상태가 실패(Failed)로 표시됩니다.
이 경우 서버에는 이미 새 버전이 배포된 상태입니다.

### 롤백 방법 1: git revert (권장)

```bash
# 로컬에서 이전 커밋으로 revert
git revert HEAD
git push origin dev    # dev 환경 롤백
# 또는
git push origin main   # prod 환경 롤백

# → GitHub Actions가 자동으로 이전 버전으로 재배포
```

### 롤백 방법 2: 서버에서 직접 롤백

긴급 상황 또는 GitHub Actions 없이 즉시 롤백해야 할 경우:

```bash
# SSH로 서버 접속
ssh -i ~/.ssh/prod-key.pem ec2-user@<PROD_HOST>

cd ~/app

# 현재 코드 이력 확인
git log --oneline -5

# 이전 커밋으로 이동
git checkout <이전-커밋-해시>

# 서비스 재빌드 및 재시작
cd infra
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

# 헬스체크 확인
curl http://localhost:3000/api/v1/health
```

### 롤백 후 복구 절차

1. 이전 버전으로 롤백 완료 및 헬스체크 통과 확인
2. 실패 원인 분석 (GitHub Actions 로그, 서버 컨테이너 로그)
3. 코드 수정 후 로컬에서 `pnpm build` 성공 확인
4. 수정된 코드로 재배포 (dev에서 검증 후 prod 적용)

### 배포 이력 추적

GitHub Actions 탭에서 모든 배포 이력을 확인할 수 있습니다.
각 배포의 커밋 SHA, 실행 시간, 성공/실패 여부가 기록됩니다.

```
저장소 > Actions > Deploy to Dev Server (또는 Prod Server)
```

### 도커 이미지 버전 관리 (권장)

권장: 현재 구성은 매 배포 시 `--no-cache` 빌드를 수행하여 이전 이미지로의 즉각적인 롤백이 어렵습니다.
다음 개선을 권장합니다:

```yaml
# 커밋 SHA를 이미지 태그로 사용
- name: Build and restart services
  run: |
    IMAGE_TAG=${{ github.sha }}
    docker build -t review-web:${IMAGE_TAG} app/web/
    docker tag review-web:${IMAGE_TAG} review-web:latest
    # 이전 태그 이미지를 유지하여 빠른 롤백 가능
```
