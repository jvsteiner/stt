class Stt < Formula
  desc "Speech-to-text CLI with speaker diarization using Parakeet v3"
  homepage "https://github.com/jvsteiner/stt"
  url "https://github.com/jvsteiner/stt/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "5472046f7d40c66d4d2c891544d612f53b486943154bb30f44b170649f207c8e"
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    # Build the Swift package
    system "swift", "build", "--configuration", "release", "--disable-sandbox"

    # Install the binary
    bin.install ".build/release/stt"

    # Create a man page directory and install documentation if you have it
    # man1.install "docs/stt.1" if File.exist?("docs/stt.1")
  end

  def caveats
    <<~EOS
      STT requires macOS 13.0 or later and will download AI models on first run.
      Models will be stored in ~/Library/Application Support/FluidAudio/Models/

      First run may take longer as it downloads required models (~495MB).

      Usage:
        stt input.mp3                    # Basic transcription with diarization
        stt input.mp3 --transcribe-only  # Transcription only
        stt input.mp3 --threshold 0.9    # Custom diarization threshold
        stt input.mp3 --verbose          # Show detailed progress
    EOS
  end

  test do
    # Test that the binary exists and shows help
    assert_match "Speech-to-text CLI", shell_output("#{bin}/stt --help")
  end
end
