# MkDocs Material Setup Guide

This guide documents the complete setup process for creating a local documentation site using MkDocs Material for CKA exam notes.

## Prerequisites

- macOS system
- Homebrew package manager installed
- Python 3 installed

## Installation Steps

### Step 1: Install MkDocs Material

```bash
# Unlink existing mkdocs if installed
brew unlink mkdocs

# Install MkDocs Material (includes MkDocs + Material theme)
brew install mkdocs-material
```

## Project Structure Setup

### Step 2: Directory Structure

Your project should have this structure:

```
/Users/dhee/k8s/CKA/
├── mkdocs.yml          # Configuration file
└── docs/               # Documentation folder
    ├── README.md
    ├── SUMMARY.md
    ├── *.md files
    └── *.png files (diagrams)
```

**Important:**
- `mkdocs.yml` must be in the parent directory
- All documentation files go in the `docs/` folder
- MkDocs expects this parent/child relationship

### Step 3: Create Configuration File

Create `mkdocs.yml` in `/Users/dhee/k8s/CKA/`:

```yaml
site_name: CKA Exam Notes - Kubernetes Troubleshooting
site_description: Complete Kubernetes Troubleshooting Guide for CKA Exam Preparation

# Point to your docs folder
docs_dir: docs

theme:
  name: material
  palette:
    # Light mode
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    # Dark mode
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.top
    - search.highlight
    - content.code.copy

markdown_extensions:
  - pymdownx.highlight
  - pymdownx.superfences
  - admonition
  - tables
  - attr_list
  - md_in_html

# Page navigation
nav:
  - Home: README.md
  - Summary: SUMMARY.md
  - Architecture: BETTER_ARCHITECTURE.md
  - Components: KNOW_YOUR_COMPONENTS.md
  - StatefulSet & PVC: statefulset-pvc-explained.md
  - Diagrams:
      - Troubleshooting Flowchart: troubleshooting-flowchart.md
      - StatefulSet Architecture: statefulset-architecture.md
      - Network Policy Architecture: network-policy-architecture.md

plugins:
  - search

extra:
  generator: false
```

## Handling Images/Diagrams

### Step 4: Create Markdown Wrappers for Images

**Problem:** MkDocs cannot display PNG files directly as pages.

**Solution:** Create markdown files that embed the images.

For each diagram PNG file, create a corresponding `.md` file:

**Example - troubleshooting-flowchart.md:**
```markdown
# Kubernetes Troubleshooting Flowchart

This flowchart provides a systematic approach to troubleshooting common Kubernetes issues.

![Troubleshooting Flowchart](troubleshooting-flowchart-detailed.png)

## Additional context or notes here...
```

**Image syntax:**
```markdown
![Alt Text](image-filename.png)
```

The image path is relative to the markdown file location (both in `docs/` folder).

## Running the Site

### Step 5: Start MkDocs Server

**Option 1: Foreground (recommended for development)**
```bash
cd /Users/dhee/k8s/CKA
mkdocs serve
```

Access at: `http://127.0.0.1:8000`

**Option 2: Background (persistent)**
```bash
cd /Users/dhee/k8s/CKA
nohup mkdocs serve > mkdocs.log 2>&1 &
```

To stop background process:
```bash
pkill -f "mkdocs serve"
```

To check logs:
```bash
tail -f /Users/dhee/k8s/CKA/mkdocs.log
```

### Step 6: Auto-Reload

MkDocs has auto-reload enabled by default:
- Edit any `.md` file or `mkdocs.yml`
- Save the file
- Browser automatically refreshes
- Check terminal for rebuild messages

If auto-reload doesn't work:
1. Stop the server (Ctrl+C or pkill)
2. Restart: `mkdocs serve`
3. Hard refresh browser: Cmd+Shift+R (macOS)

## Common Issues & Solutions

### Issue 1: "docs_dir should not be parent directory"

**Error:**
```
ERROR - Config value 'docs_dir': The 'docs_dir' should not be the parent
directory of the config file.
```

**Solution:**
- Ensure `mkdocs.yml` is in parent directory (e.g., `/Users/dhee/k8s/CKA/`)
- Set `docs_dir: docs` in config
- Never use `docs_dir: .` when config is in same directory as docs

### Issue 2: "File not found in documentation"

**Error:**
```
WARNING - A reference to 'filename.md' is included in the 'nav'
configuration, which is not found in the documentation files.
```

**Solution:**
- Verify file exists: `ls docs/filename.md`
- Check filename spelling in `nav:` section
- Restart mkdocs: `pkill -f "mkdocs serve" && mkdocs serve`

### Issue 3: Images Not Displaying

**Problem:** PNG files referenced in nav show 404 errors.

**Solution:**
- Don't reference PNG files directly in `nav:`
- Create markdown wrapper files (see Step 4)
- Reference the `.md` files in nav, not `.png` files

### Issue 4: 404 on Newly Created Files

**Problem:** File exists but shows 404 in browser.

**Solution:**
```bash
# Restart mkdocs to rebuild site
pkill -f "mkdocs serve"
cd /Users/dhee/k8s/CKA
mkdocs serve
```

Then hard refresh browser (Cmd+Shift+R).

## Building Static Site (Optional)

To generate static HTML files for deployment:

```bash
cd /Users/dhee/k8s/CKA
mkdocs build
```

Output will be in `site/` directory.

To deploy to GitHub Pages:
```bash
mkdocs gh-deploy
```

## Useful Commands

```bash
# Verify mkdocs installation
mkdocs --version

# Create new project
mkdocs new my-project

# Build documentation
mkdocs build

# Serve with custom port
mkdocs serve -a 127.0.0.1:8080

# Check for errors
mkdocs build --strict

# Clean build directory
rm -rf site/
```

## Customization Tips

### Change Theme Colors

In `mkdocs.yml`, modify:
```yaml
theme:
  palette:
    - scheme: default
      primary: blue  # Change to: red, pink, purple, indigo, blue, etc.
      accent: blue
```

### Add Custom CSS

1. Create `docs/stylesheets/extra.css`
2. Add to `mkdocs.yml`:
```yaml
extra_css:
  - stylesheets/extra.css
```

### Add More Navigation Sections

```yaml
nav:
  - Home: index.md
  - Getting Started:
      - Installation: getting-started/installation.md
      - Quick Start: getting-started/quickstart.md
  - Advanced:
      - Topic 1: advanced/topic1.md
```

## File Locations Reference

| Item | Path |
|------|------|
| Config File | `/Users/dhee/k8s/CKA/mkdocs.yml` |
| Docs Folder | `/Users/dhee/k8s/CKA/docs/` |
| Log File | `/Users/dhee/k8s/CKA/mkdocs.log` |
| Built Site | `/Users/dhee/k8s/CKA/site/` |
| Local URL | `http://127.0.0.1:8000` |

## Quick Start Checklist

- [ ] Install mkdocs-material via Homebrew
- [ ] Create project structure (parent dir + docs/ folder)
- [ ] Create mkdocs.yml configuration file
- [ ] Set `docs_dir: docs` in config
- [ ] Add markdown files to docs/ folder
- [ ] Create .md wrappers for any .png diagrams
- [ ] Configure nav section in mkdocs.yml
- [ ] Run `mkdocs serve` from parent directory
- [ ] Access site at http://127.0.0.1:8000
- [ ] Verify all pages and images load correctly

## Additional Resources

- **MkDocs Documentation:** https://www.mkdocs.org/
- **Material Theme Docs:** https://squidfunk.github.io/mkdocs-material/
- **Markdown Guide:** https://www.markdownguide.org/
- **Material Theme Customization:** https://squidfunk.github.io/mkdocs-material/customization/

## Summary

This setup provides:
- ✅ Beautiful, responsive documentation site
- ✅ Dark/light mode toggle
- ✅ Built-in search functionality
- ✅ Auto-reload during development
- ✅ Mobile-friendly design
- ✅ Code syntax highlighting
- ✅ Easy to maintain and update

Perfect for CKA exam preparation and technical documentation!
