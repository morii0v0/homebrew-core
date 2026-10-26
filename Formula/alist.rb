# frozen_string_literal: true

# Alist is a hombrew Formula class which installs the Alist language server.
class Alist < Formula
  desc "Alist - An unofficial, unendorsed language server for alist written in C++"
  homepage "https://github.com/AlistGo/alist"
  license "AGPL-3.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  url "https://github.com/AlistGo/alist/releases/download/v3.66.0/alist-darwin-arm64.tar.gz"
  sha256 "b9657f62df0f9648a309fe6db7ad6fef806b228df98076c363af9390d57f1bb4"

  on_intel do
    url "https://github.com/AlistGo/alist/releases/download/v3.60.0/alist-darwin-amd64.tar.gz"
    sha256 "aae0928d10d9c284d6975d31984da32ac7e40d4eae9a88928843a508d585bbcb"
  end

  def install
    prefix.install "alist"
  end

  test do
    system "#{bin}/alist", "--help"
  end
end
