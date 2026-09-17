#!/bin/sh
# builds sphaira.nro in the builder image, without devkitPro installed on the
# host. --send hands the result to the console over nxlink and stays attached
# to its log.
#
#   docker/nro-builder/build.sh [Release|Dev|Lite] [--send]
#
# (not docker/builder: .gitignore's build*/ would swallow it.)
#
# Release (the default) is what the release workflow publishes; Dev skips LTO,
# so a one-file change relinks in a fraction of the time.
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
preset=Release
send=

for arg in "$@"; do
    case "$arg" in
        --send) send=1 ;;
        *) preset=$arg ;;
    esac
done

image=sphaira-builder
cache=${XDG_CACHE_HOME:-$HOME/.cache}/sphaira-ccache
mkdir -p "$cache"

# a no-op from docker's layer cache unless the Dockerfile changed.
docker build -q -t "$image" "$here" > /dev/null

# configured once per build directory: after that ninja reruns cmake itself
# whenever a CMakeLists.txt changes. the dependencies are pinned, so there is
# no reason to ask the network about them on every configure.
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$root":/src -v "$cache":/ccache -w /src \
    "$image" sh -c "
        if [ ! -f build/$preset/build.ninja ]; then
            cmake --preset $preset -DFETCHCONTENT_UPDATES_DISCONNECTED=ON > /dev/null
        fi
        cmake --build --preset $preset --parallel $(nproc)
    "

nro="$root/build/$preset/sphaira.nro"
echo "built $nro"

if [ -n "$send" ]; then
    # line buffered: redirected to a file, nxlink would otherwise hold the
    # last few KB of the log, which after a failure are the lines that matter.
    stdbuf -oL nxlink -s "$nro"
fi
