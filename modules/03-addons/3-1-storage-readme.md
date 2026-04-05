# verify EBS CSI Driver

the step-by-step commands to verify your deployment.

## Step 1: Verify the EBS CSI Driver Pods are Running

The EKS add-on installs both a controller (which talks to the AWS API) and a daemonset (which runs on every node to mount the drives).

1. command to check their status:

```
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

What to look for: You should see at least two ebs-csi-controller pods and one ebs-csi-node pod for every EC2 worker node you have. They should all have a status of Running.

## Step 2: Verify the IRSA (IAM Role) Attachment

The controller pods need permission to provision EBS volumes in your AWS account. They get this via the ebs-csi-controller-sa ServiceAccount.

1. command to inspect the ServiceAccount:

```
kubectl describe sa ebs-csi-controller-sa -n kube-system
```
What to look for: Look under the Annotations: section. You should see eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<CLUSTER_NAME>-ebs-csi. This confirms the Terraform IRSA module worked.

## Step 3: Verify the Storage Classes

Your Terraform code was designed to strip the default status from gp2 and apply it to your new gp3 class.

1. List the storage classes:

```
kubectl get sc
```

What to look for: * You should see gp3 (default) clearly marked as the default.

gp2 should still exist but without the (default) tag next to it.

Both should show ebs.csi.aws.com as the PROVISIONER.

## Step 4: The Functional Test (Provision a Volume)

The ultimate test is seeing if Kubernetes can successfully ask AWS for a hard drive. Because you set volume_binding_mode = "WaitForFirstConsumer", the volume will not be created until a Pod actually requests it.

1. Create a test file named ebs-test.yaml with this content:

```YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-test-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: ebs-test-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: ebs-test-claim
```

1. Apply the manifest:

```
kubectl apply -f ebs-test.yaml
```

2. Watch the provisioning process:
Run this command to watch the PVC status change:

```
kubectl get pvc ebs-test-claim -w
```

What to look for: It will start as Pending. Once the Pod gets scheduled to a node, the EBS CSI driver will call the AWS API, create a 4Gi gp3 volume, and the status will change to Bound. Hit Ctrl+C to exit the watch mode once it binds.

3. Verify the Pod is running:

```
kubectl get pods ebs-test-pod
```

What to look for: Status should be Running. This means the EC2 instance successfully attached the EBS volume and the container mounted it.

## Step 5: Cleanup

Once you have confirmed everything works, clean up the test resources so you aren't paying for an unused 4GB EBS volume:

```
kubectl delete -f ebs-test.yaml
```
