#!/usr/bin/env bash

# Brute-force new Kiro releases by checking forward from a known starting timestamp

base_url="https://prod.download.desktop.kiro.dev/releases"
suffix="--distro-linux-x64-tar-gz"
tar_suffix="-distro-linux-x64.tar.gz"
user_agent="Mozilla/5.0 (X11; Linux x86_64)"

# Known valid base version timestamp (from PKGBUILD)
start_ts="202507222200"  # format: YYYYMMDDHHMM

# Output dir
out_dir="./kiro_attempts"

find_releases() {
    mkdir -p "$out_dir"

    # Convert start_ts to epoch
    start_epoch=$(date -d "${start_ts:0:8} ${start_ts:8:2}:${start_ts:10:2}" +%s)

    # Get current time in epoch
    now_epoch=$(date +%s)

    # Calculate total number of minutes since start_ts
    max_tries=$(( (now_epoch - start_epoch) / 60 ))

    if (( max_tries <= 0 )); then
        echo "⛔ ERROR: start_ts is in the future! ($start_ts > now)"
        exit 1
    fi

    echo "🔍 Attempting $max_tries minute-based guesses from $start_ts to now..."

    # Loop forward minute-by-minute
    for ((i = 1; i <= max_tries; i++)); do
        guess_epoch=$((start_epoch + i * 60))
        guess_ts=$(date -u -d "@$guess_epoch" +"%Y%m%d%H%M")
        url="$base_url/$guess_ts$suffix/$guess_ts$tar_suffix"
        outfile="$out_dir/$guess_ts$tar_suffix"

        echo -n "Trying $guess_ts ... "
        if curl -fsL --user-agent "$user_agent" -o "$outfile" "$url"; then
            echo "✅ Success"
            echo "$guess_ts" >> "$out_dir/working_versions.txt"
            # Uncomment next line if you want to stop at first success
            # break
        else
            echo "❌"
            rm -f "$outfile"
        fi
    done
}

download_latest() {
    if [[ ! -f "$out_dir/working_versions.txt" ]]; then
        echo "❌ Error: working_versions.txt not found. Run 'find' first."
        exit 1
    fi

    # Get the highest timestamp from working_versions.txt
    latest_ts=$(sort -r "$out_dir/working_versions.txt" | head -n1)
    
    if [[ -z "$latest_ts" ]]; then
        echo "❌ Error: No working versions found in working_versions.txt"
        exit 1
    fi

    echo "📥 Downloading latest version: $latest_ts"
    
    url="$base_url/$latest_ts$suffix/$latest_ts$tar_suffix"
    outfile="$out_dir/$latest_ts$tar_suffix"

    if curl -fsL --user-agent "$user_agent" -o "$outfile" "$url"; then
        echo "✅ Downloaded: $outfile"
        
        # Generate b2sum
        echo "🔍 Generating b2sum..."
        b2sum_value=$(b2sum "$outfile" | cut -d' ' -f1)
        echo "B2sum: $b2sum_value"
        
        # Create PKGBUILD
        create_pkgbuild "$latest_ts" "$b2sum_value"
    else
        echo "❌ Failed to download latest version"
        exit 1
    fi
}

create_pkgbuild() {
    local version_ts="$1"
    local b2sum_value="$2"
    
    # Convert timestamp to version format (YYYYMMDDHHMM -> 0.1.20 format)
    # Extract date components
    year="${version_ts:0:4}"
    month="${version_ts:4:2}"
    day="${version_ts:6:2}"
    hour="${version_ts:8:2}"
    minute="${version_ts:10:2}"
    
    # Create version string (you may want to adjust this format)
    pkgver="0.1.$(date -d "$year-$month-$day $hour:$minute" +%s | cut -c1-8)"
    
    cat > PKGBUILD << EOF
# Maintainer: AlphaLynx <AlphaLynx at protonmail dot com>

pkgname=kiro-bin
_name="\${pkgname%-bin}"
pkgver=$pkgver
pkgrel=1
pkgdesc='The AI IDE for prototype to production'
arch=('x86_64')
url='https://kiro.dev/'
# By downloading and using Kiro, you agree to the following:
#   AWS Customer Agreement: https://aws.amazon.com/agreement/
#   AWS Intellectual Property License: https://aws.amazon.com/legal/aws-ip-license-terms/
#   Service Terms: https://aws.amazon.com/service-terms/
#   Privacy Notice: https://aws.amazon.com/privacy/
license=('LicenseRef-AWS-IPL')
depends=(
    'alsa-lib'
    'at-spi2-core'
    'bash'
    'cairo'
    'dbus'
    'expat'
    'gcc-libs'
    'glib2'
    'glibc'
    'gtk3'
    'libcups'
    'libdrm'
    'libx11'
    'libxcb'
    'libxcomposite'
    'libxdamage'
    'libxext'
    'libxfixes'
    'libxkbcommon'
    'libxkbfile'
    'libxrandr'
    'mesa'
    'nodejs'
    'nspr'
    'nss'
    'pango'
)
provides=("\$_name")
conflicts=("\$_name")
options=(!strip)
source=(
    "\$_name-$version_ts.tar.gz::https://prod.download.desktop.kiro.dev/releases/$version_ts$suffix/$version_ts$tar_suffix"
    "\$_name.desktop"
    "\$_name-url-handler.desktop"
    "\$_name-workspace.xml"
)
b2sums=('$b2sum_value'
        'ab6e96fccff12d2d7c94dda4647f9fc1e6b0728ac7dd45edba14e364516ed4ad34f01bb7cc48e139fb817f57c309b8fa230c62c3b399915cc7341c2af039d309'
        'fd694d647fe06c439026f1a570fba288fb51bf41fe76de60af1e911255e4692b5a3cae1a8c279ed77a4990618b957591b79b6f152728374af97bea1189691014'
        'bf76f34c64e272831da98a3642f827b159582fafb3918db9f7334ed7ed9eace747148d6f0f863d2a5f1e751b7d43f109e35a8ac7ee1985c09d7ea90b73a40455')

package() {
    mkdir -p "\$pkgdir/opt/Kiro"
    cp -r Kiro/* "\$pkgdir/opt/Kiro"

    mkdir -p "\$pkgdir/usr/bin"
    ln -s /opt/Kiro/bin/\$_name "\$pkgdir/usr/bin/\$_name"

    mkdir -p "\$pkgdir/usr/share/licenses/\$pkgname"
    ln -s /opt/Kiro/resources/app/LICENSE.txt "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE.txt"

    mkdir -p "\$pkgdir/usr/share/pixmaps"
    ln -s /opt/Kiro/resources/app/resources/linux/code.png "\$pkgdir/usr/share/pixmaps/\$_name.png"

    mkdir -p "\$pkgdir/usr/share/bash-completion/completions"
    mkdir -p "\$pkgdir/usr/share/zsh/site-functions"

    ln -s /opt/Kiro/resources/completions/bash/\$_name \\
        "\$pkgdir/usr/share/bash-completion/completions/\$_name"
    ln -s /opt/Kiro/resources/completions/zsh/_\$_name \\
        "\$pkgdir/usr/share/zsh/site-functions/_\$_name"

    install -Dm644 \$_name.desktop "\$pkgdir/usr/share/applications/\$_name.desktop"
    install -Dm644 \$_name-url-handler.desktop \\
        "\$pkgdir/usr/share/applications/\$_name-url-handler.desktop"
    install -Dm644 \$_name-workspace.xml "\$pkgdir/usr/share/mime/packages/\$_name-workspace.xml"
}
EOF

    echo "✅ Created PKGBUILD with version $pkgver and timestamp $version_ts"
}

makeit() {
    # Get the source filename from PKGBUILD for targeted cleanup
    source_file=""
    if [ -f PKGBUILD ]; then
        source_file=$(grep -o 'kiro-[0-9]*\.tar\.gz' PKGBUILD | head -n1)
    fi
    
    makepkg -si
    if [ $? -eq 0 ]; then
        echo "✅ Build and install successful."
        # Clean up build files
        if [ -f PKGBUILD ]; then
            echo "🧹 Cleaning up build files..."
            # Remove build directories (these are always safe to remove)
            rm -rf src pkg
            # Remove only the specific source file that was downloaded
            if [ -n "$source_file" ] && [ -f "$source_file" ]; then
                rm -f "$source_file"
                echo "🗑️  Removed source file: $source_file"
            fi
        fi
    else
        echo "❌ Build or install failed."
        return 1
    fi
}

# Main script logic
case "${1:-}" in
    "find")
        find_releases
        ;;
    "latest")
        download_latest
        ;;
    "install")
        makeit
        ;;
    *)
        echo "Usage: $0 {find|latest|install}"
        echo "  find   - Search for new Kiro releases"
        echo "  latest - Download the most recent version and create PKGBUILD"
        echo "  install - Build and install the package"
        exit 1
        ;;
esac
