"""
Week 1 PoC — 세그멘테이션 결과 시각화 스크립트

사용법:
    python ml/scripts/visualize_segmentation.py --image path/to/photo.jpg
    python ml/scripts/visualize_segmentation.py --image path/to/photo.jpg --output result.png

또는 서버 API를 통해 테스트:
    curl -X POST http://localhost:8000/segment -F "image=@photo.jpg" | python -m json.tool
"""

import argparse
import base64
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# 5-class 색상 팔레트 (시각화용)
CLASS_COLORS = {
    0: (30, 30, 30),      # background — 어두운 회색
    1: (135, 206, 235),   # sky — 하늘색
    2: (64, 164, 223),    # water — 파란색
    3: (34, 139, 34),     # vegetation — 초록색
    4: (255, 105, 180),   # flower — 핑크
    5: (139, 115, 85),    # ground — 갈색
}
CLASS_LABELS = {
    0: "background", 1: "sky", 2: "water",
    3: "vegetation", 4: "flower", 5: "ground",
}


def run_local_segmentation(image: Image.Image) -> np.ndarray:
    """서버 없이 직접 모델 실행 (로컬 테스트용)."""
    # server/ 디렉토리를 sys.path에 추가
    server_dir = Path(__file__).parent.parent.parent / "server"
    sys.path.insert(0, str(server_dir))

    from models.segmentation import load_model
    model = load_model()
    return model.predict(image)


def seg_map_to_rgb(seg_map: np.ndarray) -> np.ndarray:
    """세그멘테이션 맵 → RGB 컬러 이미지."""
    h, w = seg_map.shape
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    for class_id, color in CLASS_COLORS.items():
        mask = seg_map == class_id
        rgb[mask] = color
    return rgb


def overlay_on_image(original: Image.Image, seg_map: np.ndarray, alpha: float = 0.5) -> Image.Image:
    """원본 이미지 위에 세그멘테이션 마스크를 반투명 오버레이."""
    orig_resized = original.convert("RGB").resize((seg_map.shape[1], seg_map.shape[0]))
    seg_rgb = Image.fromarray(seg_map_to_rgb(seg_map))
    blended = Image.blend(orig_resized, seg_rgb, alpha=alpha)
    return blended


def draw_legend(image: Image.Image, seg_map: np.ndarray) -> Image.Image:
    """이미지 오른쪽에 클래스별 범례 추가."""
    present_classes = sorted(set(np.unique(seg_map)) & set(CLASS_LABELS.keys()))
    legend_w = 160
    result = Image.new("RGB", (image.width + legend_w, image.height), (245, 245, 245))
    result.paste(image, (0, 0))

    draw = ImageDraw.Draw(result)
    x_start = image.width + 10
    y = 20
    draw.text((x_start, y), "Classes", fill=(0, 0, 0))
    y += 24

    total_px = seg_map.size
    for class_id in present_classes:
        color = CLASS_COLORS[class_id]
        label = CLASS_LABELS[class_id]
        area_pct = (seg_map == class_id).sum() / total_px * 100
        draw.rectangle([x_start, y, x_start + 16, y + 16], fill=color, outline=(80, 80, 80))
        draw.text((x_start + 22, y), f"{label} {area_pct:.1f}%", fill=(0, 0, 0))
        y += 24

    return result


def decode_mask_from_api(mask_b64: str) -> np.ndarray:
    """API 응답의 base64 마스크 디코딩."""
    data = base64.b64decode(mask_b64)
    img = Image.open(io.BytesIO(data)).convert("L")
    return np.array(img) > 0


def visualize_from_api_response(response_json: dict, original: Image.Image, output_path: str) -> None:
    """POST /segment API 응답을 시각화."""
    regions = response_json["regions"]
    seg_map = np.zeros((513, 513), dtype=np.uint8)

    label_to_id = {
        "sky": 1, "water": 2, "vegetation": 3, "flower": 4, "ground": 5,
    }
    for region in regions:
        label = region["label"]
        class_id = label_to_id.get(label, 0)
        mask = decode_mask_from_api(region["mask_base64"])
        seg_map[mask] = class_id

    _save_visualization(original, seg_map, output_path)


def _save_visualization(original: Image.Image, seg_map: np.ndarray, output_path: str) -> None:
    overlay = overlay_on_image(original, seg_map, alpha=0.45)
    result = draw_legend(overlay, seg_map)
    result.save(output_path)

    # 통계 출력
    total = seg_map.size
    print(f"\n세그멘테이션 결과 ({seg_map.shape[1]}×{seg_map.shape[0]}):")
    print("-" * 35)
    for class_id in sorted(CLASS_LABELS.keys()):
        count = (seg_map == class_id).sum()
        if count > 0:
            print(f"  {CLASS_LABELS[class_id]:12s} {count/total*100:5.1f}%")
    print(f"\n저장 완료: {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Repaint 세그멘테이션 PoC 시각화")
    parser.add_argument("--image", required=True, help="입력 이미지 경로")
    parser.add_argument("--output", default="segmentation_result.png", help="출력 이미지 경로")
    parser.add_argument(
        "--api", default=None,
        help="서버 API URL (예: http://localhost:8000). 지정하면 로컬 모델 대신 API 사용.",
    )
    args = parser.parse_args()

    image = Image.open(args.image).convert("RGB")
    print(f"이미지 로드: {args.image} ({image.width}×{image.height})")

    if args.api:
        import urllib.request
        import urllib.parse
        import mimetypes

        url = args.api.rstrip("/") + "/segment"
        print(f"API 호출: {url}")
        with open(args.image, "rb") as f:
            img_data = f.read()

        boundary = "----RepaintBoundary"
        mime = mimetypes.guess_type(args.image)[0] or "image/jpeg"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="image"; filename="image.jpg"\r\n'
            f"Content-Type: {mime}\r\n\r\n"
        ).encode() + img_data + f"\r\n--{boundary}--\r\n".encode()

        req = urllib.request.Request(
            url, data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        with urllib.request.urlopen(req) as resp:
            response_json = json.loads(resp.read())

        visualize_from_api_response(response_json, image, args.output)
    else:
        print("로컬 모델 실행 중 (HuggingFace SegFormer ADE20K)...")
        seg_map = run_local_segmentation(image)
        _save_visualization(image, seg_map, args.output)


if __name__ == "__main__":
    main()
