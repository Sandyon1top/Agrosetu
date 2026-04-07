const { exec } = require("child_process");
const { promisify } = require("util");
const execAsync = promisify(exec);
const fs = require("fs");
const path = require("path");

async function generateAudioBase64(text) {
  const ttsScript = path.join(__dirname, "tts_script.py");
  const tempId = Math.random().toString(36).substring(7);
  const outPath = path.join(__dirname, "uploads", `tts_${tempId}.mp3`);
  
  try {
    const command = `python3 "${ttsScript}" "${text}" "${outPath}"`;
    await execAsync(command, { cwd: __dirname, timeout: 60000 });
    const audioBytes = fs.readFileSync(outPath);
    const base64Audio = audioBytes.toString('base64');
    fs.unlinkSync(outPath);
    console.log("Base64 length:", base64Audio.length);
    return base64Audio;
  } catch (err) {
    console.error("TTS Error:", err);
    if (fs.existsSync(outPath)) fs.unlinkSync(outPath);
    return null;
  }
}

generateAudioBase64("नमस्ते साथीहरू, कस्तो छ?").then(b64 => {
  if(b64) console.log("Success");
});
