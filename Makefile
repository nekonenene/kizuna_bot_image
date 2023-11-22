APP_CONTAINER_NAME := kizuna_bot_01

RUBY_VER := $(shell cat .ruby-version)
ENV_FILE_DIR := "."

.PHONY: init
init:
	rm -rf log
	mkdir log
	cp -i default.env .env

.PHONY: build
build:
	docker build ./ \
		--build-arg RUBY_VER=$(RUBY_VER) \
		--build-arg ENV_FILE_DIR=$(ENV_FILE_DIR) \
		-t kizuna_bot:latest

.PHONY: run_prod
run_prod:
	docker run -d --rm --name $(APP_CONTAINER_NAME) \
		kizuna_bot:latest

.PHONY: stop
stop:
	docker stop $(APP_CONTAINER_NAME)

.PHONY: run_dev
run_dev:
	docker run -it --rm --name $(APP_CONTAINER_NAME) \
		-v $(shell pwd)/src:/home/repo/src \
		kizuna_bot:latest

.PHONY: login
login:
	docker run -it --rm --name $(APP_CONTAINER_NAME) \
		-v $(shell pwd)/src:/home/repo/src \
		kizuna_bot:latest \
		/bin/bash
