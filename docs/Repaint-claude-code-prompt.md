# Repaint — AI Painting Coach for iPad

## Claude Code 프로젝트 프롬프트

> 이 문서는 "Repaint" iPad 앱의 MVP 개발을 위한 종합 기술 프롬프트입니다.
> 사진을 보고 AI 가이드에 따라 내 손으로 다시 그리는(Re-paint) 경험을 만듭니다.
> Claude Code에서 이 프롬프트를 참조하여 전체 프로젝트를 단계별로 구현합니다.

---

## 1. 프로젝트 개요

### 앱 이름
**Repaint** — AI Painting Coach
*"사진을 내 손으로 다시 그리다"*

App Store 표기: **Repaint — AI Painting Coach**

### 핵심 컨셉
사용자가 iPad으로 풍경 사진을 촬영하면, AI가 사진을 영역별로 분석(segmentation)하고, 선택한 화풍(MVP: 모네 인상주의)에 맞는 단계별 페인팅 가이드를 생성한다. 사용자는 Apple Pencil로 가이드를 따라 실제로 그리며, 완성하면 모네의 수련 같은 작품이 완성된다.

### MVP 범위
- 입력: iPad 카메라로 촬영한 정원/풍경 사진 1장
- 스타일: 모네 인상주의 (Water Lilies) 1종
- 세그멘테이션 클래스: sky, water, vegetation, flower, ground (5개)
- 가이드: 단계별 (Background → Midground → Foreground → Finish)
- 출력: 완성된 작품 PNG 저장 + Before/After 비교

---

## 2. 시스템 아키텍처

### 전체 구조
```
┌─────────────────────────────────────┐
│          iPad App (SwiftUI)         │
│  ┌──────────┬──────────┬──────────┐ │
│  │ Camera   │ Canvas   │ Style    │ │
│  │ Capture  │ View     │ Preview  │ │
│  │          │(PencilKit│          │ │
│  │          │+Overlay) │          │ │
│  └──────────┴──────────┴──────────┘ │
│         │                  ▲        │
│         │ Photo            │ Guide  │
│         ▼                  │ JSON   │
│  ┌──────────────────────────────┐   │
│  │    CoreML (On-device)        │   │
│  │    DeepLabV3 Segmentation    │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
         │ (확장 시)
         ▼
┌─────────────────────────────────────┐
│       Backend (FastAPI)             │
│  - Advanced segmentation (SAM)      │
│  - Style recipe generation (LLM)    │
│  - User gallery / community         │
└─────────────────────────────────────┘
```

### MVP는 온디바이스 우선
- CoreML로 변환한 DeepLabV3 모델을 iPad에서 직접 실행
- 스타일 레시피는 앱에 하드코딩 (JSON)
- 서버 의존 없이 오프라인 동작 가능
- 개발/실험 단계에서는 FastAPI 서버도 병행 (모델 비교, 레시피 실험용)

---

## 3. 프로젝트 디렉토리 구조

```
Repaint/
├── ios/                          # iPad App (Xcode Project)
│   ├── Repaint.xcodeproj
│   ├── Repaint/
│   │   ├── App/
│   │   │   ├── RepaintApp.swift
│   │   │   └── ContentView.swift
│   │   ├── Models/
│   │   │   ├── SegmentationModel.swift      # CoreML inference wrapper
│   │   │   ├── PaintingGuide.swift          # Guide data model
│   │   │   ├── StyleRecipe.swift            # Style preset model
│   │   │   └── Region.swift                 # Segmented region model
│   │   ├── Views/
│   │   │   ├── CameraView.swift             # Camera capture
│   │   │   ├── CanvasView.swift             # PencilKit canvas + overlay
│   │   │   ├── GuideOverlayView.swift       # Region highlight + hints
│   │   │   ├── PaletteView.swift            # Color swatch picker
│   │   │   ├── BrushSettingsView.swift       # Brush type selector
│   │   │   ├── ProgressView.swift           # Step progress tracker
│   │   │   ├── ComparisonView.swift         # Before/After slider
│   │   │   ├── GalleryView.swift            # Completed works
│   │   │   └── OnboardingView.swift         # First-time tutorial
│   │   ├── ViewModels/
│   │   │   ├── CameraViewModel.swift
│   │   │   ├── PaintingSessionViewModel.swift  # Core session controller
│   │   │   └── GalleryViewModel.swift
│   │   ├── Services/
│   │   │   ├── SegmentationService.swift    # CoreML model loading/inference
│   │   │   ├── GuideGeneratorService.swift  # Segmentation → painting guide
│   │   │   ├── CoverageCalculator.swift     # Stroke coverage measurement
│   │   │   └── StyleRecipeLoader.swift      # JSON recipe parser
│   │   ├── Resources/
│   │   │   ├── DeepLabV3.mlmodel            # CoreML model
│   │   │   └── Recipes/
│   │   │       └── monet_water_lilies.json  # Style recipe
│   │   └── Utilities/
│   │       ├── ImageProcessing.swift        # CIImage / CGImage helpers
│   │       └── ColorUtils.swift             # Color space conversion
│   │
│   └── RepaintTests/
│
├── server/                        # Backend (개발/실험용)
│   ├── main.py                    # FastAPI entry
│   ├── routers/
│   │   ├── segmentation.py        # POST /segment
│   │   └── guide.py               # POST /generate-guide
│   ├── models/
│   │   ├── segmentation.py        # PyTorch model wrapper
│   │   └── schemas.py             # Pydantic schemas
│   ├── services/
│   │   ├── segment_service.py
│   │   └── guide_generator.py
│   ├── recipes/
│   │   └── monet_water_lilies.json
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── ml/                            # ML 모델 학습/변환
│   ├── notebooks/
│   │   ├── 01_deeplab_finetune.ipynb     # 파인튜닝 노트북
│   │   ├── 02_coreml_conversion.ipynb    # CoreML 변환
│   │   └── 03_segmentation_eval.ipynb    # 평가
│   ├── scripts/
│   │   ├── train.py
│   │   ├── convert_to_coreml.py
│   │   └── evaluate.py
│   ├── data/
│   │   └── README.md              # 데이터셋 구성 가이드
│   └── configs/
│       └── deeplab_landscape.yaml
│
├── docs/
│   ├── architecture.md
│   ├── style_recipe_spec.md       # Style recipe JSON 스펙
│   └── api_spec.md
│
├── .claude/
│   └── settings.json              # Claude Code 설정
│
├── CLAUDE.md                      # Claude Code 프로젝트 컨텍스트
└── README.md
```

---

## 4. CLAUDE.md (Claude Code 프로젝트 메모리)

아래 내용을 프로젝트 루트의 `CLAUDE.md` 파일로 생성하세요:

```markdown
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

## 빌드 & 실행
- iOS: Xcode 16+, iPad Pro (M-chip) 또는 Simulator
- Server: `cd server && docker-compose up`
- ML: `cd ml && pip install -r requirements.txt`

## 자주 쓰는 명령
- CoreML 변환: `python ml/scripts/convert_to_coreml.py`
- 서버 테스트: `curl -X POST http://localhost:8000/segment -F "image=@test.jpg"`
- Lint: `swiftlint` (iOS), `ruff check .` (Python)
```

---

## 5. 핵심 데이터 모델 — Style Recipe JSON 스펙

### monet_water_lilies.json

```json
{
  "style_id": "monet_water_lilies",
  "style_name": "Monet — Water Lilies",
  "description": "Impressionist landscape with soft, layered brushwork",
  "canvas_settings": {
    "background_color": "#F5F0E8",
    "suggested_canvas_size": { "width": 2048, "height": 1536 }
  },
  "painting_order": ["background", "midground", "foreground", "finish"],
  "region_recipes": {
    "sky": {
      "layer": "background",
      "palette": [
        { "hex": "#B8C9E0", "name": "Pale blue", "usage": "Base wash" },
        { "hex": "#D4A8C7", "name": "Lavender pink", "usage": "Cloud highlights" },
        { "hex": "#E8D5B7", "name": "Warm cream", "usage": "Horizon glow" },
        { "hex": "#9BAFC4", "name": "Steel blue", "usage": "Upper sky depth" }
      ],
      "brush": {
        "type": "watercolor",
        "size_range": { "min": 20, "max": 60 },
        "opacity": 0.4
      },
      "stroke_guide": {
        "direction": "horizontal",
        "pattern": "long_sweeping",
        "description": "Wide horizontal strokes, overlapping. Start light, layer darker."
      },
      "tips": [
        "Start with the lightest color as a base wash",
        "Add depth with slightly darker tones at the top",
        "Leave some canvas showing through for luminosity"
      ]
    },
    "water": {
      "layer": "background",
      "palette": [
        { "hex": "#4A7B6F", "name": "Deep teal", "usage": "Water base" },
        { "hex": "#6B9E8A", "name": "Sage green", "usage": "Mid-tone reflections" },
        { "hex": "#8FBCAA", "name": "Light aqua", "usage": "Surface shimmer" },
        { "hex": "#3D5E54", "name": "Dark green", "usage": "Depth shadows" }
      ],
      "brush": {
        "type": "watercolor",
        "size_range": { "min": 15, "max": 45 },
        "opacity": 0.5
      },
      "stroke_guide": {
        "direction": "horizontal",
        "pattern": "short_dabs",
        "description": "Short horizontal dabs with varying pressure. Mirror sky colors faintly."
      },
      "tips": [
        "Horizontal strokes only — water is flat",
        "Reflect sky colors at ~30% intensity",
        "Dark areas suggest depth, light areas suggest reflection"
      ]
    },
    "vegetation": {
      "layer": "midground",
      "palette": [
        { "hex": "#3B6B35", "name": "Forest green", "usage": "Base foliage" },
        { "hex": "#5A8F4E", "name": "Leaf green", "usage": "Sunlit areas" },
        { "hex": "#2D4F28", "name": "Shadow green", "usage": "Depth in foliage" },
        { "hex": "#7AB648", "name": "Bright lime", "usage": "Highlight touches" }
      ],
      "brush": {
        "type": "marker",
        "size_range": { "min": 10, "max": 30 },
        "opacity": 0.6
      },
      "stroke_guide": {
        "direction": "varied",
        "pattern": "stipple_cluster",
        "description": "Clusters of small marks suggesting leaf groupings. Vary pressure for organic feel."
      },
      "tips": [
        "Build up in layers: dark base, then lighter on top",
        "Cluster marks — don't try to paint individual leaves",
        "Leave gaps between clusters for depth"
      ]
    },
    "flower": {
      "layer": "foreground",
      "palette": [
        { "hex": "#E8A5C8", "name": "Rose pink", "usage": "Petal base" },
        { "hex": "#F2D4E0", "name": "Soft pink", "usage": "Petal highlights" },
        { "hex": "#C74B8B", "name": "Deep magenta", "usage": "Petal shadows" },
        { "hex": "#F5E6A3", "name": "Warm yellow", "usage": "Center/stamen" }
      ],
      "brush": {
        "type": "pen",
        "size_range": { "min": 5, "max": 15 },
        "opacity": 0.8
      },
      "stroke_guide": {
        "direction": "radial",
        "pattern": "circular_dabs",
        "description": "Small circular dabs radiating from center. Pure color, minimal mixing."
      },
      "tips": [
        "Use pure, unmixed colors — impressionist purity",
        "Each dab is a petal. Don't overblend.",
        "Add yellow center last as a bright accent"
      ]
    },
    "ground": {
      "layer": "midground",
      "palette": [
        { "hex": "#8B7355", "name": "Earth brown", "usage": "Ground base" },
        { "hex": "#A69070", "name": "Sand", "usage": "Light areas" },
        { "hex": "#6B5540", "name": "Dark earth", "usage": "Shadow/depth" },
        { "hex": "#7A8B5A", "name": "Moss green", "usage": "Grass patches" }
      ],
      "brush": {
        "type": "watercolor",
        "size_range": { "min": 15, "max": 40 },
        "opacity": 0.5
      },
      "stroke_guide": {
        "direction": "horizontal",
        "pattern": "varied_wash",
        "description": "Horizontal washes with earth tones. Add texture with small vertical dabs."
      },
      "tips": [
        "Ground anchors the scene — keep it darker near bottom",
        "Blend into water/vegetation edges softly",
        "Add moss green dabs where ground meets plants"
      ]
    }
  },
  "finish_pass": {
    "description": "Final enhancement pass after all regions complete",
    "steps": [
      {
        "name": "Highlight sparkle",
        "palette": [{ "hex": "#FFFFFF", "name": "Pure white" }],
        "brush": { "type": "pen", "size_range": { "min": 2, "max": 5 }, "opacity": 0.9 },
        "instruction": "Add tiny white dots on water surface for light reflection"
      },
      {
        "name": "Shadow anchoring",
        "palette": [{ "hex": "#2A3A2E", "name": "Dark shadow" }],
        "brush": { "type": "watercolor", "size_range": { "min": 10, "max": 20 }, "opacity": 0.3 },
        "instruction": "Deepen shadows under flowers and at water edges"
      },
      {
        "name": "Atmospheric blend",
        "palette": [{ "hex": "#D4C4A8", "name": "Warm haze" }],
        "brush": { "type": "watercolor", "size_range": { "min": 40, "max": 80 }, "opacity": 0.1 },
        "instruction": "Very light warm wash over entire painting to unify colors"
      }
    ]
  }
}
```

---

## 6. 핵심 구현 가이드

### 6.1 세그멘테이션 (CoreML)

```swift
// SegmentationService.swift — 핵심 구현 방향

import CoreML
import Vision
import CoreImage

class SegmentationService {
    private var model: VNCoreMLModel?
    
    // DeepLabV3 CoreML 모델 로드
    func loadModel() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // Neural Engine 활용
        let mlModel = try DeepLabV3(configuration: config).model
        self.model = try VNCoreMLModel(for: mlModel)
    }
    
    // 이미지 → 세그멘테이션 마스크
    // VNPixelBufferObservation으로 결과 수신
    // 각 픽셀값이 클래스 ID (0: background, 1: sky, 2: water, ...)
    // 결과를 Region 객체 배열로 변환
    
    // 클래스 매핑 (ADE20K → 우리 5-class)
    // ADE20K sky (2) → sky
    // ADE20K water (21) → water  
    // ADE20K tree (4), plant (17), grass (9) → vegetation
    // ADE20K flower (66) → flower
    // ADE20K earth (13), floor (3), road (6) → ground
    // 나머지 → ground (fallback)
}
```

**CoreML 변환 스크립트 핵심:**
```python
# ml/scripts/convert_to_coreml.py

import coremltools as ct
import torch
from torchvision.models.segmentation import deeplabv3_resnet101

# 1. PyTorch 모델 로드 (pretrained 또는 fine-tuned)
model = deeplabv3_resnet101(pretrained=True)
model.eval()

# 2. Trace
example_input = torch.randn(1, 3, 513, 513)
traced = torch.jit.trace(model, example_input)

# 3. CoreML 변환
# 입력: 513x513 RGB 이미지
# 출력: 513x513 segmentation map (각 픽셀 = class ID)
mlmodel = ct.convert(
    traced,
    inputs=[ct.ImageType(name="image", shape=(1, 3, 513, 513),
                         scale=1/255.0,
                         bias=[-0.485/0.229, -0.456/0.224, -0.406/0.225])],
    minimum_deployment_target=ct.target.iOS17
)
mlmodel.save("DeepLabV3.mlpackage")

# 4. 변환 후 검증
# - iPad Pro M2에서 inference 시간 < 500ms 확인
# - ADE20K val set에서 mIoU > 0.70 확인
```

### 6.2 PencilKit 캔버스 + 가이드 오버레이

```swift
// CanvasView.swift — 핵심 구현 방향

import SwiftUI
import PencilKit

struct CanvasView: View {
    @StateObject var session: PaintingSessionViewModel
    
    var body: some View {
        ZStack {
            // Layer 1: 원본 사진 (선택적 표시, 낮은 opacity)
            if session.showReference {
                Image(uiImage: session.originalPhoto)
                    .resizable()
                    .opacity(0.15)
            }
            
            // Layer 2: PencilKit 캔버스
            PencilCanvasRepresentable(
                canvasView: $session.canvasView,
                inkType: session.currentBrush.toPKInkType(),
                inkColor: session.currentColor
            )
            
            // Layer 3: 가이드 오버레이 (현재 활성 영역 하이라이트)
            GuideOverlayView(
                activeRegion: session.currentRegion,
                allRegions: session.regions,
                strokeHints: session.currentStrokeHints
            )
            
            // Layer 4: UI 컨트롤 (팔레트, 진행률)
            VStack {
                Spacer()
                PaletteView(
                    colors: session.currentPalette,
                    selectedColor: $session.currentColor
                )
                ProgressView(session: session)
            }
        }
    }
}

// PencilKit UIViewRepresentable wrapper
struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var inkType: PKInkingTool.InkType
    var inkColor: UIColor
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly  // Apple Pencil 전용
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = PKInkingTool(inkType, color: inkColor, width: 15)
    }
}
```

### 6.3 가이드 오버레이 시스템

```swift
// GuideOverlayView.swift — 핵심 구현 방향

struct GuideOverlayView: View {
    let activeRegion: Region?
    let allRegions: [Region]
    let strokeHints: StrokeHints?
    
    var body: some View {
        Canvas { context, size in
            // 비활성 영역 dimming (반투명 회색 마스크)
            for region in allRegions where region.id != activeRegion?.id {
                if let path = region.cgPath {
                    context.fill(Path(path), with: .color(.black.opacity(0.4)))
                }
            }
            
            // 활성 영역 테두리 하이라이트
            if let active = activeRegion, let path = active.cgPath {
                context.stroke(
                    Path(path),
                    with: .color(.white),
                    lineWidth: 2
                )
            }
            
            // 붓터치 방향 힌트 화살표
            if let hints = strokeHints {
                drawStrokeDirectionArrows(context: &context, hints: hints)
            }
        }
        .allowsHitTesting(false)  // 터치 이벤트는 PencilKit으로 통과
    }
}
```

### 6.4 Region Coverage 측정

```swift
// CoverageCalculator.swift — 핵심 구현 방향

class CoverageCalculator {
    
    // 사용자의 stroke가 target region을 얼마나 커버하는지 계산
    // PencilKit의 drawing을 rasterize → target mask와 IoU 비교
    
    func calculateCoverage(
        drawing: PKDrawing,
        targetRegion: Region,
        canvasSize: CGSize
    ) -> Float {
        // 1. PKDrawing → UIImage로 래스터라이즈
        let strokeImage = drawing.image(from: targetRegion.boundingRect, scale: 1.0)
        
        // 2. 이진화: stroke가 있는 픽셀 = 1, 없는 픽셀 = 0
        let strokeMask = binarize(strokeImage)
        
        // 3. Target region mask와 intersection 계산
        let intersection = bitwiseAnd(strokeMask, targetRegion.mask)
        let union = bitwiseOr(strokeMask, targetRegion.mask)
        
        // 4. Coverage = intersection pixels / target region pixels
        // (IoU가 아닌 단순 coverage ratio 사용 — 사용자가 영역을 넘어 그려도 OK)
        let coverage = Float(intersection.nonZeroCount) / Float(targetRegion.mask.nonZeroCount)
        
        return coverage  // 0.0 ~ 1.0, 0.7 이상이면 다음 단계 전환
    }
}
```

### 6.5 Painting Session Controller

```swift
// PaintingSessionViewModel.swift — 핵심 구현 방향

@MainActor
class PaintingSessionViewModel: ObservableObject {
    // State
    @Published var currentStep: PaintingStep = .background
    @Published var currentRegion: Region?
    @Published var currentPalette: [PaletteColor] = []
    @Published var currentColor: UIColor = .black
    @Published var currentBrush: BrushPreset = .watercolor
    @Published var currentStrokeHints: StrokeHints?
    @Published var regionProgress: [String: Float] = [:]  // region_id → coverage %
    @Published var canvasView = PKCanvasView()
    @Published var showReference: Bool = true
    
    // Data
    let originalPhoto: UIImage
    let regions: [Region]
    let recipe: StyleRecipe
    
    // 세션 시작: 사진 + 세그멘테이션 결과 + 레시피로 초기화
    init(photo: UIImage, regions: [Region], recipe: StyleRecipe) {
        self.originalPhoto = photo
        self.regions = regions
        self.recipe = recipe
        advanceToNextRegion()
    }
    
    // 다음 region으로 전환
    func advanceToNextRegion() {
        // painting_order에 따라 현재 step의 다음 미완료 region 찾기
        // region의 recipe 정보로 palette, brush, stroke hints 업데이트
    }
    
    // 주기적으로 호출 (drawing 변경 시)
    func updateProgress() {
        guard let region = currentRegion else { return }
        let coverage = CoverageCalculator().calculateCoverage(
            drawing: canvasView.drawing,
            targetRegion: region,
            canvasSize: canvasView.bounds.size
        )
        regionProgress[region.id] = coverage
        
        if coverage >= 0.7 {
            // 다음 영역으로 자동 전환 (선택적 — 사용자 확인 후)
            advanceToNextRegion()
        }
    }
}
```

---

## 7. Backend API (개발/실험용)

### FastAPI 서버

```python
# server/main.py

from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel

app = FastAPI(title="Repaint API", version="0.1.0")

# POST /segment — 이미지 → 세그멘테이션 마스크
# - Input: multipart image file
# - Output: { regions: [{ id, label, mask_base64, bbox }] }
# - 모델: DeepLabV3 (torchvision) 또는 SAM

# POST /generate-guide — 세그멘테이션 + 스타일 → 가이드
# - Input: { regions, style_id, image_analysis }
# - Output: PaintingGuide JSON (위 6.5절 스키마)
# - 현재는 rule-based, 확장 시 LLM으로 동적 생성

# GET /recipes/{style_id} — 스타일 레시피 조회
# GET /recipes — 전체 스타일 목록
```

### Docker 구성

```yaml
# server/docker-compose.yml
version: "3.8"
services:
  api:
    build: .
    ports: ["8000:8000"]
    volumes:
      - ./recipes:/app/recipes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

---

## 8. ML 파이프라인

### 데이터셋 전략

```yaml
# ml/configs/deeplab_landscape.yaml
model:
  backbone: resnet101
  pretrained: imagenet
  num_classes: 6  # background + 5 landscape classes

data:
  base_dataset: ADE20K  # 20K+ scene images, 150 classes
  class_mapping:
    sky: [2]           # ADE20K sky
    water: [21, 26]    # water, sea
    vegetation: [4, 9, 17, 66, 72]  # tree, grass, plant, palm, bush
    flower: [67]       # flower
    ground: [3, 6, 13, 29, 46]  # floor, road, earth, path, dirt
    # 나머지 → background (class 0)
  
  augmentation:
    # 풍경 사진 특화 augmentation
    - HorizontalFlip(p=0.5)
    - RandomBrightnessContrast(p=0.3)
    - ColorJitter(brightness=0.2, contrast=0.2, saturation=0.3)
    - GaussianBlur(blur_limit=3, p=0.1)
    # 해상도: 513x513 (DeepLabV3 표준)

training:
  epochs: 30
  batch_size: 8
  optimizer: AdamW
  learning_rate: 1e-4
  scheduler: CosineAnnealingLR
  loss: CrossEntropyLoss  # class weight로 flower 클래스 upweight
```

### 평가 기준

```
Target metrics (landscape 5-class):
  - sky mIoU > 0.85 (큰 영역, 잘 분리됨)
  - water mIoU > 0.75
  - vegetation mIoU > 0.70
  - flower mIoU > 0.55 (작은 영역, 어려움)
  - ground mIoU > 0.65
  - Overall mIoU > 0.70
  
iPad inference:
  - CoreML latency < 500ms (iPad Pro M2)
  - 모델 사이즈 < 100MB (.mlpackage)
```

---

## 9. 주간 개발 로드맵 (12주)

### Phase 1: Foundation (Week 1-4)

**Week 1 — 세그멘테이션 PoC**
```
작업:
1. ADE20K 데이터셋 다운로드 + landscape 5-class 매핑 스크립트 작성
2. DeepLabV3 pretrained 모델로 풍경 사진 10장 inference → 시각화
3. FastAPI 서버 scaffold (Docker + /segment endpoint)
4. 결과물: 정원 사진에서 sky/water/vegetation/flower/ground 분리 확인

검증 기준:
- pretrained 모델로 대략적인 분리가 되는지 확인
- flower 클래스의 recall이 특히 낮을 수 있음 → fine-tuning 필요성 판단
```

**Week 2 — 모델 변환 + 레시피 설계**
```
작업:
1. DeepLabV3 → CoreML 변환 (coremltools)
2. iPad Pro에서 CoreML inference 테스트 (latency 측정)
3. Style Recipe JSON 스키마 확정 (위 5절)
4. monet_water_lilies.json 1차 작성
5. 결과물: iPad에서 사진 → 세그멘테이션 mask 표시 동작

검증 기준:
- CoreML inference < 500ms
- 모델 .mlpackage < 100MB
```

**Week 3 — SwiftUI 앱 기본 골격**
```
작업:
1. Xcode 프로젝트 생성 (iPadOS 17+, iPad only)
2. CameraView: AVFoundation 기반 사진 촬영
3. PencilCanvasRepresentable: PencilKit 기본 캔버스
4. 사진 촬영 → CoreML 세그멘테이션 → 마스크 오버레이 표시
5. 결과물: 사진 찍으면 영역 마스크가 오버레이되는 앱

검증 기준:
- 카메라 → 세그멘테이션 → 오버레이까지 end-to-end 동작
- PencilKit 캔버스에서 Apple Pencil 드로잉 가능
```

**Week 4 — 세그멘테이션-레시피 연동**
```
작업:
1. SegmentationService: mask → Region 객체 변환 (CGPath 추출)
2. StyleRecipeLoader: JSON → StyleRecipe 모델 파싱
3. GuideGeneratorService: Region + Recipe → PaintingGuide 생성
4. 결과물: 사진 촬영 → 자동으로 "sky부터 그리세요" 가이드 표시

검증 기준:
- Region에 올바른 레시피가 매핑되는지 확인
- 가이드 UI가 직관적인지 본인이 직접 써보며 평가

★ Phase 1 Milestone: 사진 촬영 → 세그멘테이션 → 가이드 표시 동작 확인
```

### Phase 2: Guided Painting Core (Week 5-8)

**Week 5 — Region 가이드 UI**
```
작업:
1. GuideOverlayView: 활성 영역 하이라이트 + 비활성 dimming
2. PaletteView: 레시피의 palette 색상 swatch, 탭하면 ink color 변경
3. 현재 단계 + 다음 단계 표시 UI
4. "지금 하늘 영역을 칠하세요" 텍스트 가이드
```

**Week 6 — Brush + Stroke 가이드**
```
작업:
1. BrushSettingsView: watercolor/marker/pen 프리셋 + 자동 적용
2. PencilKit ink type 매핑:
   - watercolor → PKInkingTool(.watercolor) — 필압에 따른 opacity 변화
   - marker → PKInkingTool(.marker) — 균일한 색상, 겹치면 짙어짐
   - pen → PKInkingTool(.pen) — 선명한 선, 디테일용
3. Stroke direction hint 오버레이: 화살표/곡선으로 추천 방향 표시
4. 브러시 크기 가이드 (레시피의 size_range에 맞게 슬라이더 범위 제한)
```

**Week 7 — Step Flow + Progress**
```
작업:
1. PaintingSessionViewModel: step flow 로직 완성
   - background → midground → foreground → finish 순서
   - 각 step 내에서 해당 layer의 region들을 순회
2. CoverageCalculator: stroke coverage 측정 구현
3. ProgressView: region별 진행률 바 + 전체 진행률
4. 70% coverage 도달 시 "다음 영역으로?" 전환 프롬프트
```

**Week 8 — 통합 테스트 + Before/After**
```
작업:
1. 정원/풍경 사진 5장으로 full flow 테스트
2. ComparisonView: 완성 작품 + 원본 사진 슬라이드 비교
3. 작품 저장: PKDrawing → UIImage → Photos 앱 저장
4. UX friction 식별 및 수정 (직접 그려보며 테스트)
5. Finish pass 구현 (하이라이트, 그림자, 분위기 블렌드)

★ Phase 2 Milestone: 정원 사진 → 모네 스타일 guided painting 완주 가능
```

### Phase 3: Polish + Launch Prep (Week 9-12)

**Week 9 — 피드백 + 온보딩**
```
작업:
1. Color accuracy feedback: 사용자 stroke 색상 vs target palette CIE ΔE 비교
   - ΔE < 10: 좋음 (초록 체크)
   - ΔE 10-25: 보통 (노란 주의)  
   - ΔE > 25: 다른 색 (빨간 경고 + 추천 색 표시)
2. OnboardingView: 3-step 인터랙티브 튜토리얼
   - Step 1: 사진 찍기
   - Step 2: 팔레트에서 색 선택 + 브러시 터치
   - Step 3: 가이드 따라 한 영역 완성
```

**Week 10 — 갤러리 + 최적화**
```
작업:
1. GalleryView: 완성 작품 앱 내 갤러리 (Core Data 또는 SwiftData)
2. PNG export + 타임랩스 영상 생성 (PKDrawing의 stroke 순서 활용)
3. 성능 최적화:
   - CoreML 추론 캐싱
   - 마스크 생성 비동기화
   - 메모리 사용량 프로파일링 (Instruments)
```

**Week 11 — Edge Case + QA**
```
작업:
1. 비이상적 입력 처리:
   - 실내 사진 → "풍경 사진을 촬영해주세요" 안내
   - 역광/야경 → 밝기 자동 조정 또는 경고
   - 사람/동물 포함 → 해당 영역 ground로 fallback
2. 에러 핸들링: 모델 로드 실패, 메모리 부족 등
3. Accessibility: VoiceOver 지원, Dynamic Type
4. App Store 준비: 아이콘, 스크린샷 5장, 설명문, 프라이버시 정책
```

**Week 12 — 베타 + 출시**
```
작업:
1. TestFlight 배포 (10-20명 베타 테스터)
2. 핵심 지표 수집:
   - 완주율 (painting 완성까지 도달한 비율)
   - 세션 시간 (평균 painting 소요 시간)
   - NPS (만족도)
3. 치명적 버그 수정
4. App Store 제출

★ Phase 3 Milestone: TestFlight 베타 → App Store 제출
```

---

## 10. 확장 로드맵 (Post-MVP)

### Phase 4: Multi-style (Month 4-5)
- 스타일 추가: 고흐 별이 빛나는 밤, 세잔 정물, 우키요에, 수묵화
- 스타일별 레시피 JSON 작성 + 브러시 프리셋 추가
- Metal Shader 기반 커스텀 브러시 (PencilKit 한계 극복)

### Phase 5: Smart Guide (Month 6-7)
- SAM (Segment Anything) 도입: 사용자 터치로 세밀한 영역 지정
- LLM 기반 동적 레시피 생성: 사진 분석 → 맞춤 가이드 자동 작성
- 실시간 stroke 분석: "붓터치를 더 길게 해보세요" 등 코칭 피드백

### Phase 6: Community (Month 8+)
- 작품 갤러리 공유 (Firebase / Supabase)
- 타임랩스 영상 자동 생성 + 공유
- 사용자 커스텀 스타일: 참고 이미지 업로드 → 자동 레시피 추출
- 구독 모델: 기본 1스타일 무료, 추가 스타일 프리미엄

---

## 11. 개발 환경 셋업

### 로컬 환경
```bash
# 1. 프로젝트 clone 후
cd Repaint

# 2. Python 환경 (ML + Server)
cd ml
python -m venv .venv
source .venv/bin/activate
pip install torch torchvision coremltools fastapi uvicorn Pillow albumentations

# 3. Server 실행
cd ../server
docker-compose up -d

# 4. iOS 앱
# Xcode에서 ios/Repaint.xcodeproj 열기
# Target: iPad Pro (M-chip) Simulator 또는 실기기
# Signing: Personal Team
```

### 필요 장비
- Mac (Apple Silicon 권장) — Xcode + Simulator
- iPad Pro + Apple Pencil — 실기기 테스트 필수
- GPU (RTX 4070) — 모델 fine-tuning용 (Colab도 가능)

---

## 12. Claude Code 작업 지시 예시

프로젝트 시작 시 아래 순서로 Claude Code에 요청하세요:

```
1단계: "CLAUDE.md 파일을 생성하고, 프로젝트 디렉토리 구조를 만들어줘"

2단계: "ml/ 디렉토리에 DeepLabV3 fine-tuning 파이프라인을 구현해줘.
       ADE20K → landscape 5-class 매핑 포함."

3단계: "server/ 디렉토리에 FastAPI 세그멘테이션 서버를 구현해줘.
       POST /segment 엔드포인트, Docker 구성 포함."

4단계: "ml/scripts/convert_to_coreml.py를 구현해줘.
       DeepLabV3 PyTorch → CoreML 변환."

5단계: "ios/ Xcode 프로젝트 기본 구조를 만들어줘.
       SwiftUI + PencilKit + CoreML 세팅."

6단계: "monet_water_lilies.json 레시피를 기반으로
       GuideGeneratorService를 구현해줘."

7단계: "CanvasView + GuideOverlayView를 구현해줘.
       PencilKit 캔버스 + 영역 하이라이트 오버레이."

8단계: "PaintingSessionViewModel을 구현해줘.
       step flow + coverage 측정 + 자동 전환 로직."
```

---

> **Note**: 이 프롬프트는 살아있는 문서입니다.
> 개발 진행에 따라 업데이트하며, Claude Code의 CLAUDE.md도 함께 갱신하세요.
