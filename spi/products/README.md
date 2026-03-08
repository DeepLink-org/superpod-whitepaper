# SPI Products

此目录用于存放厂商提交的 SPI 产品文件。

建议结构：

```text
spi/products/
├── vendor-a/
│   ├── product-a.yaml
│   └── product-b.yaml
└── vendor-b/
    └── product-c.yaml
```

每个产品一个 YAML 文件，文件内容请基于 `spi/templates/product-template.yaml` 填写。

## 约定

- 厂商通过 GitHub Pull Request 新增或更新本目录内容。
- 厂商只填写 `vendor_submission` 区块。
- `committee_assessment` 由编写委员会维护。
