# 探索构型（大环路 + 分布式 dOCS）

dOCS（distributed Optical Circuit Switching）模块：指将光电路交换（OCS）能力分布式集成到可插拔光模块内部的互连器件，使单个光模块同时具备：

- 高速光互连传输（光模块基本功能）
- 线路级/通道级的动态交换与重构能力（OCS 功能）

该范式在SIGCOMM 2025 《InfiniteHBD: Building Datacenter-Scale High-Bandwidth Domain for LLM with Optical Circuit Switching Transceivers》论文中首次被明确提出并命名为 transceiver-centric HBD architecture：在收发器层统一"连接 + 动态交换"，而不是"收发器点到点 + 依赖集中式交换机做动态交换"。

## 核心技术

光互连光交换dOCS超节点方案基于分布式光交换芯片与光互连网络架构，其核心技术包括：

**（1）基于硅光的光互连光交换dOCS芯片**：传统OCS技术一般采用MEMS或者DLC等技术，dOCS芯片采用硅光技术，可利用成熟的CMOS工艺，实现更小的尺寸、更低的成本、更高的可靠性。

**（2）全光互连光交换替代电互连电交换**：传统Scale-up网络依赖电交换机（如PCIe或以太网交换机），受限于铜线传输的距离与包交换带来的延迟限制。而光互连光交换dOCS芯片，通过光信号直接传输数据，突破传统电互连的物理带宽与延迟瓶颈。并且由于无包交换处理，链路传输延迟得到大幅降低。

**（3）分布式光交换拓扑**：通过部署多颗光互连光交换dOCS芯片（每颗芯片支持多路光信号交换），构建可扩展的光交换网络。例如，32卡超节点通过100多颗分布式光互连芯片互连，形成灵活的拓扑结构。
