# Homebrew Tap for STT

Speech-to-text CLI with speaker diarization using Parakeet v3.

## Installation

```bash
# Add this tap
brew tap YOUR_USERNAME/tap

# Install STT
brew install stt
```

## Usage

```bash
# Basic usage with diarization
stt input.mp3

# Transcription only (faster)
stt input.mp3 --transcribe-only

# Custom diarization threshold
stt input.mp3 --threshold 0.8

# Verbose output
stt input.mp3 --verbose

# Show help
stt --help
```

## Requirements

- macOS 13.0 or later
- First run downloads AI models (~495MB)
- Models stored in `~/Library/Application Support/FluidAudio/Models/`

## Uninstallation

```bash
brew uninstall stt
brew untap YOUR_USERNAME/tap
```

## Features

- 🎯 **Accurate transcription** using Parakeet v3 STT model
- 👥 **Speaker diarization** to identify different speakers
- 🔄 **Clean conversation format** with grouped speaker turns
- 📁 **Multiple output files** (transcript, diarization, combined)
- ⚡ **On-device processing** with Apple Neural Engine optimization
- 🎛️ **Configurable settings** for diarization threshold and output

## Output Files

For input `audio.mp3`, creates:
- `audio_transcript.txt` - Raw transcription
- `audio_diarization.txt` - Speaker segment details  
- `audio_combined.txt` - Clean conversation format

Example combined output:
```
Speaker A: Creating a prompt to tell it to find specific things and respond in a specific way
Speaker B: I don't think that will work. Let me explain the issue with the current algorithm...
```