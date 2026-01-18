# A Quick Note on Editing Resources

In Kubernetes, the rules for editing a resource depend heavily on whether you are touching a **Pod** directly or a **Controller** (like a Deployment).

---

## 1. Editing a POD
Pods are considered **immutable** (unchangeable). Once a Pod is born, most of its DNA is locked.

### What you CAN edit on a running Pod:
*   `spec.containers[*].image` (Changing the image)
*   `spec.initContainers[*].image`
*   `spec.activeDeadlineSeconds`
*   `spec.tolerations`

### What you CANNOT edit:
You cannot change environment variables, labels (on the spec), service accounts, or resource limits on a **running** pod.

### How to "Edit" a Pod anyway (Exam Tricks):

#### Option 1: The `edit` failure shortcut
1.  Run `kubectl edit pod <pod-name>`.
2.  Make your changes.
3.  When you save, Kubernetes will **deny** the change and tell you it's not editable.
4.  **Crucially**: It will tell you it saved your changes to a **temporary file** (e.g., `/tmp/kubectl-edit-ccvrq.yaml`).
5.  **Action**: 
    ```bash
    kubectl delete pod <pod-name>
    kubectl create -f /tmp/kubectl-edit-xxxx.yaml
    ```

#### Option 2: The YAML export (Safer)
1.  Extract the YAML:
    ```bash
    kubectl get pod <pod-name> -o yaml > my-new-pod.yaml
    ```
2.  Edit the file manually using `vi` or `nano`.
3.  Delete the old pod:
    ```bash
    kubectl delete pod <pod-name>
    ```
4.  Create the new pod:
    ```bash
    kubectl create -f my-new-pod.yaml
    ```

---

## 2. Editing DEPLOYMENTS
Deployments are much smarter. You can edit **any** field in the Pod template because the Deployment controller handles the lifecycle for you.

### How it works:
When you edit a Deployment, it notices the change, triggers a **Rolling Update**, kills the old pods, and spawns new ones with your updated settings.

### The Command:
```bash
kubectl edit deployment my-deployment
```

**CKA Tip**: If you are asked to change environment variables or resource limits for a Pod that belongs to a Deployment, **ALWAYS** edit the Deployment, not the individual Pod.
