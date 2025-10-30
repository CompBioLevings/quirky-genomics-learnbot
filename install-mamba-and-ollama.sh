#!/bin/bash
# install-mamba-and-ollama.sh

# Checks for Conda/Mamba and installs Mambaforge if missing.
# Also checks for Ollama and installs the binary to $HOME/bin if missing.

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [-m MAMBA_DIR] [-o OLLAMA_HOME_DIR]

Options:
  -h                Show this help message and exit.
  -m MAMBA_DIR      Set Mambaforge installation directory (default: \$HOME/mambaforge).
  -o OLLAMA_HOME_DIR Set directory to install ollama bin and lib folders (default: \$HOME/).
EOF
}

# Defaults
MAMBA_DIR="$HOME/mambaforge"
OLLAMA_HOME_DIR="$HOME"

# Parse options
while getopts ":hm:o:" opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;
        m)
            MAMBA_DIR="$OPTARG"
            ;;
        o)
            OLLAMA_HOME_DIR="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
    esac
done

MAMBA_INSTALLER_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
MAMBA_INSTALLER_NAME=$(basename "$MAMBA_INSTALLER_URL")

# --- Step 1: Check if Conda or Mamba is already installed ---
echo "--- Starting Environment Check (Conda/Mamba) ---"
if command -v conda &> /dev/null; then
    echo "Conda is already installed and accessible. Skipping Mambaforge installation."
else
    if command -v mamba &> /dev/null; then
        echo "Mamba is already installed and accessible. Skipping Mambaforge installation."
    else
        echo "Neither Conda nor Mamba found. Proceeding with Mambaforge installation..."
        echo "Target Mambaforge installation directory: $MAMBA_DIR"

        # --- Step 2: Download the Mambaforge installer ---
        if command -v curl &> /dev/null; then
            DOWNLOAD_CMD="curl -L $MAMBA_INSTALLER_URL -o $MAMBA_INSTALLER_NAME"
        elif command -v wget &> /dev/null; then
            DOWNLOAD_CMD="wget $MAMBA_INSTALLER_URL -O $MAMBA_INSTALLER_NAME"
        else
            echo "Error: Neither curl nor wget found. Please install one of them to proceed with Mambaforge setup."
            exit 1
        fi

        echo "Downloading Mambaforge installer: $MAMBA_INSTALLER_NAME"
        $DOWNLOAD_CMD
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download the Mambaforge installer."
            exit 1
        fi

        echo "Installing Mambaforge silently into $MAMBA_DIR..."
        bash "$MAMBA_INSTALLER_NAME" -b -p "$MAMBA_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Mambaforge installation failed."
            rm -f "$MAMBA_INSTALLER_NAME"
            exit 1
        fi

        rm -f "$MAMBA_INSTALLER_NAME"
        echo "Mambaforge installation successful in $MAMBA_DIR."

        # Initialize
        INIT_SCRIPT="$MAMBA_DIR/bin/conda"
        if [ -f "$INIT_SCRIPT" ]; then
            echo "Initializing bash shell environment by updating ~/.bashrc for Conda/Mamba..."
            "$INIT_SCRIPT" init bash
            if [ $? -ne 0 ]; then
                echo "Warning: Conda initialization failed. You may need to manually run '$INIT_SCRIPT init bash'."
            fi
        else
            echo "Error: Conda initialization script not found at $INIT_SCRIPT. Check installation path."
        fi
    fi
fi

# --- Step 5: Check and Install Ollama if needed ---
echo "--- Starting Ollama Check ---"
if command -v ollama &> /dev/null; then
    echo "Ollama is already installed and accessible. Skipping Ollama installation."
else
    echo "Ollama not found. Proceeding with installation to $OLLAMA_HOME_DIR..."

    OLLAMA_BIN_DIR="$OLLAMA_HOME_DIR/bin"
    OLLAMA_URL="https://ollama.com/download/ollama-linux-amd64.tgz"

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "Error: curl or wget is required to download Ollama but was not found. Please install one."
    else
        # Download and extract to temporary dir, then move the 'ollama' binary into the bin dir
        TMPDIR=$(mktemp -d -p "$OLLAMA_HOME_DIR" tmp.ollama.XXXXXX)
        echo "Downloading Ollama to temporary directory..."
        if command -v curl &> /dev/null; then
            curl -L "$OLLAMA_URL" | tar -xzf - -C "$TMPDIR"
        else
            wget -qO- "$OLLAMA_URL" | tar -xzf - -C "$TMPDIR"
        fi

        if [ $? -ne 0 ]; then
            echo "Error: Failed to download or extract Ollama. Check URL or internet connection."
            rm -rf "$TMPDIR"
        else
            # Find the extracted ollama binary
            OLLAMA_SRC=$(find "$TMPDIR" -type f -name 'ollama' -print -quit)
            if [ -z "$OLLAMA_SRC" ]; then
                echo "Error: Ollama binary not found in archive."
                rm -rf "$TMPDIR"
            else
                mv ${TMPDIR}/* "$OLLAMA_HOME_DIR/"
                chmod +x "$OLLAMA_BIN_DIR/ollama"
                rm -rf "$TMPDIR"
                echo "Ollama installed successfully at $OLLAMA_BIN_DIR/ollama."

                # Ensure PATH contains the bin dir
                if ! grep -qF "$OLLAMA_BIN_DIR" "$HOME/.bashrc" 2>/dev/null; then
                    echo "Adding $OLLAMA_BIN_DIR to PATH in ~/.bashrc..."
                    {
                        echo ""
                        echo "# Added by install-mamba-and-ollama.sh for user binaries (Ollama, etc.)"
                        # Use expanded path so it works in scripts
                        echo "export PATH=\"$OLLAMA_BIN_DIR:\$PATH\""
                    } >> "$HOME/.bashrc"
                fi

                echo "Ollama is installed. To start the service, run '$OLLAMA_BIN_DIR/ollama serve &' in your terminal."
            fi
        fi
    fi
fi

echo "--- Script Finished ---"
echo "To use the new commands (conda, mamba, ollama), run: source ~/.bashrc or start a new terminal session"
exit 0
