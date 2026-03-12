# 参考设计

前三章建立了一套完整的分析链：架构分析定义了系统能力边界及其外移机制，并用帕累托前沿将其形式化；软件系统阐明了这些被打开的边界如何被兑现为 Goodput；建模仿真提供了度量边界位置的方法论工具。本章的任务是把这些分析收束为一个具体的工程问题：**在当前系统能力边界上，针对不同的约束优先级和负载画像，应该选择哪些点？**

需要强调的是，参考设计不是单点最优答案。这里所谓"边界上的点"，在形式化意义上对应帕累托前沿上的不可支配解：不存在一个方案能在所有维度上同时支配其他方案。每一个参考设计都是在规模、时延、带宽、功耗、成熟度与软件复杂度的权衡空间中，针对特定约束优先级做出的具体工程选择。

## 五个设计，一条边界

本章给出的五个参考设计，对应当前系统能力边界上的五个不同位置。它们之间不是"好与更好"的替代关系，而是"不同约束优先级下的不可支配点"：

- **标准以太网方案（ESUN）**在生态开放性和可运维性维度上占据前沿，为此在单跳延迟上让出 3–5 倍空间。
- **标准总线方案（UALink）**在访存延迟和内存语义完整性维度上占据前沿，为此在生态成熟度和供应链就绪度上承担风险。
- **Dragonfly + OCS** 在规模扩展性和组间带宽弹性维度上占据前沿，为此引入更高的控制面复杂度。
- **3D Torus + OCS** 在拓扑弹性和故障隔离能力维度上占据前沿，为此需要最复杂的软件协同与拓扑管理。
- **大环路 + dOCS** 在激进去交换化和功耗优化维度上探索前沿外推的极限，为此承受最高的技术不确定性。

没有任何一个方案在所有维度上胜过其余方案——这正是它们共同构成当前能力边界、而非简单排序的原因。

## 帕累托定位总览

下表将五个参考设计在七个关键维度上的位置显式对比。每个维度上的★越多，该方案在该维度上越接近当前前沿：

| 维度 | 标准以太网 | 标准总线 | Dragonfly+OCS | Torus+OCS | 大环路+dOCS |
|:-----|:---------|:--------|:-------------|:----------|:-----------|
| **单跳/访存延迟** | ★★（250–500 ns） | ★★★★（<1 μs RTT） | ★★★（低直径） | ★★★★（直连光路） | ★★★★★（无包交换） |
| **规模上限** | ★★★（≤1024） | ★★★（≤1024） | ★★★★★（万卡级） | ★★★★（千–万卡） | ★★★（探索中） |
| **拓扑弹性** | ★（固定 Spine-Leaf） | ★（固定全交叉） | ★★★（组间 OCS） | ★★★★★（全拓扑重构） | ★★★★★（收发器级重构） |
| **生态成熟度** | ★★★★★（以太网生态） | ★★（交换芯片未量产） | ★★★（组件成熟，集成新） | ★★★（Google 验证） | ★（研究阶段） |
| **功耗与 TCO** | ★★★（电交换为主） | ★★★（电交换为主） | ★★★★（减少电交换层级） | ★★★★★（无源光层核心） | ★★★★★（潜力最优） |
| **软件复杂度**（★越多越简单） | ★★★★★（复用以太运维） | ★★★（FAM 管理） | ★★★（拓扑管理+OCS控制） | ★★（全栈协同设计） | ★（全新软件栈） |
| **适用负载** | EP/DP/MoE/混部 | TP-heavy/显存共享 | 大规模训练/混合 | 邻近通信/高容错 | 前瞻探索 |

这张表的核心信息是：**没有一列全是五星**。每个方案在某些维度上领先，在另一些维度上让出空间。读者应根据自身的约束优先级——当前阶段最受限的是生态兼容还是延迟？是规模还是可运维性？——在这条能力边界上找到最匹配的位置。

上表展示的是参考设计的结构性定位。对于如何把这一坐标系进一步延伸到具体产品条目、实测证据、提交边界与后续比较口径，可参阅仍处于筹备阶段的 [SuperPod Pareto Index（SPI）](../07-spi.md)。

下图采用小多图（Small Multiples）布局，将五个参考设计的六维帕累托定位分别展示。每个子图突出一个设计的形状特征，读者可以通过对比形状差异直观感受"没有任何一个方案在所有维度上同时领先"的帕累托不可支配关系。每个顶点旁标注了该维度的得分。

```vegalite
{
  "$schema": "https://vega.github.io/schema/vega/v5.json",
  "description": "五个参考设计帕累托定位——小多图雷达",
  "padding": {"top": 10, "right": 10, "bottom": 10, "left": 10},
  "autosize": "pad",

  "data": [
    {
      "name": "table",
      "values": [
        {"key": "延迟", "value": 2, "category": "标准以太网 (ESUN)", "idx": 0},
        {"key": "规模", "value": 3, "category": "标准以太网 (ESUN)", "idx": 1},
        {"key": "弹性", "value": 1, "category": "标准以太网 (ESUN)", "idx": 2},
        {"key": "成熟度", "value": 5, "category": "标准以太网 (ESUN)", "idx": 3},
        {"key": "TCO", "value": 3, "category": "标准以太网 (ESUN)", "idx": 4},
        {"key": "软件简易度", "value": 5, "category": "标准以太网 (ESUN)", "idx": 5},

        {"key": "延迟", "value": 4, "category": "标准总线 (UALink)", "idx": 0},
        {"key": "规模", "value": 3, "category": "标准总线 (UALink)", "idx": 1},
        {"key": "弹性", "value": 1, "category": "标准总线 (UALink)", "idx": 2},
        {"key": "成熟度", "value": 2, "category": "标准总线 (UALink)", "idx": 3},
        {"key": "TCO", "value": 3, "category": "标准总线 (UALink)", "idx": 4},
        {"key": "软件简易度", "value": 3, "category": "标准总线 (UALink)", "idx": 5},

        {"key": "延迟", "value": 3, "category": "Dragonfly + OCS", "idx": 0},
        {"key": "规模", "value": 5, "category": "Dragonfly + OCS", "idx": 1},
        {"key": "弹性", "value": 3, "category": "Dragonfly + OCS", "idx": 2},
        {"key": "成熟度", "value": 3, "category": "Dragonfly + OCS", "idx": 3},
        {"key": "TCO", "value": 4, "category": "Dragonfly + OCS", "idx": 4},
        {"key": "软件简易度", "value": 3, "category": "Dragonfly + OCS", "idx": 5},

        {"key": "延迟", "value": 4, "category": "Torus + OCS", "idx": 0},
        {"key": "规模", "value": 4, "category": "Torus + OCS", "idx": 1},
        {"key": "弹性", "value": 5, "category": "Torus + OCS", "idx": 2},
        {"key": "成熟度", "value": 3, "category": "Torus + OCS", "idx": 3},
        {"key": "TCO", "value": 5, "category": "Torus + OCS", "idx": 4},
        {"key": "软件简易度", "value": 2, "category": "Torus + OCS", "idx": 5},

        {"key": "延迟", "value": 5, "category": "Ring + dOCS", "idx": 0},
        {"key": "规模", "value": 3, "category": "Ring + dOCS", "idx": 1},
        {"key": "弹性", "value": 5, "category": "Ring + dOCS", "idx": 2},
        {"key": "成熟度", "value": 1, "category": "Ring + dOCS", "idx": 3},
        {"key": "TCO", "value": 5, "category": "Ring + dOCS", "idx": 4},
        {"key": "软件简易度", "value": 1, "category": "Ring + dOCS", "idx": 5}
      ],
      "transform": [
        {"type": "formula", "as": "angle", "expr": "datum.idx * 2 * PI / 6 - PI / 2"}
      ]
    },
    {
      "name": "dims",
      "values": [
        {"key": "延迟", "idx": 0},
        {"key": "规模", "idx": 1},
        {"key": "弹性", "idx": 2},
        {"key": "成熟度", "idx": 3},
        {"key": "TCO", "idx": 4},
        {"key": "软件简易度", "idx": 5}
      ],
      "transform": [
        {"type": "formula", "as": "angle", "expr": "datum.idx * 2 * PI / 6 - PI / 2"}
      ]
    }
  ],

  "scales": [
    {"name": "r", "type": "linear", "domain": [0, 5], "range": [0, 72], "zero": true},
    {
      "name": "color", "type": "ordinal",
      "domain": ["标准以太网 (ESUN)", "标准总线 (UALink)", "Dragonfly + OCS", "Torus + OCS", "Ring + dOCS"],
      "range": ["#2563eb", "#dc2626", "#059669", "#7c3aed", "#d97706"]
    }
  ],

  "layout": {"columns": 3, "padding": {"row": 50, "column": 30}},

  "marks": [
    {
      "type": "group",
      "from": {
        "facet": {"data": "table", "name": "faceted", "groupby": ["category"]}
      },
      "encode": {
        "enter": {
          "width": {"value": 200},
          "height": {"value": 200}
        }
      },
      "marks": [
        {
          "type": "text",
          "encode": {
            "enter": {
              "x": {"value": 100}, "y": {"value": -6},
              "text": {"signal": "data('faceted')[0].category"},
              "fontSize": {"value": 12}, "fontWeight": {"value": "bold"},
              "fill": {"signal": "scale('color', data('faceted')[0].category)"},
              "align": {"value": "center"}, "baseline": {"value": "bottom"}
            }
          }
        },
        {
          "type": "line", "from": {"data": "dims"},
          "encode": {"enter": {
            "interpolate": {"value": "linear-closed"},
            "x": {"signal": "100 + scale('r', 1) * cos(datum.angle)"},
            "y": {"signal": "100 + scale('r', 1) * sin(datum.angle)"},
            "stroke": {"value": "#e5e7eb"}, "strokeWidth": {"value": 0.5}
          }}
        },
        {
          "type": "line", "from": {"data": "dims"},
          "encode": {"enter": {
            "interpolate": {"value": "linear-closed"},
            "x": {"signal": "100 + scale('r', 3) * cos(datum.angle)"},
            "y": {"signal": "100 + scale('r', 3) * sin(datum.angle)"},
            "stroke": {"value": "#e5e7eb"}, "strokeWidth": {"value": 0.5}
          }}
        },
        {
          "type": "line", "from": {"data": "dims"},
          "encode": {"enter": {
            "interpolate": {"value": "linear-closed"},
            "x": {"signal": "100 + scale('r', 5) * cos(datum.angle)"},
            "y": {"signal": "100 + scale('r', 5) * sin(datum.angle)"},
            "stroke": {"value": "#d1d5db"}, "strokeWidth": {"value": 1}
          }}
        },
        {
          "type": "rule", "from": {"data": "dims"},
          "encode": {"enter": {
            "x": {"value": 100}, "y": {"value": 100},
            "x2": {"signal": "100 + scale('r', 5) * cos(datum.angle)"},
            "y2": {"signal": "100 + scale('r', 5) * sin(datum.angle)"},
            "stroke": {"value": "#e5e7eb"}, "strokeWidth": {"value": 0.8}
          }}
        },
        {
          "type": "text", "from": {"data": "dims"},
          "encode": {"enter": {
            "x": {"signal": "100 + (scale('r', 5) + 14) * cos(datum.angle)"},
            "y": {"signal": "100 + (scale('r', 5) + 14) * sin(datum.angle)"},
            "text": {"field": "key"},
            "fontSize": {"value": 9}, "fontWeight": {"value": "600"},
            "fill": {"value": "#6b7280"},
            "align": [
              {"test": "datum.idx == 0 || datum.idx == 3", "value": "center"},
              {"test": "datum.idx <= 2", "value": "left"},
              {"value": "right"}
            ],
            "baseline": [
              {"test": "datum.idx == 0", "value": "bottom"},
              {"test": "datum.idx == 3", "value": "top"},
              {"value": "middle"}
            ]
          }}
        },
        {
          "type": "line", "from": {"data": "faceted"},
          "encode": {"enter": {
            "interpolate": {"value": "linear-closed"},
            "x": {"signal": "100 + scale('r', datum.value) * cos(datum.angle)"},
            "y": {"signal": "100 + scale('r', datum.value) * sin(datum.angle)"},
            "stroke": {"signal": "scale('color', datum.category)"},
            "strokeWidth": {"value": 2.5},
            "fill": {"signal": "scale('color', datum.category)"},
            "fillOpacity": {"value": 0.12}
          }}
        },
        {
          "type": "symbol", "from": {"data": "faceted"},
          "encode": {"enter": {
            "x": {"signal": "100 + scale('r', datum.value) * cos(datum.angle)"},
            "y": {"signal": "100 + scale('r', datum.value) * sin(datum.angle)"},
            "fill": {"signal": "scale('color', datum.category)"},
            "size": {"value": 40}
          }}
        },
        {
          "type": "text", "from": {"data": "faceted"},
          "encode": {"enter": {
            "x": {"signal": "100 + (scale('r', datum.value) + 9) * cos(datum.angle)"},
            "y": {"signal": "100 + (scale('r', datum.value) + 9) * sin(datum.angle)"},
            "text": {"signal": "datum.value"},
            "fontSize": {"value": 10}, "fontWeight": {"value": "bold"},
            "fill": {"signal": "scale('color', datum.category)"},
            "align": [
              {"test": "datum.idx == 0 || datum.idx == 3", "value": "center"},
              {"test": "datum.idx <= 2", "value": "left"},
              {"value": "right"}
            ],
            "baseline": [
              {"test": "datum.idx == 0", "value": "bottom"},
              {"test": "datum.idx == 3", "value": "top"},
              {"value": "middle"}
            ]
          }}
        }
      ]
    }
  ]
}
```
/// caption
图 4.1：五个参考设计的帕累托定位雷达图（小多图布局）。每个子图突出一个设计在六个维度上的形状，顶点数字为该维度得分（满分 5）。对比五个形状可以直观确认：没有任何一个方案在所有维度上同时最优——这正是帕累托不可支配关系的视觉表达。
///

## 前沿上的两个判断维度

在具体方案选择中，每个参考设计需要同时回答两个问题：

1. **当前位置**：它在今天的帕累托前沿上处于什么位置？在哪些维度上接近前沿极值，在哪些维度上做出了让步？
2. **演进路径**：它是否位于一条可通向下一代帕累托前沿的路径上？当光互联、先进封装、Chiplet、HBM/3D DRAM 等技术变量改写前沿形状时，该方案的投资是否仍然有效？

标准构型在"当前位置"维度上更强——成熟度高、可立即部署、风险可控；探索构型在"演进路径"维度上更强——它们的架构预设了未来技术变量（光交换、拓扑弹性、分布式 OCS）的融入空间。这意味着理想的部署策略不是二选一，而是**成熟路径优先、探索路径并行验证**。

## 方案分类

本章将参考设计分成两类：

- **标准构型**：以当前更成熟的工程路径为核心，强调可落地性、生态兼容与可运维性。在帕累托前沿上，它们的位置更偏向"成熟度–运维性–生态"端。
- **探索构型**：面向更大规模、更低时延或更高带宽目标，在拓扑与光交换等方向上主动引入更强的系统重构能力。在帕累托前沿上，它们的位置更偏向"规模–弹性–能效"端。

### 标准构型

- [标准以太网方案](standard-ether.md)：以开放以太网生态为基础，在帕累托前沿上占据**生态开放性与可运维性的极值位置**。
- [标准总线方案](standard-bus.md)：以总线/内存语义为核心，在帕累托前沿上占据**访存延迟与内存语义完整性的极值位置**。

### 探索构型

- [Dragonfly + OCS](dragonfly-ocs.md)：以 Dragonfly 分组拓扑 + OCS 组间弹性为骨架，在帕累托前沿上占据**规模扩展性与组间带宽弹性的极值位置**。
- [Torus + OCS](torus-ocs.md)：以 3D Torus + OCS 全拓扑重构为核心，在帕累托前沿上占据**拓扑弹性与故障隔离的极值位置**。
- [大环路 + 分布式 dOCS](ring-docs.md)：将光交换能力下沉到收发器级，在帕累托前沿上探索**去交换化与极致能效的前沿外推极限**。

## 方案选择维度

在本章语境下，参考设计主要沿以下维度比较（即上表的 7 个帕累托维度）：

| 维度 | 关注问题 |
|:---|:---|
| 单跳/访存延迟 | 延迟对 TP 等强耦合通信模式的 Goodput 影响有多大 |
| 规模上限 | 方案主要面向机内、机柜级还是更大规模 HBD |
| 拓扑弹性 | 能否动态重构以适配任务切片和故障绕行 |
| 生态成熟度 | 当前供应链、标准化程度和可采购性如何 |
| 功耗与 TCO | 光电转换、交换层级、布线与运维复杂度是否可控 |
| 软件复杂度 | 对运行时、拓扑管理器、流控与容错机制的要求有多高 |
| 适用负载 | 更适合稠密训练、MoE、长上下文推理还是混合负载 |

## 从方案生态到协同生态

五个参考设计的帕累托不可支配关系揭示了一个超越单一方案的结构性事实：**超节点不是单产品竞争，而是跨芯片、互联、光学、封装、整机、软件与运维的协同工程**。没有任何一个参与者能够独自覆盖帕累托前沿上的所有维度。

这意味着参考设计的工程落地需要多类角色的深度协同：

| 产业角色 | 在参考设计中的核心贡献 | 协同节点 |
|:---------|:---------------------|:---------|
| **芯片与加速器厂商** | 提供算力底座与 Die-to-Die 互联能力 | 封装接口规范、数值精度格式 |
| **互联与交换芯片厂商** | 提供 Scale-Up 交换能力与协议实现 | 互联协议标准化、拓扑适配 |
| **光模块与光交换厂商** | 提供光互联链路与可重构光交换 | 功耗-带宽-延迟的三维权衡验证 |
| **封装与先进制造厂商** | 提供 2.5D/3D 集成与 Chiplet 封装 | 热管理、信号完整性、良率 |
| **整机与系统集成商** | 提供机柜级工程集成与液冷散热 | 供电架构、布线密度、运维接口 |
| **云厂商与智算中心** | 提供规模化部署验证与运维经验 | RAS 数据、负载画像、Goodput 实测 |
| **软件与框架团队** | 提供通信运行时、调度系统与可观测性 | 硬件抽象层、并行策略、故障恢复 |
| **高校与研究机构** | 提供拓扑优化、仿真方法论与前沿理论 | 算法突破、基准测试、独立评估 |

本白皮书的参考设计评估框架（帕累托七维度）为这种协同提供了共同的分析语言：各方可以在同一坐标系下评估自身贡献的位置、识别协同的接口、量化系统级前沿外推的效果。

这些方案不是终点——它们的成立条件仍会被光互联、封装、Chiplet、HBM/3D DRAM 与模型形态演进持续改写。因此下一章将转向未来演进，讨论哪些技术变量最可能重新塑造本章帕累托前沿的形状。
