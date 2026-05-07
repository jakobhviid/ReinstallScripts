# shellcheck shell=bash
# Per-package third-party repo setup.
# Called automatically before installing a package that needs a custom repo.
# Depends on common.sh (info) being sourced first.
#
# After the bazzite-custom image rework, this file shrank to just the
# proton-vpn case — every other repo (brave, 1password, claude-desktop,
# vivaldi, zen-browser COPR) is now baked into the image's /etc/yum.repos.d/.
# Proton VPN stays here because the image can't bake the package itself
# (its post-install scriptlet calls systemctl which fails in a build
# container, killing the dnf transaction); the repo + the layered install
# happen on the live system instead.

ensure_repo() {
    case "$1" in
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
    esac
}
