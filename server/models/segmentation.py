import os
import torch
import numpy as np
from PIL import Image

# ADE20K (150-class, 0-indexed) → landscape 5-class 매핑
# 검증된 ADE20K 클래스 인덱스 기준:
#   2=sky, 3=floor, 4=tree, 6=road, 9=grass, 13=earth, 16=mountain,
#   17=plant, 21=water, 26=sea, 29=field, 34=rock, 46=sand,
#   52=path, 60=river, 66=flower, 68=hill, 72=palm
ADE20K_TO_LANDSCAPE: dict[int, int] = {
    # sky → 1
    2: 1,
    # water → 2
    21: 2, 26: 2, 60: 2,
    # vegetation → 3
    4: 3, 9: 3, 17: 3, 72: 3,
    # flower → 4
    66: 4,
    # ground → 5
    3: 5, 6: 5, 13: 5, 16: 5, 29: 5, 34: 5, 46: 5, 52: 5, 68: 5,
}

LABEL_TO_ID = {
    "background": 0, "sky": 1, "water": 2,
    "vegetation": 3, "flower": 4, "ground": 5,
}
ID_TO_LABEL = {v: k for k, v in LABEL_TO_ID.items()}


def _map_ade20k_to_landscape(seg_map: np.ndarray) -> np.ndarray:
    """150-class ADE20K 세그멘테이션 맵 → 6-class landscape 맵 (0~5)."""
    result = np.zeros_like(seg_map, dtype=np.uint8)
    for ade_id, landscape_id in ADE20K_TO_LANDSCAPE.items():
        result[seg_map == ade_id] = landscape_id
    return result


class SegFormerADE20KModel:
    """HuggingFace SegFormer (ADE20K pretrained) — checkpoint 없을 때 PoC용."""

    MODEL_ID = "nvidia/segformer-b2-finetuned-ade-512-512"

    def __init__(self) -> None:
        from transformers import SegformerForSemanticSegmentation, SegformerImageProcessor
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.processor = SegformerImageProcessor.from_pretrained(self.MODEL_ID)
        self.model = SegformerForSemanticSegmentation.from_pretrained(self.MODEL_ID)
        self.model.to(self.device)
        self.model.eval()

    @torch.no_grad()
    def predict(self, image: Image.Image) -> np.ndarray:
        """이미지 → 5-class landscape 세그멘테이션 맵 (513×513, uint8)."""
        import torch.nn.functional as F
        inputs = self.processor(images=image, return_tensors="pt").to(self.device)
        outputs = self.model(**inputs)
        # logits: (1, 150, H/4, W/4) → 513×513으로 upsample
        upsampled = F.interpolate(
            outputs.logits, size=(513, 513), mode="bilinear", align_corners=False
        )
        ade_map = upsampled.argmax(dim=1).squeeze(0).cpu().numpy().astype(np.uint8)
        return _map_ade20k_to_landscape(ade_map)


class DeepLabSegmentationModel:
    """Fine-tuned DeepLabV3 (6-class) — DEEPLAB_CHECKPOINT 환경변수로 체크포인트 경로 지정."""

    def __init__(self, checkpoint_path: str) -> None:
        from torchvision.models.segmentation import deeplabv3_resnet101
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = deeplabv3_resnet101(weights=None, num_classes=6)
        state = torch.load(checkpoint_path, map_location=self.device)
        self.model.load_state_dict(state)
        self.model.to(self.device)
        self.model.eval()

    def _preprocess(self, image: Image.Image) -> torch.Tensor:
        img = image.convert("RGB").resize((513, 513))
        arr = np.array(img, dtype=np.float32) / 255.0
        mean = np.array([0.485, 0.456, 0.406])
        std = np.array([0.229, 0.224, 0.225])
        arr = (arr - mean) / std
        tensor = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0)
        return tensor.to(self.device)

    @torch.no_grad()
    def predict(self, image: Image.Image) -> np.ndarray:
        """이미지 → 6-class 세그멘테이션 맵 (513×513, uint8)."""
        tensor = self._preprocess(image)
        output = self.model(tensor)["out"]
        return output.argmax(dim=1).squeeze(0).cpu().numpy().astype(np.uint8)


def load_model() -> SegFormerADE20KModel | DeepLabSegmentationModel:
    """
    DEEPLAB_CHECKPOINT 환경변수가 설정된 경우 → fine-tuned DeepLabV3
    없는 경우 → SegFormer ADE20K pretrained (PoC 모드)
    """
    checkpoint = os.environ.get("DEEPLAB_CHECKPOINT")
    if checkpoint:
        return DeepLabSegmentationModel(checkpoint_path=checkpoint)
    return SegFormerADE20KModel()
