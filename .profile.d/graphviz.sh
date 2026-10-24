#!/bin/sh

# APT buildpacks extract packages without running Graphviz's post-install hook.
for graphviz_plugin_dir in "$HOME"/.apt/usr/lib/*/graphviz; do
    if [ -d "$graphviz_plugin_dir" ]; then
        export GVBINDIR="$graphviz_plugin_dir"
        dot -c
        break
    fi
done
unset graphviz_plugin_dir
