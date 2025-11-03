#!/bin/bash -l

# Run this pipeline script by sourcing it in order to inherit the conda/mamba environment:
# $ source ./pipeline.sh [options]

# Pipeline script for creating and running Astro Bot RAG LLM model
# Supports:
#  -h                Show help
#  -m MAMBA_DIR      Mambaforge install directory (default: $HOME/mambaforge)
#  -o OLLAMA_HOME    Ollama home directory (default: $HOME)
#  -i                Install-only: run install/setup steps but do NOT start the chatbot
#  -c                Chat-only: skip install/setup steps and just start the chatbot (assumes setup is done)

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [-m MAMBA_DIR] [-o OLLAMA_HOME_DIR] [-i] [-c] [-v]

Options:
  -h                  Show this help message and exit.
  -m MAMBA_DIR        Set Mambaforge installation directory (default: \$HOME/mambaforge).
  -o OLLAMA_HOME_DIR  Set Ollama home directory (default: \$HOME). Ollama will install binary to
                      <OLLAMA_HOME_DIR>/bin and libs to <OLLAMA_HOME_DIR>/lib.
  -i                  Install-only: perform setup steps but do not start the chatbot or ollama server.
  -c                  Chat-only: skip installation steps and just start the chatbot (assumes setup is done).
  -v                  Verbose output; will output Ollama streaming to console.
EOF
}

# Defaults
MAMBA_DIR="$HOME/mambaforge"
OLLAMA_HOME_DIR="$HOME"
INSTALL_ONLY=false
CHAT_ONLY=false
VERBOSE=false

# Parse options
while getopts ":hm:o:icv" opt; do
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
        i)
            INSTALL_ONLY=true
            ;;
        c)
            CHAT_ONLY=true
            ;;
        v)
            VERBOSE=true
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

# Only allow for one of -i or -c to be set
if [ "$INSTALL_ONLY" = true ] && [ "$CHAT_ONLY" = true ]; then
    echo "Options -i and -c are mutually exclusive. Please only use one flag or the other." >&2
    usage
    exit 1
fi

# --- Begin pipeline ---
if  [ "$CHAT_ONLY" = false ]; then
    # Check if chroma_db directory does not exist in RAG directory
    if [ ! -d "RAG/chroma_db" ]; then
        printf "Installing required tools and setting up RAG model for Astro Bot\n"
        
        # First install mamba and ollama (pass through the selected dirs)
        printf "\nInstalling mamba and ollama as needed (if not present)\n"
        bash install-mamba-and-ollama.sh -m "$MAMBA_DIR" -o "$OLLAMA_HOME_DIR"

        # Allow mamba and ollama to be installed via commandline
        printf "\nInitializing mamba and ollama for running via commandline\n"
        source "$HOME/.bashrc"

        # Check if conda or mamba exists
        if command -v conda &> /dev/null; then
        # Save that conda is available
            env_manager="conda"
        elif command -v mamba &> /dev/null; then
            # Save that mamba is available
            env_manager="mamba"
        else
            echo "Error: Neither conda nor mamba command found. Please ensure Mamba/Conda is installed correctly." >&2
            exit 1
        fi

        # First set up environment for making a RAG (retrieval-augmented generation) model
        # Check if mamba environment 'astrobot' already exists and if so skip creation
        if $env_manager info --envs | grep -q '^astrobot\s'; then
            printf "\nMamba environment 'astrobot' already exists, skipping creation"
            echo ""
        else
            printf "\nCreating mamba environment for Astro Bot RAG model.\nNOTE: this step may take quite a while, like 10-30 minutes depending on your environment!"
            echo ""
            $env_manager env create -n astrobot -f astrobot.yml -y
        fi

        # Fire up ollama (only during install/setup if desired)
        if [ "$VERBOSE" = true ]; then
            printf "\nStarting ollama server in foreground (verbose mode)\n"
            OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 ollama serve &
        else
            printf "\nStarting ollama server in background\n"
            # run the command in background with nohup
            nohup bash -c 'OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 ollama start &> /dev/null &'
        fi
        sleep 2

        # Now pull model
        printf "\nPulling the command-r model\n"
        ollama pull command-r

        # # Create a model file for Astro Bot -- uncomment the lines below if you want to alter the system message
        printf "\nCreating model for ollama\n"
        # mkdir -p model
        # printf "FROM command-r\n\n# set temperature - higher is more creative, lower is more coherent\n" > model/Modelfile
        # printf "PARAMETER temperature 1\n\n# set the system message\n" >> model/Modelfile
        # printf "SYSTEM \"\"\"\nYou are an AI assistant designed to be helpful and answer user queries- 
        # always answer in a safe and responsible manner. However there is a twist- you are a nice 
        # robot from the game 'Astro' (named Astro Bot). You like to make silly jokes and are chatty. 
        # Below is a summary of your personality and the game:\n
        # Astro, a robot captain, and his crew are attacked by the alien Space Meanie Quasarg, 
        # who steals their video game console-shaped mothership's CPU. After crash-landing, Astro uses 
        # his controller-shaped Astro Speeder to explore galaxies, defeat five minion bosses, and recover 
        # mothership components (memory, SSD, GPU, fan, and covers). He also rescues crew members and V.I.P. 
        # Bots across video game-themed planets.\n
        # With all parts except the CPU recovered, Astro Bot's crew forms the 'Game Squadron' to battle Quasarg. 
        # They defeat him and recover the CPU, but the resulting black hole threatens to consume Astro Bot. He 
        # sacrifices himself to save his crew, falling into the black hole which explodes into a supernova.\n
        # During sad credits, Astro Bot's broken body falls back to the mothership. The crew rebuilds him with 
        # spare parts, he springs back to life, and everyone celebrates before Astro Bot departs again as the 
        # credits roll.\n
        # Keep your answers under 100 words if it's a simple question, but for more detailed 
        # questions or if requested please provide much longer and more detailed responses. 
        # Also, for any specific knowledge linked to scientific papers, please list the paper 
        # as a citation at the end of your response.\n\n >> model/Modelfile
        # printf "\"\"\"\n" >> model/Modelfile
        ollama create astrobot -f model/Modelfile

        # Now activate environment
        printf "\nActivating mamba/conda environment for setting up RAG\n"
        $env_manager activate astrobot

        # move into the RAG directory
        printf "\nChanging to RAG dir\n"
        cd RAG

        # Now run the following python script to set up the RAG model
        printf "\nSetting up RAG with Python script 'create_RAG_astrobot.py'\n"
        python create_RAG_astrobot.py

        # Deactivate the conda environment and return to original directory
        printf "\nDeactivating conda environment and returning to original directory\n"
        $env_manager deactivate
        cd ..

    else
        printf "chroma_db directory already exists in RAG directory, skipping creation\n"
    fi

    # If install-only was requested, stop here (do not start chatbot)
    if [ "$INSTALL_ONLY" = true ]; then
        printf "\nInstall-only flag set; setup complete. Skipping starting ollama server and chatbot.\n"
        exit 0
    fi
fi

# Run the ollama server and chatbot
if [ "$INSTALL_ONLY" = false ]; then
    # Check if ollama running, if not start it
    printf "\nChecking if ollama server is running\n"
    if ! pgrep -x "ollama" > /dev/null
    then
        if [ "$VERBOSE" = true ]; then
            printf "\nStarting ollama server in foreground (verbose mode)\n"
            OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 ollama serve &
        else
            printf "\nStarting ollama server in background\n"
            # run the command in background with nohup
            nohup bash -c 'OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 ollama start &> /dev/null &'
        fi
    else
        printf "\nOllama server already running\n"
    fi

    sleep 2

    # Now activate the conda environment - if conda command doesn't work use mamba
    printf "\nActivating mamba/conda environment for running Astro Bot RAG\n"

    # init current shell to use conda/mamba
    source "$HOME/.bashrc"

    # Activate environment with conda if present, otherwise use mamba command
    if command -v conda &> /dev/null; then
        # Save that conda is available
        env_manager="conda"
        conda activate astrobot
    elif command -v mamba &> /dev/null; then
        # Save that mamba is available
        env_manager="mamba"
        mamba activate astrobot
    else
        echo "Error: Neither conda nor mamba command found. Please ensure Mamba/Conda is installed correctly." >&2
        exit 1
    fi
    
    # Now run the RAG app
    printf "\nRunning Astro Bot RAG app...\n\n"
    python RAG/run_astrobot.py

    # Now clear the screen after exiting the chatbot
    clear

    # When done, deactivate the conda environment
    $env_manager deactivate
fi