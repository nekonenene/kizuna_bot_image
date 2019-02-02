CONTAINER_NAME := kizuna_bot_01

RUBY_VER := $(shell cat .ruby-version)
ENV_FILE_DIR := "."

.PHONY: build
build:
	docker build ./ \
		--build-arg RUBY_VER=$(RUBY_VER) \
		--build-arg ENV_FILE_DIR=$(ENV_FILE_DIR) \
		-t kizuna_bot:latest

.PHONY: run
run:
	docker run -it --rm --name $(CONTAINER_NAME) kizuna_bot:latest

.PHONY: dev_run
dev_run:
	docker run -it --rm -v $(shell pwd)/src:/home/repo/src --name $(CONTAINER_NAME) kizuna_bot:latest /bin/bash
