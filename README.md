# SuperPod 技术白皮书

分布式 AI 推理加速架构技术白皮书，使用 [MkDocs](https://www.mkdocs.org/) 和 [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) 构建。

## 快速开始

### 安装依赖

```bash
# 使用 pip
pip install mkdocs mkdocs-material mkdocs-material-extensions jieba

# 或使用 uv
uv pip install -r pyproject.toml
```

### 本地预览

```bash
make serve
# 或
mkdocs serve
```

然后在浏览器中打开 http://127.0.0.1:8000

## 字体（中文排版）

本项目采用**自托管字体**以获得更正式的中文排版效果：

- **正文**：思源宋体 Regular（`Source Han Serif SC`）
- **标题**：思源黑体 Bold（`Source Han Sans SC`）
- **代码**：思源黑体 Medium（等宽版本，`Source Han Sans Mono SC`；若缺失会回退到常见等宽字体）

请将字体文件（推荐 `.woff2`）放到 `src/assets/fonts/`。默认约定文件名如下（如需改名，请同步修改 `src/assets/stylesheets/custom.css` 顶部的 `@font-face`）：  

- `src/assets/fonts/SourceHanSerifSC-Regular.woff2`
- `src/assets/fonts/SourceHanSansSC-Bold.woff2`
- `src/assets/fonts/SourceHanSansMonoSC-Medium.woff2`

### 构建静态站点

```bash
make build
# 或
mkdocs build
```

构建产物将输出到 `site/` 目录。

### 部署到 GitHub Pages

```bash
make deploy
# 或
mkdocs gh-deploy --force
```

## 目录结构

```
superpod-whitepaper/
├── mkdocs.yml          # MkDocs 配置文件
├── pyproject.toml      # Python 项目配置
├── Makefile            # 构建脚本
├── README.md           # 本文件
├── overrides/          # 模板覆盖
│   └── main.html
└── src/                # 文档源文件
    ├── index.md        # 首页
    ├── architecture/   # 架构分析
    ├── software/       # 软件系统
    ├── simulation/     # 建模仿真
    ├── reference-designs/  # 参考设计
    ├── future/         # 未来演进
    ├── conclusion.md   # 总结
    ├── appendix.md     # 附录
    └── assets/         # 静态资源
        ├── stylesheets/
        ├── images/
        └── javascripts/
```

## 编写指南

### Markdown 扩展

本项目支持以下 Markdown 扩展：

- **Admonitions**: 提示框、警告框等
- **Code highlighting**: 代码高亮
- **Tables**: 表格
- **MathJax**: 数学公式
- **Mermaid**: 流程图

### 示例

#### 提示框

```markdown
!!! note "注意"
    这是一个注意事项。

!!! warning "警告"
    这是一个警告。

!!! info "信息"
    这是一个信息提示。
```

#### 数学公式

```markdown
行内公式: \( E = mc^2 \)

块级公式:
\[
\sum_{i=1}^{n} x_i = x_1 + x_2 + \cdots + x_n
\]
```

## 版权声明

本白皮书内容仅供技术讨论与评估。未经许可不得以任何形式复制、传播或用于商业用途。

© 2025 DeepLink 团队
