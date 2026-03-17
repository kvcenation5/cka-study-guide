# CKA Exam Tips — VDI, Mac Mini & Performance Guide

> A comprehensive guide to surviving and thriving in the CKA exam, with a focus on PSI VDI lag, Mac Mini optimisations, and exam-day efficiency.

---

## Mac Mini Setup — Before Exam Day

### Network & Hardware

- Use **wired Ethernet** — the Mac mini's built-in port is your biggest advantage over laptop users
- If you lose connectivity during the exam, you'll have to go through the full ID verification process again, losing valuable exam time — make it wired and reliable
- Keep a **mobile 4G dongle** as a backup in case broadband fails mid-exam
- Connect your broadband router to a **UPS (uninterruptible power supply)**

### Mac-Specific Fixes

- **Turn off Bluetooth** — disables SideCarRelay which causes keyboard input to appear as `ddddeploy` instead of `deploy` (documented Mac mini bug)
- Allow PSI Secure Browser in **System Preferences → Security & Privacy → Privacy** for:
    - Microphone
    - Camera
    - Automation
    - Input Monitoring
- Even if your Mac passes all PSI system checks, the exam may not start — have a backup PC plan

### Disk & System

- Keep at least **15–20 GB of free disk space** — PSI software takes up a significant chunk
- Restart your Mac fresh **30–60 minutes** before exam time
- Close all foreground processes before launching the exam including:
    - Programs in the system tray
    - Hypervisor services (Parallels, VMware)
    - Any command prompts opened by services

### Monitor

- PSI Secure Browser will **refuse to start** if it detects more than one enabled monitor — disconnect all extra displays
- Use the **largest single screen** you have for more real estate in the XFCE desktop

### PSI Browser

- Always download a **fresh copy** of PSI Secure Browser using the link provided at exam launch — uninstall any previous version first
- You can start the exam **30 minutes early** — use this time to troubleshoot check-in, webcam, and room scanning before the clock starts

---

## First 5 Minutes — Terminal Setup

Do this **immediately** before touching any question. It's the highest ROI time you'll spend.

### Aliases

```bash
alias k=kubectl
alias kgp="k get pod"
alias kgd="k get deploy"
alias kgs="k get svc"
alias kgn="k get nodes"
alias kd="k describe"
alias kge="k get events --sort-by='.metadata.creationTimestamp' | tail -8"
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"
source <(kubectl completion bash)
complete -F __start_kubectl k
```

!!! tip "CKA Alias Trick"
    In the CKA exam, you SSH into a separate node for each question — saving aliases to `~/.bashrc` 16 times will kill your time.
    **Better approach:** Open a text file using MousePad at the start, write all your alias statements there, and after SSH-ing into each cluster, copy and paste the aliases directly into the terminal.

### vim Setup

```bash
cat >> ~/.vimrc << EOF
set expandtab
set tabstop=2
set shiftwidth=2
set paste
EOF
```

### Copy/Paste in the VDI

- In the Linux terminal: use `Ctrl+Shift+C` and `Ctrl+Shift+V`, or right-click menus
- In Firefox (for docs): use standard `Ctrl+C` / `Ctrl+V`
- Always **wait a beat** after copying before pasting — clipboard lag can silently drop content

### Critical Keyboard Safety

!!! warning "Important"
    - Use **`Ctrl+Alt+W`** instead of `Ctrl+W` — pressing `Ctrl+W` will **close the browser window**, not the terminal tab
    - **Never reboot** the base node (hostname `base`) — rebooting will NOT restart your exam environment

---

## Speed & Efficiency During the Exam

### kubectl Power Moves

```bash
# Generate YAML skeletons — faster than typing from scratch
k run nginx --image=nginx $do > pod.yaml
k create deployment web --image=nginx $do > deploy.yaml

# Force delete stuck pods immediately
k delete pod test $now

# Edit live resources without recreating
k edit deployment my-deploy

# Use --help for built-in examples
kubectl run --help
kubectl create --help
```

### Context Switching (Critical in CKA)

Each exam task uses a **different cluster** — a single missed `exit` or mis-scoped kubectl context can derail your workflow.

- Always run the context command shown at the top of each question before anything else:

```bash
kubectl config use-context <context-name>
```

- Validate your scope before executing commands
- Always run `exit` when done with an SSH session

### tmux (Optional but Useful)

With the GUI desktop environment, tmux is optional since you can open multiple terminal windows. It's most useful when running the same commands on multiple nodes simultaneously.

```bash
cat << EOF > ~/.tmux.conf
set -g default-shell /bin/bash
set -g mouse on
bind -n C-x setw synchronize-panes
EOF
```

### VDI Display Tips

- Use `+` / `-` in the PSI Secure Browser toolbar to adjust font size
- Drag the border between the question panel and remote desktop to resize
- Shrink the toolbar by toggling next to your video thumbnail to gain more screen space

---

## Time Management Strategy

| Guideline | Detail |
|---|---|
| **Target buffer** | Aim to have 45 minutes remaining before the exam ends to revisit flagged questions |
| **Easy-first approach** | ~70% of questions are straightforward — secure full points on those first |
| **Passing score** | You only need **66%** to pass — don't chase perfection on every question |
| **Partial credit** | You may earn partial credit by completing some components of a multi-part question |
| **High-weight domains** | Troubleshooting + Cluster Architecture = over half your potential score |
| **Final review** | Keep 10–15 minutes at the end for a final sweep |

---

## Documentation Navigation

!!! info "Allowed Sites"
    - [kubernetes.io](https://kubernetes.io)
    - [Kubernetes Blog](https://kubernetes.io/blog)
    - [Helm Docs](https://helm.sh/docs)
    - [Gateway API Docs](https://gateway-api.sigs.k8s.io)

**Tips:**

- Use `Ctrl+F` on docs pages instead of scrolling — scrolling in the VDI is sluggish
- Pre-memorise key doc paths:
    - `/docs/tasks/`
    - `/docs/concepts/`
    - `/docs/reference/`
- Practice navigating docs from scratch during killer.sh sessions (no pre-saved bookmarks in PSI browser)

---

## Practice Resources

| Resource | Why It Matters |
|---|---|
| **killer.sh** | Included free with your exam (2 sessions, 36hr each). Use one a week before, one the day before |
| **KodeKloud (Mumshad)** | Best foundational course — explanations, diagrams, and labs |
| **KillerCoda** | Free browser-based scenarios in a Linux GUI desktop mirroring the exam layout |
| **Timed practice** | Speed matters — always practice with a timer, aim to finish with 10–15 min spare |

---

## If Things Go Wrong

- **VDI freezes or disconnects** → Contact proctor immediately via chat; the timer can be paused for proctor-side issues
- **Keyboard stops working** → Exit and restart PSI browser; your exam state is saved
- **Webcam not detected** → Some webcam models are incompatible with PSI Browser — test this well in advance with a USB webcam
- **After the exam** → If you had technical problems, open a ticket at [trainingsupport.linuxfoundation.org](https://trainingsupport.linuxfoundation.org) immediately

---

## Pre-Exam Checklist

- [ ] Plug in Ethernet (not Wi-Fi)
- [ ] Turn off Bluetooth (Mac-specific fix)
- [ ] Restart Mac fresh
- [ ] Disconnect all extra monitors
- [ ] Close all apps & background services
- [ ] 15–20 GB free disk space confirmed
- [ ] UPS connected to router
- [ ] 4G dongle ready as backup
- [ ] Download fresh PSI browser (available 30 min before)
- [ ] PSI Privacy permissions granted (mic, camera, input monitoring)
- [ ] Valid ID ready
- [ ] Clear desk, water nearby
- [ ] Join 30 minutes early
- [ ] Alias + vimrc text ready to paste from MousePad

---

## Why Physical Test Centres Don't Help

The CKA is an **online proctored exam only** — there are no physical test centre options. Every candidate worldwide goes through the same PSI remote desktop VDI experience. This means your Mac mini at home is actually one of the **better setups** you can have:

- Full control over your environment
- Native Ethernet port
- No shared bandwidth
- No restrictions on hardware

---

*Good luck! 🎯 You've got this.*
