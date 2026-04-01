"""
DeepLabV3 fine-tuning — ADE20K → landscape 5-class

사용법:
    python ml/scripts/train.py --config ml/configs/deeplab_landscape.yaml
"""
import argparse
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torchvision.transforms.functional as TF
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from torchvision.models.segmentation import deeplabv3_resnet101
import yaml
from PIL import Image

# ADE20K (0-indexed) → landscape 5-class ID
# 검증된 매핑 — segmentation.py, deeplab_landscape.yaml과 동기화 유지
ADE20K_MAPPING: dict[int, int] = {
    2: 1,                                    # sky
    21: 2, 26: 2, 60: 2,                     # water, sea, river
    4: 3, 9: 3, 17: 3, 72: 3,               # tree, grass, plant, palm
    66: 4,                                   # flower
    3: 5, 6: 5, 13: 5, 16: 5, 29: 5,        # floor, road, earth, mountain, field
    34: 5, 46: 5, 52: 5, 68: 5,             # rock, sand, path, hill
}


def remap_mask(mask: np.ndarray) -> np.ndarray:
    """ADE20K 150-class 마스크 → 6-class landscape 마스크."""
    out = np.zeros_like(mask, dtype=np.uint8)
    for ade_id, cls_id in ADE20K_MAPPING.items():
        out[mask == ade_id] = cls_id
    return out


class ADE20KLandscapeDataset(Dataset):
    def __init__(self, data_dir: str, split: str, input_size: int = 513, augment: bool = False):
        self.img_dir = Path(data_dir) / "images" / split
        self.ann_dir = Path(data_dir) / "annotations" / split
        self.files = sorted(self.img_dir.glob("*.jpg"))
        self.size = input_size
        self.augment = augment
        self.img_normalize = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])

    def __len__(self) -> int:
        return len(self.files)

    def __getitem__(self, idx: int):
        img_path = self.files[idx]
        ann_path = self.ann_dir / img_path.with_suffix(".png").name

        img = Image.open(img_path).convert("RGB").resize((self.size, self.size), Image.BILINEAR)
        ann = np.array(Image.open(ann_path))
        mask = Image.fromarray(remap_mask(ann)).resize((self.size, self.size), Image.NEAREST)

        if self.augment:
            img, mask = self._joint_augment(img, mask)

        return self.img_normalize(img), torch.from_numpy(np.array(mask)).long()

    def _joint_augment(self, img: Image.Image, mask: Image.Image):
        """Image + mask에 동일한 spatial transform 적용."""
        # Random horizontal flip
        if random.random() > 0.5:
            img = TF.hflip(img)
            mask = TF.hflip(mask)

        # Color jitter (image only — mask는 색상 변환 불필요)
        img = transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.3)(img)

        # Gaussian blur (image only)
        if random.random() < 0.1:
            img = transforms.GaussianBlur(kernel_size=3)(img)

        return img, mask


def train(config_path: str) -> None:
    with open(config_path) as f:
        cfg = yaml.safe_load(f)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")

    data_dir = cfg["data"]["data_dir"]
    input_size = cfg["data"]["input_size"]
    batch_size = cfg["training"]["batch_size"]
    num_classes = cfg["model"]["num_classes"]

    train_ds = ADE20KLandscapeDataset(data_dir, "training", input_size, augment=True)
    val_ds = ADE20KLandscapeDataset(data_dir, "validation", input_size, augment=False)
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True, num_workers=4, pin_memory=True)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=4, pin_memory=True)
    print(f"Train: {len(train_ds)}장  Val: {len(val_ds)}장")

    # COCO pretrained 백본 로드 → classifier head 교체 (6-class)
    model = deeplabv3_resnet101(weights="DEFAULT")
    model.classifier[4] = nn.Conv2d(256, num_classes, kernel_size=1)
    model.aux_classifier[4] = nn.Conv2d(256, num_classes, kernel_size=1)
    model.to(device)

    class_weights = torch.tensor(
        list(cfg["training"]["class_weights"].values()), dtype=torch.float
    ).to(device)
    criterion = nn.CrossEntropyLoss(weight=class_weights, ignore_index=255)
    optimizer = torch.optim.AdamW(model.parameters(), lr=cfg["training"]["learning_rate"])
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=cfg["training"]["epochs"]
    )

    ckpt_dir = Path(cfg["output"]["checkpoint_dir"])
    ckpt_dir.mkdir(parents=True, exist_ok=True)

    for epoch in range(cfg["training"]["epochs"]):
        # Train
        model.train()
        total_loss = 0.0
        for imgs, masks in train_loader:
            imgs, masks = imgs.to(device), masks.to(device)
            out = model(imgs)
            loss = criterion(out["out"], masks) + 0.4 * criterion(out["aux"], masks)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        scheduler.step()
        avg_loss = total_loss / len(train_loader)

        # Validation (5 epoch마다)
        if (epoch + 1) % 5 == 0:
            val_loss = _validate(model, val_loader, criterion, device)
            print(f"Epoch {epoch+1:2d}/{cfg['training']['epochs']} — loss: {avg_loss:.4f}  val_loss: {val_loss:.4f}")
            ckpt_path = ckpt_dir / f"deeplab_epoch{epoch+1}.pth"
            torch.save(model.state_dict(), ckpt_path)
            print(f"  체크포인트 저장: {ckpt_path}")
        else:
            print(f"Epoch {epoch+1:2d}/{cfg['training']['epochs']} — loss: {avg_loss:.4f}")

    final_path = ckpt_dir / "deeplab_final.pth"
    torch.save(model.state_dict(), final_path)
    print(f"\n학습 완료. 최종 체크포인트: {final_path}")


@torch.no_grad()
def _validate(model: nn.Module, loader: DataLoader, criterion: nn.Module, device: torch.device) -> float:
    model.eval()
    total_loss = 0.0
    for imgs, masks in loader:
        imgs, masks = imgs.to(device), masks.to(device)
        out = model(imgs)
        total_loss += criterion(out["out"], masks).item()
    model.train()
    return total_loss / len(loader)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=str, default="ml/configs/deeplab_landscape.yaml")
    args = parser.parse_args()
    train(args.config)
