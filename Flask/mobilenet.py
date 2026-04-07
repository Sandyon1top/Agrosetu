"""
mobilenet_v2.py
===============
MobileNetV2 implemented entirely from scratch in PyTorch.
NO torchvision imports. Every layer is hand-coded.

Reference:
  "MobileNetV2: Inverted Residuals and Linear Bottlenecks"
   Sandler et al., CVPR 2018 — https://arxiv.org/abs/1801.04381

Usage:
  from mobilenet_v2 import MobileNetV2Scratch
  model = MobileNetV2Scratch(num_classes=6)
"""

import torch
import torch.nn as nn


# ─────────────────────────────────────────────
#  HELPER: round channels to nearest multiple
# ─────────────────────────────────────────────

def _make_divisible(v, divisor=8):
    """
    Round channel count to nearest multiple of divisor.
    Ensures efficient memory alignment on hardware.
    """
    new_v = max(divisor, int(v + divisor / 2) // divisor * divisor)
    if new_v < 0.9 * v:
        new_v += divisor
    return new_v


# ─────────────────────────────────────────────
#  BUILDING BLOCK 1: Conv → BN → ReLU6
# ─────────────────────────────────────────────

class ConvBNReLU6(nn.Module):
    """
    Standard convolution block used throughout MobileNetV2:
        Conv2d → BatchNorm2d → ReLU6

    Why ReLU6?
      ReLU6 clips activations at 6 (min(max(x,0), 6)).
      This keeps activations in a bounded range, which improves
      robustness under fixed-point quantisation on mobile hardware.

    Args:
        in_ch   : number of input channels
        out_ch  : number of output channels
        kernel  : kernel size (default 3)
        stride  : convolution stride (default 1)
        groups  : set groups=in_ch for depthwise convolution
    """
    def __init__(self, in_ch, out_ch, kernel=3, stride=1, groups=1):
        super().__init__()
        pad = (kernel - 1) // 2     # 'same' padding for odd kernels
        self.block = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, kernel,
                      stride=stride, padding=pad,
                      groups=groups, bias=False),   # bias=False because BN has learnable bias
            nn.BatchNorm2d(out_ch),
            nn.ReLU6(inplace=True)
        )

    def forward(self, x):
        return self.block(x)


# ─────────────────────────────────────────────
#  BUILDING BLOCK 2: Inverted Residual
# ─────────────────────────────────────────────

class InvertedResidual(nn.Module):
    """
    MobileNetV2 core building block — the Inverted Residual.

    Why "inverted"?
      Normal residuals: wide → narrow → wide (bottleneck compresses then expands)
      Inverted residuals: narrow → wide → narrow (expand then compress)
      This keeps the residual connections in the low-dimensional space,
      saving memory while the heavy computation happens in the wider space.

    Structure:
        ┌──────────────────────────────────────────┐
        │ [Expand]    1×1 Conv → BN → ReLU6        │ ← only when expand_t > 1
        │ [Depthwise] 3×3 DW Conv → BN → ReLU6    │ ← groups=hidden (one filter per channel)
        │ [Project]   1×1 Conv → BN                │ ← NO activation (linear bottleneck)
        └──────────────────────────────────────────┘
              ↕ skip connection only when stride==1 AND in_ch==out_ch

    Why no activation after projection?
      The paper shows that applying non-linearities in low-dimensional spaces
      destroys information. The linear bottleneck preserves it.

    Args:
        in_ch    : input channels
        out_ch   : output channels
        stride   : 1 (no downsampling) or 2 (halve spatial dims)
        expand_t : expansion factor t — hidden_dim = in_ch * t
    """
    def __init__(self, in_ch, out_ch, stride, expand_t):
        super().__init__()
        self.use_skip = (stride == 1 and in_ch == out_ch)
        hidden = int(round(in_ch * expand_t))
        layers = []

        # 1. Pointwise expansion (skip entirely when t == 1 to save computation)
        if expand_t != 1:
            layers.append(ConvBNReLU6(in_ch, hidden, kernel=1))

        # 2. Depthwise convolution — groups=hidden makes it fully depthwise
        #    Each input channel gets its own 3×3 filter → much fewer parameters
        layers.append(ConvBNReLU6(hidden, hidden, kernel=3,
                                  stride=stride, groups=hidden))

        # 3. Pointwise projection back to out_ch — LINEAR (no activation)
        layers += [
            nn.Conv2d(hidden, out_ch, 1, bias=False),
            nn.BatchNorm2d(out_ch)
        ]
        self.conv = nn.Sequential(*layers)

    def forward(self, x):
        if self.use_skip:
            return x + self.conv(x)     # residual add
        return self.conv(x)


# ─────────────────────────────────────────────
#  MAIN MODEL: MobileNetV2
# ─────────────────────────────────────────────

class MobileNetV2Scratch(nn.Module):
    """
    Full MobileNetV2 architecture from scratch.

    Architecture (Table 1 from paper):
    ┌───────────────────┬────────┬────┬───┬───┐
    │ Operator          │  t     │ c  │ n │ s │
    ├───────────────────┼────────┼────┼───┼───┤
    │ Conv2d 3×3        │   -    │ 32 │ 1 │ 2 │  ← stem
    │ InvertedResidual  │   1    │ 16 │ 1 │ 1 │  ← no expansion on first block
    │ InvertedResidual  │   6    │ 24 │ 2 │ 2 │
    │ InvertedResidual  │   6    │ 32 │ 3 │ 2 │
    │ InvertedResidual  │   6    │ 64 │ 4 │ 2 │
    │ InvertedResidual  │   6    │ 96 │ 3 │ 1 │
    │ InvertedResidual  │   6    │160 │ 3 │ 2 │
    │ InvertedResidual  │   6    │320 │ 1 │ 1 │
    │ Conv2d 1×1        │   -    │1280│ 1 │ 1 │  ← head expansion
    │ AvgPool + Linear  │   -    │ K  │ 1 │ - │  ← classifier
    └───────────────────┴────────┴────┴───┴───┘
    t=expand_ratio, c=output channels, n=repeat, s=stride

    Args:
        num_classes : number of output classes (default 6 for AgroSetu)
        width_mult  : scales all channel counts (1.0 = standard B0 width)
    """
    def __init__(self, num_classes=6, width_mult=1.0):
        super().__init__()

        input_ch = _make_divisible(32   * width_mult)
        last_ch  = _make_divisible(1280 * max(1.0, width_mult))

        # [expand_t, out_ch, n_blocks, stride]
        cfg = [
            [1,  16, 1, 1],
            [6,  24, 2, 2],
            [6,  32, 3, 2],
            [6,  64, 4, 2],
            [6,  96, 3, 1],
            [6, 160, 3, 2],
            [6, 320, 1, 1],
        ]

        # Stem: first standard conv layer
        features = [ConvBNReLU6(3, input_ch, stride=2)]

        # Stack all inverted residual blocks
        for t, c, n, s in cfg:
            out_ch = _make_divisible(c * width_mult)
            for i in range(n):
                stride = s if i == 0 else 1     # only first block in stage uses stride
                features.append(InvertedResidual(input_ch, out_ch, stride, t))
                input_ch = out_ch

        # Head: 1×1 conv to expand to 1280 channels
        features.append(ConvBNReLU6(input_ch, last_ch, kernel=1))
        self.features = nn.Sequential(*features)

        # Global average pooling → flatten → dropout → linear classifier
        self.pool       = nn.AdaptiveAvgPool2d((1, 1))
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(last_ch, num_classes)
        )

        self._init_weights()

    def _init_weights(self):
        """Kaiming normal init for conv, ones/zeros for BN, normal for linear."""
        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode='fan_out')
                if m.bias is not None:
                    nn.init.zeros_(m.bias)
            elif isinstance(m, nn.BatchNorm2d):
                nn.init.ones_(m.weight)
                nn.init.zeros_(m.bias)
            elif isinstance(m, nn.Linear):
                nn.init.normal_(m.weight, 0, 0.01)
                nn.init.zeros_(m.bias)

    def forward(self, x):
        x = self.features(x)        # all conv + inverted residual blocks
        x = self.pool(x)            # global average pool → (B, 1280, 1, 1)
        x = torch.flatten(x, 1)    # → (B, 1280)
        x = self.classifier(x)     # → (B, num_classes)
        return x


# ─────────────────────────────────────────────
#  QUICK SANITY CHECK
# ─────────────────────────────────────────────

if __name__ == '__main__':
    model  = MobileNetV2Scratch(num_classes=6)
    dummy  = torch.randn(2, 3, 160, 160)
    output = model(dummy)
    params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"MobileNetV2Scratch")
    print(f"  Input : {dummy.shape}")
    print(f"  Output: {output.shape}")
    print(f"  Params: {params:,}")
    assert output.shape == (2, 6), f"Shape mismatch: {output.shape}"
    print("  ✅ Sanity check passed")