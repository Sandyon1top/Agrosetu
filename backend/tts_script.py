import sys
from gtts import gTTS

def main():
    if len(sys.argv) < 3:
        print("Usage: python tts_script.py <text> <output.mp3>")
        sys.exit(1)
        
    text = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        tts = gTTS(text=text, lang='ne')
        tts.save(output_file)
        print("Success")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
