# STT - Speech-to-Text with Speaker Diarization

A macOS command-line utility for speech-to-text transcription with speaker diarization using the Parakeet v3 model from FluidAudio.

## Features

- **🎵 Audio Processing**: Supports MP3 and other common audio formats
- **🗣️ Speech Recognition**: Uses Parakeet TDT v3 (0.6b) for high-accuracy transcription
- **👥 Speaker Diarization**: Identifies different speakers and segments their speech
- **🚀 On-Device Processing**: Everything runs locally on Apple Neural Engine (ANE)
- **📄 Multiple Output Formats**: Individual transcripts, diarization results, and combined output

## Requirements

- macOS 13.0 or later
- Apple Silicon Mac (M1, M2, M3, M4) recommended for optimal performance
- Swift 5.10 or later

## Installation

### Build from Source

```bash
git clone <your-repo-url>
cd stt
swift build -c release
```

The compiled binary will be available at `.build/release/stt`

### Add to PATH (Optional)

```bash
# Copy to a directory in your PATH
cp .build/release/stt /usr/local/bin/stt
```

## Usage

### Basic Usage

```bash
# Transcribe and diarize an audio file
stt input.mp3

# Transcribe only (skip diarization)
stt input.mp3 --transcribe-only

# Verbose output
stt input.mp3 --verbose

# Custom output directory
stt input.mp3 --output ./results/

# Custom diarization threshold (0.0-1.0, default: 0.8)
stt input.mp3 --threshold 0.6
```

### Command Line Options

```
USAGE: stt <input-file> [--output <output>] [--verbose] [--transcribe-only] [--threshold <threshold>]

ARGUMENTS:
  <input-file>            Input MP3 file path

OPTIONS:
  -o, --output <output>   Output directory for results (default: same as input file)
  -v, --verbose           Enable verbose output
  --transcribe-only       Skip diarization and only perform transcription
  --threshold <threshold> Diarization clustering threshold (0.0-1.0, default: 0.7)
  -h, --help             Show help information.
```

## Output Files

The tool generates up to three output files:

### 1. `*_transcript.txt`
Pure transcription text without speaker information.

```
I think we have finally got a real competitor for anthropic...
```

### 2. `*_diarization.txt` (unless `--transcribe-only` is used)
Detailed diarization results with timing and speaker information.

```
SPEAKER DIARIZATION RESULTS
==========================

Audio Duration: 296.2 seconds
Speaker Count: 2
Segments: 15
Processing Time: 2.14 seconds
Real-time Factor: 0.14x

SPEAKER SEGMENTS:
-----------------
Speaker 1: 00:00.240 - 00:45.680 (45.4s) [Quality: 85.2%]
Speaker 2: 00:45.800 - 01:32.120 (46.3s) [Quality: 91.7%]
Speaker 1: 01:32.240 - 02:15.800 (43.6s) [Quality: 88.9%]
...
```

### 3. `*_combined.txt` (unless `--transcribe-only` is used)
Transcription combined with speaker information and timing.

```
COMBINED TRANSCRIPT WITH SPEAKER DIARIZATION
===========================================

TRANSCRIPT BY SPEAKER:
---------------------

[00:00.240 - 00:45.680] Speaker 1:
I think we have finally got a real competitor for anthropic. The new model seems to be performing really well in our tests.

[00:45.800 - 01:32.120] Speaker 2:
Yes, I agree. The performance metrics are impressive, especially for code generation tasks.

...

FULL TRANSCRIPTION:
-------------------
I think we have finally got a real competitor for anthropic. The new model seems to be performing really well in our tests. Yes, I agree. The performance metrics are impressive, especially for code generation tasks...
```

## Performance

- **Real-time Factor**: Typically 0.05x - 0.2x (processes 1 minute of audio in 3-12 seconds)
- **Memory Usage**: Optimized for Apple Neural Engine with minimal CPU/GPU usage
- **Accuracy**: Competitive with state-of-the-art models
  - WER: ~2.7% on LibriSpeech test-clean
  - DER: ~17.7% on AMI benchmark for diarization

## Supported Languages

Parakeet v3 supports all 25 European languages:

- English, French, German, Italian, Spanish, Portuguese, Dutch, Polish, Russian, Ukrainian, Czech, Slovak, Hungarian, Romanian, Bulgarian, Croatian, Serbian, Slovenian, Estonian, Latvian, Lithuanian, Finnish, Danish, Swedish, Norwegian

## Examples

### Meeting Transcription
```bash
# Process a meeting recording with custom threshold
stt meeting_recording.mp3 --threshold 0.6 --verbose
```

### Podcast Processing
```bash
# Process multiple podcast episodes
for file in *.mp3; do
    echo "Processing $file..."
    stt "$file" --output ./podcast_transcripts/
done
```

### Quick Transcription Only
```bash
# Fast transcription without speaker identification
stt interview.mp3 --transcribe-only
```

## Troubleshooting

### Model Download Issues
- Models are downloaded automatically on first use
- Ensure internet connectivity for initial setup
- Models are cached locally (~2GB total)

### Performance Issues
- Use Apple Silicon Macs for optimal performance
- Ensure sufficient free memory (4GB+ recommended)
- Close other intensive applications during processing

### Audio Format Issues
- The tool automatically converts audio to the required format (16kHz mono)
- Most common formats are supported (MP3, WAV, M4A, FLAC, etc.)

### Diarization Accuracy
- Adjust `--threshold` parameter (lower = more speakers, higher = fewer speakers)
- Default 0.8 works well for most cases
- Try 0.6 for conversations with many speakers
- Try 0.8 for interviews with distinct speakers

## Technical Details

### Models Used
- **ASR**: Parakeet TDT v3 (0.6b) - NVIDIA's transformer-based model
- **Diarization**: Pyannote-based speaker segmentation and embedding
- **VAD**: Silero VAD v2 for voice activity detection

### Processing Pipeline
1. Audio format conversion (16kHz mono)
2. Voice Activity Detection (VAD)
3. Speaker embedding extraction
4. Speaker clustering and diarization
5. Speech-to-text transcription
6. Output generation and formatting

## Credits

Built with:
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Native Swift SDK for local audio AI
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) - Command line parsing
- Apple's CoreML and AVFoundation frameworks

## License

This project is licensed under the MIT License. See the FluidAudio library for its Apache 2.0 license.
