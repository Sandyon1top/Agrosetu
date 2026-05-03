"""End-to-end smoke evaluator for the voice pipeline.

Tests three components independently and reports pass/fail + latency:
  1. STT — Whisper 'small' transcribing a synthesized Nepali audio clip
  2. LLM — Groq llama-3.3-70b answering a Nepali farming question
  3. TTS — gTTS generating Nepali speech from a sample text

No model weights are modified. Read-only smoke test.
"""

import os
import sys
import time
import tempfile
from pathlib import Path

ROOT = Path(__file__).parent

# ── 1. Set up Groq env (loaded same way as production) ─────────────────────
def _load_groq_env():
    """Pull GROQ_API_KEY from Flask/.env or backend/.env (whichever exists)."""
    candidates = [ROOT / ".env", ROOT.parent / "backend" / ".env"]
    for env_file in candidates:
        if env_file.exists():
            for line in env_file.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

_load_groq_env()


def banner(title):
    print()
    print("─" * 72)
    print(f" {title}")
    print("─" * 72)


# ── 2. TTS first, so STT has audio to consume ───────────────────────────────
def test_tts(text="नमस्ते, मेरो आलुमा रोग लागेको छ"):
    banner("TTS — Google gTTS (Nepali)")
    try:
        from gtts import gTTS
    except Exception as e:
        print(f"❌ gtts not installed: {e}")
        return None
    out = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False).name
    t0 = time.time()
    try:
        tts = gTTS(text=text, lang="ne")
        tts.save(out)
        dt = time.time() - t0
        size_kb = os.path.getsize(out) / 1024
        print(f"✅ TTS ok   {dt:.2f}s   {size_kb:.1f} KB")
        print(f"   text:  {text}")
        print(f"   file:  {out}")
        return out
    except Exception as e:
        print(f"❌ TTS failed: {e}")
        return None


# ── 3. STT on the audio we just generated ───────────────────────────────────
def test_stt(audio_path):
    banner("STT — Whisper 'small' (Nepali)")
    if not audio_path or not os.path.exists(audio_path):
        print("❌ no audio file to transcribe")
        return None
    try:
        import whisper
    except Exception as e:
        print(f"❌ openai-whisper not installed: {e}")
        return None
    t0 = time.time()
    try:
        print("   loading model 'small' (~500MB; one-time download)...")
        model = whisper.load_model("small")
        result = model.transcribe(audio_path, language="ne", task="transcribe")
        dt = time.time() - t0
        text = (result.get("text") or "").strip()
        print(f"✅ STT ok   {dt:.2f}s")
        print(f"   transcript: {text}")
        return text
    except Exception as e:
        print(f"❌ STT failed: {e}")
        return None


# ── 4. LLM with a representative farming question ───────────────────────────
def test_llm(prompt="मेरो आलुमा कुहिने रोग लाग्यो, के गर्ने?"):
    banner("LLM — Groq llama-3.3-70b-versatile")
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        print("❌ GROQ_API_KEY not set in env")
        return None
    try:
        from groq import Groq
    except Exception as e:
        print(f"❌ groq sdk not installed: {e}")
        return None
    t0 = time.time()
    try:
        client = Groq(api_key=key)
        rsp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system",
                 "content": "You are an agricultural assistant. Reply in Nepali, concise."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_tokens=200,
        )
        dt = time.time() - t0
        ans = rsp.choices[0].message.content.strip()
        tokens = getattr(rsp, "usage", None)
        tin = getattr(tokens, "prompt_tokens", "?") if tokens else "?"
        tout = getattr(tokens, "completion_tokens", "?") if tokens else "?"
        print(f"✅ LLM ok   {dt:.2f}s   tokens in/out: {tin}/{tout}")
        print(f"   prompt: {prompt}")
        print(f"   answer: {ans}")
        return ans
    except Exception as e:
        print(f"❌ LLM failed: {e}")
        return None


def main():
    print("=" * 72)
    print(" AGROSETU VOICE PIPELINE — SMOKE TEST")
    print("=" * 72)

    audio = test_tts()
    transcript = test_stt(audio)
    answer = test_llm()

    print()
    print("=" * 72)
    print(" SUMMARY")
    print("=" * 72)
    print(f" TTS  (gTTS Nepali):                 {'✅ pass' if audio else '❌ fail'}")
    print(f" STT  (Whisper small Nepali):        {'✅ pass' if transcript else '❌ fail'}")
    print(f" LLM  (Groq llama-3.3-70b):          {'✅ pass' if answer else '❌ fail'}")
    if audio:
        try:
            os.unlink(audio)
        except OSError:
            pass


if __name__ == "__main__":
    main()
