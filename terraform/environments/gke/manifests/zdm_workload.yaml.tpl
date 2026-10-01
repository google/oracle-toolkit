apiVersion: v1
kind: Namespace
metadata:
  name: zdm-migration
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: zdm-k8s-sa
  namespace: zdm-migration
  annotations:
    iam.gke.io/gcp-service-account: zdm-gke-sa@${PROJECT_ID}.iam.gserviceaccount.com
---
apiVersion: v1
kind: Secret
metadata:
  name: zdm-ssh-keys
  namespace: zdm-migration
type: Opaque
stringData:
  id_rsa: |
${SSH_PRIVATE_KEY_INDENTED}
  id_rsa.pub: |
${SSH_PUBLIC_KEY_INDENTED}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zdm-base-pvc
  namespace: zdm-migration
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zdm-deployment
  namespace: zdm-migration
  labels:
    app: zdm-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zdm-service
  template:
    metadata:
      labels:
        app: zdm-service
    spec:
      serviceAccountName: zdm-k8s-sa
      securityContext:
        fsGroup: 1000
      containers:
        - name: zdm-container
          image: ${ZDM_IMAGE}
          ports:
            - containerPort: 8900
              name: mysql-port
            - containerPort: 8897
              name: rmi-port
            - containerPort: 8898
              name: http-port
          securityContext:
            runAsUser: 1000
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: zdm-base-volume
              mountPath: /u01/zdm/zdmbase
            - name: ssh-keys-volume
              mountPath: /home/zdmuser/.ssh
              readOnly: true
      volumes:
        - name: zdm-base-volume
          persistentVolumeClaim:
            claimName: zdm-base-pvc
        - name: ssh-keys-volume
          secret:
            secretName: zdm-ssh-keys
            defaultMode: 256 # equivalent to octal 0400
---
apiVersion: v1
kind: Service
metadata:
  name: zdm-service
  namespace: zdm-migration
spec:
  ports:
    - port: 8900
      targetPort: 8900
      name: mysql-port
    - port: 8897
      targetPort: 8897
      name: rmi-port
    - port: 8898
      targetPort: 8898
      name: http-port
  selector:
    app: zdm-service
  type: ClusterIP
