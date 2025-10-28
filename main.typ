// 技术白皮书最简结构 (Typst)
// 说明: 保持文件单一, 后续可拆分为 modules/*.typ
// 使用: typst watch main.typ 或 typst compile main.typ

// ------------------- 封面配置 -------------------
#import "@preview/zh-kit:0.1.0": setup-base-fonts

#let title = "SuperPod 技术白皮书"
#let subtitle = "分布式 AI 推理加速架构"
#let version = "版本 v0.1 (初始草案)"
#let date = datetime.today()
#let authors = ["DeepLink 团队"]

#show: doc => setup-base-fonts(doc)

#set text(lang: "zh", size: 12pt)
#set par(spacing: 1.2em, justify: true, leading: .8em)

// 字体策略: 如果环境未安装指定中文字体, Typst 会回退系统默认字体
// #set text(font: "Helvetica") // 确保默认可用字体, 中文系统会回退

// 标题样式统一函数
#let section-title = (lvl, body) => {
	heading(lvl: lvl, spacing: 0.6em)[#body]
}

// 代码块样式占位: 使用标准 fenced 代码

// 页眉页脚 (待后续完善: 需要正确的上下文 show 规则)
// TODO: 添加页眉页脚与页码

// 封面
#align(center)[
  #text(size: 34pt, weight: 600)[#title] \
  #text(size: 18pt, fill: gray)[#subtitle]
  #v(8mm)
  #text(size: 12pt)[#version]
  #text(size: 11pt)[发布日期: #date.display()]
  #v(15mm)
  #text(size: 11pt)[作者: DeepLink 团队]
]

#pagebreak()
= 版权声明

本白皮书内容仅供技术讨论与评估。未经许可不得以任何形式复制、传播或用于商业用途。© 2025 DeepLink.

= 摘要
本白皮书聚焦于 SuperPod / 超节点 (SuperPod / SuperNode) 架构的技术基础，系统梳理其从硬件互联、拓扑设计到软件编程模型的演进逻辑。我们给出：

- 代际演进：从 Volta/HGX 到 Blackwell / GB200 的算力、互联与封装协同路径。
- 系统结构：引入 HBD (High Bandwidth Domain) 作为 Scale-Up 域，区别于传统仅依赖 RDMA 的 Scale-Out 设计。
- 互联与交换：NVLink / NVSwitch、CEI SerDes、数据中心交换 ASIC 的协同演进。
- 拓扑策略：Full Mesh / Fat-Tree / Dragonfly / Torus / SlimFly 的适用性权衡与公式化比较。
- 未来方向：面向 MoE / 非均匀工作负载的 PGAS + 单边通信模型替代或补强 BSP + SPMD。

通过这些分析，我们强调：超节点不是“简单堆叠 GPU”，而是“算力 × 互联 × 内存 × 封装 × 编程模型”的系统工程。

#pagebreak()

#outline(depth: 2)

#set heading(numbering: "1.")

#include "sections/01-intro.typ"
#include "sections/02-nvidia.typ"

== 技术趋势与代际演进
Huang's Law @huangs_law 提出十年千倍系统算力增长由多因子复合驱动：低精度格式 (~16×)、矩阵 / Tensor Core (~12×)、制程与微架构 (~2.5×)，叠加互联规模与封装带来的 Scale-Up 扩展，形成系统级指数放大。随着 Blackwell 引入 NV-HBI 双 Die 高带宽耦合 @nvidia_blackwell_ultra，未来趋势进一步转向“系统即产品” (System-as-a-Chip)。

== 系统层级概览
自下而上：PE → Die → Chip → Node → SuperPod (HBD 域) → Cluster。差异于传统集群在于新增“SuperPod”层，将数十 ~ 数百 GPU 以内的低延迟域与跨机柜的 RDMA 域分离。

// 图占位: 分层结构示意 (PE→Cluster)。
// TODO: 添加层次结构 SVG 或绘图。

== 超节点硬件系统
超节点解决的核心问题：
- 弥补单节点内部 NVLink 与跨节点 RDMA 带宽/延迟鸿沟。
- 将 Peer Access 范式扩展为跨节点统一寻址 (由 Fabric Manager 管理全局物理地址空间)。
- 为未来大模型（MoE / 多模态 / 长上下文）提供可线性扩展且高利用率的执行底座。

特点：
1. HBD 域：机柜级 NVSwitch Fabric 构成非阻塞互联。
2. 地址全局化：47-bit 物理地址映射 + GPU MMU 透明远程访存。
3. Scale-Up 与 Scale-Out 分层：HBD 内偏向高频小粒度同步；HBD 间通过 RDMA 聚合梯度或模型分片。

== NVLink / NVSwitch 代际对比
// 表示例 (使用 Typst 原生表格)
#table(columns: 9, align: (left, left, left, left, right, right, right, right, right),
	[代际],[GPU 架构],[发布],[NVLink],[每Link双向 GB/s],[Link 数],[聚合 GB/s],[典型规模],[最大域],
	[1],[Volta],[2018],[2.0],[50],[6],[300],[16],[16],
	[2],[Ampere],[2020],[3.0],[50],[12],[600],[8/16],[16],
	[3],[Hopper],[2022],[4.0],[100],[18],[1800],[8/32],[256],
	[4],[Blackwell],[2025],[5.0],[200],[18],[3600],[72],[576 (估)]
)

说明: 末列 576 为公开资料推测 (估)。

== 数据中心交换 ASIC (简表)
#table(columns: 4, align: (left,left,left,left),
	[代际],[交换容量 Tbps],[SerDes 每 Lane],[典型聚合端口],
	[Tomahawk 3],[12.8],[50G PAM4],[64×200G],
	[Tomahawk 4],[25.6],[100G PAM4],[64×400G],
	[Tomahawk 5],[51.2],[100G PAM4],[128×400G],
		[Next],[102.4 (估)],[200G PAM4],[128×800G (估)]
)

== 互联拓扑比较
Dragonfly @dragonfly_topology 与 SlimFly @slimfly_topology 提供低直径演进路径；Torus 在邻近通信密集计算中仍具价值 @torus_network_perf。
#table(columns: 5, align: (left,center,left,left,left),
	[拓扑],[直径],[二分带宽(相对)],[优点],[局限],
	[Full Mesh],[1],[N^2 / 4],[最低延迟],[端口数平方增长],
	[Fat-Tree],[3],[~N/2],[无阻塞可控],[成本随规模上升],
	[Dragonfly],[≤3],[~N/2],[减少全局链路],[需智能路由],
	[Torus],[可变],[低],[局部性好],[全局吞吐不足],
	[SlimFly],[2–3],[近满],[高效径向],[实现复杂]
)

== 互联公式 (摘录)
Full Mesh 二分带宽: Bbi = N^2 / 4 * B
Fat-Tree 最大规模 (无阻塞近似): Nmax = Rsw^2 / (2 * Rdev)

== 电互联关键技术
SerDes + Lane 聚合构成基础带宽单元。OIF-CEI 规范演进（28G→56G→112G→224G）为 PCIe / CXL / NVLink / Ethernet 提供电气支撑；上层协议侧重在链路 / 事务层创新（如 CXL.cache / NVLink 原子访问 / RDMA 零拷贝路径）。

== 访存与地址空间
现代 GPU 通过 UVA + MMU 多级页表实现统一寻址。超节点中新引入 Fabric Manager：
1. 分配全局物理地址片段。
2. 建立 VA→全局 PA 映射 (PTE 标记远程 GPU ID)。
3. NVSwitch 基于地址+ID 硬件路由，消除 CPU 协调开销。

== 编程模型演进
单边通信实现依赖 NVSHMEM 等机制 @nvshmem_magnum_io 与 PGAS 语义 @openshmem15_spec；Pathways 框架展示异步数据流潜力 @pathways_dataflow。
#table(columns:5, align:(left,left,left,left,left),
	[模型],[核心特征],[优势],[局限],[典型场景],
	[BSP + SPMD],[阶段化 + 全局 Barrier],[思维简单 / 工具成熟],[Straggler 放大],[稠密 DNN 训练],
	[PGAS + One-Sided],[全局分区地址 + Put/Get],[解耦同步 / 动态负载友好],[编程心智门槛],[MoE / 推理调度]
)

单边通信通过 NVSHMEM / RDMA Write / 原子操作实现“通信即内存访问”，是应对非均匀工作负载 (MoE / 长序列生成) 的关键路径。

== MoE / 非均匀负载挑战 (概述)
1. Token 动态路由 → 不同专家负载差异。
2. 输出长度不定 → 序列生成阶段 GPU 时间漂移。
3. 静态 Barrier 模式下利用率坍塌。
解决方向：分片 + 异步调度 + One-Sided 完成通知。

// 核心组件
== 典型组件角色 (概述)
- Gateway / API Front：统一入口、鉴权与速率治理。
- Scheduler：拓扑感知 + 资源反馈调度 (可扩展至预测性 / RL 策略)。
- Engine Pod：多模型加载 / 热替换 / Lazy Weight Fetch。
- Resource Watcher：采集 GPU / 显存 / 链路拥塞指标形成反馈闭环。
- Policy Center：QoS / 租户隔离 / 限流与流量整形。

// 技术路线
== 演进路线 (示例)
| 阶段 | 目标 | 关键交付 |
|------|------|-----------|
| P0 | 基础可用 | HBD 内全互联 + 基础训练/推理通路 |
| P1 | 利用率提升 | 指标反馈 + 动态批合并 + 分级缓存 |
| P2 | 成本优化 | Spot 容错 / 弹性扩展 / 能耗调度 |
| P3 | 智能调度 | 预测排队 / 模型热度迁移 / 自动分片 |
| P4 | 自适应 | RL/统计混合调度 / 异构加速自配置 |

// 性能与扩展
== 性能与扩展策略
目标示例：
- HBD 内 AllReduce 放大效率 > 90% (32 / 72 GPU)。
- TP99 推理延迟 小于 200ms (中等上下文)。
- 集群 GPU 利用率 > 65%（含非均匀路由）。

关键策略：
1. 分层缓存 (权重 / KV / Embedding)。
2. 向量路由 + 近似最近邻减少跨域访问。
3. Batch 聚合 + 小请求合并。
4. 零拷贝共享 (Pinned 内存 + GPUDirect / BAR 映射)。
5. 热度感知动态加载 / 异步权重预取。

// 未来规划
== 未来规划方向
1. 面向多模态：视频 / 语音 / 图像 与 文本混合推理统一调度。
2. 子图级执行：图调度器识别计算 DAG 热路径并映射至 HBD。
3. 自动化验证：拓扑 / 路由 / 调度 联合仿真平台。
4. 可观测性闭环：将链路级拥塞信号进入调度器实时决策。
5. Green AI：功耗感知调度 + 动态频率 / 精度自适应。

// 结论
== 结论
超节点 (SuperPod) 架构代表了 AI 基础设施从“负载驱动硬件堆叠”向“系统协同设计”的范式跃迁。其价值不在于单一指标绝对值，而在于：通过互联 / 内存 / 封装 / 调度 / 编程模型的协同，使规模扩展仍保持可预测效率。面向未来，PGAS + 自适应调度 + 系统级 Telemetry 将成为突破非均匀工作负载效率天花板的关键。

// 附录 / 术语表
== 术语表
#table(columns:2, align:(left,left),
	[术语],[说明],
	[HBD],[High Bandwidth Domain, 机柜级高带宽互联域],
	[NVSwitch Fabric],[由多级 NVSwitch 构成的全互联或近似无阻塞结构],
	[PGAS],[Partitioned Global Address Space, 分区全局地址模型],
	[One-Sided],[单边通信，Put/Get 不需对端同步配对],
	[Straggler],[同步阶段拖慢整体进度的慢节点],
	[Bisection BW],[二分带宽指标],
	[SerDes],[高速串行信号转换核心单元]
)
| Straggler | 慢节点，造成同步阶段整体阻塞的节点 |
| NV-HBI | NVIDIA 高带宽 Die 间互联接口 |
| SerDes | 串行器/解串器，高速串行信号物理层核心单元 |
| Bisection BW | 二分带宽，衡量全局吞吐的关键拓扑指标 |
| Fabric Manager | 管理全局 GPU 地址映射与访问策略的组件 |

// 占位代码示例
== 示例代码片段 (调度伪代码)
```rust
fn schedule(req: InferenceReq, topo: &Topology, metrics: &Metrics) -> Node {
	let pool = topo.hbd_nodes();
	let filtered = filter(pool, |n| n.model_loaded(req.model));
	let scored = score(filtered, |n|  w_latency*n.lat + w_bw*n.free_bw - w_mem*n.mem_frag);
	let cand = pick_top_k(scored, k=4);
	// 预探测链路负载 (async)
	let refined = proactive_probe(cand);
	select_lowest(refined, |n| n.predicted_queue_time())
}
```

== 参考文献
#bibliography("refs.bib")
