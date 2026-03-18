#!/bin/bash

# Установочный скрипт для развертывания бизнес части приложения в Kubernetes
echo "Starting installation..."

# Функция для ожидания
wait_seconds() {
    local seconds=$1
    echo "Waiting $seconds seconds..."
    sleep $seconds
}

# Создание namespace и применение секретов
echo "Step 1: Creating namespaces and applying secrets..."

kubectl create namespace zsvv-main
kubectl apply -f ./install/k8s/manifests/users-secret.yaml -n zsvv-main
# kubectl apply -f ./install/k8s/manifests/kafka-secrets.yaml -n zsvv-main
kubectl apply -f ./install/k8s/manifests/notif-secrets.yaml -n zsvv-main 
kubectl apply -f ./install/k8s/manifests/order-secrets.yaml -n zsvv-main 
kubectl apply -f ./install/k8s/manifests/bill-secrets.yaml -n zsvv-main

kubectl apply -f ./install/k8s/manifests/warehouse-secrets.yaml -n zsvv-main
kubectl apply -f ./install/k8s/manifests/delivery-secrets.yaml -n zsvv-main

kubectl create namespace zsvv-authority
kubectl apply -f ./install/k8s/manifests/auth-secrets.yaml -n zsvv-authority 

# # Сборка локальных helm чартов
# echo "Step 3: Building local Helm charts..."
# helm package ./install/auth-service/ --destination ./install/auth-service/
# # helm package ./install/gateway-service/ --destination ./install/gateway-service/
# helm package ./install/users-service/ --destination ./install/users-service/
# helm package ./install/billing-service/ --destination ./install/billing-service/
# helm package ./install/notif-service/ --destination ./install/notif-service/
# helm package ./install/order-service/ --destination ./install/order-service/

# echo "Helm charts built."

# Установка Billing Service
echo "Step 2: Installing Billing Service..."
helm upgrade --install hw7-bill ./install/billing-service/ \
  -n zsvv-main \
  --set endpoints.kafka.space=zsvv-kafka

echo "Billing Service installed. Waiting 5 seconds..."
wait_seconds 20

# Установка пользовательского сервиса
echo "Step 3: Installing users service..."
helm upgrade --install hw6 ./install/users-service/ \
  -n zsvv-main \
  --set ingress.enabled=false \
  --set endpoints.kafka.space=zsvv-kafka

echo "Users service installed. Waiting 5 seconds..."
wait_seconds 20

# Установка сервиса авторизации
echo "Step 4: Installing auth service..."
helm upgrade --install hw6 ./install/auth-service/ \
  -n zsvv-authority \
  --create-namespace \
  --set endpoints.usersServiceSpace=zsvv-main \
  --set endpoints.apiGatewaySpace=zsvv-main

echo "Auth service installed. Waiting 5 seconds..."
wait_seconds 20

# Установка Notification Service
echo "Step 5: Installing Notification Service..."
helm upgrade --install hw7-notif ./install/notif-service/ \
  -n zsvv-main \
  --set endpoints.usersServiceSpace=zsvv-main \
  --set endpoints.authServiceSpace=zsvv-authority \
  --set endpoints.kafkaSpace=zsvv-kafka

echo "Notification Service installed. Waiting 5 seconds..."
wait_seconds 20

# Установка Order Service
echo "Step 6: Installing Order Service..."
helm upgrade --install hw7-order ./install/order-service/ \
  -n zsvv-main \
  --set endpoints.users.space=zsvv-main \
  --set endpoints.auth.space=zsvv-authority \
  --set endpoints.kafka.space=zsvv-kafka \
  --set endpoints.bill.space=zsvv-main

echo "Order Service installed. Waiting 5 seconds..."
wait_seconds 20


# Установка Warehouse Service
echo "Step 6: Installing Warehouse Service..."
helm upgrade --install hw8-warehouse ./install/warehouse-service/ \
  -n zsvv-main \
  --set endpoints.kafka.space=zsvv-kafka

echo "Warehouse Service installed. Waiting 5 seconds..."
wait_seconds 20

# Установка Delivery Service
echo "Step 6: Installing Delivery Service..."
helm upgrade --install hw8-delivery ./install/delivery-service/ \
  -n zsvv-main \
  --set endpoints.kafka.space=zsvv-kafka

echo "Delivery Service installed. Waiting 5 seconds..."
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
echo "1. Created namespaces: zsvv-main, zsvv-authority, zsvv-kafka, zsvv-ng"
echo "2. Applied all required secrets"
echo "3. Installed Core services:"
echo "   - Users Service (hw6)"
echo "   - Auth Service (hw6)"
# echo "   - API Gateway (hw6-api)"
echo "4. Installed Business services:"
echo "   - Notification Service (hw7-notif)"
echo "   - Order Service (hw7-order)"
echo "   - Billing Service (hw7-bill)"
echo "========================================="

# Ожидание ввода пользователя
echo "Script execution completed. You may close this window."
read -p "Press Enter to continue..."