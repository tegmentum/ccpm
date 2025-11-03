# Phase 4 Update: DNF Package Manager Support

## Overview

Added support for DNF-based Linux distributions (Fedora, RHEL, CentOS, Rocky Linux, etc.) to the init script.

## Changes Made

### File Modified
- `.claude/scripts/init.sh`

### What Was Added

1. **Package Manager Detection Function**
   ```bash
   detect_package_manager()
   ```
   Automatically detects which package manager is available:
   - `brew` (macOS)
   - `apt` (Debian, Ubuntu, Linux Mint, etc.)
   - `dnf` (Fedora, RHEL 8+, CentOS 8+, Rocky Linux, AlmaLinux)
   - `yum` (older RHEL/CentOS systems)
   - `unknown` (fallback)

2. **Generic Install Function**
   ```bash
   install_package(package_name, brew_name, apt_name, dnf_name)
   ```
   Installs packages using the detected package manager with proper package names for each system.

### Supported Distributions

**macOS:**
- Homebrew

**Debian/Ubuntu-based:**
- Debian
- Ubuntu
- Linux Mint
- Pop!_OS
- Elementary OS
- etc.

**Red Hat-based:**
- Fedora (dnf)
- RHEL 8+ (dnf)
- CentOS 8+ (dnf)
- Rocky Linux (dnf)
- AlmaLinux (dnf)
- RHEL 7 and older (yum)
- CentOS 7 and older (yum)

### Dependencies Installation

All dependencies are automatically installed on supported systems:

| Dependency | brew | apt | dnf/yum |
|------------|------|-----|---------|
| GitHub CLI | `gh` | `gh` | `gh` |
| jq | `jq` | `jq` | `jq` |
| SQLite | `sqlite` | `sqlite3` | `sqlite` |
| DuckDB | `duckdb` | manual | manual |

**Note:** DuckDB is installed from GitHub releases on Linux systems (both apt and dnf) as it's not available in default repositories.

## Testing

The init script will:
1. Detect your package manager automatically
2. Install missing dependencies
3. Show clear status messages
4. Fall back to manual installation instructions if package manager not supported

### Test on Different Systems

**macOS:**
```bash
.claude/scripts/init.sh
# Uses brew
```

**Ubuntu/Debian:**
```bash
.claude/scripts/init.sh
# Uses apt-get
```

**Fedora/RHEL 8+:**
```bash
.claude/scripts/init.sh
# Uses dnf
```

**CentOS 7/RHEL 7:**
```bash
.claude/scripts/init.sh
# Uses yum
```

## Example Output

```bash
🔍 Checking dependencies...
  ✅ GitHub CLI (gh) installed
  ❌ jq not found

  Installing jq...
  # On Fedora: sudo dnf install -y jq
  # On Ubuntu: sudo apt-get update && sudo apt-get install -y jq
  # On macOS: brew install jq

  ✅ jq installed
  ✅ SQLite installed
  ❌ DuckDB not found

  Installing duckdb...
  Installing DuckDB from GitHub releases...
  ✅ DuckDB installed
```

## Benefits

1. **Broader Linux Support** - Works on both Debian and Red Hat-based systems
2. **Automatic Detection** - No user configuration needed
3. **Consistent Behavior** - Same experience across all platforms
4. **Graceful Fallback** - Clear instructions if automatic installation fails
5. **Maintainable** - Easy to add support for other package managers

## Future Enhancements (Optional)

Could add support for:
- `pacman` (Arch Linux)
- `zypper` (openSUSE)
- `apk` (Alpine Linux)
- `nix` (NixOS)

## Conclusion

The init script now works seamlessly across all major Linux distributions, making CCPM accessible to a wider range of developers regardless of their preferred Linux distro.

**Supported Systems:**
- ✅ macOS (Homebrew)
- ✅ Debian/Ubuntu (apt)
- ✅ Fedora/RHEL/CentOS (dnf/yum)
- ⚠️ Other Linux (manual installation)

All dependencies are automatically installed with a single command:
```bash
.claude/scripts/init.sh
```
