apiVersion: apps/v1
kind: Deployment
metadata:
  name: bert-deployment
spec:
  selector:
    matchLabels:
      app: Bert
  replicas: 1
  template:
    metadata:
      labels:
        app: Bert
    spec:
      containers:
      - name: bert-container
        image: CONTAINER_IMAGE
        resources:
            limits:
             nvidia.com/gpu: GPU_COUNT
        readinessProbe:
          httpGet:
            path: /status/client
            port: 8125
          timeoutSeconds: 2
        ports:
        - containerPort: 8125
