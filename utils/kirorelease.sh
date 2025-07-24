#!/bin/bash

## Looks for the latest Kiro release by counting backwards from the current time.
## Creates a PKGBUILD and installs the package.

base_url="https://prod.download.desktop.kiro.dev/releases"
suffix="--distro-linux-x64-tar-gz"
tar_suffix="-distro-linux-x64.tar.gz"
user_agent="Mozilla/5.0 (X11; Linux x86_64)"

# Output dir
out_dir="./kiro-build"

# Version file location
version_file="$HOME/.kiro"

# Minimum interval (in minutes) between downloads to avoid excessive requests
no_download_interval=720  # 12 hours

find_latest_backwards() {
    local minutes=${1:-60}  # Default to 60 minutes if no argument provided
    
    mkdir -p "$out_dir"
    
    # Get current time in epoch
    now_epoch=$(date +%s)
    
    echo "🔍 Searching backwards from current time for the latest Kiro release..."
    echo "⏰ Checking $minutes minutes backwards..."
    
    # Loop backwards minute-by-minute for specified minutes
    for ((i = 0; i < minutes; i++)); do
        guess_epoch=$((now_epoch - i * 60))
        guess_ts=$(date -u -d "@$guess_epoch" +"%Y%m%d%H%M")
        url="$base_url/$guess_ts$suffix/$guess_ts$tar_suffix"
        
        echo -n "Trying $guess_ts ... "
        if curl -fsL --user-agent "$user_agent" --head "$url" >/dev/null 2>&1; then
            echo "✅ Found latest version: $guess_ts"
            echo "$guess_ts" > "$version_file"
            echo "📝 Written to: $version_file"
            return 0
        else
            echo "❌"
        fi
    done
    
    echo "❌ No Kiro releases found in the last $minutes minutes"
    return 1
}

auto_build() {
    echo "🚀 Starting automatic build process..."
    
    # Check if we have a recent version and skip search if it's too recent
    if [[ -f "$version_file" ]]; then
        latest_ts=$(cat "$version_file")
        echo "📋 Found existing latest version: $latest_ts"
        
        # Convert timestamp to epoch for comparison
        latest_epoch=$(date -d "${latest_ts:0:8} ${latest_ts:8:2}:${latest_ts:10:2}" +%s)
        now_epoch=$(date +%s)
        minutes_old=$(( (now_epoch - latest_epoch) / 60 ))
        
        echo "⏰ Version is $minutes_old minutes old (threshold: $no_download_interval minutes)"
        
        if (( minutes_old < no_download_interval )); then
            echo "✅ Version is recent enough, skipping search and proceeding with build..."
        else
            echo "🔍 Version is older than threshold, searching for newer version..."
            if find_latest_backwards; then
                echo "✅ Found newer version, proceeding with download and build..."
            else
                echo "❌ No newer version found, using existing version..."
            fi
        fi
    else
        echo "🔍 No existing version found, searching for latest release..."
        if find_latest_backwards; then
            echo "✅ Found latest version, proceeding with download and build..."
        else
            echo "❌ No latest version found, cannot proceed with build"
            return 1
        fi
    fi
    
    # Read the latest version from the file
    if [[ -f "$version_file" ]]; then
        latest_ts=$(cat "$version_file")
        echo "📥 Using latest version: $latest_ts"
        
        # Download the latest version
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
            
            # Build and install
            echo "🔨 Building and installing package..."
            makeit
        else
            echo "❌ Failed to download latest version"
            return 1
        fi
            else
            echo "❌ Error: version file not found after successful search"
            return 1
        fi
}

download_latest() {
    # Check if version file exists
    if [[ -f "$version_file" ]]; then
        latest_ts=$(cat "$version_file")
        echo "📥 Using latest version from $version_file: $latest_ts"
    else
        echo "❌ Error: No version file found. Run 'backwards' first."
        exit 1
    fi
    
    if [[ -z "$latest_ts" ]]; then
        echo "❌ Error: No working versions found"
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
    
    # Create the desktop files and workspace XML
    create_desktop_files
    
    cat > "$out_dir/PKGBUILD" << EOF
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
        'fdb8800b60943968e39eef72bc7c657ae3017a5d018c257240b15d9fb0d5aed8652a0f1eab4d7ad5b5d7d3246ef09f77d6576b99c591db1528ed886bbf3d038b'
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

create_desktop_files() {
    echo "📝 Creating desktop files and workspace XML..."
    
    # Create kiro.desktop
    cat > "$out_dir/kiro.desktop" << 'EOF'
[Desktop Entry]
Name=Kiro
Comment=The AI IDE for prototype to production.
GenericName=Text Editor
Exec=/usr/bin/kiro %F
Icon=kiro
Type=Application
StartupNotify=false
StartupWMClass=Kiro
Categories=TextEditor;Development;IDE;AI;
MimeType=application/x-kiro-workspace;
Actions=new-empty-window;
Keywords=kiro;

[Desktop Action new-empty-window]
Name=New Empty Window
Name[de]=Neues leeres Fenster
Name[es]=Nueva ventana vacía
Name[fr]=Nouvelle fenêtre vide
Name[it]=Nuova finestra vuota
Name[ja]=新しい空のウィンドウ
Name[ko]=새 빈 창
Name[ru]=Новое пустое окно
Name[zh_CN]=新建空窗口
Name[zh_TW]=開新空視窗
Exec=/usr/bin/kiro --new-window %F
Icon=kiro
EOF

    # Create kiro-url-handler.desktop
    cat > "$out_dir/kiro-url-handler.desktop" << 'EOF'
[Desktop Entry]
Name=Kiro - URL Handler
Comment=The AI IDE for prototype to production.
GenericName=Kiro
Exec=/usr/bin/kiro --open-url %U
Icon=kiro
Type=Application
NoDisplay=true
StartupNotify=true
Categories=Utility;TextEditor;Development;IDE;
MimeType=x-scheme-handler/kiro;
Keywords=kiro;
EOF

    # Create kiro-workspace.xml
    cat > "$out_dir/kiro-workspace.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
	<mime-type type="application/x-kiro-workspace">
		<comment>Kiro Workspace</comment>
		<glob pattern="*.kiro-workspace"/>
	</mime-type>
</mime-info>
EOF

    echo "✅ Created desktop files and workspace XML"
}

makeit() {
    # Change to the build directory
    cd "$out_dir" || exit 1
    
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
            # Remove desktop files and workspace XML (they're now in PKGBUILD)
            rm -f kiro.desktop kiro-url-handler.desktop kiro-workspace.xml
            echo "🗑️  Removed desktop files and workspace XML"
            # Remove PKGBUILD (no longer needed)
            rm -f PKGBUILD
            echo "🗑️  Removed PKGBUILD"
        fi
    else
        echo "❌ Build or install failed."
        return 1
    fi
    
    # Return to original directory
    cd - > /dev/null
    
    # Clean up the build directory if it's empty
    if [ -z "$(ls -A "$out_dir" 2>/dev/null)" ]; then
        rmdir "$out_dir"
        echo "🗑️  Removed empty build directory"
    fi
}

# Main script logic
case "${1:-}" in
    "backwards")
        find_latest_backwards "$2"
        ;;
    "latest")
        download_latest
        ;;
    "install")
        makeit
        ;;
    "auto")
        auto_build
        ;;
    *)
        echo "Usage: $0 {backwards [minutes]|latest|install|auto}"
        echo "  backwards [minutes] - Search backwards from current time for latest release"
        echo "                        (default: 60 minutes, specify number for more)"
        echo "  latest    - Download the most recent version and create PKGBUILD"
        echo "  install   - Build and install the package"
        echo "  auto      - Automatically find the latest version, download, and build"
        exit 1
        ;;
esac
