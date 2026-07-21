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

    # Step 2.5: Tag chunks with geographic metadata (Kerala districts)
    print("Tagging chunks with geographic metadata...")
    DISTRICT_MAPPING = {
        "trivandrum": "thiruvananthapuram",
        "thiruvananthapuram": "thiruvananthapuram",
        "thiruvanathapuram": "thiruvananthapuram",
        "kollam": "kollam",
        "quilon": "kollam",
        "pathanamthitta": "pathanamthitta",
        "alappuzha": "alappuzha",
        "allapuzha": "alappuzha",
        "alleppey": "alappuzha",
        "kottayam": "kottayam",
        "idukki": "idukki",
        "iddukki": "idukki",
        "ernakulam": "ernakulam",
        "ernakulum": "ernakulam",
        "kochi": "ernakulam",
        "cochin": "ernakulam",
        "thrissur": "thrissur",
        "trichur": "thrissur",
        "palakkad": "palakkad",
        "palghat": "palakkad",
        "malappuram": "malappuram",
        "calicut": "kozhikode",
        "kozhikode": "kozhikode",
        "khozhikode": "kozhikode",
        "wayanad": "wayanad",
        "kannur": "kannur",
        "cannanore": "kannur",
        "kasaragod": "kasaragod",
        "kasargod": "kasaragod"
    }

    for chunk in chunks:
        text_lower = chunk.page_content.lower()
        matched_districts = set()
        for keyword, canonical in DISTRICT_MAPPING.items():
            if keyword in text_lower:
                matched_districts.add(canonical)
        if matched_districts:
            chunk.metadata["districts"] = list(matched_districts)

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