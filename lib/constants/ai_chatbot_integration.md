# Fine-Tuning a Llama Model in Ollama & Integrating with Nizhal

This guide documents the complete end-to-end process of fine-tuning a LLaMA-3/LLaMA-3.1 model with custom drug rehabilitation, counseling, and legal datasets, converting it to GGUF format, running it locally via Ollama, and integrating it with the Flutter application.

---

## 1. Preparing the Fine-Tuning Dataset
To make the model behave like the Nizhal Rehab Counselor, we need a dataset containing system-specific questions, answers, and tone templates. Create a file named `nizhal_dataset.json` in the following instruction format:

```json
[
  {
    "instruction": "Provide advice on seeking help for drug addiction anonymously.",
    "input": "",
    "output": "Under the Nizhal program, your identity is encrypted by default. You can access chat services, find local rehab centers, and submit reports completely anonymously. Seek guidance from licensed counselors at our directory or start a chat session."
  },
  {
    "instruction": "What are the legal protections for rehabilitation in Kerala?",
    "input": "",
    "output": "In Kerala, seeking voluntary treatment for substance abuse is protected. Medical records at government rehab centers are strictly confidential. Our app provides contact details for certified de-addiction centers across all 14 districts."
  }
]
```

---

## 2. Fine-Tuning using Unsloth (Recommended)
Unsloth is a fast library for fine-tuning LLMs on a single GPU. Run this inside a Python environment or Google Colab:

```python
from unsloth import FastLanguageModel
import torch
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset

# 1. Load Llama-3-8B model
max_seq_length = 2048
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3-8b-Instruct-bnb-4bit",
    max_seq_length = max_seq_length,
    load_in_4bit = True,
)

# 2. Add LoRA Adapters for parameter-efficient tuning
model = FastLanguageModel.get_peft_model(
    model,
    r = 16,
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
    use_gradient_checkpointing = "unsloth",
)

# 3. Format prompt template
prompt_style = """Below is an instruction that describes a task. Write a response that appropriately completes the request.

### Instruction:
{}

### Response:
{}"""

def formatting_prompts_func(examples):
    instructions = examples["instruction"]
    outputs      = examples["output"]
    texts = []
    for inst, out in zip(instructions, outputs):
        texts.append(prompt_style.format(inst, out))
    return { "text" : texts }

dataset = load_dataset("json", data_files="nizhal_dataset.json", split="train")
dataset = dataset.map(formatting_prompts_func, batched=True)

# 4. Train the model
trainer = SFTTrainer(
    model = model,
    tokenizer = tokenizer,
    train_dataset = dataset,
    dataset_text_field = "text",
    max_seq_length = max_seq_length,
    dataset_num_proc = 2,
    packing = False,
    args = TrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps = 5,
        max_steps = 60,
        learning_rate = 2e-4,
        fp16 = not torch.cuda.is_bf16_supported(),
        bf16 = torch.cuda.is_bf16_supported(),
        logging_steps = 1,
        output_dir = "outputs",
    ),
)
trainer.train()

# 5. Save the fine-tuned model directly as a 16-bit GGUF file
model.save_pretrained_gguf("nizhal_llama_model", tokenizer, quantization_method = "q4_k_m")
```

---

## 3. Creating a Custom Model in Ollama
Once you have the `nizhal_llama_model-unsloth.Q4_K_M.gguf` file generated from Unsloth:

1. Move the `.gguf` file to your local computer running Ollama.
2. Create a file named `Modelfile` in the same folder with the following content:

```dockerfile
FROM ./nizhal_llama_model-unsloth.Q4_K_M.gguf

# Set parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.9

# Set the system message (tells Llama how to act)
SYSTEM """
You are Nizhal AI, a compassionate, anonymous drug rehabilitation assistant and counselor for citizens of Kerala. 
Provide legal, medical, and mental health guidance. Be concise, non-judgmental, and encourage rehabilitation.
Never expose confidential user details.
"""
```

3. Run the following command in terminal/command prompt to build the local Ollama model:
```bash
ollama create nizhal-llama -f Modelfile
```

4. Verify it runs:
```bash
ollama run nizhal-llama
```

---

## 4. Integrating with Nizhal Flutter Application

To connect the local Ollama instance (or a hosted instance) to the Nizhal Flutter App, create a service class to handle HTTP communications with the local endpoint `http://localhost:11434/api/chat`.

### Flutter Integration Service Example:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaChatService {
  final String baseUrl; // Default: 'http://localhost:11434'
  final String modelName; // Default: 'nizhal-llama'

  OllamaChatService({
    this.baseUrl = 'http://localhost:11434',
    this.modelName = 'nizhal-llama',
  });

  /// Send chat message history to Ollama and get a streaming or complete response
  Future<String> getResponse(List<Map<String, String>> messagesHistory) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelName,
          'messages': messagesHistory,
          'stream': false, // Set to true to read chunked streaming responses
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['message']['content'] ?? '';
      } else {
        return 'Error: Server returned code ${response.statusCode}';
      }
    } catch (e) {
      return 'Failed to connect to local AI engine: Ensure Ollama is running.';
    }
  }
}
```

This service can then be injected into `rehab_chat_screen.dart` to power the AI Counselor dynamically!
