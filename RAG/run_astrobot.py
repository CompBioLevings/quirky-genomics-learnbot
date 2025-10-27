# !/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Conversational RAG Bot using Ollama LLM and Chroma Vector Store.
"""

import pickle
import os
from typing import List, Dict, Optional
from langUntitled-1chain_community.llms import Ollama
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain.schema import HumanMessage, AIMessage, Document
from langchain_community.document_loaders import TextLoader, PyPDFLoader, Docx2txtLoader
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

class ConversationalRAGBot:
    def __init__(
        self,
        pickle_path: str = "conversation_memory.pkl",
        chroma_persist_dir: str = "./chroma_db",
        model_name: str = "astrobot",
        embedding_model: str = "all-mpnet-base-v2",
        verbose: bool = False
    ):
        self.pickle_path = pickle_path
        self.chroma_persist_dir = chroma_persist_dir
        
        # Initialize LLM
        self.llm = Ollama(model=model_name)
        
        # Initialize embeddings
        self.embeddings = HuggingFaceEmbeddings(
            model_name=embedding_model
        )
        
        # Load or create conversation history
        self.conversation_history = self._load_pickle()
        
        # Initialize vector store
        self.vectorstore = self._initialize_vectorstore()
        
        # Initialize memory
        self.memory = ConversationBufferMemory(
            memory_key="chat_history",
            return_messages=True,
            output_key="answer"
        )
        
        # Populate memory with loaded history
        self._populate_memory()
        
        # Initialize conversational retrieval chain
        self.chain = ConversationalRetrievalChain.from_llm(
            llm=self.llm,
            retriever=self.vectorstore.as_retriever(search_kwargs={"k": 8}),
            memory=self.memory,
            return_source_documents=True,
            verbose=verbose
        )
    
    def _load_pickle(self) -> List[Dict[str, str]]:
        """Load conversation history from pickle file."""
        if os.path.exists(self.pickle_path):
            with open(self.pickle_path, 'rb') as f:
                return pickle.load(f)
        else:
            return []
    
    def _save_pickle(self):
        """Save conversation history to pickle file."""
        with open(self.pickle_path, 'wb') as f:
            pickle.dump(self.conversation_history, f)
    
    def _initialize_vectorstore(self) -> Chroma:
        """Initialize or load Chroma vector store."""
        if os.path.exists(self.chroma_persist_dir) and os.listdir(self.chroma_persist_dir):
            # Load existing vectorstore
            vectorstore = Chroma(
                persist_directory=self.chroma_persist_dir,
                embedding_function=self.embeddings
            )
        else:
            # Create new vectorstore
            vectorstore = Chroma(
                persist_directory=self.chroma_persist_dir,
                embedding_function=self.embeddings
            )
        
        # Add conversation history to vectorstore
        if self.conversation_history:
            self._add_history_to_vectorstore(vectorstore)
        
        return vectorstore
    
    def _add_history_to_vectorstore(self, vectorstore: Chroma):
        """Add conversation history as combined exchanges to vectorstore."""
        documents = []
        i = 0
        while i < len(self.conversation_history):
            msg = self.conversation_history[i]
            
            if msg['role'] == 'HumanMessage':
                human_content = msg['content']
                ai_content = ""
                
                # Check if next message is AI response
                if i + 1 < len(self.conversation_history):
                    next_msg = self.conversation_history[i + 1]
                    if next_msg['role'] == 'AIMessage':
                        ai_content = next_msg['content']
                        i += 1  # Skip the AI message since we're combining
                
                # Combine human and AI messages
                combined_text = f"Human: {human_content}\nAssistant: {ai_content}"
                documents.append(Document(page_content=combined_text))
            
            i += 1
        
        if documents:
            vectorstore.add_documents(documents)
    
    def _populate_memory(self):
        """Populate LangChain memory with conversation history."""
        for msg in self.conversation_history:
            if msg['role'] == 'HumanMessage':
                self.memory.chat_memory.add_message(HumanMessage(content=msg['content']))
            else:
                self.memory.chat_memory.add_message(AIMessage(content=msg['content']))
    
    def add_documents(self, documents: List[str], metadatas: Optional[List[Dict]] = None):
        """Add additional documents to the vector store for RAG."""
        doc_objects = [Document(page_content=doc) for doc in documents]
        
        if metadatas:
            for doc, metadata in zip(doc_objects, metadatas):
                doc.metadata = metadata
        
        self.vectorstore.add_documents(doc_objects)
        print(f"Added {len(documents)} documents to vector store.")
    
    def chat(self, user_input: str) -> str:
        """Send a message and get a response."""
        # Get response from chain
        response = self.chain({"question": user_input})
        answer = response['answer']
        
        # Save to conversation history
        self.conversation_history.append({'role': 'HumanMessage', 'content': user_input})
        self.conversation_history.append({'role': 'AIMessage', 'content': answer})
        
        # Add this exchange to vectorstore
        combined_text = f"Human: {user_input}\nAssistant: {answer}"
        self.vectorstore.add_documents([Document(page_content=combined_text)])
        
        # Auto-save
        self._save_pickle()
        
        return answer
    
    def get_conversation_history(self) -> List[Dict[str, str]]:
        """Return the current conversation history."""
        return self.conversation_history

    def test_retrieval(self, query: str, k: int = 4):
        """Test what documents are being retrieved for a query."""
        results = self.vectorstore.similarity_search(query, k=k)
        for i, doc in enumerate(results):
            print(f"\n--- Document {i+1} ---")
            print(doc.page_content[:500])  # First 500 chars

# Start the chatbot and use
if __name__ == "__main__":
    # Initialize bot
    bot = ConversationalRAGBot()
    
    # bot.test_retrieval("Do you have any papers about ROS-independent Nrf2 activation in prostate cance", k=2)
    
    # Chat loop
    print("Astro Bot booting up! Type 'quit' to exit or 'Add a document' to load a file.")
    while True:
        user_input = input("\nQuery: ")
        
        if user_input.lower() in ['quit', 'exit', 'shutdown', 'power down', 'bye']:
            print("Until next time my curious companion!  Astro Bot to the stars!")
            break
        
        if user_input.lower() == 'add a document':
            doc_path = input("Enter document path: ")
            
            try:
                # Determine loader based on file extension
                if doc_path.endswith('.txt'):
                    loader = TextLoader(doc_path)
                elif doc_path.endswith('.pdf'):
                    loader = PyPDFLoader(doc_path)
                elif doc_path.endswith('.docx'):
                    loader = Docx2txtLoader(doc_path)
                else:
                    print(f"Unsupported file type. Attempting TextLoader...")
                    loader = TextLoader(doc_path)
                
                # Load document
                documents = loader.load()
                
                # Split documents
                text_splitter = RecursiveCharacterTextSplitter(
                    chunk_size=500,
                    chunk_overlap=50
                )
                splits = text_splitter.split_documents(documents)
                
                # Add to vectorstore (already uses all-mpnet-base-v2 embeddings)
                bot.vectorstore.add_documents(splits)
                
                print(f"Successfully added {len(splits)} document chunks to vector store.")
                
            except Exception as e:
                print(f"Error loading document: {e}")
            
            continue
        
        else:
            response = bot.chat(user_input)
            print(f"\nAstro Bot: {response}")