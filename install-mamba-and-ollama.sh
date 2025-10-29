#!/bin/bash
# install-mamba-and-ollama.sh
# Checks for Conda/Mamba and installs Mambaforge if missing.
# Also checks for Ollama and installs the binary to $HOME/bin if missing.

# --- Configuration ---
# Set the desired Mambaforge installation directory (default: in the user's home directory).
# Uses the first argument ($1) if provided, otherwise defaults to $HOME/mambaforge.
INSTALL_DIR="${1:-$HOME/mambaforge}"
MAMBA_INSTALLER_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
MAMBA_INSTALLER_NAME=$(basename "$MAMBA_INSTALLER_URL")

# --- Step 1: Check if Conda or Mamba is already installed ---
echo "--- Starting Environment Check (Conda/Mamba) ---"
echo "Target Mambaforge installation directory: $INSTALL_DIR" 

if command -v conda &> /dev/null; then
    echo "Conda is already installed and accessible. Skipping Mambaforge installation."
else
    if command -v mamba &> /dev/null; then
        echo "Mamba is already installed and accessible. Skipping Mambaforge installation."
    else
        echo "Neither Conda nor Mamba found. Proceeding with Mambaforge installation..."

        # --- Step 2: Download the Mambaforge installer ---
        DOWNLOAD_CMD=""
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

        # --- Step 3: Run silent installation ---
        echo "Installing Mambaforge silently into $INSTALL_DIR..."

        # -b: batch mode (no user prompts), -p: sets the installation prefix/directory.
        bash "$MAMBA_INSTALLER_NAME" -b -p "$INSTALL_DIR"

        if [ $? -ne 0 ]; then
            echo "Error: Mambaforge installation failed."
            rm -f "$MAMBA_INSTALLER_NAME"
            exit 1
        fi

        # Clean up the installer script
        rm -f "$MAMBA_INSTALLER_NAME"
        echo "Mambaforge installation successful in $INSTALL_DIR."

        # --- Step 4: Initialize bash environment ---
        INIT_SCRIPT="$INSTALL_DIR/bin/conda"

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

# --- Step 5: Check and Install Ollama ---
echo "--- Starting Ollama Check ---"
if command -v ollama &> /dev/null; then
    echo "Ollama is already installed and accessible. Skipping Ollama installation."
else
    echo "Ollama not found. Proceeding with installation to $HOME/bin..."
    
    OLLAMA_HOME_DIR="$HOME"
    OLLAMA_BIN_DIR="$HOME/bin"
    OLLAMA_URL="https://ollama.com/download/ollama-linux-amd64.tgz"
        
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required to download Ollama but was not found. Please install curl."
    else
    
        echo "Downloading Ollama binary..."
        curl -L "$OLLAMA_URL" | tar -xzf - -C "$OLLAMA_HOME_DIR"
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download Ollama. Check URL or internet connection."
        else
            chmod +x "$OLLAMA_BIN_DIR/ollama"
            echo "Ollama installed successfully to $OLLAMA_BIN_DIR/ollama."
            
            # Check if $HOME/bin is in PATH and add it if not
            if ! grep -q 'export PATH=.*$HOME/bin' "$HOME/.bashrc"; then
                echo "Adding \$HOME/bin to PATH in ~/.bashrc..."
                echo -e '\n# Added by install_mamba.sh for user binaries (Ollama, etc.)' >> "$HOME/.bashrc"
                echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            fi
            
            echo "Ollama is installed. To start the service, run '$OLLAMA_BIN_DIR/ollama serve &' in your terminal."
        fi
    fi
fi

echo "--- Script Finished ---"
echo "To use the new commands (conda, mamba, ollama), run: source ~/.bashrc or start a new terminal session"
exit 0
