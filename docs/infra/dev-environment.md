# 개발(dev) 서버 환경

통합 테스트, QA, 데모를 위한 개발 서버 환경입니다.
`dev` 브랜치에 push하면 GitHub Actions가 자동으로 배포합니다.

---

## 목차

1. [배포 흐름](#1-배포-흐름)
2. [서버 사양 권장안](#2-서버-사양-권장안)
3. [DB 구성 비교](#3-db-구성-비교)
4. [환경변수 관리](#4-환경변수-관리)
5. [로그 위치 및 트러블슈팅](#5-로그-위치-및-트러블슈팅)

---

## 1. 배포 흐름

### 자동 배포 트리거

```
git push origin dev
      │
      ▼
GitHub Actions: deploy-dev.yml 실행
      │
      ├── [1] SSH 키 설정
      │         GitHub Secret: DEV_SSH_KEY, DEV_HOST
      │
      ├── [2] .env.dev 파일 생성
      │         GitHub Secret: DEV_ENV → infra/scripts/.env.dev
      │
      ├── [3] 디스크 공간 확보 (배포 전 Docker prune)
      │         SSH로 dev 서버 접속 → docker system prune -af
      │
      ├── [4] 코드 동기화 (rsync)
      │         로컬 → dev 서버 /home/${USER}/app/
      │         제외: node_modules, .next, .git, *.log
      │
      ├── [5] 서비스 빌드 및 재시작
      │         SSH로 dev 서버 접속
      │         → cp scripts/.env.dev .env
      │         → docker compose -f docker-compose.dev.yml down
      │         → docker compose -f docker-compose.dev.yml build --no-cache
      │         → docker compose -f docker-compose.dev.yml up -d
      │         → sleep 30 (서비스 기동 대기)
      │
      └── [6] 헬스체크
                curl http://${DEV_HOST}:3000/api/v1/health
                HTTP 200이면 배포 성공, 그 외 실패 처리
```

### GitHub Actions 워크플로 파일

`app/.github/workflows/deploy-dev.yml`

주요 설정:
- 트리거 브랜치: `dev`
- 실행 환경: `ubuntu-latest`
- 타임아웃: 15분

### 필요한 GitHub Secrets

dev 환경 배포에 필요한 GitHub Secrets (`app` 저장소 기준):

| Secret명 | 내용 |
|----------|------|
| `DEV_SSH_KEY` | EC2 접속용 PEM 키 파일 전체 내용 |
| `DEV_HOST` | dev 서버 IP 주소 또는 도메인 |
| `DEV_USER` | EC2 SSH 접속 사용자 (예: `ec2-user`) |
| `DEV_ENV` | `.env.dev` 파일 전체 내용 (모든 환경변수 포함) |

GitHub Secrets 등록 방법:

```
저장소 > Settings > Secrets and variables > Actions > New repository secret
```

---

## 2. 서버 사양 권장안

### 현재 Terraform 기본값

`app/infra/aws/terraform.tfvars.example` 기준:

| 항목 | 값 |
|------|----|
| 리전 | `ap-northeast-2` (서울) |
| 인스턴스 타입 | `t3.medium` |
| OS | Amazon Linux 2023 |
| 스토리지 | 30GB gp3 EBS |
| 스왑 | 2GB (user-data.sh 자동 설정) |

t3.medium 사양:
- vCPU: 2
- 메모리: 4GB
- 네트워크: 최대 5Gbps
- 월 비용: 약 $34 (온디맨드, ap-northeast-2)

### Elasticsearch 메모리 요구사항 주의

현재 docker compose 설정:

```yaml
environment:
  - ES_JAVA_OPTS=-Xms512m -Xmx512m
```

Elasticsearch가 512MB JVM 힙을 사용하고, MySQL, Redis, Next.js, 워커까지 합산하면 t3.medium(4GB)에서도 타이트합니다.
`user-data.sh`에서 2GB 스왑 파일을 자동 생성하여 메모리 부족 상황을 보완합니다.

권장: dev 서버에서 메모리 부족이 자주 발생하면 t3.large(8GB, 월 약 $68)로 업그레이드를 고려합니다.

### Terraform으로 EC2 프로비저닝

```bash
cd app/infra/aws

# dev 전용 변수 파일 작성 (infra-standards.md의 환경 분리 방식 참조)
cp terraform.tfvars.example dev.tfvars
# dev.tfvars 편집: key_name, allowed_ssh_cidr, instance_type 등 설정
# 주의: dev.tfvars는 .gitignore에 포함 — 커밋하지 않습니다

# 초기화
terraform init

# 계획 확인
terraform plan -var-file=dev.tfvars

# 적용 (실제 AWS 리소스 생성)
terraform apply -var-file=dev.tfvars
```

출력값으로 SSH 명령어와 앱 URL을 확인할 수 있습니다:

```bash
terraform output ssh_command
terraform output app_url
```

---

## 3. DB 구성 비교

현재 dev 환경은 EC2 내 Docker 컨테이너로 MySQL을 실행합니다.

| 구성 | EC2 내 Docker MySQL | RDS db.t3.micro |
|------|---------------------|-----------------|
| 월 비용 | 추가 비용 없음 (EC2 비용에 포함) | 약 $15 |
| 관리 편의성 | 직접 관리 필요 | 자동 백업, 패치 |
| 가용성 | EC2와 동일 수명 | 독립적 |
| 백업 | 수동 (스크립트 필요) | 자동 (7일 보존) |
| 데이터 영속성 | EC2 종료 시 볼륨 유지 (EBS) | 독립적 |
| 설정 복잡도 | 낮음 | 보통 |

dev 환경 권장: EC2 내 Docker MySQL 사용. 비용 절감 및 설정 단순화.

운영 환경 전환 시 RDS로 마이그레이션 권장. 자세한 내용은 [prod-environment.md](./prod-environment.md) 참고.

---

## 4. 환경변수 관리

### DEV_ENV Secret 구성

GitHub Secrets의 `DEV_ENV` 값은 `.env` 파일 전체 내용입니다.
예시 구조:

```bash
# MySQL
MYSQL_ROOT_PASSWORD=dev-root-password
MYSQL_USER=review_user
MYSQL_PASSWORD=dev-db-password
MYSQL_DATABASE=review_service

# Redis
REDIS_URL=redis://redis:6379

# Elasticsearch
ELASTICSEARCH_URL=http://elasticsearch:9200

# NextAuth
NEXTAUTH_URL=http://dev-server-ip:3000
NEXTAUTH_SECRET=dev-nextauth-secret-32chars

# JWT
JWT_SECRET=dev-jwt-secret-at-least-32-chars

# OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://dev-server-ip:3000/api/auth/callback/google

# OpenAI
OPENAI_API_KEY=sk-...

# 보안
ENCRYPTION_KEY=dev-aes-256-key-must-be-32bytes!

# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_NOTIFICATIONS_ENABLED=true

# AWS S3
AWS_S3_BUCKET=reviews-dev-bucket
AWS_S3_PREFIX=dev
AWS_S3_ACCESS_KEY_ID=AKIA...
AWS_S3_SECRET_ACCESS_KEY=...

# 워커 설정
MAX_MUSINSA_PRODUCTS=10
MAX_29CM_PRODUCTS=10
MAX_WCONCEPT_PRODUCTS=10
MAX_CUDDLYBUNNY_PRODUCTS=10
MAX_REVIEWS=50
AI_PARALLEL_BATCHES=3
```

주의: `DATABASE_URL`은 `docker-compose.dev.yml`에서 컨테이너 내부 URL로 직접 조합합니다.
(`mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@mysql:3306/review_service`)

### GitHub Actions에서의 주입 흐름

```yaml
# 1. GitHub Action Runner에서 .env.dev 파일 생성
- name: Create .env.dev
  env:
    ENV_CONTENT: ${{ secrets.DEV_ENV }}
  run: echo "$ENV_CONTENT" > infra/scripts/.env.dev

# 2. rsync로 서버에 전달 (infra/scripts/ 디렉터리 포함)

# 3. 서버에서 .env로 복사
# SSH 접속 후:
cp scripts/.env.dev .env
docker compose -f docker-compose.dev.yml up -d
```

---

## 5. 로그 위치 및 트러블슈팅

### 로그 확인

dev 서버에 SSH 접속 후 다음 명령어를 사용합니다:

```bash
# SSH 접속
ssh -i ~/.ssh/dev-key.pem ec2-user@<DEV_HOST>

# 서비스 디렉터리로 이동
cd ~/app/infra

# 모든 서비스 상태
docker compose -f docker-compose.dev.yml ps

# 전체 로그 실시간 확인
docker compose -f docker-compose.dev.yml logs -f

# 특정 서비스 로그
docker logs -f review-web
docker logs -f review-workers
docker logs --tail 200 review-web
```

### GitHub Actions 배포 실패 시

1. GitHub 저장소 > Actions 탭에서 실패한 워크플로 클릭
2. 실패한 스텝 로그 확인
3. 주요 실패 원인:
   - SSH 연결 실패: `DEV_SSH_KEY`, `DEV_HOST`, `DEV_USER` Secret 확인
   - 빌드 실패: Next.js 타입 오류 또는 의존성 문제 (로컬에서 `pnpm build` 먼저 실행)
   - 헬스체크 실패: 서비스 기동 시간 초과 (로그에서 오류 확인)

### 디스크 공간 부족

dev 서버에서 자주 발생하는 문제입니다. GitHub Actions의 "Clean up disk space" 스텝에서 자동으로 `docker system prune -af`를 실행하지만, 수동 정리가 필요한 경우:

```bash
# 디스크 사용량 확인
df -h

# Docker 디스크 사용량 확인
docker system df

# 사용하지 않는 리소스 정리 (볼륨 제외)
docker system prune -f

# 강제 정리 (볼륨 포함, DB 데이터 삭제 주의)
docker system prune -af --volumes
```

### 헬스체크 실패 시 수동 확인

```bash
# dev 서버에서
curl -v http://localhost:3000/api/v1/health

# 컨테이너 상태 확인
docker inspect review-web | grep -A 20 '"Health"'

# 컨테이너 로그에서 오류 찾기
docker logs review-web 2>&1 | grep -i error | tail -20
```

### 서비스 수동 재배포

긴급 패치나 수동 배포가 필요한 경우 `app/infra/scripts/deploy.sh` 스크립트를 사용합니다:

```bash
# app/infra/scripts/ 디렉터리에서
EC2_HOST=<dev-server-ip> \
EC2_USER=ec2-user \
SSH_KEY=~/.ssh/dev-key.pem \
./deploy.sh
```
