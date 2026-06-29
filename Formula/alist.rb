# frozen_string_literal: true

# Alist is a hombrew Formula class which installs the Alist language server.
class Alist < Formula
  desc 'Alist - An unofficial, unendorsed language server for alist written in C++'
  homepage 'https://github.com/AlistGo/alist.git'
  version '3.60.0'
  license 'AGPL-3.0'

  livecheck do
    url :stable
    strategy :github_latest
  end

  url "https://github.com/AlistGo/alist/releases/download/v#{version}/alist-darwin-arm64.tar.gz"
  sha256 '70f0db97a3f6235301d8567ca6fd96604fb8ad232c872643b7e5137df46b512d'

  on_intel do
    url "https://github.com/AlistGo/alist/releases/download/v#{version}/alist-darwin-amd64.tar.gz"
    sha256 'aae0928d10d9c284d6975d31984da32ac7e40d4eae9a88928843a508d585bbcb'
  end

  def install
    prefix.install "alist"
  end

  test do
    system "#{Formula['alist'].opt_bin}/alist", "--help"
  end
end
