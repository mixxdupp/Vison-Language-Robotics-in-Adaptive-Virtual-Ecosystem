import speech_recognition as sr
import sys

def listen_and_recognize(timeout_seconds=5, phrase_time_limit_seconds=5):
    """Listens for a command via microphone and returns the recognized text."""
    r = sr.Recognizer()
    mic = sr.Microphone() # You might need to specify device_index if you have multiple mics

    with mic as source:
        # Optional: Adjust for ambient noise once at the start
        # print("Adjusting for ambient noise...")
        # r.adjust_for_ambient_noise(source, duration=1)
        # print("Listening...")
        try:
            # Listen for audio input with timeouts
            audio = r.listen(source, timeout=timeout_seconds, phrase_time_limit=phrase_time_limit_seconds)
        except sr.WaitTimeoutError:
            print("TIMEOUT: No phrase detected within timeout period.", file=sys.stderr)
            return None # Indicate timeout

    # Try recognizing the speech
    try:
        # Using Google Web Speech API (requires internet)
        recognized_text = r.recognize_google(audio)
        print(recognized_text) # Print recognized text to standard output
        return recognized_text
    except sr.UnknownValueError:
        print("ERROR: Could not understand audio", file=sys.stderr)
        return None # Indicate failure to understand
    except sr.RequestError as e:
        print(f"ERROR: Could not request results from Google Speech Recognition service; {e}", file=sys.stderr)
        return None # Indicate network/service error
    except Exception as e:
        print(f"ERROR: An unexpected error occurred during recognition: {e}", file=sys.stderr)
        return None # Indicate other errors


if __name__ == "__main__":
    # print("Python script: Listening for command...") # Debug print to stderr
    listen_and_recognize()
    # print("Python script: Finished.") # Debug print to stderr