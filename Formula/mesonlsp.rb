# frozen_string_literal: true

# MesonLsp is a hombrew Formula class which installs the Meson language server.
class Mesonlsp < Formula
  desc "Meson LSP - An unofficial, unendorsed language server for meson written in C++"
  homepage "https://github.com/JCWasmx86/mesonlsp"
  license "GPL-3.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  if Hardware::CPU.arm?
    url "https://github.com/JCWasmx86/mesonlsp/releases/download/v4.3.7/mesonlsp-aarch64-apple-darwin.zip"
    sha256 "094ffaa4aebecd17651334b8218a38b965fa262de1ccc5cebffa88ffcc3590aa"
  else
    url "https://github.com/JCWasmx86/mesonlsp/releases/download/v4.3.7/mesonlsp-x86_64-apple-darwin.zip"
    sha256 "61f3876025f4dbca1170fcc97dbd42ab65a65bb8afc297c66b9cce4cc0bed0d3"
  end

  def install
    libexec.install Dir["*"]

    bin.install_symlink Dir["#{libexec}/mesonlsp"]
  end

  test do
    system "#{bin}/mesonlsp", "--help"
  end
end
