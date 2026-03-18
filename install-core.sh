#!/bin/bash

# Установочный скрипт для развертывания приложения в Kubernetes
echo "Starting installation..."

# Функция для ожидания
wait_seconds() {
    local seconds=$1
    echo "Waiting $seconds seconds..."
    sleep $seconds
}

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo "Step 1: Installing monitoring stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack  -f install/monitoring/prometheus.yaml -f install/monitoring/grafana.yaml --namespace zsvv-monitoring --create-namespace
wait_seconds 20

echo "Step 2: Installing nginx..."
helm upgrade --install nginx ingress-nginx/ingress-nginx \
  -f install/k8s/manifests/nginx-ingress.yaml \
  --namespace zsvv-ng \
  --create-namespace \
  --set controller.admissionWebhooks.patch.enabled=true
wait_seconds 45

kubectl create namespace zsvv-main
echo "Step 3: Installing PostgreSQL..."
helm upgrade --install hw8-postgresql ./install/postgresql/ -n zsvv-main
wait_seconds 20

echo "Step 4: Installing API gateway..."
kubectl apply -f ./install/k8s/manifests/gateway-secrets.yaml -n zsvv-main
kubectl apply -f ./install/k8s/manifests/users-secret.yaml -n zsvv-main
helm upgrade --install hw6-api ./install/gateway-service/ \
  -n zsvv-main \
  --set endpoints.users.space=zsvv-main \
  --set endpoints.order.space=zsvv-main \
  --set endpoints.auth.space=zsvv-authority \
  --set endpoints.notif.space=zsvv-main \
  --set endpoints.bill.space=zsvv-main \
  --set endpoints.warehouse.space=zsvv-main \
  --set endpoints.delivery.space=zsvv-main 
wait_seconds 20

echo "Step 5: Installing Kafka..."
kubectl create namespace zsvv-kafka
kubectl apply -f ./install/k8s/manifests/kafka-secrets.yaml -n zsvv-kafka
kubectl apply -f ./install/k8s/manifests/kafka-secrets.yaml -n zsvv-main
helm upgrade --install hw7 ./install/kafka/ -n zsvv-kafka --create-namespace 			
helm upgrade --install hw7-ui ./install/kafka-ui/ -n zsvv-kafka --create-namespace 
wait_seconds 20

echo "========================================="
echo "Installation completed successfully!"
echo "========================================="

# Показать статус установленных сервисов
echo "Checking deployment status..."
echo ""
echo "Namespaces:"
kubectl get namespaces | grep zsvv
echo ""
echo "Helm releases:"
helm list -A | grep -E "zsvv|monitoring|nginx"
echo ""
echo "All pods (may take a moment to start):"
kubectl get pods --all-namespaces | grep -E "zsvv|monitoring|ingress"

echo ""
echo "========================================="
echo "Installation summary:"
echo "========================================="
echo "0. Created namespaces: zsvv-main, zsvv-kafka, zsvv-ng"
echo "1. Applied all required secrets"
echo "2. Installed Monitoring stack in zsvv-monitoring"
echo "3. Installed NGINX Ingress in zsvv-ng"
echo "4. Installed Core services:"
echo "   - API Gateway (hw6-api)"
echo "5. Installed Kafka infrastructure:"
echo "   - Kafka (hw7)"
echo "   - Kafka UI (hw7-ui)"
echo "========================================="

# Ожидание ввода пользователя
echo "Script execution completed. You may close this window."
read -p "Press Enter to continue..."