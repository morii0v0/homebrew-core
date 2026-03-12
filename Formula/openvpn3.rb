# frozen_string_literal: true

# Openvpn3 is a hombrew Formula class.
class Openvpn3 < Formula
  desc 'OpenVPN 3 is a C++ library implementing an OpenVPN client; protocol-compatible with OpenVPN 2.x.'
  homepage 'https://openvpn.net/community/'
  url 'https://github.com/OpenVPN/openvpn3/archive/refs/tags/release/3.11.5.zip'
  sha256 'ab91ace6638791f9b8596ff1c3007798a3da4e1d4aa29f95e6ef1e004235f728'
  license 'GPL-2.0-only' => { with: 'openvpn-openssl-exception' }

  depends_on 'cmake'      => :build
  depends_on 'pkg-config' => :build
  depends_on 'asio'       => :build
  depends_on 'fmt'        => :build
  depends_on 'jsoncpp'    => :build
  depends_on 'lz4'        => :build
  depends_on 'openssl'    => :build
  depends_on 'xxhash'     => :build

  def install
    system 'cmake', '.'
    system 'cmake', '--build', '.'
    system 'cmake', '--install', '.', '--prefix', "#{prefix}"
    sbin.install 'test/ovpncli/ovpncli'      => 'openvpn3'
    sbin.install 'test/ovpncli/ovpncliagent' => 'openvpn3agent'

    (etc / 'openvpn3').mkpath
    (var / 'run/openvpn3').mkpath
  end

  service do
    run [opt_sbin / 'openvpn3', etc / 'openvpn3/config.ovpn']
    keep_alive true
    require_root true
    working_dir etc / 'openvpn3'
  end

  test do
    system sbin / 'openvpn3', '--help'
  end
end
