import os
import json
from fastapi import WebSocket, WebSocketDisconnect
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_core.prompts import ChatPromptTemplate
from langchain_classic.chains.combine_documents import create_stuff_documents_chain
from langchain_classic.chains import create_retrieval_chain


INDEX_PATH = "./faiss_index"

# 1. Initialize FastAPI Application
app = FastAPI(
    title="Kerala Rehabilitation & Recovery Support API",
    description="A secure, localized API backend built for mobile app integration.",
    version="1.0.0"
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows connections from any frontend application
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Define Request Schema (Expected JSON structure from mobile app)


class ChatRequest(BaseModel):
    message: str


# 3. Load Local Components (Embeddings & FAISS)
print("Loading local HuggingFace embeddings...")
embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

if os.path.exists(INDEX_PATH):
    print("Loading local FAISS database...")
    vectorstore = FAISS.load_local(
        INDEX_PATH, embeddings, allow_dangerous_deserialization=True)
    print("FAISS database loaded successfully.")
else:
    print("Warning: Local FAISS database not found. Please run ingest.py first.")
    vectorstore = None

# 4. Connect to LM Studio Local Server
# Ensure your Llama 3.2 3B Instruct server is turned ON in LM Studio on port 1234
llm = ChatOpenAI(
    base_url="http://localhost:1234/v1",
    api_key="lm-studio",
    temperature=0.2,
    max_tokens=1024
)

# 5. Build RAG Processing Engine


def build_rag_chain():
    # Use MMR for highly diversified factual retrieval across distinct documents
    retriever = vectorstore.as_retriever(
        search_type="mmr", search_kwargs={"k": 5, "fetch_k": 20})

    system_prompt = (
        "You are a highly empathetic, professional, and knowledgeable clinical assistant specializing in drug rehabilitation and recovery, "
        "explicitly serving the people of Kerala, India.\n\n"
        "KERALA LOCALIZATION & PRIORITIZATION RULES:\n"
        "1. Your entire target audience resides in Kerala. All administrative, legal, helpline, or government-support answers MUST strictly align with the Kerala/Indian context.\n"
        "2. If the user asks about helplines, rehabilitation centers, support groups, or government schemes, you MUST ONLY provide Kerala-specific resources (such as the VIMUKTHI mission). "
        "You are strictly FORBIDDEN from mentioning non-Indian hotlines, numbers, or organizations (e.g., SAMHSA, 988, US-based hotlines) even if they appear in the retrieved international WHO documents.\n"
        "3. For general drug precaution, scientific, or clinical questions (e.g., substance classification, coping strategies, or withdrawal symptoms), provide accurate information based on the retrieved context, but frame it cleanly for a local user.\n"
        "4. If there is ever a conflict between local Kerala Government guidelines and international frameworks regarding administrative or legal processes, always prioritize the Kerala Government framework.\n\n"
        "5. SPECIFIC LOCATION FILTERING: If the user asks for rehabilitation centers, clinics, or support resources in a specific city, district, or region (e.g., 'Trivandrum', 'Kochi', 'Delhi'), you MUST ONLY return centers and resources located in that specific city or district. Do NOT list or mention centers located in other districts or cities (e.g., Kottayam, Thrissur) even if they are present in the retrieved context. If no centers in the requested location are found in the retrieved context, state clearly: 'No rehabilitation centers in [Requested Location] were found in the provided documents.'\n\n"
        "INSTRUCTIONS:\n"
        "- Synthesize the retrieved information into a clear, structured, and easy-to-read response.\n"
        "- Use bullet points or numbered lists whenever you are listing symptoms, criteria, steps, or strategies.\n\n"
        "STRICT RAG RULES:\n"
        "1. You MUST NOT answer questions outside the provided context. If the context lacks the answer, state explicitly: 'I cannot answer this based on the provided documents.'\n"
        "2. You MUST NOT provide medical diagnoses or prescribe treatments.\n"
        "3. You MUST cite the source document and page number for every piece of information provided, using the format [Source: {{source}}, Page: {{page}}].\n"
        "4. You MUST include the following disclaimer at the very end of EVERY response:\n"
        "   ***\n"
        "   *Disclaimer: This tool provides informational support only and is not a substitute for professional medical advice or treatment. "
        "If you or someone you know is in crisis, please seek immediate help. In Kerala, contact the VIMUKTHI helpline at 14405.*\n"
        "   ***\n\n"
        "CONTEXT:\n"
        "{context}"
    )

    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("human", "{input}")])
    question_answer_chain = create_stuff_documents_chain(llm, prompt)
    return create_retrieval_chain(retriever, question_answer_chain)

# 6. Build Casual/Chitchat Engine


def build_chitchat_chain():
    chitchat_prompt = ChatPromptTemplate.from_messages([
        ("system", 
         "You are an empathetic, polite, and helpful support assistant. Respond naturally to the user's greeting or casual courtesy. Keep it brief. "
         "You are strictly dedicated to drug rehabilitation and recovery. If the user asks or tries to discuss any other topic (such as love, coding, sports, general knowledge), "
         "you MUST politely decline and guide them back to drug rehabilitation and recovery topics."
        ),
        ("human", "{input}")
    ])
    return chitchat_prompt | llm


# 6.5. Build Crisis Support Engine


def build_crisis_chain():
    crisis_prompt = ChatPromptTemplate.from_messages([
        ("system", 
         "You are a deeply compassionate, empathetic, and supportive crisis response assistant. "
         "The user is expressing self-harm, suicidal thoughts, or severe psychological distress. "
         "Your primary goal is to keep them safe, validate their feelings with immense kindness, and provide immediate local help.\n\n"
         "CRITICAL HELPLINES TO INCLUDE:\n"
         "- VIMUKTHI Helpline (Kerala Government): 14405\n"
         "- Tele-MANAS (Govt of India Mental Health Helpline): 14416 or 1800-891-4416\n"
         "- Sneha India Suicide Prevention Helpline: +91 44 2464 0050\n\n"
         "INSTRUCTIONS:\n"
         "- Start with a warm, caring, non-judgmental acknowledgment of their pain.\n"
         "- Do NOT offer complex medical diagnoses, but encourage them to connect with professionals or a trusted loved one.\n"
         "- List the helpline numbers clearly using bullet points.\n"
         "- Keep the tone gentle, encouraging, and supportive."
        ),
        ("human", "{input}")
    ])
    return crisis_prompt | llm

# 7. Build Intent Router


async def check_intent(user_input):
    router_prompt = (
        "You are an AI security router for a medical/rehabilitation application. "
        "Classify the user input into exactly one of four categories: 'RAG', 'CRISIS', 'CHITCHAT', or 'IRRELEVANT'.\n\n"
        "CRITERIA:\n"
        "1. Choose 'RAG' if the user is asking about drug addiction, prevention, recovery guidelines, "
        "rehabilitation centers, hospital/clinic recommendations, helplines, support groups, coping mechanisms, or health/psychological symptoms. "
        "This includes general help requests related to addiction recovery. "
        "EXAMPLES: 'rehab center in kochi', 'rehab centres in delhi', 'list of recovery centers in kerala', 'symptoms of withdrawal', 'i need help to stop drugs'.\n"
        "2. Choose 'CRISIS' ONLY if the user is expressing active thoughts of self-harm, suicide, wanting to die, or severe self-destructive intent. "
        "Do NOT choose 'CRISIS' for general requests for rehabilitation help, symptoms, or recovery information. "
        "EXAMPLES: 'i want to die', 'I feel like giving up on life', 'how to end my life', 'I want to kill myself'.\n"
        "3. Choose 'CHITCHAT' if the user is saying hello, goodbye, thanking you, or making basic conversational small talk. "
        "EXAMPLES: 'hi', 'hello', 'thanks', 'how are you'.\n"
        "4. Choose 'IRRELEVANT' if the user is asking about general knowledge, sports, celebrities, pop culture, history, "
        "math, coding, or anything completely unrelated to health and addiction recovery. "
        "EXAMPLES: 'Who is Messi?', 'What is the capital of France?', 'Write a Python script'.\n\n"
        "Output ONLY the single word 'RAG', 'CRISIS', 'CHITCHAT', or 'IRRELEVANT' with no other text or explanation.\n\n"
        f"User Input: {user_input}"
    )
    try:
        response = await llm.ainvoke(router_prompt)
        raw_intent = response.content.strip().upper()
        # Strictly extract category keyword to prevent conversational substring matching bugs
        if "CRISIS" in raw_intent:
            return "CRISIS"
        elif "CHITCHAT" in raw_intent:
            return "CHITCHAT"
        elif "RAG" in raw_intent:
            return "RAG"
        else:
            return "IRRELEVANT"


    except Exception:
        # Fallback default if local server stumbles
        return "RAG"


# Initialize active production pipelines
rag_chain = build_rag_chain() if vectorstore else None
chitchat_chain = build_chitchat_chain()
crisis_chain = build_crisis_chain()

# 8. Main API Endpoint Called by Mobile Frontends


# =====================================================================
# REPLACE SECTION 8 ENTIRELY WITH THIS:
# =====================================================================

# CHANGED: Replaced @app.post with @app.websocket
@app.websocket("/chat")
async def websocket_endpoint(websocket: WebSocket):
    # ADDED: Handshake connection step
    await websocket.accept()
    print("Mobile app connected via WebSocket.")
    
    if not vectorstore or not rag_chain:
        # CHANGED: Uses send_json and close instead of raising HTTPException
        await websocket.send_json({"error": "Local FAISS index missing. Run ingest.py first."})
        await websocket.close(code=1008)
        return

    try:
        # ADDED: Loop keeps the persistent connection alive
        while True:
            # ADDED: Listen for text data stream and decode JSON
            data = await websocket.receive_text()
            request_data = json.loads(data)
            user_input = request_data.get("message", "").strip()

            if not user_input:
                await websocket.send_json({"error": "Message content cannot be empty."})
                continue

            # CHANGED: Added 'await' to match the async router function
            intent = await check_intent(user_input) 

            # CHANGED: Use astream for real-time streaming response chunks
            if intent == "RAG":
                async for chunk in rag_chain.astream({"input": user_input}):
                    if "answer" in chunk:
                        await websocket.send_json({
                            "reply": chunk["answer"],
                            "intent_processed": intent,
                            "done": False
                        })

            elif intent == "CRISIS":
                async for chunk in crisis_chain.astream({"input": user_input}):
                    if chunk.content:
                        await websocket.send_json({
                            "reply": chunk.content,
                            "intent_processed": intent,
                            "done": False
                        })

            elif intent == "CHITCHAT":
                async for chunk in chitchat_chain.astream({"input": user_input}):
                    if chunk.content:
                        await websocket.send_json({
                            "reply": chunk.content,
                            "intent_processed": intent,
                            "done": False
                        })

            else:
                answer = "I am a specialized support assistant dedicated strictly to drug rehabilitation, prevention, and recovery information. I cannot answer questions unrelated to these topics."
                await websocket.send_json({
                    "reply": answer,
                    "intent_processed": intent,
                    "done": False
                })

            # ADDED: Send done signal to finalize frontend rendering
            await websocket.send_json({"done": True})

    # ADDED: New catch blocks specifically for handling WebSocket events
    except WebSocketDisconnect:
        print("Mobile client disconnected normally.")
    except Exception as e:
        print(f"Error encountered: {e}")
        try:
            await websocket.send_json({"error": f"Internal local failure: {str(e)}"})
        except:
            pass