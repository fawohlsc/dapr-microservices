.PHONY: build
build:
	docker build -t dapr-microservices/tenantservice:latest -f ./TenantService/Dockerfile .
	docker build -t dapr-microservices/userservice:latest -f ./UserService/Dockerfile .

.PHONY: up
up:
	docker-compose up --build

.PHONY: down
down:
	docker-compose down --remove-orphans