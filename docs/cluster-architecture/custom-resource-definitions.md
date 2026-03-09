# Custom Resource Definitions (CRDs)

In Kubernetes, **Custom Resource Definitions (CRDs)** allow you to extend the Kubernetes API by creating your own resource types. This turns Kubernetes into a platform that can manage anything, not just Pods and Services.

---

## 🏗️ 1. What is a CRD?

*   **Custom Resource (CR)**: An object that stores your custom data (e.g., a `Database` or a `Backup`).
*   **Custom Resource Definition (CRD)**: The blueprint or "schema" that tells Kubernetes what your Custom Resource looks like.
*   **Custom Controller (Operator)**: A piece of code that watches your Custom Resources and takes action (e.g., actually creating the database).

---

## 📄 2. Creating a CRD (The Blueprint)

This defines a new resource type called `Fruit` in the `my-domain.com` API group.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: fruits.my-domain.com
spec:
  group: my-domain.com
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
                color:
                  type: string
                sweetness:
                  type: integer
  scope: Namespaced
  names:
    plural: fruits
    singular: fruit
    kind: Fruit
    shortNames:
    - fr
```

---

## 🍎 3. Creating a Custom Resource (The Instance)

Once the CRD is applied, you can create instances of it just like a Pod.

```yaml
apiVersion: my-domain.com/v1
kind: Fruit
metadata:
  name: apple
spec:
  color: red
  sweetness: 8
```

---

## 🛠️ 4. Essential kubectl Commands

### Discovering CRDs
```bash
# List all CRDs installed in the cluster
kubectl get crd

# Describe a specific CRD to see its schema
kubectl describe crd fruits.my-domain.com
```

### Managing Custom Resources
```bash
# List instances of your custom resource (using short name)
kubectl get fr

# Get detailed info as YAML
kubectl get fruit apple -o yaml
```

---

## 🚀 5. The Operator Pattern

A CRD by itself is just a "database entry" in Etcd. To make it **do** something, you need an **Operator**.

1.  **User** creates a `Database` Custom Resource.
2.  **Operator** (running as a Pod) sees the new resource.
3.  **Operator** talks to AWS/GCP to provision a real database.
4.  **Operator** updates the `status` of the Custom Resource to "Running".

---

## 🚩 6. CKA Exam Perspective

1.  **API Discovery**: Use `kubectl api-resources` to see if a resource is a standard one or a Custom Resource. CRDs will have an API Group that isn't `v1` or `apps/v1` (e.g., `projectcalico.org`).
2.  **Short Names**: If you see a resource type you don't recognize (like `bc` or `prom`), it's likely a short name for a Custom Resource. Find it with: 
    `kubectl api-resources | grep <shortname>`
3.  **Scope**: Remember that CRDs themselves are **Cluster-Scoped**, but the resources they define can be either **Namespaced** or **Cluster-Scoped**.

---

> [!TIP]
> **API Groups**: Standard Kubernetes resources are in the `core` group (empty string) or named groups like `apps`. Custom Resources ALWAYS have a domain-style group like `stable.example.com`.
