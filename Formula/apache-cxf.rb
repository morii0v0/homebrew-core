class ApacheCxf < Formula
  desc "Apache CXF - an open source services framework"
  homepage "https://cxf.apache.org"
  version "4.1.3"
  url "https://archive.apache.org/dist/cxf/#{version}/apache-cxf-#{version}.tar.gz"
  sha256 "70ec09e5431e4833f923efe5f2206859e10f14fb1b4b56f7f0b1358f94751270"
  license "Apache-2.0"
  revision 1

  depends_on "openjdk"

  def install
    rm_f Dir["bin/*.bat"]
    
    libexec.install Dir["*"]

    Dir["#{libexec}/bin/*"].each do |f|
    next if File.directory?(f) || File.extname(f) == ".bat"
    
    content = File.read(f)
    
    if content.include?("me=`basename $0`")
      content.gsub!(
        /(cxf_home=)(\$CXF_HOME|"\$CXF_HOME"|'\$CXF_HOME')/,
        #"\\1\\${CXF_HOME:-#{libexec}}"
        "\\1${CXF_HOME:-#{opt_libexec}}"
      )
      
      unless content.include?("cxf_home=")
        content.gsub!(
          /(me=`basename \$0`)/,
          #"\\1\ncxf_home=\\${CXF_HOME:-#{libexec}}"
          "\\1\ncxf_home=${CXF_HOME:-#{opt_libexec}}"
        )
      end
    end
    
    #File.open(f, "w") { |file| file.write(content) }
    File.write(f, content)
    
    #File.chmod(0755, f)

    #if File.read(f).include?("cxf_home=${CXF_HOME:-#{libexec}}")
    if File.read(f).include?("cxf_home=${CXF_HOME:-#{opt_libexec}}")
      ohai "Successfully modified #{f}"
    else
      opoo "Failed to modify #{f}"
    end
  end
    
    bin.install_symlink Dir["#{libexec}/bin/*"]
    
    (bin/"cxf-env").write <<~EOS
      #!/bin/bash
      export CXF_HOME="#{libexec}"
      #export PATH="#{libexec}/bin:$PATH"
      exec "$@"
    EOS
    chmod 0755, bin/"cxf-env"

    (prefix/"samples").make_relative_symlink(libexec/"samples")
    #prefix.install_symlink libexec/"examples" => "samples"
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
    system "#{Formula["openjdk"].opt_bin}/java", "-version"
    
    system "#{bin}/cxf-env", "java", "-cp", "#{libexec}/lib/cxf-core-#{version}.jar", "-version"
  end
end
