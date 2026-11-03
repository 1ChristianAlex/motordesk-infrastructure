apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: motordesk
spec:
  provider:
    aws:
      service: SecretsManager
      region: "${AWS_REGION}"
---
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-parameter-store
  namespace: motordesk
spec:
  provider:
    aws:
      service: ParameterStore
      region: "${AWS_REGION}"
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: motordesk-runtime
  namespace: motordesk
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: motordesk-runtime
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_PASSWORD
      remoteRef:
        key: "${POSTGRES_SECRET_ARN}"
        property: password
    - secretKey: REDIS_PASSWORD
      remoteRef:
        key: "${REDIS_SECRET_ARN}"
    - secretKey: JWT_SECRET
      remoteRef:
        key: "${JWT_SECRET_ARN}"
    - secretKey: MONGO_ROOT_USERNAME
      remoteRef:
        key: "${MONGO_SECRET_ARN}"
        property: root_username
    - secretKey: MONGO_ROOT_PASSWORD
      remoteRef:
        key: "${MONGO_SECRET_ARN}"
        property: root_password
    - secretKey: MONGO_USER
      remoteRef:
        key: "${MONGO_SECRET_ARN}"
        property: username
    - secretKey: MONGO_PASSWORD
      remoteRef:
        key: "${MONGO_SECRET_ARN}"
        property: password
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: motordesk-parameters
  namespace: motordesk
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-parameter-store
    kind: SecretStore
  target:
    name: motordesk-parameters
    creationPolicy: Owner
  data:
    - secretKey: AWS_REGION
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/aws-region"
    - secretKey: AWS_SES_FROM_ADDRESS
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/ses-from-address"
    - secretKey: JWT_ISSUER
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/jwt-issuer"
    - secretKey: JWT_AUDIENCE
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/jwt-audience"
    - secretKey: JWT_REALM
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/jwt-realm"
    - secretKey: DATABASE_URL
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/database-url"
    - secretKey: DATABASE_USER
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/database-user"
    - secretKey: REDIS_HOST
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/redis-host"
    - secretKey: MONGO_DATABASE
      remoteRef:
        key: "${PARAMETER_STORE_PREFIX}/mongo-database"
