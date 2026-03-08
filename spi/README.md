# SuperPod Pareto Index

`SuperPod Pareto Index (SPI)` 是面向超节点产品的开放式提交与委员会评估框架。

SPI 在当前仓库中采用两层结构：

- `SPI Registry`：厂商通过 GitHub Pull Request 提交标准化产品信息，形成可追踪的产品名录。
- `SPI Scorecard`：编写委员会基于白皮书现有七维框架，对产品进行统一评分并生成雷达图。

## 目录结构

```text
spi/
├── README.md
├── products/
│   └── README.md
├── schema/
│   └── spi-product.schema.json
└── templates/
    └── product-template.yaml
```

## 提交流程

1. 厂商 fork 仓库并新建分支。
2. 复制 `spi/templates/product-template.yaml`，在 `spi/products/<vendor-id>/<product-id>.yaml` 下新增或更新产品文件。
3. 按模板填写 `vendor_submission` 区块，并附上有实验支撑的客观数字与证据链接。
4. 通过 GitHub Pull Request 提交。
5. 编写委员会 review 后，在 `committee_assessment` 区块给出评分、评语和版本信息。

## 基本原则

- 厂商可以提交 `spec`、客观数字和解释性说明。
- 厂商提交的客观数字必须说明测试条件；缺乏支撑时，仅作为厂商声明展示。
- 最终雷达图与七维评分由编写委员会给出。
- 厂商在更新产品信息时，不应修改 `committee_assessment` 区块。

## 命名约定

- `vendor-id`：建议使用小写短横线形式，例如 `shlab`、`nvidia`、`huawei`
- `product-id`：建议使用小写短横线形式，例如 `nvl72`、`cloudmatrix-384`

## 七维评分

SPI 当前沿用白皮书中的七维框架：

1. 单跳/访存延迟
2. 规模上限
3. 拓扑弹性
4. 生态成熟度
5. 功耗与 TCO
6. 软件复杂度
7. 适用负载

其中前六项建议采用 1-5 分制，`适用负载` 以标签和评语为主。
