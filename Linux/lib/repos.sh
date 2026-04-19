# shellcheck shell=bash
# Per-package third-party repo setup.
# Called automatically before installing a package that needs a custom repo.
# Depends on common.sh (info) being sourced first.

ensure_repo() {
    case "$1" in
        brave-browser)
            if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
                info "Adding Brave repository"
                sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
                  https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            fi
            ;;
        1password)
            if [[ ! -f /etc/yum.repos.d/1password.repo ]]; then
                info "Adding 1Password repository"
                sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
                sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
            fi
            ;;
        code)
            if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
                info "Adding VS Code repository"
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            fi
            ;;
        proton-vpn-gnome-desktop)
            if [[ ! -f /etc/yum.repos.d/protonvpn-stable.repo ]]; then
                info "Adding Proton VPN repository"
                local fedora_release
                fedora_release="$(rpm -E %fedora)"
                sudo curl -fsSLo "/etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${fedora_release}-stable" \
                  "https://repo.protonvpn.com/fedora-${fedora_release}-stable/public_key.asc"
                sudo tee /etc/yum.repos.d/protonvpn-stable.repo >/dev/null <<EOF
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-${fedora_release}-stable/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${fedora_release}-stable
EOF
            fi
            ;;
        claude-desktop)
            if [[ ! -f /etc/yum.repos.d/claude-desktop.repo ]]; then
                info "Adding Claude Desktop repository"
                sudo curl -fsSLo /etc/yum.repos.d/claude-desktop.repo \
                  https://aaddrick.github.io/claude-desktop-debian/rpm/claude-desktop.repo
            fi
            ;;
    esac
}
