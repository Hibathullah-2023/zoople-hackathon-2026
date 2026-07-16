import os
from langchain_community.document_loaders import PyPDFDirectoryLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS

DATA_DIR = "./data"
INDEX_PATH = "./faiss_index"

def ingest_documents():
    # Step 1: Ensure data directory exists
    if not os.path.exists(DATA_DIR) or not os.listdir(DATA_DIR):
        print(f"Error: Please create a folder named '{DATA_DIR}' and place your Kerala/WHO PDFs inside it.")
        return

    print(f"Loading PDFs from '{DATA_DIR}'...")
    loader = PyPDFDirectoryLoader(DATA_DIR)
    documents = loader.load()
    print(f"Successfully loaded {len(documents)} pages.")

    # Step 2: Split text semantically without breaking sentences
    print("Splitting text into chunks...")
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1500,
        chunk_overlap=300,
        separators=["\n\n", "\n", "(?<=\. )", " ", ""]
    )
    chunks = text_splitter.split_documents(documents)
    print(f"Generated {len(chunks)} text chunks.")

    # Step 3: Compute embeddings locally using CPU (no internet required)
    print("Downloading/Loading local HuggingFace embedding model (all-MiniLM-L6-v2)...")
    embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
    
    # Step 4: Build and save the FAISS vector database
    print("Building FAISS index...")
    vectorstore = FAISS.from_documents(chunks, embeddings)
    
    print(f"Saving FAISS index locally to '{INDEX_PATH}'...")
    vectorstore.save_local(INDEX_PATH)
    print("Ingestion complete! You can now run api.py.")

if __name__ == "__main__":
    os.makedirs(DATA_DIR, exist_ok=True)
    ingest_documents()