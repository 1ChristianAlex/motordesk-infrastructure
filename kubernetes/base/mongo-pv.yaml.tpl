apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-efs-pv
  labels:
    app.kubernetes.io/name: mongodb
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    namespace: motordesk
    name: data-mongo-0
  mountOptions:
    - tls
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${EFS_FILE_SYSTEM_ID}::${EFS_ACCESS_POINT_ID}"
