# wsl2-devkit — task runner (run inside WSL/Ubuntu)
.DEFAULT_GOAL := help
SHELL := /bin/bash

WSL_SCRIPTS := wsl/stage2-ubuntu.sh wsl/verify-setup.sh demo/lib/setup.sh demo/lib/stage1.sh demo/lib/stage2.sh

.PHONY: help verify verify-quiet lint demo

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}'

verify: ## Run the WSL dev-environment health check
	@bash wsl/verify-setup.sh

verify-quiet: ## Health check — problems + summary only
	@bash wsl/verify-setup.sh -q

demo: ## Record the README walkthrough GIF (needs charmbracelet/vhs)
	@command -v vhs >/dev/null || { echo "vhs not found — install: go install github.com/charmbracelet/vhs@latest"; exit 1; }
	@vhs demo/devkit-demo.tape && echo "Wrote demo/devkit-demo.gif"

lint: ## Syntax-check + shellcheck the WSL shell scripts
	@for f in $(WSL_SCRIPTS); do \
		echo "== $$f =="; \
		bash -n "$$f" && echo "  bash -n OK"; \
		if command -v shellcheck >/dev/null; then shellcheck -S warning "$$f" || true; fi; \
	done
	@echo "Note: PowerShell scripts (windows/*.ps1) lint on Windows via PSScriptAnalyzer."
