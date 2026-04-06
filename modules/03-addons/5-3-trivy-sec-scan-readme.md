# Trivy Operator is a security scanner

runs inside cluster. Unlike a one-time scan, it creates "VulnerabilityReports" as Custom Resources (CRDs) whenever it detects a new workload or an image change.

Step-by-step verification playbook to ensure it is actively hunting for vulnerabilities.

## Step 1: Verify the Operator Pod

1. First, ensure the operator itself is running and healthy in its own namespace.
```
kubectl get pods -n trivy-system
```
What to look for: You should see one pod (e.g., trivy-operator-xxxxxxxx) with a status of Running.

## Step 2: Check the Custom Resource Definitions (CRDs)
Trivy Operator adds new "languages" to your Kubernetes API. Verify that these CRDs exist.

```
kubectl get crds | grep aquasecurity
```
What to look for: You should see several entries, including vulnerabilityreports.aquasecurity.github.io and configauditreports.aquasecurity.github.io.

## Step 3: Verify Scanning Activity (The "Work" Check)

1. When Trivy detects a pod, it spawns a temporary "Scan Job." You can see these brief jobs appearing and disappearing.
``` Bash
kubectl get jobs -n trivy-system
```
Note: If the scan is finished, the job might be gone. If you see nothing, it likely already finished its initial scan of your cluster.

## Step 4: View the Vulnerability Reports
This is the most important step. This command shows you the actual security summary of your workloads.
```
# List all vulnerability reports across all namespaces
kubectl get vulnerabilityreports -A
```
What to look for: A list of reports named after your pods (e.g., replicaset-coredns-xxxx). It will show columns for CRITICAL, HIGH, MEDIUM, and LOW counts.

## Step 5: Inspect a Specific Security Report
To see exactly which CVEs were found in a specific pod (for example, in the kube-system namespace):
```
# Pick a report name from the previous command
kubectl describe vulnerabilityreport <REPORT_NAME> -n <NAMESPACE>
```
What to look for: Scroll down to the Report: section. You will see a list of CVE IDs, the installed version of the library, and the fixed version.

## Step 6: Verify Config Audits
Trivy also checks if your Kubernetes YAML is "best practice" (e.g., are you running as root?).
```
kubectl get configauditreports -A
```
What to look for: Reports showing PASS vs FAIL counts for security configurations.

####################################################################

# To test if Trivy is actually doing its job

deploy a "purposely vulnerable" pod. We'll use an old version of nginx (like version 1.14.2) which has hundreds of known CVEs.

## Step 1: Deploy the "Vulnerable" Pod

1. Run this command to create a simple deployment using an outdated, insecure image:
```
kubectl create deployment insecure-nginx --image=nginx:1.14.2
```

## Step 2: Watch Trivy Spring into Action
1. Trivy Operator uses "Informer" patterns, meaning it notices the new Pod immediately. It will schedule a temporary scan job in the trivy-system namespace.
Monitor the scan job:
```
kubectl get jobs -n trivy-system -w
```
Wait until you see a job named scan-vulnerabilityreport-XXXXX reach 1/1 completions (usually takes 30-60 seconds).

## Step 3: Check the Results
Now, let's see the "damage report" for our insecure pod.

1. List the Vulnerability Summary
Search all namespaces for any report whose name contains our app name.

```
# Finds the report for any app - just change 'insecure-nginx' to your deployment name
kubectl get vulnerabilityreports -A -o custom-columns="NAME:.metadata.name,CRITICAL:.report.summary.criticalCount,HIGH:.report.summary.highCount" | grep "insecure-nginx"
```
What to look for: You should see a very high count in the CRITICAL and HIGH columns (likely 50+ Criticals for nginx:1.14.2).

2. Detailed CVE Inspection
To see the specific CVE IDs (like Heartbleed), we use jq to filter the JSON output. This bypasses the label issue entirely.

```
# Extract only the Vulnerability IDs and their Severity
kubectl get vulnerabilityreports -A -o json | jq -r '.items[] | select(.metadata.name | contains("insecure-nginx")) | .report.vulnerabilities[] | [.vulnerabilityID, .severity] | @tsv'
```

## Step 4: Test "Config Audit" (Best Practices)
Trivy also audits your Kubernetes manifest for security misconfigurations (e.g., running as root). Like vulnerabilities, these reports use their own naming convention.

1. Check the Configuration Audit:
```
# Search for the config audit report for your app
kubectl get configauditreports -A -o wide | grep "insecure-nginx"
```
To see the specific Failures:

2. If you want to see exactly which security checks failed (e.g., "Privileged" or "RunAsNonRoot"):
```
kubectl get configauditreports -A -o json | jq -r '.items[] | select(.metadata.name | contains("insecure-nginx")) | .report.checks[] | select(.success == false) | [.checkID, .severity, (.messages | join("; "))] | @tsv'
```
What to look for: You will see multiple FAIL counts. This is because the default Nginx image runs as root and lacks a restricted securityContext.

## Step 5: Cleanup
1. Don't leave insecure pods running in your cluster!
```
kubectl delete deployment insecure-nginx
```
Note: Trivy will automatically delete the associated reports after a short delay once the deployment is gone.

########################################################

# To generate a "Security Score" or a cluster-wide summary

The Custom Resource Definitions (CRDs) that Trivy Operator manages. Since every scan result is stored as a standard Kubernetes object, we can aggregate them to see the overall health of your EKS cluster.

## Step 1: The Cluster-Wide Vulnerability Summary
Run this command to get a high-level view of every namespace and how many Critical/High vulnerabilities are lurking in each:

```
kubectl get vulnerabilityreports -A -o custom-columns="NAMESPACE:.metadata.namespace,RESOURCE:.metadata.labels['trivy-operator\.resource\.name'],CRITICAL:.report.summary.criticalCount,HIGH:.report.summary.highCount"
```
What to look for: This creates a clean table. Ideally, your kube-system namespace should have very few (or zero) Criticals, while your application namespaces might show more depending on the images you use.

## Step 2: The "ClusterCompliance" Check
Trivy defines compliance "control sets" (like NSA, CIS Benchmark, or PSS). You can check if your cluster meets these specific security standards:
```
kubectl get clustercompliancereports
```
What to look for: Look at the STATUS column. If it says Fail, it means your cluster configuration (Node settings, API server flags, etc.) is missing key security hardening steps required by that standard.

## Step 3: Finding the "Top Offenders" (Sorting)
If you have many reports, use this one-liner to sort your pods by the number of Critical vulnerabilities, showing the worst ones at the bottom:
```
kubectl get vulnerabilityreports -A -o json | jq -r '.items[] | [.report.summary.criticalCount, .metadata.namespace, .metadata.name] | @tsv' | sort -n
```
(Note: This requires jq installed on your machine. If you don't have it, the standard kubectl get is your best bet.)

## Step 4: Automating the Cleanup (Maintenance)
In your Terraform code, you set scannerReportTTL: "24h". This is your "Auto-Cleanup" policy.

1. To verify this is working:
Check the "Age" of your reports: 
```
kubectl get vulnerabilityreports -A
```
Any report older than 24 hours will be automatically purged by the Trivy Operator. This prevents your Kubernetes etcd database from getting bloated with thousands of old security records.

### Summary of your "Security Score"

* A+ Score: Zero Criticals, Zero Highs, and all ClusterCompliance reports show Pass.
* B Score: Some Medium/Low vulnerabilities, but all Criticals are patched.
* F Score: Any Critical vulnerabilities in the kube-system namespace or failing the CIS Benchmark compliance check.
