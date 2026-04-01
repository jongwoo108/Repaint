"""
세그멘테이션 모델 평가 — mIoU 계산
사용법: python ml/scripts/evaluate.py --checkpoint PATH --config ml/configs/deeplab_landscape.yaml
"""
import argparse
import numpy as np
import torch
from torch.utils.data import DataLoader
import yaml
from train import ADE20KLandscapeDataset
from torchvision.models.segmentation import deeplabv3_resnet101
import torch.nn as nn

CLASS_NAMES = ["background", "sky", "water", "vegetation", "flower", "ground"]


def compute_iou(pred: np.ndarray, target: np.ndarray, num_classes: int) -> np.ndarray:
    ious = []
    for cls in range(num_classes):
        p = pred == cls
        t = target == cls
        intersection = (p & t).sum()
        union = (p | t).sum()
        ious.append(intersection / union if union > 0 else float("nan"))
    return np.array(ious)


def evaluate(checkpoint_path: str, config_path: str):
    with open(config_path) as f:
        cfg = yaml.safe_load(f)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    model = deeplabv3_resnet101(weights=None)
    model.classifier[4] = nn.Conv2d(256, cfg["model"]["num_classes"], 1)
    model.aux_classifier[4] = nn.Conv2d(256, cfg["model"]["num_classes"], 1)
    model.load_state_dict(torch.load(checkpoint_path, map_location=device))
    model.to(device)
    model.eval()

    val_ds = ADE20KLandscapeDataset(cfg["data"]["data_dir"], "validation", cfg["data"]["input_size"])
    val_loader = DataLoader(val_ds, batch_size=4, shuffle=False, num_workers=4)

    all_ious = []
    with torch.no_grad():
        for imgs, masks in val_loader:
            imgs = imgs.to(device)
            preds = model(imgs)["out"].argmax(dim=1).cpu().numpy()
            for pred, mask in zip(preds, masks.numpy()):
                all_ious.append(compute_iou(pred, mask, cfg["model"]["num_classes"]))

    mean_ious = np.nanmean(all_ious, axis=0)
    print("\n=== 평가 결과 ===")
    for i, name in enumerate(CLASS_NAMES):
        target = cfg["evaluation"]["target_metrics"].get(f"{name}_miou")
        status = "✅" if target and mean_ious[i] >= target else "❌"
        print(f"  {status} {name:15s}: mIoU = {mean_ious[i]:.3f}" + (f" (목표: {target})" if target else ""))
    print(f"\n  Overall mIoU: {np.nanmean(mean_ious[1:]):.3f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--config", default="ml/configs/deeplab_landscape.yaml")
    args = parser.parse_args()
    evaluate(args.checkpoint, args.config)
