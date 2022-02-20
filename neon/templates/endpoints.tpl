---
apiVersion: v1
kind: Service
metadata:
  name: postgres-svc
spec:
  ports:
    - port: 5432
      name: tcp5432
  type: ExternalName
  externalName: ${postgres_ip}
  clusterIP:
---
kind: Endpoints
apiVersion: v1
metadata:
  name: solana-svc
subsets:
  - addresses:
      - ip: ${solana_private_ip}
    ports:
      - port: 8899
        name: tcp8899
      - port: 8900
        name: tcp8900
---
kind: Service
apiVersion: v1
metadata:
  name: solana-svc
spec:
    ports:
      - port: 8899
        name: tcp8899
        targetPort: tcp8899
      - port: 8900
        name: tcp8900
        targetPort: tcp8900
