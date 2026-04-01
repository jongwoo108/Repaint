# 데이터셋 구성 가이드

## ADE20K 다운로드

```bash
# 공식 사이트: http://groups.csail.mit.edu/vision/datasets/ADE20K/
wget http://data.csail.mit.edu/places/ADEchallenge/ADEChallengeData2016.zip
unzip ADEChallengeData2016.zip -d ade20k/
```

## 디렉토리 구조 (다운로드 후)

```
ml/data/
├── ade20k/
│   ├── images/
│   │   ├── training/   # 20,210장
│   │   └── validation/ # 2,000장
│   └── annotations/
│       ├── training/   # PNG, 픽셀값 = ADE20K class ID (0-indexed)
│       └── validation/
└── README.md
```

## 5-class 매핑 (ADE20K 0-indexed class ID 기준)

| 클래스 | ADE20K ID | ADE20K 레이블 |
|--------|-----------|--------------|
| sky | 2 | sky |
| water | 21, 26, 60 | water, sea, river |
| vegetation | 4, 9, 17, 72 | tree, grass, plant, palm |
| flower | 66 | flower |
| ground | 3, 6, 13, 16, 29, 34, 46, 52, 68 | floor, road, earth, mountain, field, rock, sand, path, hill |
| background | 나머지 전부 | — |

> **주의:** ADE20K annotation PNG 픽셀값은 0-indexed class ID입니다.
> 일부 툴은 1-indexed로 읽으므로 확인 필요.
