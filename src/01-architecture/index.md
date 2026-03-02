# 什么是超节点

“超节点（SuperPod）”作为术语最早由 NVIDIA 在其 DGX SuperPOD 体系中系统化提出，用于描述以 Pod 为粒度、围绕 GPU 高带宽互联构建的训练基础设施单元。在此之前，业界已经存在一系列“相似方向”的探索：例如超算领域的“胖节点/超级节点”思路、Google TPU Pod 等专用加速器 Pod 形态，以及以 NVLink/NVSwitch 为代表的机内 GPU 互联域扩展。这些尝试共同指向同一类问题：当工作负载从“单机可解”演进到“强耦合并行不可避免”时，系统形态必须随之改变。

从 2020 年的 Meena 到 2025 年的 Grok 4，顶级生成式 AI 模型训练的算力开销出现数量级跃迁（以公开材料与行业估算口径计，需求规模约提升 **3000 倍**）。趋势本身比单点数值更重要：训练开销的指数抬升正在把“系统瓶颈”从单卡算力，推向互联、显存容量与通信效率。

```vegalite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "Training compute of frontier AI models over time.",
  "width": 700,
  "height": 500,
  "data": {
    "values": [
      {"model": "Meena", "organization": "Google", "date": "2020-01-28", "compute": 1.12e+23, "parameters": 2600000000},
      {"model": "GPT-3 175B", "organization": "OpenAI", "date": "2020-05-28", "compute": 3.14e+23, "parameters": 175000000000},
      {"model": "GShard", "organization": "Google", "date": "2020-06-30", "compute": 4.77e+22, "parameters": 2300000000},
      {"model": "Switch", "organization": "Google", "date": "2021-01-11", "compute": 8.22e+22, "parameters": 1571000000000},
      {"model": "FLAN 137B", "organization": "Google", "date": "2021-09-03", "compute": 2.05e+24, "parameters": 137000000000},
      {"model": "Gopher", "organization": "Google", "date": "2021-12-08", "compute": 6.31e+23, "parameters": 280000000000},
      {"model": "PaLM", "organization": "Google", "date": "2022-04-04", "compute": 2.53e+24, "parameters": 540000000000},
      {"model": "GPT-4", "organization": "OpenAI", "date": "2023-03-15", "compute": 2.1e+25, "parameters": 1800000000000},
      {"model": "PaLM 2", "organization": "Google", "date": "2023-05-10", "compute": 7.34e+24, "parameters": 340000000000},
      {"model": "Claude 2", "organization": "Anthropic", "date": "2023-07-11", "compute": 3.87e+24, "parameters": null},
      {"model": "Qwen-Max", "organization": "Alibaba", "date": "2023-09-12", "compute": 6e+24, "parameters": null},
      {"model": "Gemini 1.0 Ultra", "organization": "Google", "date": "2023-12-06", "compute": 5e+25, "parameters": null},
      {"model": "GLM-4", "organization": "Zhipu AI", "date": "2024-01-16", "compute": 1.2e+25, "parameters": null},
      {"model": "DeepSeek-V2", "organization": "DeepSeek", "date": "2024-05-06", "compute": 5e+24, "parameters": 236000000000},
      {"model": "Nemotron-4 340B", "organization": "NVIDIA", "date": "2024-06-14", "compute": 1.8e+25, "parameters": 340000000000},
      {"model": "Claude 3.5 Sonnet", "organization": "Anthropic", "date": "2024-06-20", "compute": 2.7e+25, "parameters": null},
      {"model": "Llama 3.1 405B", "organization": "Meta", "date": "2024-07-23", "compute": 3.8e+25, "parameters": 405000000000},
      {"model": "Grok-3", "organization": "xAI", "date": "2025-02-17", "compute": 3.5e+26, "parameters": 3e12},
      {"model": "Grok-4", "organization": "xAI", "date": "2025-07-09", "compute": 5.00e+26, "parameters": 3e12},
      {"model": "Qwen3-Max", "organization": "Alibaba", "date": "2025-09-05", "compute": 1.5e+25, "parameters": 1.0e12},
      {"model": "GPT-4.5", "organization": "OpenAI", "date": "2025-02-27", "compute": 3.8e+26, "parameters": 1.0e10}
    ]
  },
  "layer": [
    {
      "mark": {"type": "circle", "opacity": 0.7},
      "encoding": {
        "x": {
          "field": "date",
          "type": "temporal",
          "title": "发布时间",
          "axis": {"format": "%Y", "grid": true}
        },
        "y": {
          "field": "compute",
          "type": "quantitative",
          "scale": {"type": "log"},
          "title": "训练计算量 (FLOPs, Log Scale)",
          "axis": {"format": ".0e", "grid": true}
        },
        "color": {
          "field": "organization",
          "type": "nominal",
          "title": "机构"
        },
        "size": {
          "field": "parameters",
          "type": "quantitative",
          "title": "参数量",
          "scale": {"range": [50, 500], "domain": [1e9, 3e12]},
          "legend": {"format": ".1s"}
        },
        "tooltip": [
          {"field": "model", "title": "模型"},
          {"field": "organization", "title": "机构"},
          {"field": "date", "type": "temporal", "title": "发布时间", "format": "%Y-%m-%d"},
          {"field": "compute", "title": "计算量", "format": ".2e"},
          {"field": "parameters", "title": "参数量", "format": ",.0f"}
        ]
      }
    },
    {
      "mark": {"type": "text", "align": "left", "dx": 8, "dy": 2, "fontSize": 10},
      "encoding": {
        "x": {"field": "date", "type": "temporal"},
        "y": {"field": "compute", "type": "quantitative"},
        "text": {"field": "model"},
        "color": {"value": "#444"}
      }
    }
  ]
}
```
/// caption
图 1.1：顶级生成式 AI 模型训练算力需求演进趋势 (2020-2025)
///

相比之下，单芯片（单 GPU）算力仍在持续增长，但其增幅通常处于“数十倍量级”，难以与训练需求的三位数到四位数倍增同速演进。下图基于公开规格与行业资料整理，取 NVIDIA 代表性数据中心训练 GPU 的 FP16（张量）峰值算力，并给出指数回归趋势线；以 V100 到 GB200 的代际跨度为例，单卡峰值算力约提升 **30–40 倍量级**。

```vegalite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "NVIDIA AI Chip FP16 Performance over time.",
  "width": 700,
  "height": 400,
  "data": {
    "values": [
      {"name": "Tesla P100", "date": "2016-04-05", "flops": 2.12e13},
      {"name": "Tesla V100", "date": "2017-06-21", "flops": 1.25e14},
      {"name": "A100", "date": "2020-05-14", "flops": 3.12e14},
      {"name": "H100 SXM", "date": "2022-09-20", "flops": 9.89e14},
      {"name": "H200", "date": "2023-11-13", "flops": 1.98e15},
      {"name": "B200", "date": "2024-03-18", "flops": 4.5e15},
      {"name": "GB200", "date": "2025-02-15", "flops": 5.0e15}
    ]
  },
  "layer": [
    {
      "mark": {"type": "circle", "size": 60, "tooltip": true},
      "encoding": {
        "x": {"field": "date", "type": "temporal", "title": "发布时间"},
        "y": {
          "field": "flops",
          "type": "quantitative",
          "scale": {"type": "log"},
          "title": "FP16 算力 (FLOPs, Log Scale)",
           "axis": {"format": ".0e"}
        },
        "tooltip": [{"field": "name"}, {"field": "flops", "format": ".2e"}, {"field": "date", "type": "temporal", "format": "%Y-%m-%d"}]
      }
    },
    {
      "mark": {"type": "text", "align": "left", "dx": 5, "dy": -5},
      "encoding": {
        "x": {"field": "date", "type": "temporal"},
        "y": {"field": "flops", "type": "quantitative"},
        "text": {"field": "name"}
      }
    },
    {
      "transform": [
        {
          "regression": "flops",
          "on": "date",
          "method": "exp"
        }
      ],
      "mark": {"type": "line", "color": "firebrick", "strokeDash": [4, 4]},
      "encoding": {
        "x": {"field": "date", "type": "temporal"},
        "y": {"field": "flops", "type": "quantitative"}
      }
    }
  ]
}
```
/// caption
图 1.2：NVIDIA 数据中心 GPU FP16 峰值算力演进趋势
///

需求侧（~3000×）与供给侧（~30×量级）之间的增长鸿沟，必须通过系统级手段弥补：把关键通信尽量留在高带宽域内、把有效显存容量“做大”、把集合通信效率做高。正是在这一背景下，“超节点”从产品名词逐步演化为一种基础设施形态。

### 本白皮书的分析框架：指数增长与帕累托前沿

理解超节点的技术演进与设计决策，需要同时持有两个视角：

**视角一：指数增长轨道——“前沿在往哪里走？”**

以 NVIDIA 的代际演进为标杆，AI 基础设施的性能边界以近似指数速度外移。粗略而言，每一代硬件带来约 2× 的峰值算力提升，而配套软件栈（编译器、通信库、推理引擎）在同代硬件上再贡献约 5× 的实际性能增益，合计每代约 10× 的系统级跃迁[^nextplatform-pareto]。NVIDIA 在 GTC 2025 上展示了 Blackwell NVL72 相比 Hopper NVL8 在推理甜点配置上达到约 25–40× 的综合提升（tokens/s/MW × tokens/s/user），并在 Rubin 平台上进一步实现了相比 Blackwell 的 10× 推理吞吐密度增长与 10× 单位 token 成本下降[^nvidia-rubin]。这条轨道定义了**前沿的移动速度**——如果你的系统设计不能跟上这个节奏，就会在 2–3 年内从“领先”变为“落后”。

**视角二：帕累托前沿——“我应该站在前沿的哪个位置？”**

但指数增长并不能替代设计决策。在任意时间截面上，超节点的每一个工程选择都面临多目标权衡：带宽 vs 成本、时延 vs 规模、算力密度 vs 散热能力、编程易用性 vs 运行时效率。帕累托前沿提供了一张“性能地图”——它不给出唯一最优解，而是标出所有“不可能同时在每个维度上都更好”的最优权衡点集合。不同角色（架构师、采购、运维）可以根据自己的约束条件，在前沿上找到最适合的决策点。

**双轨的交汇**

这两个视角并非独立：新一代硬件和软件的核心价值，正是**把帕累托前沿整体向外推**——让之前“不可能同时达到”的性能组合变为可能。NVIDIA 在 2025 年 10 月的实测中展示了一个典型案例：仅通过数周的软件优化（TensorRT 推理栈升级、NVSwitch 内存互联优化、多 token 预测），在同一 GB200 NVL72 硬件上，推理帕累托前沿被推出了近 5×——曾经需要两年才能实现的软件增益，在数周内完成[^nextplatform-pareto]。

本白皮书采用这一双轨框架组织全部内容：

- **架构分析**（本章）与**参考设计**定义当前前沿在哪里、不同方案在前沿上的位置
- **软件系统**描述软件如何在同代硬件上推动前沿外移
- **建模仿真**提供计算和验证帕累托前沿的方法论工具
- **未来演进**讨论哪些技术能以最高的工程投入产出比把前沿再向外推一步

[^nextplatform-pareto]: Timothy Prickett Morgan. “Software Pushes The AI Pareto Frontier More Than Hardware.” *The Next Platform*, Oct 2025. `https://www.nextplatform.com/ai/2025/10/21/software-pushes-the-ai-pareto-frontier-more-than-hardware/`
[^nvidia-rubin]: Kyle Aubrey. “Inside the NVIDIA Rubin Platform: Six New Chips, One AI Supercomputer.” *NVIDIA Technical Blog*, Jan 2026. `https://developer.nvidia.com/blog/inside-the-nvidia-rubin-platform-six-new-chips-one-ai-supercomputer/`

下面给出本文语境下的工作性定义与边界说明。

## 1.1 核心概念定义

为了避免将“超节点”泛化为“多机集群”的同义词，本文采用如下工作性定义：

- **高带宽域（High Bandwidth Domain, HBD）**：在受控物理范围内（通常机柜/Pod），以加速器互联 Fabric 为中心，提供更接近“机内互联”特征的带宽、时延与拥塞行为。
- **对上层的抽象**：对训练栈而言，HBD 更像一台“放大版单机”（更大的显存池、更高的集合通信效率、更一致的性能）。
- **与 Scale-Out 的分工**：HBD 内解决“强耦合通信 + 显存池化”的瓶颈；HBD 间（跨 Pod）依赖 RDMA/DCN 承担“弱耦合扩展 + 数据/任务分发”。

需要强调的是：超节点并不意味着所有资源共享“物理一致的统一地址空间”，而是通过 **统一虚拟地址空间、P2P/单边通信能力、集合通信库与系统软件协同**，在性能与可编程性之间取得工程上的最优解。

## 1.2 架构设计驱动力

为什么单纯依赖 Scale-Out（水平扩展）已不足以应对挑战？超节点架构的诞生源于以下三个核心矛盾：

- **互联带宽的“剪刀差”**  
  训练工作负载以加速器为中心，但传统节点形态仍长期受制于 PCIe 与通用网络的带宽/拥塞特征。以典型数据中心 GPU 为例，NVLink（GPU↔GPU）带宽与 PCIe（GPU↔CPU/外设）带宽存在数量级差异；当关键通信路径被“挤回”PCIe/以太网时，系统可扩展性会快速恶化。超节点通过把 Scale-Up 域扩大到机柜/Pod 尺度，尽量让关键通信留在高带宽互联内完成。

- **“显存墙”与模型并行**  
  规模化训练不仅“需要更多算力”，更需要 **更大的有效显存容量** 以及更低的并行通信代价。随着模型规模、序列长度与并行策略演进，单卡/单机显存的物理上限会更频繁地成为系统瓶颈。超节点通过高带宽互联支撑更高效的张量并行（TP）、流水线并行（PP）与专家并行（EP），使得显存池化与跨节点协同成为可行选项。

- **通信时延与尾延迟敏感**  
  大规模训练中 All-Reduce/All-Gather/Reduce-Scatter 等集合通信高频发生，且对尾延迟与抖动敏感。跨机网络往往处于微秒级时延且更容易受拥塞影响；而机内/机柜级互联可将关键通信压缩到 **亚微秒甚至百纳秒量级**，并提供更可控的拥塞行为，从而提升通信可隐藏性与整体算力利用率。

### DeepSeek 后的通信范式跃迁

2024–2025 年间，以 DeepSeek-V2/V3 为代表的 MoE（Mixture of Experts）架构在前沿模型中全面铺开，从根本上改变了 Scale-Up 域的通信需求画像。

**从 TP 主导到 EP 主导**：Dense 模型时代的核心通信模式是张量并行（TP）驱动的 AllReduce/ReduceScatter，其流量模式相对规则（集合操作、同步屏障）。MoE 架构引入的专家并行（EP）则要求高频 All-to-All 通信——每个 token 需要被路由到少量专家，且路由结果高度动态，流量模式呈现**不可预测的稀疏多播**特征。

**对互联的新要求**：

| 维度 | Dense/TP 时代 | MoE/EP 时代 |
|:-----|:-------------|:------------|
| 主要通信模式 | AllReduce, AllGather | All-to-All（动态路由） |
| 流量可预测性 | 高（同步、对称） | 低（稀疏、动态、非对称） |
| 带宽敏感性 | 高（梯度同步） | 极高（每层每 token 均需路由） |
| 延迟敏感性 | 中（可隐藏） | 极高（EP 路由在关键路径上） |
| 尾延迟容忍度 | 可接受 | 极低（一个慢专家拖慢全局） |
| 对交换芯片的要求 | 聚合带宽 | 聚合带宽 + 动态负载均衡 + 低排队时延 |

这一范式跃迁直接解释了为什么 2025 年出现了如此密集的 Scale-Up 协议竞赛——**EP 通信对带宽、延迟和动态调度能力的三重极端要求**，使得传统 PCIe/RoCE 的性能天花板成为模型训练效率的核心瓶颈，倒逼产业界从物理层到事务层进行全栈重构。

## 1.3 超节点设计的底层逻辑：物理三面墙与帕累托跃迁

在讨论超节点时，我们真正在讨论的是：**“如何把足够多的晶体管塞进一个系统，并让它们高效地转起来。”**

基于这个第一性原理，限制系统规模和效率的，从来不是单纯的技术路径，而是三个最基础的物理边界，它们构成了超节点设计的**“硬件约束三面墙”**：

1.  **物理空间边界（面积墙/Density）**：受限于光刻机的掩膜版极限（约 858 mm²），单颗芯片上的晶体管数量是有绝对上限的。要获得更大算力，就必须把芯片做大；但做大受限于良率和物理极限。
2.  **热力学边界（能耗墙/Power）**：晶体管翻转就会发热。在给定的面积内塞入更多晶体管或提高频率，会导致功耗密度呈显著的非线性上升。如果热量散不出去，芯片就会面临热节流甚至烧毁（暗硅效应）。
3.  **信息传输边界（内存墙与通信墙/Bandwidth & Latency）**：算力再高，如果单卡数据“喂不饱”（内存带宽与容量造成的供数瓶颈），或者多卡之间“协同太慢”（多卡互联造成的协同瓶颈），晶体管就会闲置。而由于引脚数量与信道衰减的物理限制，片外访存与系统外延互联带来的带宽增长，往往赶不上芯片内部算力密度的增长。

这三面墙在每一代特定的底层技术（如 7nm 制程、HBM2、PCIe 4.0）与封装约束下，形成了难以逾越的强约束。如果要强行在现有技术栈内追求某一项指标的极致，就会不可避免地在其他维度付出巨大代价（例如在缺乏高带宽 Scale-Up 互联的条件下，将 GPU 集群从 8 卡扩展到 64 卡，All-Reduce 通信开销可从 <5% 膨胀至 >30%，算力线性度扩展效率急剧下跌），这构成了一个多目标的**“帕累托极限前沿”**。

### 英伟达的代际跃迁：持续推进帕累托边界

如本章第一节图 1.2 所示，如果我们以数据中心训练 GPU 峰值算力为标尺，行业呈现出**约每两年提升 6 倍的复合增长轨迹**（这构成了系统级 10 倍以上性能提升的硬件基石）。

这 6 倍的硬件级跃迁，远不足以仅靠半导体制程微缩来解释（例如从 7nm 到 3nm 的演进通常仅能带来约 2× 的密度提升与有限的能效改善）。它的奇迹在于，架构师在每一代都精准地引入了**“系统级的破局变量”**，从不同维度推移这三面约束墙，从而实现了整个帕累托极限前沿的跃迁：

*   **从 Pascal 到 Volta (2017)**：引入了**专用计算单元（Tensor Core）**。这打破了通用计算单元的“面积效率墙”，在单卡热设计功耗（TDP）仅增加 20%（250W 到 300W）的情况下，通过专门设计的 4x4 矩阵乘法电路并引入 Tensor Core 口径计算，将 AI 深度学习的峰值算力提升了约 6 倍（从 P100 基于 CUDA Core 的 21.2 TFLOPS FP16 算力，跃升至 V100 基于 Tensor Core 的 125 TFLOPS）。
*   **从 Volta 到 Ampere (2020)**：引入了**TF32 格式（并辅助以 2:4 结构化稀疏）**，在硅逻辑层面用数据格式置换了算力，使得原本需要 FP32 计算的负载能以接近 FP16 的速度运行；同时，NVSwitch 升级至第二代，使得基于 HGX A100 的 8 卡系统能够提供高达 600 GB/s（每 GPU 双向）接近全对等、在典型负载下近似无阻塞的互联带宽，缓解了单机内 GPU 通信互相拥挤的瓶颈。
*   **从 Ampere 到 Hopper (2022)**：确立了**超节点的标准形态**。通过引入 NVLink 4.0 与 NVSwitch 3.0，Hopper 时代支持通过 NVLink Switch System 实现跨节点的两级 NVSwitch 拓扑，构成最大 256 GPU 的同一 NVLink 域。这打破了跨机通信的“延迟墙”，显著降低跨节点通信的时延与拥塞开销，使其更接近节点内互联的协同体验。同时引入 FP8 与 TMA（Tensor Memory Accelerator）彻底解耦了访存与计算。
*   **从 Hopper 到 Blackwell (2024)**：引入了**先进封装与机柜级物理重构**。NV-HBI 用 10 TB/s 的 D2D 互联实现两块 Die 的逻辑单芯片化，推移了光刻机的“面积墙”；为了解决 MoE 模型带来的海量 All-to-All 流量，推出了 NVL72 铜缆背板架构，在机柜内 <2m 的物理距离内，采用被动铜缆直连以规避光电转换的功耗与延迟开销，构建了 130 TB/s（系统双向总带宽）近似全互联的互联域，推移了“功耗/互联墙”。同时引入 FP4 微张量缩放，再次压榨了单比特的算力价值。
*   **未来（Rubin及以后）**：可以预见，下一代架构必将依赖 **HBM4 (更高带宽与更低 pJ/bit，可能走向混合键合等实现)** 和 **光互联形态演进 (CPO、LPO 等低功耗光方案)** 来推移当前的“内存能效墙”与“长距互联传输墙”。

### 小结：多维协同的系统工程

回顾这段技术史，我们得出一个明确的结论：**“2年6倍”的算力硬件增长并非单维度的线性外推，而是架构师“不断引入跨领域新技术，连续推平物理约束墙”所带来的系统工程结果。** 

与传统木桶效应关注最短板不同，超节点的代际跃迁恰恰是每一代精准识别并击穿当代物理短板的协同演进过程。对于任何试图在超节点领域竞争的玩家而言，单纯在某一条旧曲线上做微调（例如仅靠堆积流片工艺缩小面积，或者单纯提升芯片标称时钟频率）都只会撞上边际效益递减的南墙。要实现代际的追赶与超越，必须在**先进封装、存储底座、Scale-Up 互联协议、数值精度、高密供电制冷**等多个技术路径上协同发力，才能完成系统级帕累托前沿的跃迁。

## 1.4 系统分层蓝图

现代 AI 超算系统的硬件架构通常遵循自底向上的层次化设计原则：每一层都通过特定互联技术，将计算单元组织成更大规模的计算资源，并逐步引入路由、拥塞控制与可靠性机制。

```mermaid
block-beta
    columns 4
    PE0["PE"] space:2 PE1["PE"]
    space:4
    Die0["Die"] space:2 Die1["Die"]
    space:4
    Chip0["Chip"] space:2 Chip1["Chip"]
    space:4
    Node0["Node"] space:2 Node1["Node"]
    space:4
    Pod0["SuperPod"] space:2 Pod1["SuperPod"]
    space:4
    Cluster0["Cluster"] space:2 Cluster1["Cluster"]

    PE0<-- "NOC" -->PE1
    Die0<-- "D2D" -->Die1
    Chip0<-- "C2C" -->Chip1
    Node0<-- "C2C" -->Node1
    Pod0<-- "RDMA" -->Pod1
    Cluster0<-- "DCN" -->Cluster1

    PE0-- "NOC" -->Die0
    PE1-- "NOC" -->Die1
    Die0-- "Chiplet" -->Chip0
    Die1-- "Chiplet" -->Chip1
    Chip0-- "PCIE" -->Node0
    Chip1-- "PCIE" -->Node1
    Node0-- "C2C" -->Pod0
    Node1-- "C2C" -->Pod1
    Pod0-- "RDMA" -->Cluster0
    Pod1-- "RDMA" -->Cluster1
```
/// caption
图 1.3：AI 超算系统硬件分层蓝图
///

1. **层级1 - 芯粒内部 (Die)**: 系统的最基本计算单元是**处理单元 (PE)**，例如GPU中的流式多处理器(SM)。在单个硅片(**Die**)上，众多的PE通过**片上网络 (NoC)**高效互联。
2. **层级2 - 芯片 (Chip)**: 借助先进封装技术(Chiplet)，多个独立的**芯粒 (Die)**被封装在一起，构成一个完整的**芯片 (Chip)**。它们之间通过高速的**Die-to-Die (D2D)**接口（如NV-HBI, UCIe）通信，使其在逻辑上表现得像一个单片大芯片。
3. **层级3 - 节点 (Node)**: 一个服务器**节点 (Node)**通常包含多个**芯片 (Chip)**（如多块GPU）和CPU。节点内的GPU之间通过**芯片间互联 (C2C)**技术（如NVLink + NVSwitch）构建高速通信域，而GPU与CPU之间则主要通过**PCIe总线**连接。
4. **层级4 - SuperPod/HBD**: 节点间以 NVSwitch Fabric/自研协议组成机柜级 Scale-Up 域。
5. **层级5 - 集群 (Cluster)**: 多个**SuperPod**组合成一个**集群 (Cluster)**。SuperPod之间的通信（Scale-Out）依赖于**数据中心网络**，通常使用基于**RDMA**的InfiniBand或RoCE高速网络。

真正的竞争点往往集中在第 3–4 层：如何在机柜级保持低直径与高二分带宽，同时兼顾工程可运维性（线缆/散热/电源/故障域）与软件可用性（编程模型/调度/容错）。

