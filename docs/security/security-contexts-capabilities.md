# Security Contexts & Linux Capabilities

In Kubernetes, the **Security Context** defines the privilege and access control settings for a Pod or Container. This is where you control whether a process can run as root, what parts of the host it can see, and what specific powers (Capabilities) it has.

---

## 🏗️ 1. Container Root vs. Host Root

A common misconception is that "Root inside a Pod" is safe because it is "namespaced." 

### The Reality:
By default, the `root` user (UID 0) inside a container is the **same** `root` user as on the host machine. While Linux Namespaces (Mount, Network, PID) provide isolation, if a container process escapes, it has full root privileges on your worker node.

### How to deal with it:
*   **User Namespaces (USNS)**: (Available in newer K8s versions) This maps UID 0 (root) inside the container to a non-zero UID (e.g., 10000) on the host. Even if the process escapes, it is just a regular user on the host.
*   **runAsNonRoot**: A directive that forces the container to fail if it tries to start as the root user.

---

## 🛠️ 2. Capabilities: Adding and Dropping

Linux does not just have "Root" and "User." It has **Capabilities**—fine-grained units of power. Instead of giving a Pod full root access just to change the system time, you can give it exactly one capability.

### ⬇️ Dropping Privileges (The Secure Default)
The most secure practice is to drop **ALL** default capabilities and then add back only what you need.

```yaml
spec:
  containers:
  - name: secure-app
    image: nginx
    securityContext:
      capabilities:
        drop:
          - ALL # Removes even basic powers like 'CHOWN' or 'SETUID'
```

### ⬆️ Adding Specific Privileges
Use this for networking tools or system utilities.

```yaml
securityContext:
  capabilities:
    add:
      - NET_ADMIN  # Can modify network interfaces/iptables
      - SYS_TIME   # Can change the system clock
```

---

## 🚀 3. Full Privileges (`privileged: true`)

Setting `privileged: true` is essentially turning off all security. 
*   **What it does**: It gives the container access to all devices on the host and grants nearly all capabilities.
*   **Use Case**: Only for infrastructure pods like `kube-proxy`, `calico` (CNI), or storage drivers that must talk directly to hardware.
*   **Risk**: If a `privileged` pod is compromised, the **entire worker node** is compromised.

---

## 📄 4. Practical YAML Example

Here is a hardened Pod definition that follows the "Least Privilege" principle.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
spec:
  securityContext:
    # Set at the POD level
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000 # Files created in volumes will belong to this group
  containers:
  - name: app
    image: my-app:v1
    securityContext:
      # Set at the CONTAINER level (overrides pod level)
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE # Allows binding to ports < 1024
```

---

## 📊 5. Hierarchy and Inheritance: Pod Level vs. Container Level

Security settings can be applied at two levels. Understanding the inheritance is critical for the CKA exam.

### The Inheritance Rule:
> **Container-level settings always override Pod-level settings.** If a setting is defined in both places, the container-specific value is what actual process uses.

| Setting | Pod Level (`spec.securityContext`) | Container Level (`spec.containers[].securityContext`) | Available? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **runAsUser / runAsGroup** | ✅ | ✅ | **Both** | Pod level acts as the default for all containers. |
| **runAsNonRoot** | ✅ | ✅ | **Both** | Forces the container to fail if UID is 0. |
| **seccompProfile** | ✅ | ✅ | **Both** | Restricts system calls. |
| **fsGroup** | ✅ | ❌ | **Pod Only** | Applies to volume permissions. |
| **Capabilities (add/drop)** | ❌ | ✅ | **Container Only** | Manage Linux-level powers. |
| **Privileged** | ❌ | ✅ | **Container Only** | Full host access. |
| **allowPrivilegeEscalation**| ❌ | ✅ | **Container Only** | Prevents gaining more power than parent. |
| **readOnlyRootFilesystem** | ❌ | ✅ | **Container Only** | Locks the container's disk. |

---

## 🧪 6. Practical Scenario: Overriding the Pod Default

Suppose you want all containers in a pod to run as `user 1000`, but one specific "helper" container needs to run as `user 2000`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: complex-security-demo
spec:
  securityContext:
    runAsUser: 1000 # Default for all containers
  containers:
  - name: main-app
    image: nginx
    # Inherits runAsUser: 1000
  - name: helper-tool
    image: busybox
    securityContext:
      runAsUser: 2000 # OVERRIDES the pod default for this container only
```

---

## 🧪 6. Inspecting Privileges at Runtime

To see what user a pod is actually running as:
```bash
kubectl exec <pod-name> -- id
# Output: uid=1000(user) gid=3000(group) groups=3000(group),2000(fsgroup)
```

To see what capabilities a process has (requires `libcap` to be in the image):
```bash
kubectl exec <pod-name> -- capsh --print
```

---

## 📄 7. Master YAML Example: Pod vs. Container

This example combines all concepts: Pod-level defaults, Container-level overrides, and specific Container-only privileges.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-master-demo
spec:
  # --- POD LEVEL SETTINGS ---
  # These apply to ALL containers in the pod unless overridden
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000 # Only available at Pod level
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: web-app
    image: nginx
    # Inherits: runAsUser: 1000, runAsGroup: 3000, seccompProfile
    securityContext:
      # --- CONTAINER LEVEL ONLY ---
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE # Allow port 80

  - name: admin-helper
    image: busybox
    command: ["sh", "-c", "sleep 1h"]
    # OVERRIDES Pod Level settings
    securityContext:
      runAsUser: 0      # Overrides Pod default (Runs as Root!)
      privileged: true  # Full host access (Dangerous!)
```

---

> [!WARNING]
> **allowPrivilegeEscalation**: Even if you run as a non-root user, a process can still gain root if there are "setuid" binaries in the image. Always set `allowPrivilegeEscalation: false` to prevent child processes from gaining more privileges than their parent.
