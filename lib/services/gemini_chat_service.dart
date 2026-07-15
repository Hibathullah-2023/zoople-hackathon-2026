import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

/// Gemini AI Chat Service for Rehabilitation Support.
///
/// This service uses the Google Gemini API with a carefully fine-tuned
/// system instruction to act as a compassionate rehabilitation assistant.
///
/// ## Fine-Tuning Instructions (for future custom model training):
///
/// ### 1. Prepare Training Data
/// Create a JSONL file with prompt-response pairs focused on:
/// - Substance abuse recovery guidance
/// - Kerala-specific rehabilitation resources
/// - Mental health support conversations
/// - Crisis intervention dialogues
/// - Harm reduction information
///
/// Example JSONL format:
/// ```json
/// {"prompt": "I'm struggling with alcohol addiction", "response": "I hear you, and I want you to know that reaching out is a courageous first step..."}
/// {"prompt": "Where can I find help in Ernakulam?", "response": "In Ernakulam, you can visit the Government De-addiction Centre at General Hospital..."}
/// ```
///
/// ### 2. Fine-Tune via Vertex AI (Google Cloud)
/// ```bash
/// # Upload training data to GCS
/// gsutil cp training_data.jsonl gs://your-bucket/rehab-training/
///
/// # Create a tuning job via Vertex AI
/// gcloud ai model-tuning-jobs create \
///   --region=us-central1 \
///   --display-name="nizhal-rehab-assistant" \
///   --model="gemini-1.5-flash" \
///   --training-data="gs://your-bucket/rehab-training/training_data.jsonl" \
///   --tuned-model-display-name="nizhal-rehab-v1"
/// ```
///
/// ### 3. Fine-Tune via Google AI Studio (simpler)
/// 1. Go to https://aistudio.google.com/
/// 2. Click "New tuned model"
/// 3. Upload your JSONL training data
/// 4. Select base model (Gemini 1.5 Flash recommended for speed)
/// 5. Set hyperparameters (epochs: 5, learning rate: 0.001)
/// 6. Start training and note the tuned model name
/// 7. Replace the model name in this service with your tuned model name
///
/// ### 4. Switch to Custom Backend (future)
/// When ready for a custom RAG backend:
/// 1. Deploy a FastAPI/Flask backend with your vector DB (Pinecone, ChromaDB)
/// 2. Index Kerala rehab center data, helpline numbers, recovery guides
/// 3. Replace the `sendMessage()` method to call your REST API instead
/// 4. Keep the same system instruction as context for your RAG pipeline
///
class GeminiChatService {
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isInitialized = false;
  String? _initError;

  /// The API key for Gemini. In production, store this securely
  /// (e.g., Firebase Remote Config, environment variable, or server-side proxy).
  ///
  /// Get your API key from: https://aistudio.google.com/apikey

  static const _apiKey = String.fromEnvironment('');

  /// System instruction that fine-tunes Gemini's behavior for rehabilitation support.
  /// This acts as the "personality" and knowledge base for the chatbot.
  static const String _systemInstruction = '''
You are "Nizhal Assistant", a compassionate and knowledgeable AI rehabilitation support counselor for the Nizhal app — an anonymous drug incident reporting platform in Kerala, India.

YOUR ROLE:
- You are a supportive, non-judgmental rehabilitation assistant
- You provide information about substance abuse recovery, coping strategies, and available resources
- You are NOT a doctor or therapist — always recommend professional help for medical/clinical concerns
- You speak in a warm, empathetic, and encouraging tone

KNOWLEDGE BASE (Kerala-specific):
- Government De-addiction Centres exist in: Thiruvananthapuram, Ernakulam, Kozhikode, Thrissur, Kollam, Palakkad, Kannur
- Kerala State Mental Health Authority helpline: 1800-599-0019 (toll-free)
- NIMHANS helpline: 080-46110007
- Vandrevala Foundation: 1860-2662-345 (24/7)
- Kerala Excise Department anti-drug helpline: 1800-233-0200
- Support groups: Narcotics Anonymous (NA), Alcoholics Anonymous (AA) chapters are active across Kerala
- Common substances of concern in Kerala: alcohol, cannabis, synthetic drugs, prescription drug misuse

GUIDELINES:
1. Always validate the user's feelings first before giving information
2. Never shame or judge the user for substance use
3. Encourage professional treatment and provide helpline numbers when appropriate
4. If someone mentions suicidal thoughts, immediately provide crisis helpline numbers
5. Keep responses concise (2-4 paragraphs max) but informative
6. Use simple, accessible language (avoid clinical jargon)
7. When asked about specific districts, provide the nearest Government De-addiction Centre
8. Remind users that recovery is a journey and relapses are not failures
9. Maintain strict confidentiality — never ask for personal identifying information
10. If unsure, say so honestly and recommend consulting a professional

TOPICS YOU CAN HELP WITH:
- Understanding addiction and its effects
- Recovery strategies and coping mechanisms
- Finding nearby rehabilitation centres in Kerala
- Supporting a family member with addiction
- Understanding withdrawal symptoms
- Harm reduction approaches
- Mental health and co-occurring disorders
- Legal aspects of drug possession in India (NDPS Act)
- Motivational support and encouragement

TOPICS YOU MUST DECLINE:
- Specific medical dosage advice
- Diagnosing conditions
- Recommending specific medications
- Any information that could enable substance abuse
- Legal advice (recommend a lawyer instead)
''';

  /// Initialize the Gemini model and start a chat session.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_apiKey == 'YOUR_GEMINI_API_KEY' || _apiKey.isEmpty) {
      _initError = 'Gemini API key not configured. Using offline mode.';
      debugPrint(_initError);
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash', // Use 'gemini-1.5-pro' for better quality
        apiKey: _apiKey,
        systemInstruction: Content.system(_systemInstruction),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.low),
          SafetySetting(
            HarmCategory.sexuallyExplicit,
            HarmBlockThreshold.medium,
          ),
        ],
      );

      _chat = _model!.startChat(history: []);
      _isInitialized = true;
      _initError = null;
      debugPrint('Gemini Chat Service initialized successfully.');
    } catch (e) {
      _initError = 'Failed to initialize Gemini: $e';
      debugPrint(_initError);
    }
  }

  /// Whether the service is ready to send messages.
  bool get isReady => _isInitialized && _chat != null;

  /// The initialization error, if any.
  String? get initError => _initError;

  /// Send a message and get a response from Gemini.
  /// Returns the AI response text, or a fallback if the API is unavailable.
  Future<String> sendMessage(String userMessage) async {
    if (!isReady) {
      return _getFallbackResponse(userMessage);
    }

    try {
      final response = await _chat!.sendMessage(Content.text(userMessage));

      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'I appreciate you reaching out. Could you tell me a bit more about what you\'re going through? I\'m here to listen and help.';
      }
      return text;
    } catch (e) {
      debugPrint('Gemini API error: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  /// Fallback responses when the API is unavailable.
  /// These provide basic support even without network connectivity.
  String _getFallbackResponse(String userInput) {
    final cleanInput = userInput.toLowerCase();

    if (cleanInput.contains('suicid') ||
        cleanInput.contains('kill myself') ||
        cleanInput.contains('end my life')) {
      return '🚨 If you or someone you know is in immediate danger, please call:\n\n'
          '• Kerala State Mental Health Helpline: 1800-599-0019 (toll-free)\n'
          '• NIMHANS Helpline: 080-46110007\n'
          '• Vandrevala Foundation: 1860-2662-345 (24/7)\n\n'
          'You are not alone. Please reach out to a professional right now.';
    }

    if (cleanInput.contains('hello') ||
        cleanInput.contains('hi') ||
        cleanInput.contains('hey')) {
      return 'Hello! I\'m the Nizhal Rehabilitation Assistant. I\'m here to listen, support, and share information on substance abuse recovery. How can I help you today?';
    }

    if (cleanInput.contains('rehab') ||
        cleanInput.contains('centre') ||
        cleanInput.contains('center') ||
        cleanInput.contains('hospital')) {
      return 'Kerala has Government De-addiction Centres in major districts including Thiruvananthapuram, Ernakulam, Kozhikode, Thrissur, Kollam, Palakkad, and Kannur.\n\n'
          'You can view a list of nearby centres by selecting the "Nearby Centres" tab above. Would you like help finding a specific centre?';
    }

    if (cleanInput.contains('help') || cleanInput.contains('support')) {
      return 'I can help with:\n\n'
          '• Information on nearby rehabilitation centres\n'
          '• Recovery advice and coping strategies\n'
          '• Understanding withdrawal symptoms\n'
          '• Supporting a family member with addiction\n'
          '• Helpline numbers and crisis resources\n\n'
          'What would you like to know more about?';
    }

    if (cleanInput.contains('addict') ||
        cleanInput.contains('drug') ||
        cleanInput.contains('alcohol') ||
        cleanInput.contains('substance')) {
      return 'Addiction is a complex condition, but recovery is absolutely possible with the right support. Professional treatment programs, behavioral therapy, and support groups like Narcotics Anonymous are highly effective.\n\n'
          'Kerala Excise Anti-Drug Helpline: 1800-233-0200\n\n'
          'Would you like me to help you find a treatment centre near you?';
    }

    if (cleanInput.contains('depress') ||
        cleanInput.contains('sad') ||
        cleanInput.contains('anxious') ||
        cleanInput.contains('stress')) {
      return 'I hear you, and your feelings are valid. Recovery can be emotionally challenging, and it\'s completely normal to have difficult days.\n\n'
          'Please consider reaching out to a mental health professional. You can contact:\n'
          '• Kerala Mental Health Helpline: 1800-599-0019\n'
          '• Vandrevala Foundation: 1860-2662-345 (24/7)\n\n'
          'Remember: seeking help is a sign of strength, not weakness.';
    }

    if (cleanInput.contains('thank') || cleanInput.contains('thanks')) {
      return 'You\'re very welcome! Remember, every step forward matters, no matter how small. Nizhal is here to support our community. Stay strong, and take care of yourself. 💙';
    }

    if (cleanInput.contains('family') ||
        cleanInput.contains('friend') ||
        cleanInput.contains('someone I know')) {
      return 'Supporting a loved one through addiction is challenging but deeply important. Here are some suggestions:\n\n'
          '• Educate yourself about addiction — it\'s a medical condition, not a moral failure\n'
          '• Set healthy boundaries while showing compassion\n'
          '• Encourage professional treatment without forcing it\n'
          '• Take care of your own mental health too\n'
          '• Consider joining a support group like Al-Anon for families\n\n'
          'Would you like more specific guidance?';
    }

    return 'Thank you for reaching out. I\'m currently in offline mode, but I want you to know that help is available.\n\n'
        'You can call the Kerala Mental Health Helpline at 1800-599-0019 (toll-free, 24/7) for immediate support.\n\n'
        'Please also check the "Nearby Centres" tab above for rehabilitation centres in your district.';
  }

  /// Dispose the service and free resources.
  void dispose() {
    _chat = null;
    _model = null;
    _isInitialized = false;
  }
}
