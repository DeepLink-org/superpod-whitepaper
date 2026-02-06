# Makefile for SuperPod 技术白皮书 (MkDocs)

.PHONY: help install serve build clean deploy

# Default target
help:
	@echo "SuperPod 技术白皮书构建系统"
	@echo ""
	@echo "使用方法:"
	@echo "  make install   安装文档依赖"
	@echo "  make serve     启动实时预览服务器"
	@echo "  make build     构建静态文档站点"
	@echo "  make clean     清理构建产物"
	@echo "  make deploy    部署到 GitHub Pages"

# Install dependencies
install:
	@echo "正在安装文档依赖..."
	pip install -r requirements.txt

# Live preview server
serve:
	@echo "正在启动实时预览服务器..."
	@echo "请在浏览器中打开 http://127.0.0.1:8000"
	mkdocs serve -w src -w mkdocs.yml --dev-addr 127.0.0.1:8000

# Build static site
build:
	@echo "正在构建文档..."
	mkdocs build

# Clean build artifacts
clean:
	@echo "正在清理构建产物..."
	rm -rf site/

# Deploy to GitHub Pages
deploy:
	@echo "正在部署到 GitHub Pages..."
	mkdocs gh-deploy --force

