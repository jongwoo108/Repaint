"""
DeepLabV3 PyTorch → CoreML 변환 스크립트

사용법:
    # fine-tuned 체크포인트로 변환 (권장)
    python ml/scripts/convert_to_coreml.py --checkpoint ml/checkpoints/deeplab_final.pth

    # 구조 테스트용 (학습 없이 변환 파이프라인만 검증)
    python ml/scripts/convert_to_coreml.py --dry-run

주의: coremltools는 macOS에서만 실제 변환이 동작합니다.
"""
import argparse
import time
from pathlib import Path

import torch
import torch.nn as nn
from torchvision.models.segmentation import deeplabv3_resnet101

NUM_CLASSES = 6


class SegWrapper(torch.nn.Module):
    """CoreML 변환용 래퍼 — dict 출력을 tensor로 단순화."""

    def __init__(self, model: nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x)["out"]  # (1, NUM_CLASSES, H, W)


def _load_model(checkpoint_path: str | None) -> nn.Module:
    if checkpoint_path:
        print(f"   fine-tuned 체크포인트 로드: {checkpoint_path}")
        model = deeplabv3_resnet101(weights=None, num_classes=NUM_CLASSES)
        state = torch.load(checkpoint_path, map_location="cpu")
        model.load_state_dict(state)
    else:
        print("   COCO pretrained 백본 로드 + 6-class head 초기화 (구조 테스트용)")
        model = deeplabv3_resnet101(weights="DEFAULT")
        # COCO 21-class head → 6-class head 교체
        model.classifier[4] = nn.Conv2d(256, NUM_CLASSES, kernel_size=1)
        model.aux_classifier[4] = nn.Conv2d(256, NUM_CLASSES, kernel_size=1)
    model.eval()
    return model


def _benchmark_torch(model: nn.Module) -> float:
    """PyTorch CPU에서 inference 시간 측정 (참고용)."""
    example = torch.randn(1, 3, 513, 513)
    # warmup
    with torch.no_grad():
        for _ in range(2):
            SegWrapper(model)(example)
    # measure
    times = []
    with torch.no_grad():
        for _ in range(5):
            t0 = time.perf_counter()
            SegWrapper(model)(example)
            times.append((time.perf_counter() - t0) * 1000)
    avg_ms = sum(times) / len(times)
    print(f"   PyTorch CPU inference: {avg_ms:.0f} ms (참고용, iPad Neural Engine은 훨씬 빠름)")
    return avg_ms


def _model_size_mb(output_path: str) -> float:
    return sum(
        f.stat().st_size for f in Path(output_path).rglob("*") if f.is_file()
    ) / (1024 * 1024)


def convert(checkpoint_path: str | None, output_path: str, dry_run: bool = False) -> None:
    print("1. PyTorch 모델 로드...")
    model = _load_model(checkpoint_path)

    print("2. TorchScript trace...")
    wrapped = SegWrapper(model)
    example_input = torch.randn(1, 3, 513, 513)
    with torch.no_grad():
        traced = torch.jit.trace(wrapped, example_input)

    if dry_run:
        print("   [dry-run] trace 성공. CoreML 변환 생략.")
        _benchmark_torch(model)
        return

    print("3. CoreML 변환 (iOS 17 target, FLOAT16)...")
    import coremltools as ct

    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(
            name="image",
            shape=(1, 3, 513, 513),
            scale=1 / 255.0,
            bias=[-0.485 / 0.229, -0.456 / 0.224, -0.406 / 0.225],
        )],
        outputs=[ct.TensorType(name="segmentation_logits")],
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )

    # 메타데이터
    mlmodel.short_description = "DeepLabV3 landscape segmentation (5-class)"
    mlmodel.input_description["image"] = "513×513 RGB landscape photo"
    mlmodel.output_description["segmentation_logits"] = (
        "Logits (1, 6, 513, 513) — argmax로 class ID 추출. "
        "0=background 1=sky 2=water 3=vegetation 4=flower 5=ground"
    )

    print(f"4. 저장: {output_path}")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(output_path)

    size_mb = _model_size_mb(output_path)
    status = "✅" if size_mb < 100 else "❌ (100MB 초과)"
    print(f"   모델 크기: {size_mb:.1f} MB {status}")

    print("5. 변환 후 검증 (Python 추론 시간 측정)...")
    _benchmark_torch(model)

    print("\n완료.")
    print("다음 단계:")
    print(f"  - {output_path} 를 Xcode 프로젝트에 추가")
    print("  - iPad Pro M2에서 실제 latency 측정 (목표: < 500ms)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=str, default=None, help="PyTorch 체크포인트 (.pth)")
    parser.add_argument(
        "--output",
        type=str,
        default="ios/Repaint/Resources/DeepLabV3.mlpackage",
        help="출력 .mlpackage 경로",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="CoreML 변환 없이 TorchScript trace + 시간 측정만 수행 (비-macOS 환경)",
    )
    args = parser.parse_args()
    convert(args.checkpoint, args.output, dry_run=args.dry_run)
