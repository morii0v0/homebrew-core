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

  url "https://github.com/AlistGo/alist/releases/download/v3.64.0/alist-darwin-arm64.tar.gz"
  sha256 "5f3cd409b1ba5c25d240ccb93bb77fa8a8e8cabbd21a467849ac90443e8f8140"

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
