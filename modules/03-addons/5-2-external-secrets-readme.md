# The External Secrets Operator (ESO) acts as a bridge between your AWS Secrets Manager and your Kubernetes cluster

It doesn't store the secrets itself; it simply "syncs" them.

To verify this setup, we need to check the IAM Role (IRSA), the Operator health, and finally, the ClusterSecretStore connectivity.

## Step 1: Verify the Operator Pods

1. Ensure the operator, the webhook, and the cert-controller are running in the external-secrets namespace.

```
kubectl get pods -n external-secrets
```
What to look for: You should see 3 pods (or more depending on replicas) in a Running state.

## Step 2: Verify the IAM Role (IRSA) Attachment
1. Since you are using IRSA, the external-secrets ServiceAccount must be annotated with the AWS IAM Role ARN created by your Terraform module.
```
kubectl describe sa external-secrets -n external-secrets
```
What to look for: Under Annotations, verify it shows eks.amazonaws.com/role-arn: arn:aws:iam::.... If this is missing, ESO will not have permission to talk to AWS Secrets Manager.

## Step 3: Verify the ClusterSecretStore Status
1. This is the most important check. It tells you if the operator successfully authenticated with AWS using the IAM role.

```
kubectl get clustersecretstore aws-secrets-manager
```
What to look for: The STATUS column must say Valid.

2. If it doesn't say Valid, check the error message:
```
kubectl describe clustersecretstore aws-secrets-manager
```
Common error: AccessDenied (means the IAM role policy is missing or the Trust Relationship is wrong).

## Step 4: Functional Test (Fetch a Real Secret)

To prove the "plumbing" works, create a test secret in your AWS Console (Secrets Manager) named "test-secret" with a key-value pair (e.g., api-key: 12345), then run this:

1. Create the ExternalSecret Manifest:

```
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-test-secret
  namespace: default
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: k8s-native-secret  # This is the name of the secret ESO will CREATE
    creationPolicy: Owner
  data:

- secretKey: my-api-key    # Key inside the K8s secret
    remoteRef:
      key: test-secret       # Name of the secret in AWS Secrets Manager
      property: api-key      # Key inside the AWS secret
EOF
```

2. Verify the Sync:
```
kubectl get externalsecret aws-test-secret
```
What to look for: STATUS should be SecretSynced.

3. Check the native Kubernetes Secret:
```
kubectl get secret k8s-native-secret -o jsonpath='{.data.my-api-key}' | base64 -d
```

What to look for: It should print 12345.

################################################################################################

# Setting up AWS Systems Manager (SSM) Parameter Store is a great choice for configuration data that isn't quite a "secret" (like API endpoints or feature flags) but still needs to be managed centrally

Since you've already installed the External Secrets Operator (ESO) and the IAM Role, we just need to add a new ClusterSecretStore that points to the SSM service instead of Secrets Manager.

## Step 1: Check Store Status

```
kubectl get clustersecretstore aws-ssm-parameter-store
```

Target: STATUS should be Valid.

## Step 2: Create a Parameter in AWS
Go to the AWS Console (Systems Manager > Parameter Store) and create a parameter:

Name: /dev/app/database_url

Type: String (or SecureString)

Value: postgres://db.devsecopsguru.in:5432

## Step 3: Sync to Kubernetes

Apply this ExternalSecret to fetch the parameter:

```
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ssm-app-config
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-ssm-parameter-store
    kind: ClusterSecretStore
  target:
    name: app-config-secret
  data:

- secretKey: DB_URL
    remoteRef:
      key: /dev/app/database_url
EOF
```

## Step 4: Confirm the Data

```
kubectl get secret app-config-secret -o jsonpath='{.data.DB_URL}' | base64 -d
```
