# 인프라 문서 디렉터리

리뷰 모으기 서비스(reviews)의 인프라 표준 문서 모음입니다.
실제 코드베이스 패턴과 설정 파일을 기반으로 작성되었습니다.

---

## 문서 목록

| 파일 | 설명 |
|------|------|
| [infra-standards.md](./infra-standards.md) | 인프라 전체 표준 — 환경 구성, 기술 스택, 네트워크 원칙, 시크릿 관리, 로깅/모니터링, 백업 정책 |
| [local-environment.md](./local-environment.md) | 로컬 개발 환경 — Docker Compose 셋업, 포트 매핑, DB 초기화, 자주 쓰는 명령어 |
| [dev-environment.md](./dev-environment.md) | 개발(dev) 서버 환경 — GitHub Actions 배포 흐름, 서버 사양, 환경변수 주입, 트러블슈팅 |
| [prod-environment.md](./prod-environment.md) | 운영(prod) 서버 환경 — 가용성/확장성, HTTPS, 시크릿 관리, 모니터링, 장애 복구 |
| [security-standards.md](./security-standards.md) | 보안 표준 — 인증/인가 흐름, 입력 검증, 네트워크 보안, OWASP 체크리스트 |
| [ci-cd-standards.md](./ci-cd-standards.md) | CI/CD 표준 — 브랜치 전략, GitHub Actions 워크플로, 헬스체크 규약, 롤백 절차 |
| [CHANGELOG.md](./CHANGELOG.md) | 인프라 문서 변경 이력 |

---

## 관련 파일 위치

```
app/
├── .github/workflows/
│   ├── deploy-dev.yml       # dev 브랜치 자동 배포
│   └── deploy-prod.yml      # main 브랜치 자동 배포
├── infra/
│   ├── docker-compose.dev.yml   # 개발/로컬 환경 컨테이너 구성
│   ├── docker-compose.prod.yml  # 운영 환경 컨테이너 구성
│   ├── init.sql                 # MySQL 초기화 스크립트
│   ├── .env.example             # 환경변수 템플릿
│   ├── scripts/
│   │   ├── deploy.sh            # 수동 배포 스크립트
│   │   └── sync-db.sh           # DB 동기화 스크립트
│   └── aws/
│       ├── main.tf              # VPC, EC2, 보안 그룹 Terraform 구성
│       ├── variables.tf         # Terraform 변수 정의
│       ├── outputs.tf           # Terraform 출력값
│       ├── user-data.sh         # EC2 초기 설정 스크립트
│       └── terraform.tfvars.example  # Terraform 변수 예시
└── web/
    ├── Dockerfile               # Next.js 멀티스테이지 빌드
    └── Dockerfile.workers       # BullMQ 워커 (Playwright 포함)
```

---

## 빠른 참조

### 로컬 환경 시작

```bash
cd app/infra
cp .env.example .env
# .env 파일에 실제 값 입력
docker compose -f docker-compose.dev.yml up -d
```

### 헬스체크 엔드포인트

```
GET /api/v1/health
```

### 배포 트리거

| 환경 | 방법 |
|------|------|
| dev | `git push origin dev` |
| prod | `git push origin main` |
