# Grafana & Prometheus setup Verify

## Step 1: Verify the Pods & Services

1. Since this stack installs many components, check the monitoring namespace to ensure everything is Running.

```
kubectl get pods -n monitoring
```
What to look for: You should see pods for grafana, prometheus-operator, prometheus-kube-prometheus-stack-prometheus, and alertmanager.

## Step 2: Access the Grafana Dashboard
Grafana is the visual "frontend" for your metrics. By default, it is not exposed to the internet. Use port-forwarding to access it locally.

1. Start the Port-Forward:

```
kubectl port-forward deployment/kube-prometheus-stack-grafana 3000:3000 -n monitoring
```

2. Open your browser: Go to <http://localhost:3000>.

3. Login:
Username: admin  
Password: admin  

3. Check Dashboards: Once inside, go to Dashboards > Browse. You should see pre-installed EKS/Kubernetes dashboards showing CPU, Memory, and Node status.

## Step 3: Verify the Prometheus Targets

Prometheus needs to "discover" your nodes and pods to scrape metrics.

1. Port-Forward to Prometheus:

```
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```

2. Check Targets:
Open <http://localhost:9090/targets>.

What to look for: Look for serviceMonitor/monitoring/kube-prometheus-stack-apiserver and others. They should show a green UP status. If they are red, the Prometheus Operator is having trouble reaching the metrics endpoints.

## Step 4: Verify Custom Resource Definitions (CRDs)

The "Stack" uses Operators. This means it adds new types of objects to your Kubernetes API.

```
kubectl get servicemonitors -n monitoring
```
What to look for: A list of ServiceMonitor objects. These are the "instructions" that tell Prometheus which apps to monitor.

## Important Troubleshooting for Labs

Because you set storageSpec: null, all your monitoring data will be lost if the pods restart. This is fine for a lab, but if you see Prometheus stuck in Pending, run:

```
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus
```
If you see pod has unbound immediate PersistentVolumeClaims, it means the storageSpec: null didn't override a default setting in that specific chart version. You may need to explicitly set enabled: false for persistence in the values.
