# Developing Custom Controllers

A **Custom Controller** is the engine that makes Custom Resources (CRDs) actually *do* something. It follows the core Kubernetes **Control Loop** pattern to bring the current state of the cluster closer to the desired state.

---

## 🏗️ 1. The Control Loop Pattern

All controllers in Kubernetes (like the Deployment or ReplicaSet controllers) follow a simple, infinite loop:

1.  **Observe**: Watch for changes to specific resources (e.g., a new `Database` CR).
2.  **Diff**: Compare the **Desired State** (what's in the YAML) with the **Current State** (what's actually running).
3.  **Act**: Perform the necessary steps to fix the difference (e.g., create an RDS instance in AWS).

---

## 🛠️ 2. Key Internal Components

When developing a controller (usually in Go), you use several core concepts from `client-go`:

| Component | Responsibility |
| :--- | :--- |
| **Informer** | Watches the API server and maintains a local cache of resources. This prevents overloading the API. |
| **SharedInformer** | A central cache shared by multiple controllers to save memory. |
| **Workqueue** | A queue that stores keys (e.g., `namespace/name`) of resources that need reconciliation. Supports retries and rate limiting. |
| **Lister** | Provides a simple API to retrieve resources directly from the Informer's cache. |
| **Reconciler** | The function where your logic lives. It gets a "key," fetches the resource, and decides what to do. |

---

## 🚀 3. Popular Frameworks (The Standard Way)

Writing a controller from scratch with `client-go` is complex. Most developers use one of these high-level frameworks:

### A. Kubebuilder
The "SDK for Kubernetes APIs." It uses a tool called `controller-runtime` and provides scaffolding for your project.
*   **Workflow**: `kubebuilder init` -> `kubebuilder create api` -> Edit `Reconcile()` function.

### B. Operator SDK
Formerly separate, now built on top of Kubebuilder. It adds extra tools for metadata, lifecycle management (OLM), and supports writing operators in **Ansible** or **Helm** (not just Go).

---

## 🧪 4. Example: A "Database" Reconcile Loop

Imagine your "Database" controller's `Reconcile` function:

```go
func (r *DatabaseReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. Fetch the Database instance from the cache
    db := &infrav1.Database{}
    if err := r.Get(ctx, req.NamespacedName, db); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 2. Diff: Check if a real database exists in the cloud
    exists, err := cloudProvider.CheckDatabase(db.Name)
    
    // 3. Act: If it doesn't exist, create it!
    if !exists {
        log.Info("Creating real database", "name", db.Name, "engine", db.Spec.Engine)
        err := cloudProvider.CreateDatabase(db.Spec.Engine, db.Spec.StorageGB)
        if err != nil {
            return ctrl.Result{Requeue: true}, err // Retry if it fails
        }
    }

    return ctrl.Result{}, nil // Success!
}
```

---

## 🚩 5. CKA Exam Perspective

*   **Recognition**: You don't need to write Go code in the CKA, but you MUST know that a CRD is useless without a controller/operator.
*   **Troubleshooting**: If a Custom Resource is "stuck" or not doing anything, check the **Logs of the Controller Pod**.
    *   Example: `kubectl logs -n operator-system deployment/database-controller`
*   **Finalizers**: If you can't delete a Custom Resource, it's usually because the controller has added a **Finalizer** to the metadata and is waiting to finish cleanup.

---

> [!TIP]
> **Events**: Always make your controller emit "Events" when it takes action. This allows users to see what's happening via `kubectl describe`.
> `kubectl get events --field-selector involvedObject.kind=Database`
