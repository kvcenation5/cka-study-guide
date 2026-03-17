# IP Address Management (IPAM) in CNI

This section covers how virtual bridge networks in the nodes are assigned an IP subnet, and how pods are assigned an IP. It does *not* concern the IP addresses assigned to the nodes themselves (which are managed externally or by the infrastructure).

## Who is Responsible?

According to CNI standards, it is the responsibility of the **CNI plugin** (the network solution provider) to take care of assigning IP addresses to the containers.

Kubernetes doesn't care exactly *how* it's done, as long as the plugin ensures:
- IPs are assigned to the container network namespace
- No duplicate IPs are assigned
- The IP pool is managed properly

## How are IPs Managed?

A simple approach to IP management is to store the list of assigned IPs in a local file and make sure the network script manages this file properly. This file would be placed on each host and manage the IPs of pods specifically for that node.

Instead of writing custom code to manage this file state in every script, CNI comes with two built-in IPAM (IP Address Management) plugins to which you can outsource this task:

1. **host-local**
2. **dhcp**

### The `host-local` Plugin

The `host-local` plugin implements the approach of managing IP addresses locally on each host. It stores the state of allocated IPs locally on the host's filesystem. 

Even though it is a built-in plugin, it is still the responsibility of the overall CNI network script to invoke the `host-local` plugin.

### CNI Configuration for IPAM

Instead of hardcoding the main script to always use the `host-local` plugin, we can make the script dynamic to support different kinds of IPAM plugins. 

The CNI configuration file has a specific section called `ipam` where we can specify:
- The `type` of IPAM plugin to be used
- The `subnet` to be used
- The `routes` to be configured

These details can be read from the script to invoke the appropriate IPAM plugin dynamically.

**Example CNI Configuration with IPAM:**
```json
{
  "cniVersion": "0.3.1",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.22.0.0/16",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
```
