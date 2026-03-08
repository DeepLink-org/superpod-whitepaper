from __future__ import annotations

import json
import subprocess
from datetime import date
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    yaml = None


ROOT = Path(__file__).resolve().parents[1]
SPI_PRODUCTS_DIR = ROOT / "spi" / "products"
OUTPUT_FILE = ROOT / "src" / "07-spi-registry.md"
GITHUB_BASE = "https://github.com/DeepLink-org/superpod-whitepaper/blob/main"

SUBMISSION_TYPE_LABELS = {
    "vendor_pr": "厂商 PR 提交",
    "committee_init": "仓库内置示例",
    "committee_update": "委员会更新",
}

STATUS_LABELS = {
    "submitted": "已提交",
    "under_review": "审查中",
    "published": "已发布",
    "archived": "已归档",
}

EVIDENCE_LEVEL_LABELS = {
    "unreviewed": "未审查",
    "self_reported": "厂商自报",
    "evidence_backed": "证据支持",
    "committee_estimated": "委员会估计",
}


def load_product(path: Path) -> dict[str, Any]:
    if yaml is not None:
        with path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        return data or {}

    ruby_cmd = [
        "ruby",
        "-e",
        (
            'require "yaml";'
            'require "json";'
            'data = YAML.load_file(ARGV[0]);'
            "puts JSON.generate(data)"
        ),
        str(path),
    ]
    output = subprocess.check_output(ruby_cmd, text=True)
    return json.loads(output)


def fmt(value: Any, fallback: str = "—") -> str:
    if value is None:
        return fallback
    if isinstance(value, str) and not value.strip():
        return fallback
    return str(value)


def bullet_list(items: list[str]) -> str:
    if not items:
        return "- —"
    return "\n".join(f"- {item}" for item in items)


def build_table_row(product: dict[str, Any], rel_path: str) -> str:
    meta = product.get("meta", {})
    vendor = product.get("vendor_submission", {}).get("contacts", {}).get("company_name", "")
    spec = product.get("vendor_submission", {}).get("spec", {})
    interconnect = spec.get("interconnect", {})
    scale = spec.get("scale", {})
    committee = product.get("committee_assessment", {})

    product_name = fmt(meta.get("product_name"))
    vendor_name = fmt(vendor)
    submission_type = SUBMISSION_TYPE_LABELS.get(fmt(meta.get("submission_type")), fmt(meta.get("submission_type")))
    status = STATUS_LABELS.get(fmt(meta.get("status")), fmt(meta.get("status")))
    evidence_level = EVIDENCE_LEVEL_LABELS.get(fmt(committee.get("evidence_level")), fmt(committee.get("evidence_level")))
    hbd_size = fmt(scale.get("max_hbd_size"))
    fabric = fmt(interconnect.get("fabric_type"))
    source_link = f"[`{rel_path}`]({GITHUB_BASE}/{rel_path})"

    return (
        f"| {product_name} | {vendor_name} | {submission_type} | {status} | "
        f"{evidence_level} | {hbd_size} | {fabric} | {source_link} |"
    )


def build_score_table(product: dict[str, Any]) -> str:
    scoring = product.get("committee_assessment", {}).get("scoring", {})
    rows = [
        ("单跳/访存延迟", scoring.get("latency_memory_semantics"), "原生内存语义与时延能力"),
        ("规模上限", scoring.get("scale_limit"), "单 HBD 域内规模能力"),
        ("拓扑弹性", scoring.get("topology_elasticity"), "拓扑重构与调度灵活性"),
        ("生态成熟度", scoring.get("ecosystem_maturity"), "软硬件生态与交付成熟度"),
        ("功耗与 TCO", scoring.get("power_tco"), "性能密度与工程成本平衡"),
        ("软件复杂度", scoring.get("software_complexity"), "对用户的软件使用门槛")
    ]
    lines = [
        "| 维度 | 分数 | 说明 |",
        "|:-----|:----:|:-----|",
    ]
    for name, score, desc in rows:
        lines.append(f"| {name} | {fmt(score)} | {desc} |")
    return "\n".join(lines)


def build_product_section(product: dict[str, Any], rel_path: str) -> str:
    meta = product.get("meta", {})
    vendor = product.get("vendor_submission", {})
    summary = vendor.get("product_summary", {})
    spec = vendor.get("spec", {})
    accelerator = spec.get("accelerator", {})
    interconnect = spec.get("interconnect", {})
    system = spec.get("system", {})
    committee = product.get("committee_assessment", {})

    name = fmt(meta.get("product_name"))
    company = fmt(vendor.get("contacts", {}).get("company_name"))
    status = STATUS_LABELS.get(fmt(meta.get("status")), fmt(meta.get("status")))
    submission_type = SUBMISSION_TYPE_LABELS.get(fmt(meta.get("submission_type")), fmt(meta.get("submission_type")))
    evidence_level = EVIDENCE_LEVEL_LABELS.get(fmt(committee.get("evidence_level")), fmt(committee.get("evidence_level")))
    workload_fit = committee.get("workload_fit", []) or []
    radar_summary = fmt(committee.get("radar_summary"))
    comments = fmt(committee.get("committee_comments"))
    source_link = f"[`{rel_path}`]({GITHUB_BASE}/{rel_path})"

    return f"""## {name}

| 字段 | 内容 |
|:-----|:-----|
| 厂商 | {company} |
| 状态 | {status} |
| 提交方式 | {submission_type} |
| 证据等级 | {evidence_level} |
| 产品定位 | {fmt(summary.get("short_description"))} |
| 加速器 | {fmt(accelerator.get("accelerator_count_per_hbd"))} |
| 加速器型号 | {fmt(accelerator.get("model"))} |
| 总 HBD 显存 | {fmt(accelerator.get("total_hbd_memory_gb"))} GB |
| 互联技术 | {fmt(interconnect.get("fabric_type"))} |
| 单跳时延 | {fmt(interconnect.get("stated_single_hop_latency_ns"))} ns |
| 域内总带宽 | {fmt(interconnect.get("stated_bisection_bandwidth_tbps"))} TB/s |
| 功耗 | {fmt(system.get("power_kw_per_hbd"))} kW |
| 源文件 | {source_link} |

### 委员会评分摘要

{build_score_table(product)}

### 适用负载

{bullet_list(workload_fit)}

### 雷达图摘要

> {radar_summary}

### 委员会评语

> {comments}
"""


def generate() -> str:
    product_files = sorted(SPI_PRODUCTS_DIR.glob("**/*.yaml"))
    products: list[tuple[dict[str, Any], str]] = []
    for path in product_files:
        rel_path = path.relative_to(ROOT).as_posix()
        products.append((load_product(path), rel_path))

    lines = [
        "# 当前已收录产品",
        "",
        "<!-- This file is auto-generated by scripts/generate_spi_registry.py. Do not edit directly. -->",
        "",
        f"本页由构建脚本自动扫描 `spi/products/` 目录生成。生成日期：{date.today().isoformat()}。",
        "",
        f"当前仓库共收录 **{len(products)}** 个产品条目。",
        "",
        "## 产品总表",
        "",
        "| 产品 | 厂商 | 提交方式 | 状态 | 证据等级 | HBD 规模 | 互联 | 源文件 |",
        "|:-----|:-----|:---------|:-----|:---------|:--------|:-----|:-------|",
    ]

    lines.extend(build_table_row(product, rel_path) for product, rel_path in products)
    lines.append("")
    lines.append("## 产品详情")
    lines.append("")

    for product, rel_path in products:
        lines.append(build_product_section(product, rel_path))
        lines.append("")

    return "\n".join(lines).strip() + "\n"


if __name__ == "__main__":
    OUTPUT_FILE.write_text(generate(), encoding="utf-8")
    print(f"Generated {OUTPUT_FILE}")
