# ReplicaSets vs. Deployments

While both manage multiple Pods, a Deployment is a higher-level abstraction that manages ReplicaSets. In 99% of production cases, you should use a **Deployment**.

---

## 1. The Relationship

```
Deployment (The Boss)
    └── ReplicaSet (The Supervisor)
            └── Pods (The Workers)
```

1.  You create a **Deployment**.
2.  The Deployment creates a **ReplicaSet**.
3.  The ReplicaSet ensures the correct number of **Pods** are running.

---

## 2. Key Differences

| Feature | ReplicaSet | Deployment |
| :--- | :--- | :--- |
| **Primary Goal** | Desired count of identical Pods | Rolling Updates and Version Tracking |
| **Updating Pods** | **Difficult.** You must manually delete old Pods to get new ones. | **Automatic.** Performs a Rolling Update. |
| **Rollback** | **Manual.** No history kept. | **Easy.** `kubectl rollout undo`. |
| **Discrepancy** | High risk of "Mixed Generations" if template changes. | No risk. Deployment creates a new RS for new versions. |

---

## 3. The "Discrepancy" Problem in ReplicaSets

If you edit the Pod Template in a **ReplicaSet**:
1.  The existing Pods **stay as they are** (unaffected).
2.  Only **newly created** Pods (after a scale-up or crash) will use the new template.
3.  **Result:** You have "Mixed Generations" of Pods managed by the same object. This is a debugging nightmare.

---

## 4. How Deployments Solve It (Rolling Update)

When you change the template in a **Deployment**:
1.  The Deployment creates a **NEW** ReplicaSet.
2.  It scales **UP** the new RS (1 Pod at a time).
3.  It scales **DOWN** the old RS (1 Pod at a time).
4.  **Result:** A smooth transition where all old Pods are replaced by new ones.

---

## 5. When to use which?

*   **ReplicaSet:** Use it only when you need a static set of Pods that never change their image/config (rarely).
*   **Deployment:** Use it for everything else. It gives you lifecycle management (Update, Rollback, Pause).

---

## 6. CKA Exam Commands

### Deployment Rollouts
```bash
# Check status
kubectl rollout status deployment/my-app

# View history
kubectl rollout history deployment/my-app

# Rollback to previous version
kubectl rollout undo deployment/my-app
```

### Scale (Same for both)
```bash
kubectl scale deployment/my-app --replicas=5
kubectl scale rs/my-rs --replicas=5
```

---

## Summary

*   **ReplicaSets** focus on **keeping a set of pods running**.
*   **Deployments** focus on **how those pods evolve over time** (updates/rollbacks).
*   **Always use Deployments** to ensure consistent configuration across all Pods.
