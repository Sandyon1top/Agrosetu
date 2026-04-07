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
        if text:
            print(text)
        else:
            print("", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Whisper error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()