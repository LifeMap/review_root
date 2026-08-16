# CHANGELOG

인프라 문서 변경 이력입니다.

---

## [v1.1.1] - 2026-05-26

### Changed

- `infra-standards.md` §3 보안 그룹 표에 "적용 환경" 컬럼 추가, 포트 3000 현행 정책 명시 (운영도 직접 노출, D6 결정)
- `infra-standards.md` §2 기술 스택에 Node.js 20 LTS 기준점 명시 (`node:20-alpine` for web, `node:20-slim` for workers)
- `infra-standards.md` §2 IaC 섹션에 Terraform 환경 분리 방식 명시 (`dev.tfvars` / `prod.tfvars`, workspace 대안, `.gitignore` 지침, 디렉터리 분리 기준) (D6 결정)
- `infra-standards.md` §4 환경변수 `AI_PARALLEL_BATCHES` 설명을 "동시 처리 배치 수 (기본 15). 각 배치는 15개 리뷰를 묶음 — 상세는 ai-processing 모듈 참조"로 통일
- `local-environment.md` §1 Node.js 버전을 "20 LTS (상세: `infra-standards.md` 참조)"로 변경 (단일 기준점 참조)
- `dev-environment.md` Terraform 프로비저닝 명령어를 `dev.tfvars` 방식으로 업데이트, `현재 docker compose 설정` 표기 수정
- `dev-environment.md` 배포 흐름 다이어그램의 `docker-compose` 명령어를 `docker compose` (V2)로 통일
- `prod-environment.md` §1 현재 운영 구성에 보안 그룹 포트 3000 명시, 현행 정책 한 줄 추가 (D5 결정)
- `prod-environment.md` §1 확장 방향 표 하단에 Terraform 운영 환경 프로비저닝 섹션 추가 (`prod.tfvars` 방식 명시)
- `prod-environment.md` 전체 `docker-compose` 명령어를 `docker compose` (V2)로 통일
- `ci-cd-standards.md` 배포 파이프라인의 `docker-compose` 명령어를 `docker compose` (V2)로 통일

---

## [v1.0.0] - 2026-05-26

### Added

- `README.md` — `/docs/infra/` 디렉터리 개요 및 문서 목록 작성
- `infra-standards.md` — 인프라 표준 문서 최초 작성
  - 환경 구성 개요 (local / dev / prod)
  - 기술 스택 (Docker, Docker Compose, Terraform, AWS, GitHub Actions)
  - 네트워크 구성 원칙 (VPC, 서브넷, 보안 그룹)
  - 시크릿/환경변수 관리 원칙
  - 로깅/모니터링/알림 표준
  - 백업 및 복구 정책
- `local-environment.md` — 로컬 개발 환경 설정 가이드 최초 작성
  - 사전 요구사항 및 최초 셋업 절차
  - 서비스 포트 매핑 표
  - DB 초기화 방법
  - 자주 쓰는 명령어 모음
- `dev-environment.md` — 개발 서버 환경 가이드 최초 작성
  - GitHub Actions deploy-dev.yml 배포 흐름
  - 서버 사양 권장안 (EC2 t3.medium)
  - GitHub Secrets 구성 방법
  - 로그 확인 및 트러블슈팅 절차
- `prod-environment.md` — 운영 서버 환경 가이드 최초 작성
  - 현재 구성 및 단계별 확장 방향
  - 비용 효율 옵션 vs 안정성 강화 옵션 비교
  - HTTPS/TLS 설정 방법 (Let's Encrypt, ALB+ACM)
  - 시크릿 관리 (GitHub Secrets, AWS SSM 권장)
  - CloudWatch 모니터링 권장 설정
  - 장애 복구 및 롤백 절차
- `security-standards.md` — 보안 표준 문서 최초 작성
  - 입력 검증 (zod 스키마)
  - 인증/인가 흐름 (NextAuth + JWT + jose 미들웨어)
  - 데이터 노출 방지 원칙
  - 네트워크 보안 (보안 그룹, Docker 내부 격리)
  - CSRF/CORS/CSP 가이드
  - OWASP Top 10 체크리스트
  - 시크릿 누출 방지 (gitleaks, git-secrets)
  - 의존성 보안 (pnpm audit, Dependabot)
- `ci-cd-standards.md` — CI/CD 표준 문서 최초 작성
  - 브랜치 전략 (main/dev/feature)
  - 로컬 빌드 필수 규칙 (pnpm build)
  - GitHub Actions 워크플로 단계별 설명
  - 헬스체크 엔드포인트 규약 (/api/v1/health)
  - 배포 실패 시 롤백 절차
- `CHANGELOG.md` — 변경 이력 최초 작성

### 기반 파일

이 문서들은 다음 실제 파일을 기반으로 작성되었습니다:
- `app/infra/docker-compose.dev.yml`
- `app/infra/docker-compose.prod.yml`
- `app/infra/.env.example`
- `app/infra/aws/main.tf`, `variables.tf`, `outputs.tf`, `user-data.sh`
- `app/.github/workflows/deploy-dev.yml`
- `app/.github/workflows/deploy-prod.yml`
- `app/web/Dockerfile`
- `app/web/Dockerfile.workers`
- `app/infra/scripts/deploy.sh`
- `app/CLAUDE.md`
