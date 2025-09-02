class ApacheCxf < Formula
  desc "Apache CXF - an open source services framework"
  homepage "https://cxf.apache.org"
  url "https://archive.apache.org/dist/cxf/4.1.3/apache-cxf-4.1.3.tar.gz"
  sha256 "70ec09e5431e4833f923efe5f2206859e10f14fb1b4b56f7f0b1358f94751270"
  license "Apache-2.0"
  revision 1

  depends_on "openjdk"

  def install
    rm_f Dir["bin/*.bat"]
    
    libexec.install Dir["*"]
    
    bin.install_symlink Dir["#{libexec}/bin/*"]
    
    samples.install_symlink Dir["#{libexec}/samples"]
    
    (bin/"cxf-env").write <<~EOS
      #!/bin/bash
      export CXF_HOME="#{libexec}"
      export PATH="#{libexec}/bin:$PATH"
      exec "$@"
    EOS
    chmod 0755, bin/"cxf-env"
  end

  def caveats
    <<~EOS
      Apache CXF has been installed to:
        #{opt_libexec}

      To use CXF, you may need to set the environment variables:
        export CXF_HOME="#{opt_libexec}"
        export PATH="#{opt_libexec}/bin:$PATH"

      Or use the provided wrapper script:
        cxf-env <command>

      Samples are installed at:
        #{opt_libexec}/samples
    EOS
  end

  test do
    system "#{Formula["openjdk@11"].opt_bin}/java", "-version"
    
    system "#{bin}/cxf-env", "java", "-cp", "#{libexec}/lib/cxf-core-4.1.3.jar", "-version"
  end
end
