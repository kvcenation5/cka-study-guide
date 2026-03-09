# CRD & Custom Resource: Hands-on YAML Examples

To use a Custom Resource, you must follow a two-step process: First, apply the **Definition (The Blueprint)**, and then create the **Resource (The Instance)**.

---

## 🏗️ 1. The Blueprint (CustomResourceDefinition)

This YAML defines a new resource type called `Database` in the `infra.mycompany.io` API group.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # name must match: <plural>.<group>
  name: databases.infra.mycompany.io
spec:
  group: infra.mycompany.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                engine:
                  type: string
                version:
                  type: string
                storageGB:
                  type: integer
  scope: Namespaced # This resource will live inside a namespace
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
```

---

## 💾 2. The Instance (Custom Resource)

After applying the CRD above (`kubectl apply -f crd.yaml`), you can now create a "Database" object just like you would a Pod or Deployment.

```yaml
apiVersion: infra.mycompany.io/v1
kind: Database
metadata:
  name: production-mysql
  namespace: default
spec:
  engine: "mysql"
  version: "8.0"
  storageGB: 50
```

---

## 🧪 3. Verification Commands

Once both are applied, use these standard Kubernetes commands to interact with your custom object:

### See the Definition
```bash
kubectl get crd databases.infra.mycompany.io
```

### See your Custom Resources
```bash
# Using the plural name
kubectl get databases

# Using the short name (db) defined in the CRD
kubectl get db
```

### Inspect the Instance
```bash
kubectl describe db production-mysql
```

---

> [!IMPORTANT]
> **Why doesn't it run?** 
> If you apply these YAMLs, you will see the `Database` object in `kubectl get db`, but nothing will actually happen in your cloud (No real MySQL will be created). This is because you still need an **Operator (Controller)** pod running in your cluster that is programmed to watch for these objects and fulfill their requests.
