# Simple local workflow:
#   - Docker Compose runs observability only.
#   - Kubernetes runs the microservices.
#
# Most days:
#   make up
#   make status
#   make logs
#   make down

IMAGE_TAG ?= latest
NAMESPACE := microservices

.PHONY: help up down obs-up obs-down build push deploy ingress health status logs

help:
	@echo "Simple targets:"
	@echo "  make up       - start observability, build/push images, deploy app and ingress"
	@echo "  make down     - delete Kubernetes app and stop observability"
	@echo "  make status   - show Kubernetes pods/services and observability containers"
	@echo "  make health   - run Kubernetes health and Config Server DEV checks"
	@echo "  make logs     - tail Kubernetes app logs"
	@echo ""
	@echo "Step-by-step targets:"
	@echo "  make obs-up   - start observability with Docker Compose"
	@echo "  make obs-down - stop observability"
	@echo "  make build    - build all service images"
	@echo "  make push     - push all service images"
	@echo "  make deploy   - apply Kubernetes manifests and update images"
	@echo "  make ingress  - apply API gateway ingress"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"

up: obs-up build push deploy ingress

down:
	kubectl delete -n $(NAMESPACE) -f ms-api-gateway/k8/apigateway-ingress.yaml --ignore-not-found=true
	kubectl delete -k . --ignore-not-found=true
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	docker compose -f observability/docker-compose.yml down

obs-up:
	docker network inspect observability >NUL 2>NUL || docker network create observability
	docker compose -f observability/docker-compose.yml up -d

obs-down:
	docker compose -f observability/docker-compose.yml down

build:
	docker build -t dayasahu6077/configserver:$(IMAGE_TAG) configserver
	docker build -t dayasahu6077/employee:$(IMAGE_TAG) employee
	docker build -t dayasahu6077/department:$(IMAGE_TAG) department
	docker build -t dayasahu6077/ms-api-gateway:$(IMAGE_TAG) ms-api-gateway
	docker build -t dayasahu6077/auth-service:$(IMAGE_TAG) auth-service

push:
	docker push dayasahu6077/configserver:$(IMAGE_TAG)
	docker push dayasahu6077/employee:$(IMAGE_TAG)
	docker push dayasahu6077/department:$(IMAGE_TAG)
	docker push dayasahu6077/ms-api-gateway:$(IMAGE_TAG)
	docker push dayasahu6077/auth-service:$(IMAGE_TAG)

deploy:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k .
	kubectl -n $(NAMESPACE) set image deployment/configserver configserver=dayasahu6077/configserver:$(IMAGE_TAG)
	kubectl -n $(NAMESPACE) set image deployment/employee employee=dayasahu6077/employee:$(IMAGE_TAG)
	kubectl -n $(NAMESPACE) set image deployment/department department=dayasahu6077/department:$(IMAGE_TAG)
	kubectl -n $(NAMESPACE) set image deployment/apigateway apigateway=dayasahu6077/ms-api-gateway:$(IMAGE_TAG)
	kubectl -n $(NAMESPACE) set image deployment/auth-service auth-service=dayasahu6077/auth-service:$(IMAGE_TAG)
	kubectl -n $(NAMESPACE) rollout status deployment/configserver --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deployment/employee --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deployment/department --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deployment/apigateway --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deployment/auth-service --timeout=180s

ingress:
	kubectl apply -n $(NAMESPACE) -f ms-api-gateway/k8/apigateway-ingress.yaml

status:
	kubectl -n $(NAMESPACE) get pods,svc,ingress
	docker compose -f observability/docker-compose.yml ps

health:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/health-check.ps1 -Namespace $(NAMESPACE)

logs:
	kubectl -n $(NAMESPACE) logs -f --tail=100 -l app.kubernetes.io/part-of=microservices-training --all-containers=true
