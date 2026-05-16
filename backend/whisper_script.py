import sys
import whisper

def main():
    if len(sys.argv) < 2:
        print("No audio file path provided", file=sys.stderr)
        sys.exit(1)

    audio_path = sys.argv[1]

    try:
        # "small" model is significantly better for Nepali than "base"
        # First-run will download ~460MB — subsequent runs use cache
        model = whisper.load_model("small")
        result = model.transcribe(audio_path, language="ne", task="transcribe")
        text = result["text"].strip()
        # Always print to stdout and exit 0 on successful transcription —
        # even when the result is empty (e.g. silent recording, sound
        # effect, or audio with no speech). The Node caller checks for an
        # empty string and returns a friendly "speak more clearly" message;
        # if we exit 1 here that path is unreachable and the user sees a
        # cryptic "Command failed: python3 …" error instead.
        print(text)
    except Exception as e:
        # Real failures (corrupt file, model load error, etc.) still bubble
        # up with a non-zero exit so the caller can surface a 500.
        print(f"Whisper error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()