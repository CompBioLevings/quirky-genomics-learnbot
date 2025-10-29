# !/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
Python file to create a RAG (retrieval-augmented generation) model for Astro Bot
Uses LangChain, Ollama, HuggingFace embeddings, and Chroma vector database
'''

# xterm -fa 'Monospace' -fs 11 -e 'OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 /users/5/levin252/Ollama/bin/ollama serve' &
# xterm -fa 'Monospace' -fs 11 -e 'watch -n 1 nvidia-smi' & # to monitor GPU usage
# conda activate astrobot
# ipython

# Set working dir
# %cd RAG

# Set up environment
import os
import sys
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
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)\

## load the pdf files and split it into chunks - this part has already been done and saved to a pickle file
# scan the provided directory for PDF files inside RAG folder and loads them - 
# CAREFUL- with this many files this process takes a long time and a lot of memory (5 hrs)

## DirectoryLoader is a LangChain utility to load data from the directories
## Note this takes a LOT of time and memory for a large number of files
# loader = DirectoryLoader('/users/5/levin252/papers', glob="**/pdfs/*.pdf", show_progress=True)
# data = loader.load()
# print("DATA LOAD DONE")

## 2. Save the list of Document objects to a pickle file
# output_file = 'genomic_papers_data.pkl'
# with open(output_file, 'wb') as f:
#     pickle.dump(data, f)

# print(f'Parsed data has been saved to {output_file}')

# Example of how to load the data back
output_file = 'genomic_papers_data.pkl'
with open(output_file, 'rb') as f:
    data = pickle.load(f)

# print(f'Loaded {len(data)} documents from {output_file}')

## Split documents
# We need to split large documents into 500 character chunks. 
# RecursiveCharacterTextSplitter() is used to split based on the structure of (e.g. sentences, paragraphs)
# all_splits is a list that contains document chunks ready for embedding
text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
all_splits = text_splitter.split_documents(data)
print("DATA SPLIT DONE")

## Create embeddings
# convert each text chunk into a vector representation using a pre-trained model
# use GPU to run the embedding model
model_name = "sentence-transformers/all-mpnet-base-v2"
model_kwargs = {'device':'cuda'}
embeddings = HuggingFaceEmbeddings(model_name=model_name, model_kwargs=model_kwargs)

## Store embeddings in a Vector Database
# Use the Chroma DB vector database
# The vector db is created in memory and can later be retrieved based on similarity
print("creating vector store...")
vectorstore = Chroma.from_documents(documents=all_splits, embedding=embeddings, persist_directory='./chroma_db')
print("VectorStore DONE")
