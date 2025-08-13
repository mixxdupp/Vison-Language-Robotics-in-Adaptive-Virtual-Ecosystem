import pyttsx3
import sys

def speak(text_to_speak):
    """Uses pyttsx3 to speak the provided text."""
    try:
        engine = pyttsx3.init()
        # Optional: Adjust rate, volume, voice
        # rate = engine.getProperty('rate')
        # engine.setProperty('rate', rate - 50) # Slower
        # volume = engine.getProperty('volume')
        # engine.setProperty('volume', 1.0) # Max volume
        # voices = engine.getProperty('voices')
        # engine.setProperty('voice', voices[0].id) # Change index for different voices

        engine.say(text_to_speak)
        engine.runAndWait() # Blocks until speaking is finished
        engine.stop()
    except Exception as e:
        print(f"Error initializing or using TTS engine: {e}", file=sys.stderr)
        # Fallback: print to console if TTS fails
        print(f"TTS Fallback: {text_to_speak}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:]) # Join arguments in case text has spaces
        speak(text)
    else:
        print("Usage: python speak_text.py <text to speak>", file=sys.stderr)