class Stt < Formula
  desc "Speech-to-text CLI with speaker diarization using Parakeet v3"
  homepage "https://github.com/USERNAME/stt"  # Replace with your GitHub URL
  url "https://github.com/USERNAME/stt/archive/refs/tags/v1.0.0.tar.gz"  # Replace with your release
  sha256 "REPLACE_WITH_ACTUAL_SHA256"  # Will be calculated from the release tarball
  license "MIT"  # Replace with your license

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
