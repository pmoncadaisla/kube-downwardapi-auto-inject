# Kubernetes Mutating Admission Webhook for sidecar injection

This project is strongly inspired in https://github.com/morvencao/kube-mutating-webhook-tutorial

Inject POD information to contqainers using the [Kubernetes DownwardAPI](https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/) automatically.


It will inject:
- Environment variables
- Volumes

Environment variables contain:
```
- name: K8S_DWA_NODE_NAME
  valueFrom:
    fieldRef:
        fieldPath: spec.nodeName
- name: K8S_DWA_NODE_IP
  valueFrom:
    fieldRef:
        fieldPath: status.hostIP
- name: K8S_DWA_POD_NAME
  valueFrom:
    fieldRef:
        fieldPath: metadata.name
- name: K8S_DWA_NAMESPACE
  valueFrom:
    fieldRef:
        fieldPath: metadata.namespace
- name: K8S_DWA_POD_IP
  valueFrom:
    fieldRef:
        fieldPath: status.podIP
- name: K8S_DWA_POD_UID
  valueFrom:
    fieldRef:
        fieldPath: metadata.uid
- name: K8S_DWA_LIMITS_CPU
  valueFrom:
    resourceFieldRef:
        resource: limits.cpu
        containerName: pod_name
- name: K8S_DWA_LIMITS_MEMORY
  valueFrom:
    resourceFieldRef:
        resource: limits.memory
        containerName: pod_name
- name: K8S_DWA_REQUESTS_CPU
  valueFrom:
    resourceFieldRef:
        resource: requests.cpu
        containerName: pod_name
- name: K8S_DWA_REQUESTS_MEMORY
  valueFrom:
    resourceFieldRef:
        resource: requests.memory
        containerName: pod_name
```

And `labels` and `annotations` are accesible though volume:
```
volumemounts:
  - name: podinfo
    readOnly: true
    mountPath: /kubernetes
volumes:
  - name: podinfo
    downwardAPI:
      items:
        - path: "labels"
          fieldRef:
            fieldPath: metadata.labels
        - path: "annotations"
          fieldRef:
            fieldPath: metadata.annotations
```


## Prerequisites

Kubernetes 1.9.0 or above with the `admissionregistration.k8s.io/v1beta1` API enabled. Verify that by the following command:
```
kubectl api-versions | grep admissionregistration.k8s.io/v1beta1
```
The result should be:
```
admissionregistration.k8s.io/v1beta1
```

In addition, the `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` admission controllers should be added and listed in the correct order in the admission-control flag of kube-apiserver.

## Build

1. Setup dep

   The repo uses [dep](https://github.com/golang/dep) as the dependency management tool for its Go codebase. Install `dep` by the following command:
```
go get -u github.com/golang/dep/cmd/dep
```

2. Build and push docker image
   
```
./build
```

## Deploy adminssion controller

1. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed by sidecar deployment
```
./deploy/webhook-create-signed-cert.sh \
    --service sidecar-injector-webhook-svc \
    --secret sidecar-injector-webhook-certs \
    --namespace kube-system
```

2. Patch the `MutatingWebhookConfiguration` by set `caBundle` with correct value from Kubernetes cluster
```
cat deployment/mutatingwebhook.yaml | \
    deployment/webhook-patch-ca-bundle.sh > \
    deployment/mutatingwebhook-ca-bundle.yaml
```

3. Deploy resources
```
kubectl apply -f deployment/nginxconfigmap.yaml
kubectl apply -f deployment/configmap.yaml
kubectl apply -f deployment/deployment.yaml
kubectl apply -f deployment/service.yaml
kubectl apply -f deployment/mutatingwebhook-ca-bundle.yaml
```

It will watch for all resources created in all namespaces.
If you want to restrict the namespaces where it applies, modified the expression at `deployment/mutatingwebhook.yaml`:
```
namespaceSelector:
      matchExpressions:
        - key: downwardapi-injector-disabled
          operator: DoesNotExist
```

or add label `downwardapi-injector-disabled=yes' to those namespaces you want to exlcude from the webhook.

## Deploy your apps

You will have to add the annotation `downwardapi.injector/inject=yes` in those resources where you want the Downward information is injected.

Deploy an app in Kubernetes cluster, take `sleep` app as an example
```
[root@mstnode ~]# cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  template:
    metadata:
      annotations:
        downwardapi.injector/inject: "yes"
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: tutum/curl
        command: ["/bin/sleep","infinity"]
        imagePullPolicy: 
EOF
```