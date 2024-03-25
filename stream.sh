#!/usr/bin/env bash

# Automates switching in/out of recording workflow.
# Ran just before I click record, and I Ctrl+C after clicking stop recording
#
# Perform the following:
# 1. Start OSKD
#    a. This renders my keypresses to the screen for seeing vim combos
# 2. Increase font size in alacritty
#    a. I perfer a smaller font size day to day, and always forget to change this, so increase this automatically
# 3. Swap Fish history to recording
#    a. Use a separate fish history when recording, to resume on the same "page" when doing series
# 4. Open OBS Studio
#    a. So I can then click record while having to run one program instead of two
#
# The reverse is done when Ctrl+C is detected (kill OSKD, restore font, restore fish history, obs killed automatically on script exit)

set -euo pipefail

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

OSKD_REPO_PATH="/home/troy/Rust/OSKD"

NIXOS_SYSTEMS_REPO_PATH="/home/troy/nix/systems"
# TODO: Fix hack of storing alacritty config in nvim config (nix lang workaround)
ALACRITTY_CONFIG_PATH="$NIXOS_SYSTEMS_REPO_PATH/home/features/cli/nvim/default.nix"
FONT_SIZE_FILE="$SCRIPT_DIR/old-alacritty-size.txt"

FISH_HISTORY_FILE="$HOME/.local/share/fish/fish_history"
PERSONAL_HISTORY_FILE="$HOME/.local/share/fish/personal_fish_history"
RECORDING_HISTORY_FILE="$HOME/.local/share/fish/recording_fish_history"

PERSONAL_HISTORY_BACKUP_DIR="$SCRIPT_DIR/personal-fish-history"
RECORDING_HISTORY_BACKUP_DIR="$SCRIPT_DIR/recording-fish-history"

RECORDING_FONT_SIZE="15"

# Creates a backup of the given fish history file
backup_history_file() {
    local source_file=$1
    local backup_dir=$2
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_file="$backup_dir/$(basename "$source_file")_$timestamp"
    cp "$source_file" "$backup_file"
}

start_recording() {

    # ===== 1. Start OSKD =====
    echo "Starting OSKD..."
    pushd "$OSKD_REPO_PATH" > /dev/null
    nix run --option warn-dirty false --quiet > /dev/null &
    OSKD_PID=$!
    popd > /dev/null

    # ===== 2. Increase font size in alacritty =====
    ORIGINAL_FONT_SIZE=$(awk -F " = " '/font.size/{print $2}' "$ALACRITTY_CONFIG_PATH")
    echo $ORIGINAL_FONT_SIZE > "$FONT_SIZE_FILE"
    echo "Adjusting alacritty font size from $ORIGINAL_FONT_SIZE to $RECORDING_FONT_SIZE..."
    sed -i "s/font.size = [0-9]*/font.size = $RECORDING_FONT_SIZE/" "$ALACRITTY_CONFIG_PATH"

    # Rebuild nixos system so alacritty instances pick up new config
    pushd "$NIXOS_SYSTEMS_REPO_PATH" > /dev/null
    just switch --option warn-dirty false --quiet
    popd > /dev/null

    # ===== 3. Swap Fish history to recording =====
    echo "Swapping Fish history to recording..."
    if [ ! -f "$RECORDING_HISTORY_FILE" ]; then
        touch "$RECORDING_HISTORY_FILE"
    fi
    # Backup personal history
    backup_history_file "$FISH_HISTORY_FILE" "$PERSONAL_HISTORY_BACKUP_DIR"
    mv "$FISH_HISTORY_FILE" "$PERSONAL_HISTORY_FILE"
    cp "$RECORDING_HISTORY_FILE" "$FISH_HISTORY_FILE"

    # ===== 4. Open OBS Studio =====
    echo "Opening OBS Studio..."
    obs > /dev/null 2>&1 & disown


    echo "Entered recording mode successfully"
}

stop_recording() {
    echo ""
    echo ""
    echo "Stopping recording..."

    # ===== 1. Kill OSKD =====
    echo "Killing OSKD..."
    kill $OSKD_PID

    # ===== 2. Restore font size in Alacritty =====
    if [ -f "$FONT_SIZE_FILE" ]; then
        ORIGINAL_FONT_SIZE=$(cat "$FONT_SIZE_FILE")
        sed -i "s/font.size = [0-9]*/font.size = $ORIGINAL_FONT_SIZE/" "$ALACRITTY_CONFIG_PATH"
        pushd "$NIXOS_SYSTEMS_REPO_PATH" > /dev/null
        just switch --option warn-dirty false --quiet
        popd > /dev/null
        rm "$FONT_SIZE_FILE"
        echo "Restored alacritty font size to $ORIGINAL_FONT_SIZE"
    else
        echo "Original font size file not found"
    fi

    # ===== 3. Restore Fish history to personal =====
    echo "Restoring Fish history to personal..."
    # Backup recording history
    backup_history_file "$FISH_HISTORY_FILE" "$RECORDING_HISTORY_BACKUP_DIR"
    if [ -f "$PERSONAL_HISTORY_FILE" ]; then
        mv "$FISH_HISTORY_FILE" "$RECORDING_HISTORY_FILE"
        cp "$PERSONAL_HISTORY_FILE" "$FISH_HISTORY_FILE"
    else
        echo "Personal Fish history file not found"
    fi

    echo "Exited recording mode"
    exit
}

# Trap CTRL+C and call stop_recording()
trap stop_recording SIGINT

start_recording

# Keep script running until CTRL+C is pressed
while true; do sleep 10; done

