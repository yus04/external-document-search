import os
import time
from flask import Flask, request, jsonify

import tiktoken
import openai

from azure.identity import DefaultAzureCredential
from approaches.chatlogging import get_user_name, write_error
from approaches.chatreadretrieveread import ChatReadRetrieveReadApproach
from approaches.chatread import ChatReadApproach

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry.instrumentation.flask import FlaskInstrumentor


# Replace these with your own values, either in environment variables or directly here
AZURE_OPENAI_SERVICE = os.environ.get("AZURE_OPENAI_SERVICE")
AZURE_OPENAI_API_VERSION = os.environ.get("AZURE_OPENAI_API_VERSION")

AZURE_OPENAI_GPT_35_TURBO_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT_35_TURBO_DEPLOYMENT")
AZURE_OPENAI_GPT_35_TURBO_16K_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT_35_TURBO_16K_DEPLOYMENT")
AZURE_OPENAI_GPT_4_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT_4_DEPLOYMENT")
AZURE_OPENAI_GPT_4_32K_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT_4_32K_DEPLOYMENT")

BING_SEARCH_SUBSCRIPTION_KEY = os.environ.get("BING_SEARCH_SUBSCRIPTION_KEY")
BING_SEARCH_URL = os.environ.get("BING_SEARCH_URL")

gpt_models = {
    "gpt-3.5-turbo": {
        "deployment": AZURE_OPENAI_GPT_35_TURBO_DEPLOYMENT,
        "max_tokens": 4096,
        "encoding": tiktoken.encoding_for_model("gpt-3.5-turbo")
    },
    "gpt-3.5-turbo-16k": {
        "deployment": AZURE_OPENAI_GPT_35_TURBO_16K_DEPLOYMENT,
        "max_tokens": 16384,
        "encoding": tiktoken.encoding_for_model("gpt-3.5-turbo")
    },
    "gpt-4": {
        "deployment": AZURE_OPENAI_GPT_4_DEPLOYMENT,
        "max_tokens": 8192,
        "encoding": tiktoken.encoding_for_model("gpt-4")
    },
    "gpt-4-32k": {
        "deployment": AZURE_OPENAI_GPT_4_32K_DEPLOYMENT,
        "max_tokens": 32768,
        "encoding": tiktoken.encoding_for_model("gpt-4-32k")
    }
}

# Use the current user identity to authenticate with Azure OpenAI, (no secrets needed, 
# just use 'az login' locally, and managed identity when deployed on Azure). If you need to use keys, use separate AzureKeyCredential instances with the 
# keys for each service
# If you encounter a blocking error during a DefaultAzureCredntial resolution, you can exclude the problematic credential by using a parameter (ex. exclude_shared_token_cache_credential=True)
azure_credential = DefaultAzureCredential()

# Used by the OpenAI SDK
openai.api_type = "azure"
openai.api_base = f"https://{AZURE_OPENAI_SERVICE}.openai.azure.com"
openai.api_version = AZURE_OPENAI_API_VERSION

# Comment these two lines out if using keys, set your API key in the OPENAI_API_KEY environment variable instead
openai.api_type = "azure_ad"
openai_token = azure_credential.get_token("https://cognitiveservices.azure.com/.default")
openai.api_key = openai_token.token
# openai.api_key = os.environ.get("AZURE_OPENAI_KEY")

chat_approaches = {
    "rrr": ChatReadRetrieveReadApproach(
        BING_SEARCH_SUBSCRIPTION_KEY,
        BING_SEARCH_URL
    ),
    "r": ChatReadApproach()
}

# configure_azure_monitor()

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route("/", defaults={"path": "index.html"})
@app.route("/<path:path>")
def static_file(path):
    return app.send_static_file(path)

# Chat
@app.route("/chat", methods=["POST"])
def chat():
    ensure_openai_token()
    approach = request.json["approach"]
    user_name = get_user_name(request)
    overrides = request.json.get("overrides")

    try:
        impl = chat_approaches.get(approach)
        if not impl:
            return jsonify({"error": "unknown approach"}), 400
        r = impl.run(user_name, request.json["history"], overrides)
        return jsonify(r)
    except Exception as e:
        write_error("chat", user_name, str(e))
        return jsonify({"error": str(e)}), 500

# Document Search
@app.route("/docsearch", methods=["POST"])
def docsearch():
    ensure_openai_token()
    approach = request.json["approach"]
    user_name = get_user_name(request)
    overrides = request.json.get("overrides")

    try:
        impl = chat_approaches.get(approach)
        if not impl:
            return jsonify({"error": "unknown approach"}), 400
        r = impl.run(user_name, request.json["history"], overrides)
        return jsonify(r)
    except Exception as e:
        write_error("docsearch", user_name, str(e))
        return jsonify({"error": str(e)}), 500

def ensure_openai_token():
    global openai_token
    if openai_token.expires_on < int(time.time()) - 60:
        openai_token = azure_credential.get_token("https://cognitiveservices.azure.com/.default")
        openai.api_key = openai_token.token
    # openai.api_key = os.environ.get("AZURE_OPENAI_KEY")
   
if __name__ == "__main__":
    app.run(debug=True, port=5000, host='0.0.0.0')
