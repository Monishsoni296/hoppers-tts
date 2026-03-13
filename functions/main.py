import base64
import emoji
from firebase_functions import https_fn, options
from firebase_admin import initialize_app, storage
from google.cloud import texttospeech

initialize_app()

@https_fn.on_call(
        cors=options.CorsOptions(
            cors_origins="*",
            cors_methods=["POST"]
        )
)
def generate_tts(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError("unauthenticated", "Authentication required")
    
    text_input = req.data.get("text", "") if req.data else ""
    if not text_input:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a 'text' argument.",
        )
    # Convert emojis to text
    raw_demojized = emoji.demojize(text_input)
    text_with_names = raw_demojized.replace('_',' ').replace(':','')
    text_for_filename = text_with_names.replace(' ','_')
    
    # Check Cache (Firebase Storage)
    bucket = storage.bucket("hoppers-489314.appspot.com")
    blob = bucket.blob(f"tts_cache/{text_for_filename}.mp3")

    if blob.exists():
        audio_bytes = blob.download_as_bytes()
        return {
            "audioContent": base64.b64encode(audio_bytes).decode("utf-8"),
            "cached": True
        }

    # Cache Miss
    client = texttospeech.TextToSpeechClient()
    synthesis_input = texttospeech.SynthesisInput(text=text_with_names)
    voice = texttospeech.VoiceSelectionParams(
        language_code="en-US",
        name="en-US-Chirp-HD-F" 
    )

    # AUDIO CONFIG
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        speaking_rate=1.1,
        # pitch=10,
        # effects_profile_id=["small-bluetooth-speaker-class-device"]
    )

    try:
        response = client.synthesize_speech(
            input=synthesis_input, voice=voice, audio_config=audio_config
        )

        blob.upload_from_string(response.audio_content, content_type="audio/mpeg")

        return {
            "audioContent": base64.b64encode(response.audio_content).decode("utf-8"),
            "cached": False
        }

    except Exception as e:
        print(f"Error: {e}")
        return https_fn.HttpsError("internal", f"Internal Error: {e}")