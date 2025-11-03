# Chat with Astro Bot the genomics explorer!  

## Summary  

This is a project to create a 'chatbot' learning tool using a library of genomics information with a RAG-LLM and conversation history/memory- so that people can query it with questions about genomics and oxidative stress in order to learn more about the kinds of things I/my lab research.

## Requirements  

- bash and curl or wget (one required for downloading installers/models).  
- Approximately 45 GB of RAM (preferably GPU VRAM). Running with less than 45 GB of VRAM will result in very slow answers (bot could take up to a couple minutes per query).  
- Tested on:
  - Ubuntu 22.04 (native and WSL)
  - Rocky Linux 8.10

## Running the pipeline (*pipeline.sh*)  

__*Important:*__ *pipeline.sh* must be sourced (not executed) so it can export and activate the conda/mamba environment into your current shell session.  

Use:  
```source pipeline.sh [options]```

Why source? The install step (*install-mamba-and-ollama.sh*) sets up a conda/mamba environment and *pipeline.sh* activates that environment and exports variables that the rest of the session needs. Running *pipeline.sh* in a subshell (```bash ./pipeline.sh```) will not preserve those environment changes in the running shell.  

*Note:* This chatbot allows incorporation of additional documents to the vector store if you would like to add more information to it's knowledge base (to ask questions about).  Just put the documents in the folder `new_docs/` use the '*add a document*' command and follow the prompts to do so.

### Basic workflow examples  
- Run install-only (perform installation of necessary dependencies and build Chroma db only):  
```source pipeline.sh -i```

- Run chat-only (skip installation steps if already configured and start the chat interface):  
```source pipeline.sh -c```

### Custom installation paths  
- pipeline.sh supports options to set custom installation locations for mamba and ollama. Example usage (replace with the exact option names found at the top of pipeline.sh if they differ):  
```source pipeline.sh -m /custom/mamba/path -o /custom/ollama/path```

## Notes and troubleshooting  
- See the top of pipeline.sh for the exact option names and any additional flags it supports.
- Always source *pipeline.sh* in the same shell where you want to run the chat or other commands that rely on the activated environment.
