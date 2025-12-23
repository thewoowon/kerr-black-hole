// ============================================================================
// Kerr Black Hole Post-Processing Shader - 한글 주석 버전
// ============================================================================
// 이 셰이더는 인터스텔라의 가르강튀아처럼 회전하는 블랙홀을 렌더링합니다.
// 화면 전체(Full-Screen Quad)에 적용되는 Fragment Shader입니다.

// ============================================================================
// UNIFORM 변수들 (JavaScript/React에서 전달받는 값들)
// ============================================================================

uniform vec2 uResolution;        // 화면 해상도 (width, height)
uniform vec3 uCamPos;            // 카메라 위치
uniform float uTime;             // 시간 (애니메이션용)

// 물리 파라미터
uniform float uMass;             // 블랙홀 질량 (M)
uniform float uSpin;             // 블랙홀 회전 파라미터 (a = J/M, 각운동량)

// 강착 원반(Accretion Disk) 파라미터
uniform float uDiskInner;        // 원반 내부 반지름
uniform float uDiskOuter;        // 원반 외부 반지름
uniform float uDiskThickness;    // 원반 두께 (Y축 방향)
uniform float uDiskRotationSpeed; // 원반 회전 속도

// 시각 효과 파라미터
uniform float uGlowIntensity;    // 발광 강도 (현재 미사용)

// ============================================================================
// 상수 정의
// ============================================================================

#ifndef PI
#define PI 3.14159265359         // 원주율
#endif

#ifndef EPSILON
#define EPSILON 0.0001           // 0으로 나누는 것 방지용 작은 값
#endif

#define MAX_STEPS 300            // Ray Marching 최대 스텝 수 (클수록 정확하지만 느림)
#define STEP_SIZE 0.1            // 한 스텝당 이동 거리 (작을수록 정밀하지만 느림)

// ============================================================================
// SIMPLEX NOISE (절차적 노이즈 생성 - 강착 원반 텍스처용)
// ============================================================================
// 3D Simplex Noise - 표준 알고리즘 (Stefan Gustavson)
// 강착 원반에 불규칙한 패턴을 만들기 위해 사용됩니다.

vec4 permute(vec4 x) {
    // 유사 난수 생성을 위한 순열 함수
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}

vec4 taylorInvSqrt(vec4 r) {
    // Taylor 급수 근사를 이용한 역제곱근 (빠른 계산용)
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    // 3D Simplex Noise 메인 함수
    // 입력: 3D 좌표 v
    // 출력: -1.0 ~ 1.0 범위의 노이즈 값

    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // 그리드 좌표 계산
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Simplex 내 위치 결정
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    // 코너 오프셋
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;

    // 순열 계산
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // 그래디언트 계산
    float n_ = 1.0 / 7.0;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    // 정규화
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // 보간 및 최종 노이즈 값 계산
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// ============================================================================
// UTILITY FUNCTIONS (유틸리티 함수들)
// ============================================================================

// 쿼터니언 생성: 축-각도 회전을 쿼터니언으로 변환
vec4 quadFromAxisAngle(vec3 axis, float angle) {
    vec4 qr;
    float half_angle = (angle * 0.5) * PI / 180.0;  // 각도를 라디안으로 변환 후 절반
    qr.x = axis.x * sin(half_angle);
    qr.y = axis.y * sin(half_angle);
    qr.z = axis.z * sin(half_angle);
    qr.w = cos(half_angle);
    return qr;
}

// 쿼터니언 켤레(Conjugate): 역회전 표현
vec4 quadConj(vec4 q) {
    return vec4(-q.x, -q.y, -q.z, q.w);
}

// 쿼터니언 곱셈: 두 회전을 합성
vec4 quat_mult(vec4 q1, vec4 q2) {
    vec4 qr;
    qr.x = (q1.w * q2.x) + (q1.x * q2.w) + (q1.y * q2.z) - (q1.z * q2.y);
    qr.y = (q1.w * q2.y) - (q1.x * q2.z) + (q1.y * q2.w) + (q1.z * q2.x);
    qr.z = (q1.w * q2.z) + (q1.x * q2.y) - (q1.y * q2.x) + (q1.z * q2.w);
    qr.w = (q1.w * q2.w) - (q1.x * q2.x) - (q1.y * q2.y) - (q1.z * q2.z);
    return qr;
}

// 벡터를 축 기준으로 회전 (쿼터니언 사용)
vec3 rotateVector(vec3 position, vec3 axis, float angle) {
    vec4 qr = quadFromAxisAngle(axis, angle);           // 회전 쿼터니언
    vec4 qr_conj = quadConj(qr);                        // 켤레 쿼터니언
    vec4 q_pos = vec4(position.x, position.y, position.z, 0.0);  // 위치를 쿼터니언 형태로

    vec4 q_tmp = quat_mult(qr, q_pos);                  // q * p
    qr = quat_mult(q_tmp, qr_conj);                     // (q * p) * q^-1

    return vec3(qr.x, qr.y, qr.z);                      // 회전된 벡터 반환
}

// 직교 좌표 → 구면 좌표 변환
vec3 toSpherical(vec3 p) {
    float rho = length(p);                              // 반지름 (r)
    float theta = atan(p.z, p.x);                       // 방위각 (azimuth, φ)
    float phi = asin(clamp(p.y / rho, -1.0, 1.0));      // 고도각 (elevation, θ)
    return vec3(rho, theta, phi);
}

// ============================================================================
// 중력 가속도 계산 (슈바르츠실트 근사)
// ============================================================================
// 블랙홀 주변에서 광선이 휘어지는 효과를 계산합니다.
// 정확한 Kerr metric을 쓰지 않고, 유효 포텐셜 기반 근사를 사용합니다.

vec3 accel(float h2, vec3 pos) {
    // 입력:
    //   h2  - 각운동량의 제곱 (h^2)
    //   pos - 현재 광선 위치
    // 출력:
    //   가속도 벡터 (광선 방향 변화)

    float r2 = dot(pos, pos);    // r^2 = x^2 + y^2 + z^2
    float r = sqrt(r2);          // 중심으로부터 거리

    // 중심 너무 가까우면 가속도 0 (수치 안정성)
    if (r < 1.0) {
        return vec3(0.0);
    }

    // 유효 포텐셜 기반 가속도 계산
    // V_eff = h^2/r^2 - 2Mh^2/r^3
    // 가속도 a ∝ -∂V/∂r ∝ -h^2/r^3 (근사)

    float r5 = pow(r2, 2.5);                // r^5 = (r^2)^2.5
    vec3 acc = -1.5 * h2 * pos / r5;        // 중심 방향 가속도

    // 계수 -1.5는 실험적 조정값
    // 물리적으로 정확한 값은 아니지만, 시각적으로 적절한 렌즈 효과를 만듭니다.

    return acc;
}

// ============================================================================
// ACCRETION DISK (강착 원반 렌더링)
// ============================================================================
// 블랙홀 주변을 도는 뜨거운 가스 원반을 그립니다.
// 도플러 효과로 한쪽은 파랗게(blue-shift), 한쪽은 붉게(red-shift) 표현합니다.

void adiskColor(vec3 pos, inout vec3 color, inout float alpha) {
    // 입력:
    //   pos   - 현재 광선 위치
    // 출력:
    //   color - 누적 색상에 원반 색상 추가
    //   alpha - 투명도 (누적용)

    float innerRadius = uDiskInner;     // 원반 내부 경계
    float outerRadius = uDiskOuter;     // 원반 외부 경계

    // ========================================================================
    // 1. 원반 영역 판정: 타원체(ellipsoid) 내부인지 확인
    // ========================================================================
    // X, Z 방향: outerRadius로 스케일
    // Y 방향: uDiskThickness로 스케일 (얇은 원반)
    float density = max(0.0, 1.0 - length(pos.xyz / vec3(outerRadius, uDiskThickness, outerRadius)));

    if (density < 0.001) return;  // 원반 밖이면 즉시 반환

    // ========================================================================
    // 2. Y축 방향 감쇠: 원반 중심(y=0)에서 가장 밝고, 위아래로 어두워짐
    // ========================================================================
    density *= pow(1.0 - abs(pos.y) / uDiskThickness, 2.0);

    // ========================================================================
    // 3. 내부 경계 부드럽게 처리 (smoothstep)
    // ========================================================================
    // innerRadius보다 안쪽은 완전히 어둡고, 1.1배 지점부터 서서히 밝아짐
    density *= smoothstep(innerRadius, innerRadius * 1.1, length(pos));

    if (density < 0.001) return;

    // ========================================================================
    // 4. 구면 좌표 변환 및 노이즈 스케일 조정
    // ========================================================================
    vec3 sphericalCoord = toSpherical(pos);
    sphericalCoord.y *= 2.0;  // 방위각 스케일 (노이즈 패턴 조절)
    sphericalCoord.z *= 4.0;  // 고도각 스케일

    // ========================================================================
    // 5. 거리 기반 밝기: 블랙홀에 가까울수록 밝음 (중력 에너지 방출)
    // ========================================================================
    // 물리: 강착 물질이 블랙홀에 가까울수록 뜨거워짐
    // 근사: 밝기 ∝ 1/r^4
    density *= 1.0 / pow(sphericalCoord.x, 4.0);
    density *= 32000.0;  // 전체 밝기 증폭

    // ========================================================================
    // 6. 절차적 노이즈로 텍스처 생성
    // ========================================================================
    // 다층 노이즈를 겹쳐서 복잡한 패턴 생성
    float noise = 1.0;
    for (int i = 0; i < 5; i++) {
        noise *= 0.5 * snoise(sphericalCoord * pow(float(i), 2.0) * 0.8) + 0.5;

        // 짝수/홀수 레이어마다 회전 방향 반대 (난류 효과)
        if (i % 2 == 0) {
            sphericalCoord.y += uTime * uDiskRotationSpeed;
        } else {
            sphericalCoord.y -= uTime * uDiskRotationSpeed;
        }
    }

    // ========================================================================
    // 7. 케플러 궤도 및 도플러 효과 계산
    // ========================================================================
    float r = length(pos.xz);              // XZ 평면상 거리
    float angle = atan(pos.z, pos.x);      // 방위각

    // 온도: 안쪽일수록 뜨거움
    float temp = smoothstep(outerRadius, innerRadius, r);
    temp = pow(temp, 0.75);

    // 케플러 궤도 속도: v ∝ 1/√r
    float orbitalVel = 1.0 / sqrt(max(r, 0.1));

    // 현재 시간에서의 회전 각도
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;

    // 도플러 인자: sin(각도)로 접근/후퇴 판단
    float dopplerFactor = sin(rotAngle);

    // 상대론적 빔잉(beaming) 효과 근사
    float beaming = 1.0 + dopplerFactor * 0.7;

    // ========================================================================
    // 8. 도플러 색상 매핑
    // ========================================================================
    vec3 blueshifted = vec3(0.3, 0.6, 2.0);   // 접근: 파랗고 밝음
    vec3 neutral = vec3(1.2, 1.0, 0.7);       // 중립: 주황색
    vec3 redshifted = vec3(2.0, 0.3, 0.05);   // 후퇴: 붉고 어두움

    vec3 diskColor;
    if (dopplerFactor > 0.0) {
        // 관측자 방향으로 움직임 → blue-shift
        diskColor = mix(neutral, blueshifted, dopplerFactor);
    } else {
        // 관측자 반대 방향으로 움직임 → red-shift
        diskColor = mix(neutral, redshifted, -dopplerFactor);
    }

    // 온도 기반 색상 보정 (안쪽일수록 하얗게)
    diskColor = mix(diskColor, vec3(1.8, 1.6, 1.4), temp * 0.8);

    // 최종 밝기 계산
    float brightness = (temp * 12.0 + 2.0) * beaming;
    diskColor *= brightness;

    // ========================================================================
    // 9. 최종 색상 누적
    // ========================================================================
    color += density * 0.8 * diskColor * alpha * abs(noise);
}

// ============================================================================
// 배경 샘플링 (우주 별 생성)
// ============================================================================
// 광선이 블랙홀에 포획되지 않고 멀리 나갔을 때, 배경 별을 샘플링합니다.

vec3 sampleBackground(vec3 dir) {
    // 입력: 광선 방향 (정규화된 벡터)
    // 출력: 배경 색상 (별)

    // 배경을 천천히 회전 (시각적 효과)
    dir = rotateVector(dir, vec3(0.0, 1.0, 0.0), uTime * 10.0);

    // ========================================================================
    // 구면 좌표 → UV 매핑 (Equirectangular projection)
    // ========================================================================
    vec2 uv = vec2(
        0.5 - atan(dir.z, dir.x) / (2.0 * PI),      // 방위각 → U (0~1)
        0.5 - asin(clamp(dir.y, -1.0, 1.0)) / PI    // 고도각 → V (0~1)
    );

    vec3 bgColor = vec3(0.0);

    // ========================================================================
    // 절차적 별 생성 (Hash 기반 랜덤)
    // ========================================================================
    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);              // 스케일 증가 (다양한 크기의 별)
        vec2 coord = uv * 30.0 * scale;

        // 유사 난수 생성 (sin + dot 해시)
        float n = fract(sin(dot(coord, vec2(127.1, 311.7))) * 43758.5453123);

        // 0.5% 확률로만 별 생성 (threshold: 0.995)
        // i가 클수록 threshold 낮아짐 (작은 별 더 많이)
        stars += step(0.995 - i * 0.003, n) * (1.0 - i * 0.25);
    }

    bgColor = vec3(stars) * 0.9;  // 별 밝기

    return bgColor;
}

// ============================================================================
// RAY TRACING 메인 함수
// ============================================================================
// 광선을 블랙홀 주변에서 추적하며, 중력 렌즈 + 강착 원반 + 배경을 렌더링합니다.

vec3 traceColor(vec3 pos, vec3 dir) {
    // 입력:
    //   pos - 광선 시작 위치 (카메라 위치)
    //   dir - 광선 방향 (픽셀 방향)
    // 출력:
    //   최종 색상

    vec3 color = vec3(0.0);  // 누적 색상
    float alpha = 1.0;       // 투명도

    dir *= STEP_SIZE;  // 방향 벡터를 스텝 크기로 스케일

    // ========================================================================
    // 각운동량 계산 (보존량)
    // ========================================================================
    vec3 h = cross(pos, dir);     // h = r × v
    float h2 = dot(h, h);         // h^2 (광선이 얼마나 휘어질지 결정)

    // ========================================================================
    // Ray Marching Loop
    // ========================================================================
    for (int i = 0; i < MAX_STEPS; i++) {
        float r = length(pos);  // 블랙홀 중심으로부터 거리

        // ====================================================================
        // 사건의 지평선 판정 (Event Horizon)
        // ====================================================================
        // Schwarzschild: r_s = 2M
        // Kerr (근사): r_s ≈ 2M(1 - a/2)
        float eventHorizon = 2.0 * uMass * (1.0 - uSpin * 0.5);

        if (r < eventHorizon) {
            return color;  // 블랙홀에 포획됨 → 검은색 반환
        }

        // ====================================================================
        // 충분히 멀리 벗어났으면 배경 샘플링 후 종료
        // ====================================================================
        if (r > 100.0) {
            color += sampleBackground(normalize(dir)) * alpha;
            return color;
        }

        // ====================================================================
        // 강착 원반 색상 추가
        // ====================================================================
        adiskColor(pos, color, alpha);

        // ====================================================================
        // 중력 가속도 적용 (광선 휘어짐)
        // ====================================================================
        vec3 acc = accel(h2, pos);
        dir += acc;  // 방향 업데이트

        // ====================================================================
        // 광선 위치 전진
        // ====================================================================
        pos += dir;
    }

    // 최대 스텝 도달 → 배경 샘플링
    color += sampleBackground(normalize(dir)) * alpha;
    return color;
}

// ============================================================================
// Look-At 행렬 생성
// ============================================================================
// 카메라의 "시선 방향"을 나타내는 회전 행렬을 만듭니다.

mat3 lookAt(vec3 origin, vec3 target, float roll) {
    // 입력:
    //   origin - 카메라 위치
    //   target - 카메라가 바라보는 대상
    //   roll   - 카메라 회전(roll) 각도
    // 출력:
    //   3x3 회전 행렬 (뷰 행렬)

    vec3 rr = vec3(sin(roll), cos(roll), 0.0);  // Roll 벡터
    vec3 ww = normalize(target - origin);       // Forward 방향
    vec3 uu = normalize(cross(ww, rr));         // Right 방향
    vec3 vv = normalize(cross(uu, ww));         // Up 방향

    return mat3(uu, vv, ww);  // 열 벡터로 행렬 구성
}

// ============================================================================
// MAIN IMAGE (Fragment Shader 진입점)
// ============================================================================
// 각 픽셀마다 실행되는 메인 함수입니다.

void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
    // 입력:
    //   inputColor - 이전 렌더링 결과 (현재 미사용)
    //   uv         - 현재 픽셀의 UV 좌표 (0~1 범위)
    // 출력:
    //   outputColor - 최종 픽셀 색상

    // ========================================================================
    // 1. 카메라 설정
    // ========================================================================
    vec3 cameraPos = uCamPos;                   // 카메라 위치 (uniform)
    vec3 target = vec3(0.0, 0.0, 0.0);          // 블랙홀 중심을 바라봄
    mat3 view = lookAt(cameraPos, target, 0.0); // 뷰 행렬

    // ========================================================================
    // 2. 화면 좌표를 NDC(Normalized Device Coordinates)로 변환
    // ========================================================================
    vec2 screenUv = uv * 2.0 - 1.0;  // [0,1] → [-1,1]
    screenUv.x *= uResolution.x / uResolution.y;  // Aspect ratio 보정

    // ========================================================================
    // 3. Ray Direction 생성
    // ========================================================================
    vec3 dir = normalize(vec3(-screenUv.x, screenUv.y, 1.0));
    dir = view * dir;  // 카메라 방향 적용

    // ========================================================================
    // 4. Ray Tracing 수행
    // ========================================================================
    vec3 finalColor = traceColor(cameraPos, dir);

    // ========================================================================
    // 5. 후처리 효과
    // ========================================================================

    // Vignette (주변부 어둡게)
    float vignette = 1.0 - length(screenUv) * 0.15;
    finalColor *= vignette;

    // Gamma Correction (감마 보정)
    finalColor = pow(finalColor, vec3(0.85));

    // ========================================================================
    // 6. 최종 출력
    // ========================================================================
    outputColor = vec4(finalColor, 1.0);
}

// ============================================================================
// 끝!
// ============================================================================
// 이 셰이더는:
// - 슈바르츠실트 근사를 사용한 중력 렌즈 효과
// - 케플러 궤도 + 도플러 효과 기반 강착 원반
// - 절차적 별 생성 배경
// 을 실시간으로 렌더링합니다.
//
// 정확한 Kerr metric을 구현하지 않았지만,
// 시각적으로 설득력 있는 "인터스텔라 스타일" 블랙홀을 만듭니다.
// ============================================================================
