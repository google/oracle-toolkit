apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ogg-trail-pvc
  namespace: zdm-migration
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: hyperdisk-balanced
  resources:
    requests:
      storage: 100Gi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: goldengate-pdb
  namespace: zdm-migration
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: goldengate
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: goldengate-deployment
  namespace: zdm-migration
  labels:
    app: goldengate
spec:
  replicas: 1
  selector:
    matchLabels:
      app: goldengate
  template:
    metadata:
      labels:
        app: goldengate
    spec:
      serviceAccountName: ogg-service-account
      containers:
        - name: goldengate
          image: ${OGG_IMAGE}
          ports:
            - containerPort: 9011
              name: servicemanager
            - containerPort: 9012
              name: admin-server
            - containerPort: 9013
              name: dist-server
            - containerPort: 9014
              name: recv-server
            - containerPort: 9015
              name: metrics-server
          env:
            - name: OGG_ADMIN_USER
              value: oggadmin
            - name: OGG_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ogg-admin-secret
                  key: password
                  optional: true
          volumeMounts:
            - name: ogg-storage
              mountPath: /u01/app/goldengate/dirdat
      volumes:
        - name: ogg-storage
          persistentVolumeClaim:
            claimName: ogg-trail-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: goldengate-service
  namespace: zdm-migration
spec:
  ports:
    - port: 9011
      targetPort: 9011
      name: sm-admin
    - port: 9012
      targetPort: 9012
      name: ogg-admin
    - port: 9013
      targetPort: 9013
      name: ogg-dist
    - port: 9014
      targetPort: 9014
      name: ogg-recv
    - port: 9015
      targetPort: 9015
      name: ogg-metrics
  selector:
    app: goldengate
  type: ClusterIP
