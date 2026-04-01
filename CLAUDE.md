# Repaint — AI Painting Guide iPad App

## 프로젝트 컨텍스트
- iPad 전용 앱. Apple Pencil로 AI 가이드에 따라 풍경화를 그리는 앱.
- 사진 → segmentation → 스타일 매핑 → 단계별 페인팅 가이드 → 사용자 드로잉
- MVP: 모네 인상주의 스타일 1종, 풍경/정원 사진 전용

## 기술 스택
- iOS: SwiftUI, PencilKit, CoreML, AVFoundation (카메라)
- ML: DeepLabV3 (ResNet-101), ADE20K → landscape 5-class fine-tuning
- Backend (개발용): FastAPI, PyTorch, Docker
- CoreML 변환: coremltools

## 핵심 규칙
- iPad 전용 (iPadOS 17.0+). iPhone 지원 안 함.
- PencilKit은 PKCanvasView 사용. ink type: .watercolor, .marker, .pen
- 세그멘테이션 마스크는 CIImage로 처리, region별 CGPath 추출
- 스타일 레시피는 JSON으로 관리, 앱 번들에 포함
- 가이드 순서: background → midground → foreground → finish (뒤→앞)
- 사용자 stroke의 region coverage는 IoU로 측정 (70% 이상이면 다음 단계)

## 세그멘테이션 클래스 매핑 (ADE20K → 5-class)
- sky: ADE20K class 2
- water: ADE20K class 21, 26
- vegetation: ADE20K class 4, 9, 17, 66, 72
- flower: ADE20K class 67
- ground: ADE20K class 3, 6, 13, 29, 46
- 나머지 → background (class 0)

## 빌드 & 실행
- iOS: Xcode 16+, iPad Pro (M-chip) 또는 Simulator
- Server: `cd server && docker-compose up`
- ML: `cd ml && pip install -r requirements.txt`

## 자주 쓰는 명령
- CoreML 변환: `python ml/scripts/convert_to_coreml.py`
- 서버 테스트: `curl -X POST http://localhost:8000/segment -F "image=@test.jpg"`
- Lint: `swiftlint` (iOS), `ruff check .` (Python)

## 개발 현황
- 현재 단계: Phase 0 (프로젝트 초기화)
- 참고 문서: docs/Repaint-claude-code-prompt.md
