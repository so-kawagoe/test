IMAGE_NAME := aws-gpt-api

all: build run

build:
	docker build --platform linux/x86_64 -t $(IMAGE_NAME) .

run:
	docker run -p 8000:80 --rm $(IMAGE_NAME)

.PHONY: all build run