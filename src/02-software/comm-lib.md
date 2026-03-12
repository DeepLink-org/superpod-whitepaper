# 通信库的架构与设计

本节讨论的是一个经常被低估的问题：**硬件互联再强，如果通信库不能把这些能力组织成稳定、可组合、可调度的通信语义，超节点的带宽和低时延也很难真正兑现为 Goodput。** 对软件层来说，通信库不是简单的“调用几种 collective”；它实际上承担着把硬件拓扑、并行策略、拥塞状态和同步语义翻译为稳定吞吐的职责。

在超节点中，这个问题比传统集群更尖锐。数据并行、张量并行、流水并行和专家并行会同时存在，集合通信与单边通信也不再是互斥关系，而是分别服务于**规整高吞吐数据流**与**不规整细粒度数据流**。因此，本节沿着“集合通信收益”和“PGAS/SHMEM/单边通信”两条线索展开，并尽可能按原始编号结构组织内容。

## 集合通信语义在超节点上的收益

### 2.2.1 超节点中集合通信的特点

超节点通常指在一个逻辑域内，将大量加速卡通过高带宽、低时延互联紧耦合，使其对上层软件呈现“近似单机”的通信特性与资源管理语义。业界已经出现“256/384 级别”的规模化超节点实例：其一，NVLink Switch System 通过外置二层 NVLink 交换将 NVLink 从单机扩展到多节点，可互联最高 256 GPU，并在文档中被描述为形成“数据中心级 GPU”[^1]；其二，Atlas 900 A3 SuperPoD 可 “pack up to 384 Ascend 910C chips”，并被定位为可协同工作的“单台计算机式”系统[^3]；其三，CloudMatrix384 论文披露该超节点跨 16 个机柜，包含 48 个 Ascend 910C 节点（合计 384 NPU）与 4 个通信机柜（L2 交换）[^5]。

在这样的超节点内部，集合通信不再只是“跨节点 MPI 的一个实现细节”，而是承载了多种并行策略的关键数据路径：例如数据并行/ZeRO/FSDP 典型依赖 `AllReduce`/`ReduceScatter`/`AllGather`；张量并行在层内会频繁触发 `AllReduce`/`AllGather`；MoE 专家并行的 token dispatch/combine 往往抽象为 `AllToAll`/`AllToAllv`；这些原语在超节点尺度上会被反复调用并直接决定迭代时间与尾延迟[^13]。

超节点集合通信与“普通单机/小集群集合通信”的核心区别主要体现在三点。

第一，**互联呈层级化且异构**：同一通信域内同时存在多种链路形态与带宽/时延数量级差异（例如 NVLink/片内互联 vs IB/RoCE；或超节点内 UB 平面 vs RDMA 平面），这使得“单一算法/单一拓扑”难以在全域最优[^14]。

第二，**通信并发与多租户竞争更加常态化**：训练/推理任务在超节点内会出现多通信组（多个 communicator）并发，且通信模式由并行策略决定（DP/TP/PP/EP 混合），导致拥塞与热点不再是“边缘情况”，而是设计前提。阿里云在其数据中心网络论文中指出，通过在集合通信库内部按连接拥塞状态选路，在 512 GPU 上四个 `AllReduce` 并发可提升最高 34.7% [^15][^16]。

第三，**可靠性成为一阶约束**：规模增大使故障频率与故障影响显著提升。来自大规模研究集群的实测显示，1024-GPU 作业 MTTF 仅 7.9 小时，并随规模可预测下降；甚至预测 16,384 GPU 作业 MTTF 约 1.8 小时[^6]。在 Scale-Up 域内，单卡故障会通过并行度结构放大为显著吞吐损失，例如 TP64 下 0.1% 故障可放大至近 10% GPU 吞吐损失[^7]。因此，超节点集合通信必须天然考虑快速检测、隔离、降级与恢复机制，而不仅是“无故障时的峰值带宽”。

基于上述差异，适配超节点集合通信的关键能力可概括为：**分层拓扑感知**、**拥塞避免与可靠容错**、**通信下沉与软硬协同**。

### 2.2.2 超节点拓扑感知与层级算法

“分层拓扑感知”指集合通信库能识别并抽象通信域内的层级结构（卡内/机内/机间/超节点内/跨超节点），并基于层级差异选择或合成合适的逻辑拓扑（ring/tree/分层 ring-tree 组合等），以在不同消息规模与并行策略下接近最优。相关能力不仅包括拓扑发现，也包括**按层划分通信阶段（phase）**、按消息大小切换协议、以及在多层之间进行分片/聚合（aggregation）策略设计[^23]。因为在超节点内部常见“快域 + 慢域”并存：例如 NVLink 域内带宽远高于机间 RDMA，若采用全域 ring，则慢域链路成为迭代瓶颈；而采用层级算法把跨慢域的数据规模压缩到最小（典型为 `1/K` 的缩减），可显著降低跨域时间占比[^24]。

工业库普遍采用多算法并通过拓扑/消息大小进行切换。xCCL 综述在算法模型中给出 ring `AllGather`/`AllReduce` 的代价公式，并指出 `AllReduce ring` 由 `ReduceScatter + AllGather` 两阶段构成[^25]；同时，该综述也明确列出 ACCL 的混合 `AllReduce`：**intra-node ReduceScatter（ring）→ inter-node AllReduce（halving-doubling）→ intra-node AllGather（ring）** [^17]。另一方面，针对“非对称层级/跨超节点卡数不一致”等超节点常见问题，HCCL 的开源文档直接指出其提供 Mesh/Ring/RHD/NHR/NB/AHC/Pipeline 等多种（含层级与非均衡）算法，并用 α–β–γ 模型评估算法耗时[^26]；其中 AHC 文档给出当通信域跨多个层次且层间带宽收敛、甚至分组卡数不一致时的三步流程（分组、组内 `ReduceScatter`、逻辑同号卡组间 `AllReduce`）[^27]。

更进一步，近五年研究趋势是“可编程/可合成”的集合通信：MSCCLang（ASPLOS'23）提出 DSL + 编译/运行时，将自定义 `AllReduce`/`AllToAll` 算法编译为单 CUDA kernel，相对手工实现的性能提升 `AllReduce` 最高 1.9×、`AllToAll` 最高 1.3×，且在 256 A100 训练与线上服务中获得 1.10–1.89× 的加速[^19]。类似方向还包括 NVIDIA[^28]、Microsoft[^29] 和 TACCL。这类方法在超节点上的价值在于：当物理拓扑复杂、同时存在多原语混叠（例如 TP+EP）时，固定的 ring/tree 往往无法覆盖“作业特定最优”，而合成/编译式方案能把拓扑、消息大小、端口数、并行度结构一起纳入搜索/生成空间[^30]。

在超节点场景中，层级 `AllReduce` 常见拆分范式之一是：**（层内）ReduceScatter →（层间）AllReduce →（层内）AllGather** [^19]。这一拆分可用 α–β–γ 模型进行工程化估算，用于指导切分粒度、并行度与协议选择。工程落地通常包含三步：

1. 拓扑发现与分组：识别 NVLink/NVSwitch 域、PCIe 亲和、NIC 归属与 rail 划分。
2. 按消息大小/并行策略选择算法族：ring/tree/RHD/层级 ring-tree 等。
3. 跨层数据分片与聚合：确定 `ReduceScatter` 粒度、是否做 chunk pipeline；并在多 communicator 并发时做资源隔离（channel/stream/QP 配额），避免合成的最优在并发时退化为拥塞[^31]。

层级算法的收益主要体现在“跨慢域的字节数下降”和“跨域同步点减少”。在真实系统中，收益通常随三类因素增大：域内外带宽差距越大（例如 NVLink ≫ IB/RoCE）[^1]；`K` 越大（例如超节点 Scale-Up 域从 8/16 扩到 64/256）[^32]；通信模式越偏“高频小消息”（TP/推理解码）或“高并发多 communicator”（多任务/多租户）[^33]。

![层级 AllReduce 拆分示意](imgs/image5.png)
/// caption
intra-node/inter-node 分层 ReduceScatter 与 AllGather 拆分
///

## All-to-All 性能分析

`AllToAll` 是最能暴露超节点通信问题的原语之一，因为它同时放大了小包抖动、大包拥塞与负载不均。对 MoE、分段推理和稀疏专家路由而言，问题往往不在“总带宽够不够”，而在于流量是否集中打向少量专家或少数链路，导致热点持续堆积。

对稀疏 `AllToAll` 而言，通信库至少需要具备三种能力：一是**拓扑感知分组**，知道哪些路径属于同一快域、哪些必须跨域；二是**消息分片与流水推进**，避免大消息独占链路；三是**路由感知或负载感知调度**，在多个可用 rail、多个 QP 或多个连接之间主动避开热点。对超节点软件栈来说，这类能力决定了高带宽互联能否真正转化为训练和推理系统里的有效吞吐。

### 2.2.3 超节点拥塞避免与可靠容错

超节点规模上去后，拥塞与故障不再是偶发。拥塞方面，超节点同时承载多条通信链（DP 梯度归约、TP 层内交换、EP token shuffle），且多任务并发会把“理论无阻塞拓扑”变成“现实多流拥塞拓扑”[^35]。故障方面，作业 MTTF 随规模快速下降：1024 GPU 作业 MTTF 7.9 小时；并预测 16,384 GPU 作业 MTTF 1.8 小时[^6]。对推理/训练系统而言，这意味着“默认重启”会造成显著的 GPU-hours 浪费与尾部 SLO 违约风险。

这就要求超节点的集合通信拥有两类紧耦合能力：

1. **拥塞感知的路径/rail 调度**：在多 NIC、多 rail、甚至多 QP 的物理条件下，集合通信库能够对流量进行条带化（striping）、避堵（hotspot avoidance），并进行组间公平（inter-communicator fairness）。
2. **面向故障的持续运行（resilience）**：当链路抖动、NIC 故障、超时发生时，通信层能够快速检测并把故障影响从“全局 abort + 重启”缩小为“局部迁移/降级/重构”，对训练 goodput 与推理尾延迟提供可解释的上界。

在拥塞调度上，阿里云 HPN 论文给出“在集合通信库内部”进行拥塞感知选路的实例：利用连接的 Work Queue Elements（WQE）计数器作为拥塞信号，选择最不拥塞连接发送；在 512 GPU 上四个 `AllReduce` 任务并发时，性能可提升最高 34.7% [^15]。在故障容错上，R²CCL（2026）指出在大规模 ML 训练/推理中，网络故障可因恢复慢而浪费 10–15% 的 GPU hours，并提出利用 multi-NIC 冗余进行快速连接迁移、带宽感知重分配与弹性集合算法[^36]。其机制包括：OOB 通知与探针定位将检测时间从分钟降到毫秒量级、DMA-buffer rollback 支持无损重传、以及在 512 GPU 仿真中故障数从 1 到 10 时迭代开销仅从 1.5% 增到 4.3%（sub-linear）[^37][^38]。此外，训练系统层面的“故障放大”也必须被通信层理解：NTP 研究指出在 TP64 规模下，0.1% GPU 故障可导致近 10% GPU 无效产出，并提出在失败发生后把 TP 度降低以把吞吐损失压到接近“故障比例”[^7]。它直接说明“超节点集合通信的并行组结构（TP/DP 映射）”与可靠性是强耦合问题。

拥塞感知 multi-rail 的工程要点可拆为四层：

1. **GPU-NIC 亲和与 rail 绑定**：确保通信线程块/通信 stream 与具体 NIC/rail 的映射稳定可控，避免流量“随机落点”导致热点[^39]。
2. **条带化与多 QP 并行**：将大消息切分为 chunk，在多 rail 上并发推进，并维持 per-rail completion/credit 机制；该层通常直接决定峰值带宽是否可达[^40]。
3. **拥塞信号与在线选路/调度**：引入低开销拥塞信号（如 WQE drain rate），并在通信库内部进行“每次发送的连接选择”；对多 communicator 并发，还需要“全局公平/优先级”概念，否则单 communicator 的局部最优会转化为系统层面更糟的拥塞[^15][^41]。
4. **故障检测、隔离与无损迁移**：快速检测（OOB 通知 + RDMA probe）[^42]、无损迁移（multi-NIC 注册 + DMA rollback）[^43]、算法重构（快速剔除故障边并必要时降级到带宽较低但可持续的拓扑），以及面向框架提供“可恢复错误语义”。

在现有生态中，通信错误处理往往以 “abort communicator” 为主。例如 PyTorch 文档指出启用 NCCL 异步错误处理后，collective 会被异步 abort 且进程崩溃；blocking wait 可把错误返回给用户但会有性能开销[^44]。这进一步说明超节点需要“通信层 + 系统层”的联合容错方案，而不仅是库级别的错误码。拥塞调度的收益往往以“并发场景提升”体现（如 34.7%）[^15]；容错收益则以“避免全局重启与 checkpoint I/O”体现。R²CCL 的核心价值在于把训练/推理从“故障→重启→重放/恢复”变成“故障→迁移→继续”的快速路径，从而避免 10–15% GPU-hours 的浪费[^45]。

![双 ToR 冗余与故障切换示意](imgs/image8.png)
/// caption
stacked / non-stacked dual-ToR 场景下的数据面与控制面切换
///

### 2.2.4 超节点通信下沉与软硬协同

“通信卸载”指将集合通信的部分数据搬运、规约计算或进度推进从 CPU 甚至 GPU SM 上移出，交由网络交换芯片、SmartNIC/DPU、专用 DMA/Copy Engine 或交换侧计算单元执行，以减少端侧介入、降低同步成本并提升规模稳定性。在超节点尺度上，端侧（CPU/GPU）承担全部集合通信进度不仅带来额外计算开销，更引入系统噪声和尾延迟抖动；且当并发通信组增多时，端侧线程/核的抖动会放大为全局 barrier 的尾部。硬件卸载的关键价值在于降低“需要全局一致的同步点”对系统噪声的敏感性[^48]。

这里主要涉及两个方向。

其一，**网络内规约（in-network reduction）**。SHARP 官方文档说明其通过把集合操作从 CPU/GPU 卸载到网络并减少数据在网络中的重复穿越，从而 “dramatically reduces collective operations time” [^49]。在 Frontera 全系统规模（7,861 nodes）评测中，基于 SHARP 的设计使 `AllReduce` 延迟最多降低 5.1×（同时 `Reduce` 5.4×、`Barrier` 7.1×）[^21]。NCCL 的 release notes 明确列出 “inter-node algorithms for NVLink SHARP: NVLS、NVLSTREE” [^22]。云上实测也开始公开：Azure HPC 博文在单节点上报告 NVLS 模式 16GB `AllReduce` 的 BusBw 可达 481.42 GB/s，并将其归因于 NVLink SHARP（在 NVSwitch 上卸载算术以减少数据传输）[^50]。

其二，**SmartNIC/DPU 卸载**。DOCA DPA All-to-all guide 给出 DPA 加速 `all-to-all` 的参考实现，并明确“由 DPA 线程执行 `all-to-all`，CPU free”[^51]。UCC 的 DOCA UROM 示例同样展示将 UCC `all-to-all` 卸载到 DPU 侧 progress queues/threads[^52]。研究上，针对 multicast-based `Broadcast/AllGather` 的工作展示了将 collective progress engine 卸载到 DPA：DPA 由 16 个 RISC-V 核、每核 16 硬件线程构成，并可在 DPA kernel 中发起 RDMA 与 Atomic[^53]；在其实验中，DPA 单线程 UC 接收路径吞吐达 11.9 GiB/s，且 128 线程可支撑等效 1600 Gbit/s 的 chunk 处理率（用于推演下一代 Tb/s 链路）[^54]。

通信卸载的实现模式常见三类：

1. **网络内汇聚树（aggregation tree）**：把规约算子放到交换侧（如 SHARP aggregation node），并通过树形汇聚减少网络中重复转发；优点是延迟/带宽随规模更平滑，缺点是对交换能力与数据类型/算子支持有约束[^48]。
2. **域内交换卸载（NVLink SHARP/NVLS）**：把域内规约放到 NVSwitch 等交换侧硬件，从而在 GPU 间传输的同时完成规约，减少 GPU 端搬运与规约次数；该类通常与库的算法选择（NVLS vs Tree）共同决定收益与适用消息区间[^55]。
3. **SmartNIC/DPU 进度卸载**：把拆包/重组/重传等“低 IPC 的数据搬运逻辑”放到 DPA/DPU 线程，利用硬件多线程隐藏 load/store 延迟，并通过 DMA engine 与 CQ 事件驱动推进；该类适配面广（不仅限 reduction），但需要处理一致性、缓冲区注册以及与主通信库的协同[^56]。

通信卸载与软硬协同的收益常以“延迟倍数下降 / CPU 占用下降 / 尾延迟收敛”呈现：SHARP 在全系统规模 `AllReduce` 延迟可降 5.1× [^21]；NVLS 在单节点 16GB `AllReduce` 上体现了域内卸载的峰值潜力[^50]；DPA 卸载则展示了在极高速链路下以少量 DPA 线程支撑线速的可能性[^57]。

![传统归约与 NVIDIA SHARP 对比](imgs/image9.png)
/// caption
传统路径与 SHARP in-network computing 的对比
///

![BlueField-3 上的 multicast / allgather 卸载示意](imgs/image10.png)
/// caption
DPU / Datapath Accelerator 参与集合通信进度推进
///

![SHARP 聚合树示意](imgs/image11.png)
/// caption
物理拓扑与单棵 SHARP tree 的映射
///

### 小结

超节点集合通信的收益可概括为三项：**分层拓扑感知**解决“层级不均质导致的慢链路与热点”；**拥塞避免和可靠容错**解决“规模化下的拥塞与尾延迟”以及“系统可用性”；**通信下沉与卸载**解决“CPU/GPU 参与通信的结构性开销”[^26]。

其主要局限也同样明确：其一，**自动调优 / 故障恢复仍有工程门槛**，拓扑-协议组合复杂，可能出现性能退化甚至正确性风险[^8][^14]；其二，**算法选择与调度往往是“库内局部最优”**，与系统级多租户调度仍存在 gap；其三，**通信卸载会把“跨原语/跨阶段”的更深度优化推到台前**，这正是下一部分 PGAS/SHMEM/单边通信要解决的语义基座与工程边界问题。

## PGAS 内存模型与单边通信

### 2.3.1 超节点中的 PGAS & SHMEM

分区全局地址空间（Partitioned Global Address Space）是一类并行编程与运行时模型：把分布式系统中的内存视为“全局可寻址空间”，但同时承认每个处理单元对其本地分区具有更低延迟/更高带宽。其中，全局意味着从任何一个 PE 的角度来看，它都可以访问这个地址空间中的任何位置，就好像在访问一个巨大的、统一的内存池一样。分区意味着这个全局地址空间在物理上是分散的，每个 PE “拥有”并管理其中的一部分（即它自己的对称堆）。OpenSHMEM 是 PGAS 路线中最常用的标准之一，其核心概念是**对称对象（symmetric objects）**与**对称堆（symmetric heap）**，并围绕 `put/get`、原子操作以及同步/完成语义提供 API 规范。

超节点通信之所以会涉及 PGAS/SHMEM/单边通信，原因不是“它能替代 collectives”，而是：在超节点里存在大量**非规整、细粒度、强依赖链**的数据流（典型如 MoE token routing、KV Cache 分发/聚合、稀疏更新、异步流水），这类模式用 `AllReduce/AllToAll` 等标准 collectives 表达并不总是自然且高效；相反，“发起方单边 `put/get` + 显式信号同步”的方式能把控制面简化，并更容易进入 GPU kernel 融合。

在超节点场景中，引入 PGAS/SHMEM/单边通信的动机通常不止“写起来像共享内存”，而是三点系统性需求：

1. **更细粒度、可组合的通信原语**：集合通信擅长固定模式，但当应用要跨阶段/跨并行组组织数据流（例如推理中的 KV Cache 迁移、MoE 动态分派、跨层流水）时，单边 `put/get + signal/AMO` 往往更易把通信嵌入算子和调度器[^66]。
2. **设备端发起（kernel 内）与异步任务化**：超节点追求把通信推进从 CPU 控制路径中剥离，使其像“设备侧异步任务”一样与计算并行。Triton-distributed 明确引入 `symmetric memory`、`signal exchange`、`async-task` 作为核心概念，并展示在每个 rank 同时并行运行 inter-node P2P、intra-node P2P 与 compute[^67][^68][^69]。
3. **资源池化（尤其推理 KV Cache）**：超节点推理系统常出现“prefill 与 decode 分离、KV Cache 迁移、历史上下文复用”等需求。CloudMatrix384 论文给出一条清晰的数据路径：prefill 完成后通过 RDMA 平面把完整 KV Cache 迁移到 decode 节点，并把 KV Cache 转移与 decode 平面通信隔离；同时，“Context Caching”通过一个分布式存储库组织 paged KV blocks，供所有 NPUs 访问与复用，并给出 UB 平面可将 prefill 吞吐提升至 1.52×、TTFT 随复用率显著下降等数据点[^9]。这些机制在抽象上与“全局地址 / 全局内存池”的 PGAS 目标高度一致。

![对称堆 / registered buffer 示意](imgs/image12.png)
/// caption
NVSHMEM 风格的 symmetric heap 与 registered buffer 关系
///

![Attention node 与 Expert node 间的 M2N / N2M 数据流](imgs/image13.png)
/// caption
MoE / KV Cache 场景中的跨节点数据流组织
///

### 2.3.2 对称内存与全局地址

对称堆 / 对称对象要求：各处理单元以一致方式分配一段“对称存在”的内存区域，使得同一对象在各 PE 上的地址计算具有一致性，从而支持“远端可寻址”的 `put/get` 等单边操作。对称堆管理及相关约束在 OpenSHMEM 规范中有明确定义[^5]。在设备侧发起、融合算子与细粒度通信中，“对象定位”不能完全依赖 host 控制面反复分发元数据；对称堆提供了一个稳定的、可缓存的对象寻址基础，使 kernel 内的通信可以更少依赖 CPU 协调。这也是 NVSHMEM、rocSHMEM、Intel SHMEM 都围绕“对称堆在加速器内存上”组织 API 的原因之一[^32]。

下图给出了 SHMEM 的内存模型与构建过程。其核心链路可以概括为三步：

1. `UVA`：runtime 提供统一虚拟地址供上层使用，SHMEM 通过 API 预留 VA。
2. `UVA -> PGAS`：SHMEM 将预留 VA 绑定本卡 / 远端卡物理内存，构造对称堆。
3. `PGAS Usage`：SHMEM 保存 `base[PE]`，通过 `malloc` 获取对称堆内空间，再通过对称地址做 `put/get`。

![UVA 到 PGAS 的地址构建示意](imgs/image15.png)
/// caption
UVA、各 PE 物理地址空间与 PGAS 之间的映射关系
///

需要注意的是，UVA 能够支撑 SHMEM 更好地构建（简化地址管理和控制面交互），但并非一定需要 UVA 才能构建 SHMEM。此外，构建 Host+device 的 UVA 同样能更好支持统一寻址与资源池化，但 SHMEM 也可以通过自行管理对称堆地址来实现类似功能。而对称内存模型的引入，使得算子的开发变得更加易用与高效。下面是一个最小单边通信示例：

```cpp
#include <stdio.h>
#include <shmem.h>

int main(void) {
    shmem_init();
    int me = shmem_my_pe();
    int npes = shmem_n_pes();

    int *target = (int *) shmem_malloc(sizeof(int));
    *target = -1;

    int my_value = me;
    int right = (me + 1) % npes;

    // one-sided put：右邻居无需配对 recv
    shmem_int_p(target, my_value, right);

    shmem_barrier_all();
    printf("PE %d: target = %d\n", me, *target);

    shmem_free(target);
    shmem_finalize();
    return 0;
}
```

简单来说，SHMEM 对称堆提供的是“全局对象寻址的约束”，收益主要体现在：减少地址交换与元数据同步（尤其在 kernel-initiated 模式下）；使 PGAS 原语可直接映射到硬件能力（GPUDirect RDMA、GPU-fabric 原语等），降低控制面复杂度；为 UCC 这类 “one-sided collectives” 映射提供基础[^9]。对称堆不是性能优化本身，而是“让单边通信与设备侧融合可工程化”的前提。

### 2.3.3 单边访存与原子操作

`put/get` 将数据移动变成“发起方单边操作”：发起方把本地数据写入远端对称对象（`put`）或从远端读取（`get`），不要求远端同步参与一次配对发送 / 接收；原子操作则提供跨 PE 的计数、标志与轻量同步。NVSHMEM 官方文档将 signaling operations 定义为“更新远端 flag，并与 `wait/test` 配合提供高效点对点同步”[^79]；AMO 则分为 fetching 与 non-fetching 两类，并指出 non-fetching 原子可通过 `quiet/barrier` 强制完成[^75]。

普通的集合通信适合规整同步的数据流；但超节点训练 / 推理中存在大量“非规整数据面 + 规整计算核”的组合：例如 MoE 的 token 路由可以看成“按专家 sparse scatter/gather”；KV Cache 的搬运也常是点对点 / 一对多的分发。对这类模式，`put/get` 作为数据面，一方面能降低“收发双方协商”的控制复杂度（特别是当发起方已知目标远端对象位置时），另一方面更容易与 `signal/wait` 组合成轻量同步，从而在 kernel 内形成可融合的流水[^80]。Triton-distributed 将 OpenSHMEM 原语集成到编译器与 Python 侧，并用信号构造异步任务；其总体加速范围可达 1.09×–44.97×（相对 PyTorch+NCCL/RCCL），其中包含推理低时延 `AllToAll` dispatch/combine 等通信算子[^82][^83]。

在实现上，SHMEM 往往会同时支持 Scale-Up 域和 Scale-Out 域的单边访存与原子操作。以 C2C 和 RDMA 为例，两者的差异在于：Scale-Up 域内部实现一般基于 GPU 的 `Load/Store` 语义（如 NVLink 域内数据搬运），而 Scale-Out 域则是 GPU 触发的 RDMA `Read/Write`（如 IBGDA）。二者统一由 SHMEM 封装，从而向上层提供一致的 `put/get/AMO` 能力，只是在作用于不同域时，自适应或指定不同的底层物理链路。

![Scale-Up 域单边通信流程示意](imgs/image17.png)
/// caption
基于本地拓扑信息与 heap 管理的 Scale-Up 域 put/get 流程
///

![Scale-Out 域单边通信流程示意](imgs/image18.png)
/// caption
基于 RDMA 注册信息与 QP 的 Scale-Out 域 put/get 流程
///

下面给出一个 KV Cache 场景下的 M:N 通信算子，用来说明 SHMEM 在编写此类稀疏通信算子时的高性能与高易用性：

```cpp
/*
 * KV Cache M:N Disaggregated Transfer (Prefill -> Decode)
 * 核心机制：
 * 1) 1 个 kernel 内并发对多个 Decode PE 做 PUT
 * 2) GPU 直接发起（零 CPU 参与数据面），控制面不需要交互 KV 地址
 * 3) PUT 完成后用 signal 通知，Decode 侧用 wait 阻塞等待
 */
#include "ptshmem.h"

#define NUM_PREFILL_PES 1
#define NUM_DECODE_PES 3
#define KV_SIZE (/* bytes per decode */)

__global__ void prefill_m2n_kernel(const uint8_t *local_kv,
                                   void *kv_sym,
                                   uint32_t *flags,
                                   int num_decode) {
    const int lane = (int)blockIdx.x;
    if (lane >= num_decode) return;

    const int target_pe = NUM_PREFILL_PES + lane;
    const uint8_t *src = local_kv + (size_t)lane * (size_t)KV_SIZE;

    ptshmem_putmem_block_d(target_pe, kv_sym, src, KV_SIZE);

    if (threadIdx.x == 0) {
        ptshmem_signal_u32_d(target_pe, &flags[lane], 1);
    }
}

__global__ void decode_wait_kernel(uint32_t *my_flag) {
    if (threadIdx.x == 0) ptshmem_wait_until_eq_u32_d(my_flag, 1);
    __syncthreads();
    // 就绪后启动 flash_attention 等计算...
}
```

单边访存与原子操作的收益在于：

1. **细粒度语义**：把“数据移动”与“同步完成”解耦，允许更松散的开始 / 完成同步。将同步从“collective 完成点”细化到“tile/chunk 完成点”能显著提高 overlap 上限，更容易构建 producer-consumer 流水[^82]。
2. **高效率工程**：为 GPU-initiated 与融合提供接口点，把“通信启动时机”绑定到 GPU stream / 调度器，而不是 host 线程。GPU-initiated 通信能减少 kernel launches、CUDA API 调用与 CPU-GPU 同步带来的开销[^33]。

`put/get + AMO` 把复杂通信模式的“控制面”显式化，有利于超节点内部的融合与异步；但需要注意一致性与内存序要求（例如 `fence/quiet` 或等价机制），工程上最容易踩的坑是“弱一致性 + stream 语义 + 进度保证”。NVSHMEM 的 CUDA interactions 文档给出典型死锁案例：若一个 PE 在 barrier 阻塞而另一个 PE 等待 signal，且 signal 的 put-with-signal 被 barrier 阻塞，则双方无法前进[^84]。

### 2.3.4 通算融合与超级算子

“通算融合”在此特指把通信语义嵌入算子或 kernel，以减少 kernel launch 边界与全局同步点，实现通信与计算在更细粒度（tile/chunk）上的交错；“超算子（super operator）”则强调跨多个通信原语（甚至跨网络平面 / 层级）组合成端到端数据流的能力（例如 `EP dispatch -> expert GEMM -> combine`，或 `prefill -> KV transfer -> decode`）。

超节点场景下追求的不是“某一个 collective 的峰值带宽”，而是端到端训练 / 推理的迭代时间与尾延迟。当通信比例升高（大模型、TP/EP 增多）时，仅靠库内 ring/tree 切换往往不足，需要把通信与算子形态协同设计（如把 `ReduceScatter` 或 `AllGather` 的分片与 GEMM tile 对齐）[^60]。

这也是业界当前发展的重要方向：

1. NCCL 官方文档明确其以“单 kernel”实现 collective，把通信与计算放在同一 kernel 中以降低同步与资源开销[^72]。
2. Triton-distributed 报告在多类 workload 上相对 PyTorch+NCCL/RCCL 加速 1.09×–44.97×，并在 `AG+GEMM`、`GEMM+RS` 上给出平均 1.42×（相对 PyTorch+NCCL）等结果[^82]。
3. Flux 提出通过 kernel fusion 细粒度隐藏通信，可在融合 kernel 中 overlap 最高 96% 的通信，并报告在 128 GPU 训练上最高 1.24× 提升、推理 prefill/decoding 上最高 1.66× / 1.30× [^86]。
4. Ascend 提出 `MoeDistributeDispatch` 和 `MoeDistributeCombine` 两个通算融合算子技术：将计算和传输拆解为 token 粒度的计算单位，通过流水排布实现通信和计算并行执行。

![通信 / 计算 / signal exchange 的异步任务化示意](imgs/image16.png)
/// caption
symmetric memory 与 signal exchange 组织的异步任务模型
///

![producer GEMM、local reduction 与 p2p kernel 的并行流水](imgs/image19.png)
/// caption
多 stream 下的通算重叠执行
///

下面给出一个 `AllGather + GEMM` 融合算子示例，说明 SHMEM 在通信计算重叠上的优势：

```cpp
/*
 * AllGather + GEMM 融合算子（一机 4 卡）
 * 核心机制：
 * 1) 单 kernel 融合：通信 blocks 与计算 blocks 在同一 kernel 并发执行
 * 2) 对称堆免交换：gather 缓冲用 ptshmem_malloc，所有 PE 对称
 * 3) 天然重叠：一块数据通信就绪即开始计算
 */
__global__ void fused_allgather_gemm(const float* B, float* C, float* gather,
                                     volatile uint32_t* flags,
                                     int npes, int me, int m_local, int k, int n) {
    int comm_blocks = npes - 1;
    bool is_comm = blockIdx.x < comm_blocks;

    if (is_comm) {
        int peer = blockIdx.x;
        float* my_data = gather + me * m_local * k;
        ptshmem_putmem_block_d(peer, my_data, my_data, m_local * k * sizeof(float));
        if (threadIdx.x == 0) ptshmem_signal_u32_d(peer, &flags[me], 1);
    } else {
        for (int src = 0; src < npes; ++src) {
            if (threadIdx.x == 0) ptshmem_wait_until_eq_u32_d(&flags[src], 1);
            __syncthreads();
            for (int row = blockIdx.x - comm_blocks; row < m_local; row += gridDim.x - comm_blocks) {
                float* Arow = gather + src * m_local * k + row * k;
                for (int j = threadIdx.x; j < n; j += blockDim.x) {
                    float acc = 0.f;
                    for (int kk = 0; kk < k; ++kk) acc += Arow[kk] * B[kk * n + j];
                    C[(src * m_local + row) * n + j] = acc;
                }
            }
        }
    }
}
```

![AllGather + GEMM 融合流水示意](imgs/image20.png)
/// caption
本地数据计算、分阶段 gather 与计算重叠
///

在真正的项目实现层面，需要注意三点：其一，通信分片粒度（dispatch/combine chunk）与算子 tile 对齐；其二，执行资源隔离（Copy Engine / DMA vs SM）避免互相抢占；其三，同步机制从全局 barrier 下沉到 `signal/wait/AMO`。Triton-distributed 的实现明确采用“在 host 侧分配 symmetric memory，并把通信部分与计算部分放到不同 stream；在 GEMM kernel 内用 `wait/consume_token` 建立依赖”的方式，以达到“计算不等待通信”的效果[^80]。

## SPMD/BSP vs PGAS/单边通信

| 特性 | SPMD + 集合通信（BSP） | PGAS + 单边通信 |
| --- | --- | --- |
| 通信模式 | 双边或集合式，强调阶段性同步 | 单边 `Put/Get/Atomic`，强调异步解耦 |
| 同步边界 | 通常是 communicator 级、阶段级 | 可以缩小到对象级、chunk 级、信号级 |
| 性能风险 | Straggler 放大，屏障拖累长尾 | 需要自行管理一致性与完成语义 |
| 优势场景 | 稠密训练、规整归约、负载较均匀 | MoE、长序列推理、KV Cache 迁移、异步流水 |
| 软件要求 | 高质量 collective 算法与拓扑调优 | 对称内存、完成通知、设备侧发起与运行时进度机制 |

从系统设计角度看，真正重要的问题不是“选哪一种”，而是**哪些数据流适合留在集合通信里，哪些应该下沉到单边语义里。** 超节点的软件竞争力，很大程度上就体现在这条边界划分是否合理。

## 小结

PGAS/SHMEM/单边通信在超节点中的核心价值不是替代集合通信，而是提供“更细粒度、更可组合、更易嵌入算子与调度器”的通信语义：对称堆 / 全局地址降低远端数据结构的寻址与管理成本；`signal/wait/AMO` 支撑异步任务化与细粒度同步；通算融合与超算子把通信与算子的边界向内收缩，从而提升端到端效率。

未来，PGAS/SHMEM 与 CCL 的演进边界大致包括三条：

1. 把 one-sided 与 collectives 统一到同一运行时资源模型（如 UCC 的 one-sided collectives / 资源抽象）[^38]。
2. 把通信-计算联合优化进一步推向编译器 / DSL（如 Triton-distributed）。
3. 在 Scale-Out 侧引入更强的硬件 offload 与 multicast（如 SHARP 及相关方向）。

## 待补充

- [ ] 将当前脚注补全为完整书目信息。
- [ ] 将尚未完整保留的公式部分，补为可渲染的 LaTeX / MathJax。
- [ ] 视排版效果进一步精简或分拆图片密度。

[^1]: NVLink Switch System 相关公开资料，用于 256 GPU 级超节点规模、层级带宽差异等论述。
[^3]: Atlas 900 A3 SuperPoD 相关公开资料，用于 384 芯片级超节点实例描述。
[^5]: CloudMatrix384 / OpenSHMEM 相关材料；在正文中分别用于超节点实例与对称堆规范来源。
[^6]: 大规模 GPU 作业 MTTF 研究，用于 1024/16384 GPU 规模下可靠性分析。
[^7]: 并行度结构下的故障放大研究，用于 TP64 故障对吞吐影响的分析。
[^8]: 自动调优、故障恢复或通信正确性风险相关研究，用于当前方案局限性说明。
[^9]: CloudMatrix384 / UCC 相关材料，用于 KV Cache 池化与 one-sided collectives 语义映射说明。
[^13]: 超节点中数据并行、张量并行、专家并行与集合通信关系的背景材料。
[^14]: 层级异构互联与算法鲁棒性相关材料，用于“单一算法难以全域最优”的论证。
[^15]: 阿里云 HPN 论文，用于拥塞感知选路及 34.7% 并发收益数据。
[^16]: 阿里云相关补充资料，与 HPN 论文共同支撑并发拥塞论述。
[^17]: ACCL 混合 AllReduce 结构材料。
[^19]: MSCCLang（ASPLOS 2023）及其层级/合成式集合通信结果。
[^21]: SHARP 在 Frontera 全系统规模上的评测结果。
[^22]: NCCL release notes 中 NVLS / NVLSTREE 相关说明。
[^23]: 分层拓扑感知、phase 划分与 aggregation 设计相关综述或论文。
[^24]: 通过压缩跨慢域字节量降低跨域时间占比的层级算法分析。
[^25]: xCCL 综述，用于 ring AllGather / AllReduce 代价模型。
[^26]: HCCL 开源文档，用于算法家族与总结构成说明。
[^27]: AHC 算法文档，用于非均衡 / 跨层通信三步流程说明。
[^28]: NVIDIA 在可编程 / 可合成集合通信方向的相关资料。
[^29]: Microsoft 在集合通信合成或编译式优化方向的相关资料。
[^30]: 将拓扑、消息大小、并行度纳入搜索空间的可合成集合通信研究。
[^31]: 多 communicator 并发时的资源隔离与拥塞退化相关研究。
[^32]: 超节点规模扩展或 SHMEM / 对称堆生态资料，用于 K 扩大收益与 API 生态说明。
[^33]: 高频小消息 / GPU-initiated 通信收益相关材料。
[^35]: 超节点多流拥塞与理论无阻塞拓扑失配的相关研究。
[^36]: R²CCL（2026）关于弹性集合通信与快速迁移的研究。
[^37]: R²CCL 中 OOB 通知、探针定位或 DMA rollback 相关实验数据。
[^38]: R²CCL / UCC 资源抽象相关材料，用于弹性恢复或 one-sided 统一运行时说明。
[^39]: GPU-NIC 亲和与 rail 绑定相关工程实践。
[^40]: 多 QP 并行、chunk 条带化与 completion / credit 机制相关材料。
[^41]: 多 communicator 全局公平、优先级与 GPU 利用率相关研究。
[^42]: OOB 通知与 RDMA probe 快速检测相关资料。
[^43]: multi-NIC 注册与 DMA rollback 无损迁移相关资料。
[^44]: PyTorch / NCCL 异步错误处理相关官方文档。
[^45]: 通信层快速迁移减少 GPU-hours 浪费的成本分析。
[^48]: 通信卸载、aggregation tree 与同步噪声相关基础材料。
[^49]: SHARP 官方文档。
[^50]: Azure HPC 关于 NVLS 模式 BusBw 的实测博文或公开材料。
[^51]: DOCA DPA all-to-all guide。
[^52]: UCC 的 DOCA UROM 示例。
[^53]: DPA 线程 / 核心架构与 RDMA、Atomic 能力相关研究。
[^54]: DPA 单线程吞吐与 128 线程 chunk 处理率实验数据。
[^55]: NVLink SHARP / NVLS 与算法选择相关材料。
[^56]: SmartNIC / DPU progress engine、一致性与缓冲区注册协同相关资料。
[^57]: 通信卸载在高速链路下的线速潜力与尾延迟收益分析。
[^60]: 将 collective 分片与 GEMM tile 对齐的通算协同设计相关资料。
[^66]: 单边 put/get + signal/AMO 在跨阶段数据流中的应用材料。
[^67]: [triton-dist.language — Triton-distributed documentation](https://triton-distributed.readthedocs.io/en/latest/python-api/triton-dist.language.html)；其中 `symm_at()`、`nvshmem_create_tensor()` 等接口用于对称内存与 symmetric memory 编程。
[^68]: [triton-dist.language — Triton-distributed documentation](https://triton-distributed.readthedocs.io/en/latest/python-api/triton-dist.language.html)；其中 `notify()`、`wait()`、`consume_token()` 等接口对应文中的 signal exchange 语义。
[^69]: Zheng, S. et al. [Triton-distributed: Programming Overlapping Kernels on Distributed AI Systems with the Triton Compiler](https://arxiv.org/abs/2504.19442), arXiv:2504.19442, 2025.
[^72]: NCCL 官方关于 single-kernel collective 的说明。
[^75]: NVSHMEM / SHMEM 中 non-fetching AMO 与 quiet / barrier 语义说明。
[^79]: NVSHMEM signaling operations 官方文档。
[^80]: [triton-dist.language — Triton-distributed documentation](https://triton-distributed.readthedocs.io/en/latest/python-api/triton-dist.language.html)；`wait()` 返回 token，`consume_token()` 保证与等待操作的顺序关系，`notify()` 提供远端信号通知。
[^82]: Zheng, S. et al. [Triton-distributed: Programming Overlapping Kernels on Distributed AI Systems with the Triton Compiler](https://arxiv.org/abs/2504.19442), arXiv:2504.19442, 2025.
[^83]: Zheng, S. et al. [Triton-distributed: Programming Overlapping Kernels on Distributed AI Systems with the Triton Compiler](https://arxiv.org/abs/2504.19442), arXiv:2504.19442, 2025.
[^84]: NVSHMEM CUDA interactions 文档中的死锁案例。
[^86]: Flux 关于 kernel fusion 与通信隐藏的结果。
