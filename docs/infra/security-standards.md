# 보안 표준

리뷰 모으기 서비스의 보안 원칙과 구현 가이드입니다.
보안 담당자가 기준 문서로 활용합니다.

---

## 목차

1. [입력 검증](#1-입력-검증)
2. [인증 및 인가](#2-인증-및-인가)
3. [데이터 노출 방지](#3-데이터-노출-방지)
4. [네트워크 보안](#4-네트워크-보안)
5. [CSRF / CORS / CSP 가이드](#5-csrf--cors--csp-가이드)
6. [OWASP Top 10 체크리스트](#6-owasp-top-10-체크리스트)
7. [시크릿 누출 방지](#7-시크릿-누출-방지)
8. [의존성 보안](#8-의존성-보안)

---

## 1. 입력 검증

### 원칙

모든 API 엔드포인트 입력값은 **zod 스키마**로 검증합니다.
클라이언트와 서버 양쪽에서 검증하되, 서버 검증을 신뢰의 기준으로 삼습니다.

### 적용 패턴

```typescript
import { z } from 'zod';

// 스키마 정의
const createReviewSchema = z.object({
  product_id: z.string().uuid(),
  content: z.string().min(1).max(2000),
  rating: z.number().int().min(1).max(5),
});

// API 핸들러에서 검증
export async function POST(request: Request) {
  const body = await request.json();
  const parsed = createReviewSchema.safeParse(body);

  if (!parsed.success) {
    return Response.json(
      { error: '입력값이 올바르지 않습니다.', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  // parsed.data는 타입 안전한 검증된 값
  const { product_id, content, rating } = parsed.data;
}
```

### 금지 사항

- `any` 타입으로 요청 바디를 사용하는 것을 금지합니다.
- 클라이언트 검증만으로 보안을 신뢰하는 것을 금지합니다.
- SQL 쿼리에 사용자 입력을 직접 문자열 보간하는 것을 금지합니다 (Drizzle prepared statement 사용).

---

## 2. 인증 및 인가

### 인증 방식

프로젝트는 두 가지 인증 방식을 병용합니다.

| 방식 | 사용처 | 토큰 저장 |
|------|--------|-----------|
| NextAuth.js | OAuth 로그인 흐름 (Google, Apple, Kakao) | 서버 세션 |
| JWT (커스텀) | API 인증, 미들웨어 보호 | **localStorage** |

### JWT 인증 흐름

```
1. 로그인 성공
   → 서버에서 JWT 발급
   → 클라이언트 localStorage에 access_token, refresh_token 저장

2. 페이지 접근
   → 클라이언트 레이아웃(admin/layout.tsx)에서 localStorage 토큰 확인
   → 토큰 없으면 로그인 페이지로 리다이렉트

3. API 호출
   → authFetch 유틸리티가 Authorization 헤더 자동 추가
   → Authorization: Bearer <access_token>

4. 서버 미들웨어
   → Authorization 헤더 추출
   → jose 라이브러리로 JWT 서명 검증
   → 검증 실패 시 401 반환
```

### 미들웨어 JWT 검증 패턴

```typescript
import { jwtVerify } from 'jose';

export async function verifyToken(token: string) {
  const secret = new TextEncoder().encode(process.env.JWT_SECRET!);
  const { payload } = await jwtVerify(token, secret);
  return payload;
}

// API 핸들러에서 사용
export async function GET(request: Request) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return Response.json({ error: '인증이 필요합니다.' }, { status: 401 });
  }

  const token = authHeader.slice(7);
  try {
    const payload = await verifyToken(token);
    // payload.sub = 사용자 ID
  } catch {
    return Response.json({ error: '유효하지 않은 토큰입니다.' }, { status: 401 });
  }
}
```

### 주의 사항

- **JWT 토큰을 쿠키에 저장하지 않습니다** (아키텍처 결정 사항, CLAUDE.md 참고).
- `JWT_SECRET`은 최소 32자 이상의 랜덤 문자열을 사용합니다.
- 토큰 만료 시간을 반드시 설정합니다 (**현행 30분** — `app/web/src/features/auth/lib/jwt.ts`의 `setExpirationTime('30m')`과 일치. 변경 시 보안 영향 검토 필요, refresh_token 7일).
- 권장: refresh_token 재사용 방지(RTR, Refresh Token Rotation)를 구현하는 것을 권장합니다.

### 인가 (Authorization)

관리자 기능은 역할(role) 기반으로 접근을 제어합니다.

```typescript
// JWT payload에 role 포함
type JWTPayload = {
  sub: string;        // user_id
  role: 'user' | 'admin';
  iat: number;
  exp: number;
};

// 미들웨어에서 역할 검증
if (payload.role !== 'admin') {
  return Response.json({ error: '권한이 없습니다.' }, { status: 403 });
}
```

---

## 3. 데이터 노출 방지

### API 응답에서 제외해야 하는 필드

| 필드 | 이유 |
|------|------|
| `password_hash` | 비밀번호 해시 노출 금지 |
| `JWT_SECRET` 값 | 시크릿 키 노출 금지 |
| `ENCRYPTION_KEY` 값 | 암호화 키 노출 금지 |
| `refresh_token` (DB 저장 시) | 토큰 탈취 방지 |
| 사용자 개인정보 (이메일, 전화번호) | 불필요한 노출 방지 |

### 안전한 응답 패턴

```typescript
// 나쁜 예: DB 레코드를 그대로 반환
return Response.json(user);

// 좋은 예: 필요한 필드만 선택
return Response.json({
  id: user.id,
  name: user.name,
  // password_hash, created_at 등 내부 필드 제외
});
```

### 암호화

민감한 데이터 저장 시 `ENCRYPTION_KEY`를 사용하여 AES-256으로 암호화합니다.
`ENCRYPTION_KEY`는 32바이트(256비트) 이상이어야 합니다.

---

## 4. 네트워크 보안

### 보안 그룹 원칙

| 포트 | 허용 대상 | 현재 상태 |
|------|-----------|-----------|
| 22 (SSH) | 관리자 IP만 | `allowed_ssh_cidr` 변수로 제어 |
| 80 (HTTP) | 전체 | 허용 |
| 443 (HTTPS) | 전체 | 허용 |
| 3000 (앱) | `allowed_ssh_cidr` | 직접 접근 제한 |
| 3306 (MySQL) | Docker 내부 | 외부 미노출 |
| 6379 (Redis) | Docker 내부 | 외부 미노출 |
| 9200 (Elasticsearch) | Docker 내부 | 외부 미노출 |

**운영 환경 필수 조치:**
- `terraform.tfvars`의 `allowed_ssh_cidr`을 `"0.0.0.0/0"` 대신 실제 관리자 IP로 변경합니다.
- MySQL, Redis, Elasticsearch 포트는 절대 보안 그룹 인바운드 규칙에 추가하지 않습니다.

### Docker 내부 네트워크 격리

모든 컨테이너는 `app-network` 브리지 네트워크를 공유합니다.
DB, Redis, Elasticsearch는 외부 포트 바인딩 없이 컨테이너 간 통신만 허용합니다.

### RDS 사용 시 (권장 구성)

권장: RDS는 반드시 **프라이빗 서브넷**에 배치하고, EC2의 보안 그룹만 접근을 허용합니다.

```hcl
# Terraform 예시 (현재 미적용, 권장 구성)
resource "aws_db_instance" "main" {
  # ...
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # 외부 접근 차단
}
```

### SSH 보안

- 비밀번호 인증을 비활성화하고 키 기반 인증만 허용합니다.
- EC2 키페어는 안전한 장소에 보관하고 분실 시 즉시 폐기합니다.
- 권장: 기본 SSH 포트(22) 대신 비표준 포트 사용을 고려합니다.

---

## 5. CSRF / CORS / CSP 가이드

### CSRF (Cross-Site Request Forgery)

JWT를 Authorization 헤더로 전송하는 현재 구조는 기본적으로 CSRF 공격에 안전합니다.
(CSRF는 쿠키 기반 인증에서 주로 발생하는 공격)

- 쿠키에 토큰을 저장하지 않으므로 CSRF 토큰 없이도 보호됩니다.
- SameSite 쿠키를 사용하는 세션이 있다면 `SameSite=Strict` 또는 `SameSite=Lax`를 설정합니다.

### CORS (Cross-Origin Resource Sharing)

Next.js API Routes에서 CORS 설정:

```typescript
// app/web/src/app/api/v1/[...]/route.ts
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': process.env.NEXTAUTH_URL ?? '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}
```

운영 환경에서는 `Access-Control-Allow-Origin`을 `*` 대신 실제 도메인으로 제한합니다.

### CSP (Content Security Policy)

권장: `next.config.ts`에 CSP 헤더를 추가하는 것을 권장합니다.

```typescript
// app/web/next.config.ts
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-eval' 'unsafe-inline'", // Next.js 요구사항
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "connect-src 'self' https://api.openai.com",
    ].join('; '),
  },
  {
    key: 'X-Frame-Options',
    value: 'DENY',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
];
```

---

## 6. OWASP Top 10 체크리스트

| # | 취약점 | 상태 | 대응 방법 |
|---|--------|------|-----------|
| A01 | 접근 제어 실패 | 적용 | JWT 미들웨어 검증, 역할 기반 인가 |
| A02 | 암호화 실패 | 적용 | ENCRYPTION_KEY로 민감 데이터 암호화, HTTPS 강제 |
| A03 | 인젝션 | **필수** | Drizzle ORM prepared statement 사용 |
| A04 | 안전하지 않은 설계 | 적용 중 | zod 입력 검증, 최소 권한 원칙 |
| A05 | 보안 구성 오류 | 검토 필요 | 보안 그룹 IP 제한, 기본값 변경 |
| A06 | 취약하고 오래된 구성요소 | 적용 | pnpm audit, Dependabot |
| A07 | 식별 및 인증 실패 | 적용 | JWT 서명 검증, 토큰 만료 설정 |
| A08 | 소프트웨어 및 데이터 무결성 실패 | 권장 | pnpm frozen-lockfile, 이미지 버전 고정 |
| A09 | 보안 로깅 및 모니터링 실패 | 적용 중 | Slack 알림, 헬스체크 모니터링 |
| A10 | 서버사이드 요청 위조 (SSRF) | 검토 필요 | 외부 URL 요청 시 허용 도메인 화이트리스트 |

### A03 인젝션 — SQL Injection 방지 (Drizzle ORM)

```typescript
// 나쁜 예: 원시 SQL 문자열 보간
const result = await db.execute(
  sql`SELECT * FROM users WHERE email = '${userInput}'`  // 위험!
);

// 좋은 예: Drizzle 빌더 API 사용 (파라미터 자동 바인딩)
const result = await db.select()
  .from(users)
  .where(eq(users.email, userInput));  // 안전

// prepared statement
const prepared = db.select()
  .from(users)
  .where(eq(users.id, sql.placeholder('id')))
  .prepare('get_user');
const user = await prepared.execute({ id: userId });
```

### A03 인젝션 — XSS (Cross-Site Scripting) 방지

React는 기본적으로 JSX에서 HTML을 자동 이스케이프합니다.

```tsx
// 안전: React 자동 이스케이프
<div>{userContent}</div>

// 위험: HTML을 직접 삽입하는 API
// 이 API는 사용을 금지합니다.
// 부득이하게 사용해야 하는 경우 DOMPurify 등으로 반드시 새니타이징합니다.
```

XSS 방지 원칙:
- 사용자 입력을 HTML로 렌더링하는 API는 프로젝트에서 사용을 금지합니다.
- 부득이하게 HTML 렌더링이 필요한 경우에는 DOMPurify로 새니타이징 후 사용합니다.

---

## 7. 시크릿 누출 방지

### 커밋 전 검사

권장: git commit 전에 시크릿이 포함된 파일이 없는지 자동으로 검사하는 도구를 설치하는 것을 권장합니다.

#### gitleaks 설치 및 사용

```bash
# macOS
brew install gitleaks

# 현재 저장소 검사
gitleaks detect --source . --verbose

# pre-commit hook으로 자동 검사 설정
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks protect --staged
EOF
chmod +x .git/hooks/pre-commit
```

#### git-secrets 설치 및 사용

```bash
# macOS
brew install git-secrets

# AWS 키 패턴 등록
git secrets --register-aws

# 저장소에 훅 설치
git secrets --install
```

### .gitignore 필수 항목

`.gitignore`에 다음 항목이 포함되어 있는지 확인합니다:

```gitignore
# 환경변수 파일
.env
.env.local
.env.dev
.env.prod
.env.staging
infra/scripts/.env.*
infra/.env

# Terraform 상태 파일 (민감 정보 포함 가능)
*.tfstate
*.tfstate.backup
terraform.tfvars
```

주의: `app/infra/aws/terraform.tfstate` 파일이 저장소에 포함되어 있는지 확인하세요.
현재 `.gitignore`에 `terraform.tfstate`가 포함되어 있는지 반드시 검토가 필요합니다.

### 환경변수 하드코딩 금지

```typescript
// 금지: 코드에 시크릿 하드코딩
const jwtSecret = 'my-super-secret-key';

// 올바른 방법: 환경변수 사용
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) throw new Error('JWT_SECRET 환경변수가 설정되지 않았습니다.');
```

---

## 시크릿 회전 (Rotation) 정책

시크릿이 장기간 동일한 값으로 유지되면 탈취 시 피해 범위가 커집니다. 유형별 회전 주기와 절차를 준수합니다.

### 시크릿 유형별 회전 주기 및 절차

| 시크릿 유형 | 권장 회전 주기 | 회전 절차 | 비고 |
|---------|------------|---------|------|
| `JWT_SECRET` | 90일 | 새 시크릿 생성 → GitHub Secrets 등록 → grace period 동안 구/신 키 양쪽 인식 → 구 키 제거 | grace period 7일 권장. 기간 중 기존 토큰은 유효 |
| `NEXTAUTH_SECRET` | 90일 | 동일 | 회전 시 기존 세션 무효화 발생 가능 → 사용자 재로그인 필요 |
| `ENCRYPTION_KEY` | 365일 | 키 버전 관리(`v1`, `v2`) 도입 → 신 키로 신규 데이터 암호화 → 기존 데이터 점진 재암호화 → 구 키 제거 | 재암호화 배치 작업 필요. 데이터 볼륨에 따라 작업 기간 상이 |
| `OPENAI_API_KEY` | 사고 발생 시 즉시 | OpenAI 콘솔에서 신규 키 발급 → GitHub Secrets 교체 → 재배포 | 정기 회전 불필요. 노출 의심 즉시 폐기 |
| OAuth Client Secrets (Google/Apple/Kakao) | 사고 발생 시 즉시 | 각 콘솔에서 신규 시크릿 발급 → GitHub Secrets 교체 → 재배포 | 정기 회전 불필요 |
| DB 비밀번호 | 180일 | RDS: Secrets Manager 자동 회전 활용 / Docker MySQL: `ALTER USER ... IDENTIFIED BY '신규비밀번호'` 실행 후 `.env` 업데이트 + 재배포 | 재배포 시 약 1분 다운타임 발생 |
| AWS IAM 액세스 키 | 90일 | 신규 키 페어 발급 → GitHub Secrets 교체 → 배포 검증 → 구 키 비활성화 → 7일 후 삭제 | IAM Access Analyzer로 사용 여부 확인 후 삭제 |
| `SLACK_WEBHOOK_URL` | 사고 발생 시 즉시 | Slack 앱 설정에서 Webhook 재발급 → GitHub Secrets 교체 → 재배포 | 정기 회전 불필요 |

### GitHub Secrets 환경에서의 일반 회전 절차

```
1. 새 시크릿 값 생성 (랜덤 생성기 사용 권장)
   예: openssl rand -hex 32

2. GitHub 저장소 > Settings > Secrets and variables > Actions
   해당 Secret 값 수정

3. 다음 배포 시 자동으로 새 시크릿이 컨테이너에 주입됨

4. 즉시 적용이 필요한 경우:
   - GitHub Actions에서 해당 환경(dev/prod) 워크플로를 수동 트리거(workflow_dispatch)
   - 또는 빈 커밋으로 배포 유도: git commit --allow-empty -m "chore: rotate secret"
```

### 회전 이력 관리

누가 언제 어떤 시크릿을 회전했는지 기록합니다. 기록 위치는 팀 내부 비공개 채널(예: Notion 내부 문서 또는 사내 위키)을 사용하며, 실제 시크릿 값은 절대 기록하지 않습니다.

기록 형식 예시:

```
날짜: 2026-05-26
담당자: 홍길동
대상: JWT_SECRET, NEXTAUTH_SECRET
사유: 정기 90일 회전
영향: dev, prod 환경 재배포 완료 / 기존 세션 무효화 없음 (grace period 적용)
```

### 사고 발생 시 긴급 회전 체크리스트

시크릿 노출이 의심되거나 확인된 경우 즉시 아래 5단계를 순서대로 수행합니다.

```
1단계. 노출 확인 및 범위 파악
   [ ] 어떤 시크릿이 노출되었는가
   [ ] 노출 경로는 무엇인가 (코드 커밋, 로그 유출, 직원 퇴사 등)
   [ ] 노출 시점 이후 이상 접근 로그 확인 (AWS CloudTrail, GitHub Access Log 등)

2단계. 즉시 폐기
   [ ] 해당 시크릿을 즉시 무효화/폐기
     - AWS IAM 키: IAM 콘솔에서 즉시 비활성화
     - OpenAI API 키: OpenAI 콘솔에서 즉시 삭제
     - OAuth 시크릿: 각 제공자 콘솔에서 즉시 재발급
     - JWT_SECRET 등: 새 값 생성 후 GitHub Secrets 즉시 교체

3단계. 긴급 재배포
   [ ] 새 시크릿으로 dev 환경 배포 및 동작 확인
   [ ] prod 환경 긴급 배포 수행

4단계. 피해 범위 조사
   [ ] 노출된 시크릿으로 실제 비인가 접근이 발생했는지 로그 분석
   [ ] 영향받은 사용자 또는 데이터 범위 확인
   [ ] 필요 시 관련 사용자에게 세션 만료 처리

5단계. 사후 조치 및 재발 방지
   [ ] 노출 원인 제거 (코드에서 하드코딩 제거, .gitignore 보강 등)
   [ ] 내부 인시던트 보고서 작성
   [ ] 재발 방지 대책 적용 (gitleaks pre-commit hook 강화 등)
```

---

## 8. 의존성 보안

### 취약점 검사

```bash
# pnpm audit (알려진 취약점 검사)
cd app/web
pnpm audit

# 자동 수정 시도
pnpm audit --fix
```

### 권장: Dependabot 설정

권장: GitHub Dependabot을 활성화하여 의존성 취약점을 자동으로 감지하는 것을 권장합니다.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/app/web"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
  - package-ecosystem: "docker"
    directory: "/app/infra"
    schedule:
      interval: "monthly"
```

### Docker 이미지 보안

- 공식 이미지만 사용합니다 (`mysql:8.0`, `redis:7-alpine`, `node:20-alpine`).
- `latest` 태그 대신 구체적인 버전 태그를 사용합니다.
- 정기적으로 이미지를 최신 패치 버전으로 업데이트합니다.
- `Dockerfile`에서 루트 사용자로 실행하지 않습니다 (현재 `nextjs` 사용자, `worker` 사용자로 설정됨).

### 보안 패치 주기

| 대상 | 주기 |
|------|------|
| npm 의존성 | 주 1회 `pnpm audit` 실행 |
| Docker 기반 이미지 | 월 1회 버전 확인 및 업데이트 |
| EC2 OS 패키지 | 월 1회 `dnf update` 실행 (Amazon Linux 2023) |
| Terraform AWS Provider | 분기 1회 버전 검토 |
