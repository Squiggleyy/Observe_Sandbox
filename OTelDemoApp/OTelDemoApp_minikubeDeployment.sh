#!/bin/bash

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Docker is not running. Please start Docker Desktop and re-run the script."
  exit 1
fi

# Stop and delete existing Minikube instance if present
minikube stop
minikube delete
minikube start --driver=docker

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update

# Install Helm if not present
if ! command -v helm &> /dev/null; then
  brew install helm
fi

helm version

NAMESPACE="oteldemo"
kubectl create namespace $NAMESPACE || true

# Wait for Minikube to be ready
echo "Waiting for Minikube to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install Istio
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system

# Create the initial ConfigMap for service version
kubectl create configmap service-version --from-literal=service.version="initial" -n $NAMESPACE

# Add OpenTelemetry Helm chart repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Uninstall existing Helm release if present
if helm status oteldemo -n $NAMESPACE > /dev/null 2>&1; then
  helm uninstall oteldemo -n $NAMESPACE
fi

HELM_CHART_VERSION="0.27.2"

# Template and validate the Helm chart
helm template oteldemo open-telemetry/opentelemetry-demo \
  --version $HELM_CHART_VERSION \
  --namespace $NAMESPACE \
  --values oteldemo-to-observe-override.yaml \
  --set opentelemetry-collector.enabled=true > /dev/null

if [ $? -ne 0 ]; then
  echo "Helm chart validation failed. Please check your configuration."
  exit 1
fi

# Install/Upgrade Helm chart
helm upgrade --install oteldemo open-telemetry/opentelemetry-demo \
  --version $HELM_CHART_VERSION \
  --namespace $NAMESPACE \
  --values oteldemo-to-observe-override.yaml \
  --set opentelemetry-collector.enabled=true

# Wait for resources to initialize
sleep 90

# Apply RBAC and Configurations
# kubectl apply -f otel-cronjob-sa.yaml
# kubectl apply -f otel-cronjob-role.yaml
# kubectl apply -f otel-cronjob-rolebinding.yaml
# kubectl apply -f update-otel-service-version.yaml
# kubectl apply -f collector-configmap-volume.yaml

# Apply the EnvoyFilter to inject Elastic APM
# kubectl apply -f inject-elastic-apm.yaml

# Restart and verify OpenTelemetry Collector deployment
# kubectl rollout restart deployment oteldemo-otelcol -n $NAMESPACE
# kubectl rollout status deployment oteldemo-otelcol -n $NAMESPACE

# Wait for services to stabilize
sleep 120

# Port-forward to access frontend service locally
kubectl --namespace $NAMESPACE port-forward svc/oteldemo-frontendproxy 8080:8080