## https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

check-scripts-all: ## Run shellcheck static analysis on all .sh files within git repo
	git ls-files --exclude='*.sh' --ignored | xargs shellcheck ## See https://github.com/koalaman/shellcheck/wiki/GitLab-CI
	echo "[SUCCESS] check passed"

