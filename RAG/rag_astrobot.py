# xterm -fa 'Monospace' -fs 11 -e 'OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 /users/5/levin252/Ollama/bin/ollama serve' &
# xterm -fa 'Monospace' -fs 11 -e 'watch -n 1 nvidia-smi' & # to monitor GPU usage
# conda activate astrobot
# ipython

# Set working dir
%cd RAG

# Set up environment
import os
import sys
import re
import pickle
from langchain_community.document_loaders import DirectoryLoader, TextLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.memory import ConversationBufferMemory
from langchain.chains import ConversationalRetrievalChain
from langchain.schema import HumanMessage, AIMessage
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.prompts import PromptTemplate
from langchain_ollama import OllamaLLM
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler
from langchain.chains import RetrievalQA
from contextlib import contextmanager

# Define function to suppress output
@contextmanager
def suppress_stdout():
    """Suppress output to console

    This function allows code to be run that would normally output text to
    the console to be 'silenced'.

    Args:
        None

    Returns:
        None
    
    Examples:
        >>> with suppress_stdout():
        >>>     print('hello')
        
        >>> 
    """
    with open(os.devnull, "w") as devnull:
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:  
            yield
        finally:
            sys.stdout = old_stdout

# Create embeddings
# convert each text chunk into a vector representation using a pre-trained model
# use GPU to run the embedding model
model_name = "sentence-transformers/all-mpnet-base-v2"
model_kwargs = {'device':'cuda'}
embeddings = HuggingFaceEmbeddings(model_name=model_name, model_kwargs=model_kwargs)

# Store embeddings in a Vector Database
# Use the Chroma DB vector database
# The vector db is created in memory and can later be retrieved based on similarity
# suppress warning
with suppress_stdout():
    print("creating vector store...")
    # vectorstore = Chroma.from_documents(documents=all_splits, embedding=embeddings, persist_directory='.')
    vectorstore = Chroma(persist_directory='.', embedding_function=embeddings)
    print("VectorStore DONE")

# -------------------------
# Conversation memory + persistent save/load
# -------------------------
memory_file = "conversation_memory.pkl"

def _serialize_messages(messages):
    return [(type(m).__name__, m.content) for m in messages]

def _deserialize_messages(data):
    out = []
    for role, content in data:
        if role == "HumanMessage":
            out.append(HumanMessage(content))
        else:
            out.append(AIMessage(content))
    return out

saved = None
try:
    with open(memory_file, "rb") as f:
        saved = pickle.load(f)
except FileNotFoundError:
    saved = None

memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)
if saved:
    memory.chat_memory.messages = _deserialize_messages(saved)


# Interactive chat loop
# a) runs until user enters one of a number of 'exit' keywords
# c) response is limited to approximately 100 words
# d) initialize a command-r model served by Ollama in the background (must start ollama serve)
# e) connect the command-r to a retriever - the vector store that fetches the most relevant chunks 
# f) wraps everything into conversational prompt that has been created with an Astro Bot personality

# Create LLM and conversational chain once so memory persists across queries
llm = OllamaLLM(model="astrobot", callbacks=[StreamingStdOutCallbackHandler()])
qa_chain = ConversationalRetrievalChain.from_llm(
    llm,
    retriever=vectorstore.as_retriever(),
    memory=memory,
    verbose=False
)

# Interactive chat loop (now uses conversational chain)
while True:
    query = input("\n\nQuery: ")
    if query == "bye" or query == "power down" or query == "shutdown" or query == "exit":
        # persist memory before exiting
        try:
            with open(memory_file, "wb") as f:
                pickle.dump(_serialize_messages(memory.chat_memory.messages), f)
                print(f"Saved conversation to {memory_file}")
        except Exception as e:
            print("Failed to save memory:", e)
        break
    if query.strip() == "":
        continue

    # run the conversational retrieval chain (it uses the memory internally)
    result = qa_chain.invoke({"question": query})
