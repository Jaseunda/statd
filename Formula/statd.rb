class Statd < Formula
  desc "Minimal, flicker-free terminal system stats HUD for servers and homelabs"
  homepage "https://github.com/Jaseunda/statd"
  url "https://github.com/Jaseunda/statd/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "replace_with_actual_sha256_after_tagging"
  license "MIT"
  head "https://github.com/Jaseunda/statd.git", branch: "main"

  # No compiled dependencies — pure Bash.
  # bash 4.0+ is required; macOS ships Bash 3.2, so we depend on the
  # Homebrew-managed bash.
  depends_on "bash"

  def install
    bin.install "statd"
    (lib/"statd").install Dir["lib/*.sh"]
  end

  def caveats
    <<~EOS
      statd requires Bash 4.0 or later. The installed script uses:
        #!/usr/bin/env bash
      which will resolve to the Homebrew bash at #{Formula["bash"].opt_bin}/bash
      as long as it appears earlier in your PATH than /bin/bash.

      For CPU temperature on macOS, install osx-cpu-temp:
        brew install osx-cpu-temp
    EOS
  end

  test do
    assert_predicate bin/"statd", :executable?
    # Verify all library files installed correctly
    %w[colors.sh render.sh sensors_linux.sh sensors_macos.sh sensors.sh llm.sh].each do |f|
      assert_predicate lib/"statd/#{f}", :exist?
    end
    # Syntax check every file
    system "bash", "-n", bin/"statd"
    Dir[lib/"statd/*.sh"].each { |f| system "bash", "-n", f }
  end
end
