#!/bin/bash -l

# Pipeline script for creating and running Astro Bot RAG LLM model

# Check if chroma_db directory does not exist in RAG directory
if [ ! -d "RAG/chroma_db" ]; then
    printf "Installing required tools and setting up RAG model for Astro Bot\n"
    
    # First install mamba and ollama
    printf "\nInstalling mamba and ollama as needed (if not present)\n"
    bash install-mamba-and-ollama.sh

    # Allow mamba and ollama to be installed via commandline
    printf "\nInitializing mamba and ollama for running via commandline\n"
    source "$HOME/.bashrc"

    # First set up environment for making a RAG (retrieval-augmented generation) model
    mamba env create -n astrobot -f astrobot.yml -y

    # Fire up ollama
    OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 ollama serve > /dev/null 2>&1 &

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
    # Keep your answers under 100 words if it's a simple question, but for more detailed 
    # questions or if requested please provide much longer and more detailed responses. 
    # Also, for any specific knowledge linked to scientific papers, please list the paper 
    # as a citation at the end of your response.\n\n
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
    # credits roll.\n\n" >> model/Modelfile
    # printf "\"\"\"\n" >> model/Modelfile
    ollama create astrobot -f model/Modelfile

    # Now activate environment
    printf "\nActivating mamba/conda environment for setting up RAG\n"
    conda activate astrobot

    # move into the RAG directory
    printf "\nChanging to RAG dir\n"
    cd RAG

    # Now run the following python script to set up the RAG model
    printf "\nSetting up RAG with Python script 'create_RAG_astrobot.py'\n"
    python create_RAG_astrobot.py

    # Deactivate the conda environment and return to original directory
    printf "\nDeactivating conda environment and returning to original directory\n"
    conda deactivate
    cd ..
else
    printf "chroma_db directory already exists in RAG directory, skipping creation\n"
fi

# Now activate the conda environment - if conda command doesn't work use mamba
printf "\nActivating mamba/conda environment for running Astro Bot RAG\n"

# init current shell to use conda/mamba
source "$HOME/.bashrc"
${conda:-mamba} activate astrobot

# Now run the RAG app
printf "\nRunning Astro Bot RAG app\n\n"
python RAG/run_astrobot.py
