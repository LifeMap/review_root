# 인프라 표준 문서

리뷰 모으기 서비스의 인프라 구성 원칙과 표준을 정의합니다.

---

## 목차

1. [환경 구성 개요](#1-환경-구성-개요)
2. [기술 스택](#2-기술-스택)
3. [네트워크 구성 원칙](#3-네트워크-구성-원칙)
4. [시크릿 및 환경변수 관리 원칙](#4-시크릿-및-환경변수-관리-원칙)
5. [로깅 / 모니터링 / 알림 표준](#5-로깅--모니터링--알림-표준)
6. [백업 및 복구 정책](#6-백업-및-복구-정책)

---

## 1. 환경 구성 개요

서비스는 로컬 / 개발(dev) / 운영(prod) 세 환경으로 분리됩니다.

| 환경 | 목적 | 배포 방법 | 도메인 |
|------|------|-----------|--------|
| **로컬 (local)** | 개발자 PC에서 개발 및 테스트 | `docker compose up` | `localhost:3000` |
| **개발 (dev)** | 통합 테스트, QA, 데모 | `dev` 브랜치 push → GitHub Actions | dev 서버 IP:3000 |
| **운영 (prod)** | 실제 서비스 운영 | `main` 브랜치 push → GitHub Actions | 서비스 도메인 |

### 환경별 구성 비교

| 구성요소 | 로컬 | 개발 | 운영 |
|---------|------|------|------|
| 앱 서버 (web) | Docker 컨테이너 | EC2 t3.medium + Docker | EC2 + Docker (권장: ALB 추가) |
| DB (MySQL 8.0) | Docker 컨테이너 | EC2 내장 Docker MySQL | EC2 내장 Docker MySQL (권장: RDS Multi-AZ) |
| 캐시 (Redis 7) | Docker 컨테이너 | EC2 내장 Docker Redis | EC2 내장 Docker Redis |
| 검색 (Elasticsearch 8.12.0) | Docker 컨테이너 | EC2 내장 Docker ES | EC2 내장 Docker ES |
| 워커 (BullMQ + Playwright) | Docker 컨테이너 | EC2 내장 Docker workers | EC2 내장 Docker workers |
| 파일 저장 | 로컬 볼륨 | AWS S3 | AWS S3 |
| CI/CD | 수동 | GitHub Actions | GitHub Actions |
| 모니터링 | 로그 출력 | Slack 알림 | Slack 알림 + CloudWatch |

---

## 2. 기술 스택

### 컨테이너화

| 도구 | 버전 | 용도 |
|------|------|------|
| Docker | 최신 안정 버전 | 컨테이너 런타임 |
| Docker Compose | v2.24.0+ | 멀티 컨테이너 오케스트레이션 |

**컨테이너 구성 파일:**
- `app/infra/docker-compose.dev.yml` — 로컬 및 dev 환경
- `app/infra/docker-compose.prod.yml` — 운영 환경

**Node.js 버전 기준점:**
- **Node.js 20 LTS** (이미지: `node:20-alpine` for web, `node:20-slim` for workers/Playwright)

**Dockerfile:**
- `app/web/Dockerfile` — Next.js 멀티스테이지 빌드 (node:20-alpine, standalone 출력)
- `app/web/Dockerfile.workers` — BullMQ 워커 (node:20-slim, Playwright Chromium 포함)

### IaC (Infrastructure as Code)

| 도구 | 버전 | 용도 |
|------|------|------|
| Terraform | >= 1.0 | AWS 리소스 프로비저닝 |
| AWS Provider | ~5.0 | Terraform AWS 프로바이더 |

**Terraform 파일 위치:** `app/infra/aws/`

| 파일 | 역할 |
|------|------|
| `main.tf` | VPC, IGW, 서브넷, 보안 그룹, EC2, Elastic IP 정의 |
| `variables.tf` | 입력 변수 선언 (리전, 프로젝트명, 환경, 인스턴스 타입 등) |
| `outputs.tf` | 출력값 (EC2 ID, 퍼블릭 IP, SSH 명령어, 앱 URL) |
| `user-data.sh` | EC2 초기 설정 스크립트 (Docker, Docker Compose, Node.js, pnpm, swap 설정) |
| `terraform.tfvars.example` | 변수 값 예시 파일 |

기본 설정값:
- 리전(Region): `ap-northeast-2` (서울)
- 프로젝트명: `reviews`
- EC2 인스턴스 타입: `t3.medium`

**환경 분리 방식 (D6 결정):**

현행: 단일 `app/infra/aws/main.tf` + variables.tf/outputs.tf 파일 구조를 유지합니다.
환경별 변수값은 `dev.tfvars`, `prod.tfvars`로 분리하여 관리합니다.

```bash
# dev 환경 적용
terraform apply -var-file=dev.tfvars

# prod 환경 적용
terraform apply -var-file=prod.tfvars
```

또는 Terraform workspace를 사용하는 방식도 동등하게 허용합니다:

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
terraform apply
```

`.gitignore`에 `*.tfvars`를 추가하세요 (시크릿 값이 포함될 수 있습니다):

```
*.tfvars
!terraform.tfvars.example
```

향후 디렉터리 분리 기준: 운영 자원이 50개 이상이거나 다른 AWS 리전을 추가로 사용하기 시작하는 시점에 `infra/aws/dev/`, `infra/aws/prod/` 디렉터리 분리를 검토합니다.

### 클라우드 (AWS)

| 서비스 | 용도 |
|--------|------|
| EC2 | 앱 서버 (Amazon Linux 2023) |
| Elastic IP | EC2 고정 IP |
| VPC / 서브넷 / 보안 그룹 | 네트워크 격리 및 접근 제어 |
| S3 | 파일 저장소 |
| ACM | SSL/TLS 인증서 (권장) |
| CloudWatch | 로그 및 메트릭 모니터링 (권장) |

### CI/CD

| 도구 | 용도 |
|------|------|
| GitHub Actions | 자동 배포 파이프라인 |
| SSH + rsync | 코드 동기화 |
| Docker Compose | 서비스 빌드 및 재시작 |

---

## 3. 네트워크 구성 원칙

### VPC 구성 (Terraform 기준)

```
VPC: 10.0.0.0/16
└── 퍼블릭 서브넷: 10.0.1.0/24 (ap-northeast-2a)
    └── EC2 인스턴스 (Elastic IP 연결)
    └── Internet Gateway 연결
```

현재 Terraform(`app/infra/aws/main.tf`)은 단일 퍼블릭 서브넷 구성입니다.

권장: 운영 환경은 퍼블릭 + 프라이빗 서브넷을 분리하고, DB는 프라이빗 서브넷에 배치하는 것을 권장합니다.

### 보안 그룹 (Security Group) 규칙

현재 적용된 보안 그룹 규칙 (`app/infra/aws/main.tf` 기준):

| 방향 | 포트 | 프로토콜 | 허용 대상 | 목적 | 적용 환경 |
|------|------|----------|-----------|------|----------|
| 인바운드 | 22 | TCP | `allowed_ssh_cidr` 변수값 | SSH 접근 | 공통 |
| 인바운드 | 80 | TCP | 0.0.0.0/0 | HTTP | 공통 |
| 인바운드 | 443 | TCP | 0.0.0.0/0 | HTTPS | 공통 |
| 인바운드 | 3000 | TCP | `allowed_ssh_cidr` 변수값 | Next.js 앱 서버 | 공통 — 운영도 3000 직접 노출 (현행 결정) |
| 아웃바운드 | 전체 | 전체 | 0.0.0.0/0 | 외부 통신 | 공통 |

보안 원칙:
- SSH 접근은 반드시 특정 IP CIDR로 제한합니다 (`terraform.tfvars`의 `allowed_ssh_cidr`).
  `"0.0.0.0/0"` 설정은 개발 초기에만 임시 사용하고, 운영 환경에서는 반드시 관리자 IP로 교체하세요.
- DB 포트(3306), Redis 포트(6379), Elasticsearch 포트(9200)는 외부에 노출하지 않습니다.
  이 포트들은 Docker 내부 `app-network` 브리지 네트워크를 통해서만 컨테이너 간 통신합니다.
- 현행 정책: 운영 환경도 3000 포트를 직접 노출합니다. 향후 트래픽 증가 시 Nginx 또는 ALB(Application Load Balancer) 도입 검토.

### Docker 내부 네트워크

모든 컨테이너는 `app-network` (bridge 드라이버) 네트워크를 공유합니다.

```
app-network (bridge)
├── review-mysql      (MySQL 8.0)
├── review-redis      (Redis 7-alpine)
├── review-elasticsearch  (ES 8.12.0)
├── review-web        (Next.js, 포트 3000 외부 노출)
└── review-workers    (BullMQ + Playwright, 외부 포트 없음)
```

서비스 간 통신은 컨테이너명을 호스트명으로 사용합니다. 예: `mysql:3306`, `redis:6379`, `http://elasticsearch:9200`

---

## 4. 시크릿 및 환경변수 관리 원칙

### 핵심 원칙

**`.env` 파일을 절대 git에 커밋하지 않습니다.**

`.gitignore`에 다음이 포함되어야 합니다:
```
.env
.env.dev
.env.prod
.env.local
infra/scripts/.env.*
```

### 환경변수 목록 (`.env.example` 기준)

| 카테고리 | 변수명 | 설명 |
|----------|--------|------|
| **DB** | `MYSQL_ROOT_PASSWORD` | MySQL root 비밀번호 |
| | `MYSQL_USER` | 앱 DB 사용자 |
| | `MYSQL_PASSWORD` | 앱 DB 비밀번호 |
| | `DATABASE_URL` | Drizzle ORM 연결 URL |
| **캐시** | `REDIS_URL` | Redis 연결 URL |
| **검색** | `ELASTICSEARCH_URL` | Elasticsearch HTTP URL |
| **인증** | `JWT_SECRET` | JWT 서명 시크릿 |
| | `NEXTAUTH_URL` | NextAuth 기준 URL |
| | `NEXTAUTH_SECRET` | NextAuth 암호화 키 |
| **OAuth** | `GOOGLE_CLIENT_ID` | Google OAuth 클라이언트 ID |
| | `GOOGLE_CLIENT_SECRET` | Google OAuth 시크릿 |
| | `GOOGLE_REDIRECT_URI` | Google OAuth 리다이렉트 URI |
| | `APPLE_CLIENT_ID` | Apple OAuth 클라이언트 ID |
| | `APPLE_CLIENT_SECRET` | Apple OAuth 시크릿 |
| | `KAKAO_CLIENT_ID` | Kakao OAuth 클라이언트 ID |
| | `KAKAO_CLIENT_SECRET` | Kakao OAuth 시크릿 |
| **AI** | `OPENAI_API_KEY` | OpenAI API 키 |
| **보안** | `ENCRYPTION_KEY` | AES-256 암호화 키 (32바이트) |
| **알림** | `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |
| | `SLACK_NOTIFICATIONS_ENABLED` | Slack 알림 활성화 여부 |
| **AWS S3** | `AWS_S3_BUCKET` | S3 버킷명 |
| | `AWS_S3_PREFIX` | S3 경로 접두사 |
| | `AWS_S3_ACCESS_KEY_ID` | AWS 액세스 키 ID |
| | `AWS_S3_SECRET_ACCESS_KEY` | AWS 시크릿 액세스 키 |
| **워커** | `MAX_MUSINSA_PRODUCTS` | 무신사 최대 수집 수 |
| | `MAX_29CM_PRODUCTS` | 29CM 최대 수집 수 |
| | `MAX_WCONCEPT_PRODUCTS` | W컨셉 최대 수집 수 |
| | `MAX_CUDDLYBUNNY_PRODUCTS` | 컬리버니 최대 수집 수 |
| | `MAX_REVIEWS` | 최대 리뷰 수집 수 |
| | `AI_PARALLEL_BATCHES` | 동시 처리 배치 수 (기본 15). 각 배치는 15개 리뷰를 묶음 — 상세는 ai-processing 모듈 참조 |

### 환경별 시크릿 주입 방법

| 환경 | 방법 |
|------|------|
| **로컬** | `app/infra/.env` 파일 직접 작성 (`app/infra/.env.example` 복사 후 값 입력) |
| **개발 (dev)** | GitHub Secrets(`DEV_ENV`)에 `.env.dev` 전체 내용 저장 → GitHub Actions에서 파일로 주입 |
| **운영 (prod)** | GitHub Secrets(`PROD_ENV`)에 `.env.prod` 전체 내용 저장 → GitHub Actions에서 파일로 주입 |

GitHub Actions 주입 흐름 (`deploy-dev.yml` 기준):

```yaml
- name: Create .env.dev
  env:
    ENV_CONTENT: ${{ secrets.DEV_ENV }}
  run: echo "$ENV_CONTENT" > infra/scripts/.env.dev
```

서버에서 `.env`로 복사:

```bash
cp scripts/.env.dev .env
```

권장: 운영 환경의 시크릿은 GitHub Secrets 대신 AWS Secrets Manager 또는 AWS SSM Parameter Store로 관리하는 것을 권장합니다. 이 경우 서버 기동 시 IAM 역할을 통해 시크릿을 주입합니다.

---

## 5. 로깅 / 모니터링 / 알림 표준

### 로깅 원칙

- 애플리케이션 코드에서 `console.log` 직접 사용을 금지합니다. 반드시 프로젝트 내 `logger` 모듈을 사용합니다.
- Docker 컨테이너 로그는 `docker logs` 명령으로 확인합니다.
- 로그 레벨: `error` > `warn` > `info` > `debug`

### 컨테이너 로그 확인

```bash
# 특정 컨테이너 로그 실시간 확인
docker logs -f review-web
docker logs -f review-workers
docker logs -f review-mysql

# 최근 100줄
docker logs --tail 100 review-web
```

### Slack 알림

Slack Incoming Webhook을 통해 주요 이벤트를 알림으로 발송합니다.

- 환경변수 `SLACK_WEBHOOK_URL`에 Webhook URL 설정
- `SLACK_NOTIFICATIONS_ENABLED=true`로 활성화
- 알림 대상 이벤트: 크롤링 완료/실패, AI 분석 오류, 서비스 장애

코드에서의 사용 패턴:

```typescript
// 환경변수로 활성화 여부 제어
if (process.env.SLACK_NOTIFICATIONS_ENABLED === 'true') {
  await sendSlackNotification(process.env.SLACK_WEBHOOK_URL!, message);
}
```

### 헬스체크 엔드포인트

모든 환경에서 공통으로 사용하는 헬스체크 엔드포인트:

```
GET /api/v1/health
```

- HTTP 200 응답 시 정상
- Docker Compose `healthcheck`에 적용됨 (`docker-compose.dev.yml` 기준)
- GitHub Actions 배포 후 검증에 사용됨

**현행 (Current):** 응답은 단순 형식입니다.

```json
{
  "success": true,
  "data": { "status": "ok", "timestamp": "2026-05-26T00:00:00.000Z" }
}
```

**권장 (Recommendation):** 의존성 상태 포함 형식으로 확장하세요. 확장 시 다른 곳에서 단순 응답을 파싱하는 코드가 없는지 확인 후 별도 PR로 적용합니다.

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

### 권장: CloudWatch 모니터링 (운영 환경)

권장: 운영 환경에서는 AWS CloudWatch를 통해 다음을 모니터링하는 것을 권장합니다.

| 메트릭 | 임계치 예시 | 알림 |
|--------|------------|------|
| EC2 CPU 사용률 | > 80% | Slack + 이메일 |
| EC2 메모리 사용률 | > 85% | Slack |
| 디스크 사용률 | > 85% | Slack |
| 4xx/5xx 에러율 | > 1% | Slack |
| 헬스체크 실패 | 1회 이상 | Slack |

---

## 6. 백업 및 복구 정책

### MySQL 데이터

현재 구성: Docker 볼륨 `mysql_data`에 데이터 저장.

로컬/개발 환경 백업:

```bash
# 데이터 덤프
docker exec review-mysql mysqldump \
  -u root -p${MYSQL_ROOT_PASSWORD} review_service \
  > backup_$(date +%Y%m%d_%H%M%S).sql

# 복구
docker exec -i review-mysql mysql \
  -u root -p${MYSQL_ROOT_PASSWORD} review_service \
  < backup_20240101_000000.sql
```

권장: 운영 환경에서는 다음 중 하나를 선택하는 것을 권장합니다.

| 방안 | 특징 | 비용 |
|------|------|------|
| RDS (AWS) 마이그레이션 | 자동 백업, Multi-AZ, 스냅샷 | 월 ~$30+ (db.t3.micro 기준) |
| EC2 MySQL 자동 백업 스크립트 | Cron으로 S3 업로드 | S3 스토리지 비용만 발생 |

EC2 내 MySQL S3 백업 스크립트 예시 (cron 등록):

```bash
#!/bin/bash
# /home/ec2-user/backup-db.sh
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/review_service_${TIMESTAMP}.sql.gz"

docker exec review-mysql mysqldump \
  -u root -p"${MYSQL_ROOT_PASSWORD}" review_service \
  | gzip > "${BACKUP_FILE}"

aws s3 cp "${BACKUP_FILE}" "s3://${AWS_S3_BUCKET}/backups/db/${BACKUP_FILE##*/}"
rm "${BACKUP_FILE}"

# 30일 이전 백업 삭제
aws s3 ls "s3://${AWS_S3_BUCKET}/backups/db/" \
  | awk '{print $4}' \
  | sort | head -n -30 \
  | xargs -I{} aws s3 rm "s3://${AWS_S3_BUCKET}/backups/db/{}"
```

### Redis 데이터

Redis는 BullMQ 작업 큐 용도로 사용됩니다. 휘발성 데이터 특성상 영속 백업보다는 장애 시 재처리가 가능한 구조를 유지합니다.

현재 구성: Docker 볼륨 `redis_data`에 AOF(Append-Only File) 없이 기본 RDB 스냅샷만 저장.

### Elasticsearch 데이터

현재 구성: Docker 볼륨 `es_data`에 저장.

Elasticsearch 인덱스는 MySQL 원본 데이터로부터 재색인이 가능하므로, DB 백업이 주요 복구 수단입니다.

### S3 파일 저장소

권장: S3 버킷에 버전 관리(Versioning)를 활성화하고, 수명 주기(Lifecycle) 정책으로 이전 버전을 자동 삭제하는 것을 권장합니다.

```bash
# S3 버전 관리 활성화
aws s3api put-bucket-versioning \
  --bucket ${AWS_S3_BUCKET} \
  --versioning-configuration Status=Enabled
```

### Docker 볼륨 백업

```bash
# 볼륨 백업 (타르볼로 압축)
docker run --rm \
  -v mysql_data:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/mysql_data_$(date +%Y%m%d).tar.gz -C /source .
```
