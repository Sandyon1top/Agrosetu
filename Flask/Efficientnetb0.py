"""
efficientnet_b0.py
==================
EfficientNet-B0 implemented entirely from scratch in PyTorch.
NO torchvision imports. Every layer is hand-coded.

Reference:
  "EfficientNet: Rethinking Model Scaling for Convolutional Neural Networks"
   Tan & Le, ICML 2019 — https://arxiv.org/abs/1905.11946

Usage:
  from efficientnet_b0 import EfficientNetB0Scratch
  model = EfficientNetB0Scratch(num_classes=6)
"""

import torch
import torch.nn as nn


# ─────────────────────────────────────────────
#  BUILDING BLOCK 1: Swish Activation
# ─────────────────────────────────────────────

class Swish(nn.Module):
    """
    Swish activation function: f(x) = x · σ(x)

    Why Swish instead of ReLU?
      - Smooth and non-monotonic — allows small negative values to pass
      - Empirically outperforms ReLU on deep networks
      - Self-gated: no extra parameters needed
      - Better gradient flow in very deep nets
    """
    def forward(self, x):
        return x * torch.sigmoid(x)


# ─────────────────────────────────────────────
#  BUILDING BLOCK 2: Conv → BN → Swish
# ─────────────────────────────────────────────

class ConvBNSwish(nn.Module):
    """
    Standard EfficientNet conv block:
        Conv2d → BatchNorm2d (momentum=0.01, eps=1e-3) → Swish

    Note: EfficientNet uses tighter BN params than default PyTorch
    (momentum=0.01 vs 0.1, eps=1e-3 vs 1e-5) to match TF implementation.

    Args:
        in_ch  : input channels
        out_ch : output channels
        kernel : kernel size
        stride : convolution stride
        groups : set groups=in_ch for depthwise conv
    """
    def __init__(self, in_ch, out_ch, kernel=3, stride=1, groups=1):
        super().__init__()
        pad = (kernel - 1) // 2
        self.block = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, kernel,
                      stride=stride, padding=pad,
                      groups=groups, bias=False),
            nn.BatchNorm2d(out_ch, momentum=0.01, eps=1e-3),
            Swish()
        )

    def forward(self, x):
        return self.block(x)


# ─────────────────────────────────────────────
#  BUILDING BLOCK 3: Squeeze-and-Excitation
# ─────────────────────────────────────────────

class SqueezeExcitation(nn.Module):
    """
    Squeeze-and-Excitation (SE) channel attention block.

    Key idea:
      Globally pool all spatial info into a single vector (squeeze),
      then learn which channels to emphasise or suppress (excite).
      This lets the network focus on the most informative features.

    Structure:
        GlobalAvgPool → FC1 (squeeze) → Swish → FC2 (excite) → Sigmoid
        Output is a per-channel weight in [0, 1] — multiply with input.

    Why implemented as 1×1 Conv instead of Linear?
      Functionally identical for (B, C, 1, 1) tensors, but Conv
      avoids an explicit reshape operation.

    Args:
        in_ch    : channels of the input (hidden/expanded channels)
        se_ratio : fraction to squeeze down to (0.25 = 25% of in_ch)
    """
    def __init__(self, in_ch, se_ratio=0.25):
        super().__init__()
        squeezed = max(1, int(in_ch * se_ratio))
        self.se = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),                        # (B, C, H, W) → (B, C, 1, 1)
            nn.Conv2d(in_ch, squeezed, 1, bias=True),       # squeeze
            Swish(),
            nn.Conv2d(squeezed, in_ch, 1, bias=True),       # excite
            nn.Sigmoid()                                     # weights in [0, 1]
        )

    def forward(self, x):
        return x * self.se(x)                               # channel-wise rescaling


# ─────────────────────────────────────────────
#  BUILDING BLOCK 4: Stochastic Depth
# ─────────────────────────────────────────────

class StochasticDepth(nn.Module):
    """
    Stochastic Depth (Drop Path) regularisation.

    Key idea:
      During training, randomly drop entire residual branches
      with probability `drop_prob`. At test time, always use full network.
      This is equivalent to training an implicit ensemble of shallower networks.

    Why is this useful?
      - Acts as strong regularisation (similar to Dropout but at block level)
      - Allows training very deep networks without vanishing gradients
      - Drop rate is usually scheduled linearly: deeper layers drop more often

    Args:
        drop_prob : probability of dropping the residual branch (0.0 = never drop)
    """
    def __init__(self, drop_prob=0.0):
        super().__init__()
        self.drop_prob = drop_prob

    def forward(self, x):
        if not self.training or self.drop_prob == 0.0:
            return x
        keep_prob = 1 - self.drop_prob
        # Shape (B, 1, 1, 1) so it broadcasts across all spatial positions and channels
        rand_tensor = torch.rand(x.shape[0], 1, 1, 1, device=x.device, dtype=x.dtype)
        rand_tensor = torch.floor(rand_tensor + keep_prob)
        # Scale output to maintain expected value (unbiased estimator)
        return x * rand_tensor / keep_prob


# ─────────────────────────────────────────────
#  BUILDING BLOCK 5: MBConv Block
# ─────────────────────────────────────────────

class MBConv(nn.Module):
    """
    EfficientNet MBConv (Mobile Inverted Bottleneck Convolution) block.

    This is the core building block of EfficientNet.
    It extends MobileNetV2's InvertedResidual with two additions:
      1. Squeeze-and-Excitation after the depthwise conv
      2. Stochastic Depth on the residual branch

    Structure:
        ┌────────────────────────────────────────────────┐
        │ [Expand]    1×1 Conv → BN → Swish              │ ← only when expand_ratio > 1
        │ [Depthwise] k×k DW Conv → BN → Swish           │ ← k=3 or k=5
        │ [SE]        Squeeze-and-Excitation              │ ← channel attention
        │ [Project]   1×1 Conv → BN                      │ ← NO activation (linear)
        │ [DropPath]  Stochastic Depth (training only)    │ ← regularisation
        └────────────────────────────────────────────────┘
              ↕ skip connection only when stride==1 AND in_ch==out_ch

    Args:
        in_ch          : input channels
        out_ch         : output channels
        kernel         : depthwise kernel size (3 or 5)
        stride         : 1 or 2
        expand_ratio   : channel expansion multiplier
        se_ratio       : squeeze-excitation reduction ratio
        drop_path_rate : stochastic depth drop probability
    """
    def __init__(self, in_ch, out_ch, kernel, stride,
                 expand_ratio, se_ratio=0.25, drop_path_rate=0.0):
        super().__init__()
        self.use_skip = (stride == 1 and in_ch == out_ch)
        hidden = int(in_ch * expand_ratio)
        pad    = (kernel - 1) // 2

        layers = []

        # 1. Expansion phase — pointwise conv to widen channels
        if expand_ratio != 1:
            layers += [
                nn.Conv2d(in_ch, hidden, 1, bias=False),
                nn.BatchNorm2d(hidden, momentum=0.01, eps=1e-3),
                Swish()
            ]

        # 2. Depthwise conv — spatial filtering, one filter per channel
        #    EfficientNet uses both 3×3 and 5×5 kernels depending on stage
        layers += [
            nn.Conv2d(hidden, hidden, kernel,
                      stride=stride, padding=pad,
                      groups=hidden, bias=False),           # depthwise
            nn.BatchNorm2d(hidden, momentum=0.01, eps=1e-3),
            Swish()
        ]

        # 3. Squeeze-and-Excitation — applied to the hidden (expanded) channels
        layers.append(SqueezeExcitation(hidden, se_ratio))

        # 4. Pointwise projection — compress back to out_ch, NO activation
        layers += [
            nn.Conv2d(hidden, out_ch, 1, bias=False),
            nn.BatchNorm2d(out_ch, momentum=0.01, eps=1e-3)
        ]

        self.block     = nn.Sequential(*layers)
        self.drop_path = StochasticDepth(drop_path_rate)

    def forward(self, x):
        out = self.block(x)
        if self.use_skip:
            out = self.drop_path(out)   # randomly drop residual during training
            return x + out              # residual add
        return out


# ─────────────────────────────────────────────
#  MAIN MODEL: EfficientNet-B0
# ─────────────────────────────────────────────

class EfficientNetB0Scratch(nn.Module):
    """
    Full EfficientNet-B0 architecture from scratch.

    B0 is the baseline model — other variants (B1–B7) are obtained
    by compound scaling (simultaneously scaling width, depth, resolution).

    Architecture (Table 1 from paper):
    ┌───────┬────────────┬─────┬──────┬────┬───┬───┐
    │ Stage │ Operator   │  k  │  t   │ c  │ n │ s │
    ├───────┼────────────┼─────┼──────┼────┼───┼───┤
    │   1   │ Conv3×3    │  3  │  -   │ 32 │ 1 │ 2 │  ← stem
    │   2   │ MBConv1    │  3  │  1   │ 16 │ 1 │ 1 │
    │   3   │ MBConv6    │  3  │  6   │ 24 │ 2 │ 2 │
    │   4   │ MBConv6    │  5  │  6   │ 40 │ 2 │ 2 │  ← 5×5 kernel
    │   5   │ MBConv6    │  3  │  6   │ 80 │ 3 │ 2 │
    │   6   │ MBConv6    │  5  │  6   │112 │ 3 │ 1 │  ← 5×5 kernel
    │   7   │ MBConv6    │  5  │  6   │192 │ 4 │ 2 │  ← 5×5 kernel
    │   8   │ MBConv6    │  3  │  6   │320 │ 1 │ 1 │
    │   9   │ Conv1×1    │  1  │  -   │1280│ 1 │ 1 │  ← head
    │  10   │ Pool+Linear│  -  │  -   │ K  │ 1 │ - │  ← classifier
    └───────┴────────────┴─────┴──────┴────┴───┴───┘
    k=kernel, t=expand_ratio, c=channels, n=layers, s=stride

    Args:
        num_classes    : output classes (default 6 for AgroSetu)
        drop_path_rate : max stochastic depth rate (linearly scaled per block)
    """
    def __init__(self, num_classes=6, drop_path_rate=0.2):
        super().__init__()

        # Stage config: [expand_ratio, out_ch, n_layers, stride, kernel_size]
        stages_cfg = [
            [1,  16, 1, 1, 3],   # Stage 2 — t=1, no expansion conv
            [6,  24, 2, 2, 3],   # Stage 3
            [6,  40, 2, 2, 5],   # Stage 4 — 5×5 depthwise
            [6,  80, 3, 2, 3],   # Stage 5
            [6, 112, 3, 1, 5],   # Stage 6 — 5×5 depthwise
            [6, 192, 4, 2, 5],   # Stage 7 — 5×5 depthwise, 4 layers
            [6, 320, 1, 1, 3],   # Stage 8
        ]

        # Total MBConv blocks (for linear drop path scheduling)
        total_blocks = sum(n for _, _, n, _, _ in stages_cfg)
        block_idx    = 0

        # ── Stage 1: Stem ──
        self.stem = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, stride=2, padding=1, bias=False),
            nn.BatchNorm2d(32, momentum=0.01, eps=1e-3),
            Swish()
        )

        # ── Stages 2–8: MBConv blocks ──
        in_ch  = 32
        blocks = []
        for expand_ratio, out_ch, n_layers, stride, kernel in stages_cfg:
            for i in range(n_layers):
                # Linear drop path schedule: earlier blocks drop less
                dp_rate = drop_path_rate * block_idx / total_blocks
                blocks.append(MBConv(
                    in_ch          = in_ch,
                    out_ch         = out_ch,
                    kernel         = kernel,
                    stride         = stride if i == 0 else 1,  # only first block strides
                    expand_ratio   = expand_ratio,
                    se_ratio       = 0.25,
                    drop_path_rate = dp_rate
                ))
                in_ch = out_ch
                block_idx += 1

        self.blocks = nn.Sequential(*blocks)

        # ── Stage 9: Head conv ──
        self.head = nn.Sequential(
            nn.Conv2d(320, 1280, kernel_size=1, bias=False),
            nn.BatchNorm2d(1280, momentum=0.01, eps=1e-3),
            Swish()
        )

        # ── Stage 10: Classifier ──
        self.pool       = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(1280, num_classes)
        )

        self._init_weights()

    def _init_weights(self):
        """Kaiming normal for conv, ones/zeros for BN, normal for linear."""
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
        x = self.stem(x)            # (B, 3, H, W)   → (B, 32, H/2, W/2)
        x = self.blocks(x)          # MBConv stages  → (B, 320, H/32, W/32)
        x = self.head(x)            # 1×1 expansion  → (B, 1280, H/32, W/32)
        x = self.pool(x)            # global avg pool → (B, 1280, 1, 1)
        x = torch.flatten(x, 1)    # flatten         → (B, 1280)
        x = self.classifier(x)     # linear          → (B, num_classes)
        return x


# ─────────────────────────────────────────────
#  QUICK SANITY CHECK
# ─────────────────────────────────────────────

if __name__ == '__main__':
    model  = EfficientNetB0Scratch(num_classes=6)
    dummy  = torch.randn(2, 3, 160, 160)
    output = model(dummy)
    params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"EfficientNetB0Scratch")
    print(f"  Input : {dummy.shape}")
    print(f"  Output: {output.shape}")
    print(f"  Params: {params:,}")
    assert output.shape == (2, 6), f"Shape mismatch: {output.shape}"
    print("  ✅ Sanity check passed")