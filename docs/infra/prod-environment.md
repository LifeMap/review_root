# 운영(prod) 서버 환경

실제 서비스 운영을 위한 프로덕션 환경 구성입니다.
`main` 브랜치에 push하면 GitHub Actions가 자동으로 배포합니다.

---

## 목차

1. [가용성 및 확장성 원칙](#1-가용성-및-확장성-원칙)
2. [구성 옵션 비교](#2-구성-옵션-비교)
3. [HTTPS 및 TLS 설정](#3-https-및-tls-설정)
4. [시크릿 관리](#4-시크릿-관리)
5. [모니터링 및 알림](#5-모니터링-및-알림)
6. [장애 복구 절차](#6-장애-복구-절차)

---

## 1. 가용성 및 확장성 원칙

### 현재 운영 구성 (실제 배포 중인 구성)

현재 `docker-compose.prod.yml`과 `deploy-prod.yml` 기반:

```
인터넷
    │
    ▼
EC2 인스턴스 (t3.medium, 단일 AZ)
    │
    ├── review-web      (Next.js, 포트 3000)
    ├── review-workers  (BullMQ + Playwright)
    ├── review-mysql    (MySQL 8.0, 도커 볼륨)
    ├── review-redis    (Redis 7, 도커 볼륨)
    └── review-elasticsearch (ES 8.12.0, 도커 볼륨)
```

- 단일 EC2 인스턴스에 전체 스택이 실행됩니다.
- Elastic IP로 고정 IP를 유지합니다.
- 보안 그룹으로 SSH(22), HTTP(80), HTTPS(443), App(3000) 포트를 제어합니다.
- 현행 정책: 3000 포트를 EC2에 직접 노출합니다 (의도된 현행 구성, D6 결정). 트래픽 증가 시 ALB/Nginx 도입 검토.

### 확장 방향 (단계별)

| 단계 | 구성 | 적합한 시점 |
|------|------|-------------|
| **현재** | 단일 EC2 + Docker Compose | 초기 운영, 소규모 트래픽 |
| **1단계 확장** | EC2 + Nginx 리버스 프록시 + SSL | HTTPS 적용 필요 시 |
| **2단계 확장** | EC2 + ALB + ACM + RDS | 다중 AZ, DB 분리 필요 시 |
| **3단계 확장** | Auto Scaling Group + RDS Multi-AZ + ElastiCache | 트래픽 급증 대응 |

### Terraform 운영 환경 프로비저닝 (D6 결정)

현행: 단일 `app/infra/aws/main.tf` 구조. 운영 환경 변수값은 `prod.tfvars`로 관리합니다.

```bash
cd app/infra/aws

# prod 전용 변수 파일 작성 (infra-standards.md의 환경 분리 방식 참조)
cp terraform.tfvars.example prod.tfvars
# prod.tfvars 편집: key_name, allowed_ssh_cidr, instance_type=t3.medium 등 설정
# 주의: prod.tfvars는 .gitignore에 포함 — 커밋하지 않습니다

terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

환경 분리 상세 기준은 `infra-standards.md` §2 IaC 섹션을 참조합니다.

---

## 2. 구성 옵션 비교

### 옵션 A: 현행 유지 (비용 효율 우선)

현재 실제 구성입니다.

| 항목 | 구성 |
|------|------|
| 앱 서버 | EC2 t3.medium (단일) |
| DB | EC2 내 Docker MySQL (볼륨 영속) |
| 캐시 | EC2 내 Docker Redis |
| 검색 | EC2 내 Docker Elasticsearch |
| 로드 밸런서 | 없음 (EC2 직접 노출) |
| SSL | 없음 또는 Nginx 셀프 서명 |
| 예상 월 비용 | 약 $35~$40 (EC2 t3.medium + EIP + S3) |

장점:
- 구성 단순, 운영 부담 낮음
- 비용 최소화

단점:
- DB/앱 서버 장애 시 동시 다운
- HTTPS 없음 (브라우저 경고)
- 수동 롤백 필요

### 옵션 B: 안정성 강화 (권장)

권장: 서비스 운영이 안정화된 시점에 아래 구성으로 전환을 권장합니다.

| 항목 | 구성 |
|------|------|
| 앱 서버 | EC2 t3.medium (Nginx 리버스 프록시 추가) |
| DB | RDS db.t3.micro (MySQL 8.0) — Multi-AZ는 선택 |
| 캐시 | EC2 내 Docker Redis (ElastiCache는 추후 고려) |
| 검색 | EC2 내 Docker Elasticsearch |
| 로드 밸런서 | ALB (Application Load Balancer) |
| SSL | ACM (AWS Certificate Manager) 인증서 |
| 예상 월 비용 | 약 $80~$120 (ALB $18 + RDS $15 + EC2 $34 + 기타) |

장점:
- HTTPS 자동 인증서 관리 (ACM)
- DB 독립 → 앱 재시작 시 데이터 안전
- ALB 헬스체크 기반 트래픽 라우팅

단점:
- 비용 증가
- 구성 복잡도 증가

### Nginx 리버스 프록시 설정 예시 (옵션 B 적용 시)

```nginx
# /etc/nginx/conf.d/reviews.conf
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    # ACM 인증서 연동 시 ALB에서 SSL 종단 처리
    # EC2 직접 SSL 사용 시 아래 설정 적용
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/key.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 3. HTTPS 및 TLS 설정

### 옵션 A: Let's Encrypt (Certbot) — EC2 직접 SSL

도메인이 있고 ALB 없이 EC2 직접 HTTPS를 적용하는 방법:

```bash
# Amazon Linux 2023에서 Certbot 설치
sudo dnf install -y certbot python3-certbot-nginx

# 인증서 발급 (도메인 필요)
sudo certbot --nginx -d your-domain.com

# 자동 갱신 설정
sudo systemctl enable certbot-renew.timer
```

### 옵션 B: ALB + ACM — 권장 방법

ALB에서 SSL/TLS를 종단(terminate)하고, EC2는 HTTP로만 통신합니다.

```bash
# ACM 인증서 요청 (AWS CLI)
aws acm request-certificate \
  --domain-name your-domain.com \
  --validation-method DNS \
  --region ap-northeast-2
```

ACM 인증서 ARN을 ALB HTTPS 리스너에 연결합니다.

ALB → EC2 통신은 HTTP:3000으로 유지하고, 보안 그룹에서 ALB의 보안 그룹만 3000 포트를 허용합니다.

---

## 4. 시크릿 관리

### 현재 방법 (GitHub Secrets)

`deploy-prod.yml` 기반:

| Secret명 | 내용 |
|----------|------|
| `PROD_SSH_KEY` | EC2 접속용 PEM 키 |
| `PROD_HOST` | prod 서버 IP 또는 도메인 |
| `PROD_USER` | SSH 접속 사용자 |
| `PROD_ENV` | `.env.prod` 파일 전체 내용 |

GitHub Actions에서 서버로 전달하는 흐름:

```
GitHub Secrets(PROD_ENV)
    └── GitHub Action Runner에서 infra/scripts/.env.prod 생성
            └── rsync로 서버 전달
                    └── cp scripts/.env.prod .env
                            └── docker compose up -d
```

### 권장: AWS Secrets Manager 또는 SSM Parameter Store

권장: 운영 환경의 시크릿은 GitHub Secrets보다 AWS 네이티브 서비스로 관리하는 것을 권장합니다.

#### SSM Parameter Store 사용 예시

```bash
# 시크릿 저장
aws ssm put-parameter \
  --name "/reviews/prod/JWT_SECRET" \
  --value "your-jwt-secret" \
  --type SecureString \
  --region ap-northeast-2

# 시크릿 조회 (EC2에서 IAM 역할로 접근)
aws ssm get-parameter \
  --name "/reviews/prod/JWT_SECRET" \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

EC2 IAM 역할에 `ssm:GetParameter` 권한을 부여하고, 기동 스크립트에서 시크릿을 환경변수로 주입합니다.

---

## 5. 모니터링 및 알림

### Slack 알림 (현재 구성)

`SLACK_WEBHOOK_URL`과 `SLACK_NOTIFICATIONS_ENABLED=true` 설정으로 앱 내 주요 이벤트를 Slack으로 알림 발송합니다.

```bash
# 헬스체크 모니터링 스크립트 예시 (cron 등록)
#!/bin/bash
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/v1/health)
if [ "$STATUS" != "200" ]; then
  curl -X POST "${SLACK_WEBHOOK_URL}" \
    -H 'Content-type: application/json' \
    --data "{\"text\":\"[운영] 헬스체크 실패: HTTP $STATUS\"}"
fi
```

cron 등록 (5분마다 확인):

```bash
crontab -e
# 추가:
*/5 * * * * /home/ec2-user/health-check.sh
```

### 권장: CloudWatch 모니터링

권장: 운영 환경에서는 CloudWatch를 통해 시스템 메트릭을 수집하고 알림을 설정하는 것을 권장합니다.

```bash
# CloudWatch 에이전트 설치 (Amazon Linux 2023)
sudo dnf install -y amazon-cloudwatch-agent

# 에이전트 설정 (CPU, 메모리, 디스크 메트릭 수집)
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# 에이전트 시작
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
```

CloudWatch 알림 설정 (주요 임계치):

| 메트릭 | 임계치 | 알림 |
|--------|--------|------|
| CPUUtilization | > 80% (5분 연속) | SNS → Slack |
| 메모리 사용률 | > 85% | SNS → Slack |
| 디스크 사용률 | > 85% | SNS → Slack |

---

## 백업 및 복구 목표 (RPO / RTO)

서비스 장애 또는 데이터 손실 시 얼마나 빠르게, 어느 시점까지 복구할 수 있는지를 수치로 정의합니다.

**정의**

| 지표 | 설명 |
|------|------|
| **RPO (Recovery Point Objective)** | 허용할 수 있는 최대 데이터 손실 시점. "마지막 백업 시점 이후의 데이터는 손실될 수 있다"는 기준 |
| **RTO (Recovery Time Objective)** | 장애 발생 후 서비스를 정상화해야 하는 목표 시간 |

### 환경별 RPO/RTO 현황 및 목표

| 구성 | RPO | RTO | 비고 |
|------|-----|-----|------|
| **현행** (EC2 내 Docker MySQL + S3 일일 백업) | **24시간** | **2~4시간** | 일일 덤프 기준. EC2 재기동 + 데이터 복구 시간 포함 |
| **권장** (RDS Multi-AZ + 자동 백업) | **5분 이내** | **30분 이내** | RDS PITR(Point-in-Time Recovery) 활용. 자동 페일오버로 RTO 단축 |

현행 구성에서 최악의 경우 24시간치 데이터가 손실될 수 있습니다. 서비스가 성장함에 따라 권장 구성으로 전환을 검토하세요.

### 마이그레이션 로드맵

일 활성 사용자(DAU) 500명 초과 또는 일 트랜잭션 10,000건 초과 시점에 RDS Multi-AZ로 전환을 권장합니다.

### 현행 백업 구성

**S3 일일 백업 (현재 구성)**

```bash
# /home/ec2-user/backup-mysql.sh — cron에 등록 (매일 00:00)
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}.sql"

# MySQL 덤프
docker exec review-mysql mysqldump \
  -u root -p${MYSQL_ROOT_PASSWORD} \
  --all-databases \
  --single-transaction \
  > /home/ec2-user/backups/${BACKUP_FILE}

# S3 업로드
aws s3 cp /home/ec2-user/backups/${BACKUP_FILE} \
  s3://${S3_BUCKET}/mysql-backups/${BACKUP_FILE}

# 로컬 7일 이상 된 백업 삭제
find /home/ec2-user/backups/ -name "backup_*.sql" -mtime +7 -delete

echo "백업 완료: ${BACKUP_FILE}"
```

```bash
# cron 등록
crontab -e
# 추가:
0 0 * * * /home/ec2-user/backup-mysql.sh >> /home/ec2-user/logs/backup.log 2>&1
```

**백업 보존 정책**

| 저장소 | 보존 기간 | 비고 |
|--------|---------|------|
| EC2 로컬 | 7일 | 빠른 복구용 |
| S3 | 30일 | 장기 보관, S3 수명 주기 정책으로 자동 삭제 |

### 복구 테스트 주기

분기 1회(3개월마다) 복구 테스트를 수행합니다. 테스트 절차:

```
1. 최신 S3 백업 파일 다운로드
2. 개발 환경(dev)의 별도 MySQL 인스턴스에 복원
3. 앱 연결 후 데이터 정합성 확인 (레코드 수, 최근 생성 데이터 등)
4. 복구 소요 시간 기록 → RTO 달성 여부 검증
5. 테스트 결과를 내부 문서에 기록
```

---

## 6. 장애 복구 절차

### 헬스체크 실패 시 대응 흐름

```
1. /api/v1/health 응답 없음 또는 비정상
        │
        ├── 컨테이너 상태 확인
        │   docker compose -f docker-compose.prod.yml ps
        │
        ├── 로그 확인
        │   docker logs --tail 100 review-web
        │
        ├── 컨테이너 재시작 시도
        │   docker compose -f docker-compose.prod.yml restart web
        │
        └── 재시작 후에도 실패 → 롤백
```

### 이전 버전 롤백

현재 배포 방식(rsync + docker compose)은 이미지 태그 없이 빌드하므로, 코드 롤백으로 대응합니다.

```bash
# 로컬 또는 서버에서 이전 커밋으로 롤백
git revert HEAD
git push origin main
# → GitHub Actions가 자동으로 재배포
```

또는 서버에서 직접:

```bash
# SSH로 서버 접속
ssh -i ~/.ssh/prod-key.pem ec2-user@<PROD_HOST>

# 서비스 디렉터리로 이동
cd ~/app

# 이전 커밋으로 롤백
git log --oneline -5
git checkout <이전-커밋-해시>

# 서비스 재빌드 및 재시작
cd infra
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

### DB 데이터 복구

Docker 볼륨 백업이 있는 경우:

```bash
# 서비스 정지
docker compose -f docker-compose.prod.yml stop mysql

# 볼륨 데이터 복원
docker run --rm \
  -v mysql_data:/target \
  -v /home/ec2-user/backups:/backup \
  alpine tar xzf /backup/mysql_data_20240101.tar.gz -C /target

# 서비스 재시작
docker compose -f docker-compose.prod.yml start mysql
```

SQL 덤프 파일로 복원:

```bash
docker exec -i review-mysql mysql \
  -u root -p${MYSQL_ROOT_PASSWORD} review_service \
  < /home/ec2-user/backups/backup_20240101_000000.sql
```

### 긴급 수동 배포

GitHub Actions 없이 즉시 배포해야 할 경우 `app/infra/scripts/deploy.sh` 사용:

```bash
cd app/infra/scripts

EC2_HOST=<prod-server-ip> \
EC2_USER=ec2-user \
SSH_KEY=~/.ssh/prod-key.pem \
./deploy.sh
```

`scripts/.env.prod` 파일이 있으면 서버의 `.env`를 교체합니다.

### 서비스별 재시작 순서

의존성 순서에 따라 재시작합니다:

```bash
# 1. 인프라 서비스 먼저 재시작
docker compose -f docker-compose.prod.yml restart mysql
docker compose -f docker-compose.prod.yml restart redis
docker compose -f docker-compose.prod.yml restart elasticsearch

# 2. 인프라 서비스 healthy 상태 확인 후 앱 재시작
docker compose -f docker-compose.prod.yml restart web
docker compose -f docker-compose.prod.yml restart workers

# 3. 헬스체크
curl http://localhost:3000/api/v1/health
```
