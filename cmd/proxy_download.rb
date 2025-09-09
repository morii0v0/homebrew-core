# typed: strict
# frozen_string_literal: true

module Homebrew
  module Custom
    module ProxyDownload
      private
      @@default_algorithm = "sha256"
      @@default_iterations = 1
      @@proxyed_files_addrs = [
        "files.m.daocloud.io"
      ]
      @@proxyed_bottle_addrs = [
        "mirrors.ustc.edu.cn",
        "mirrors.tuna.tsinghua.edu.cn",
        "mirrors.aliyun.com"
      ]

      def proxyed_files_addrs
        get_proxyed_addrs_or(@@proxyed_files_addrs)
      end

      def proxyed_bottle_addrs
        get_proxyed_addrs_or(@@proxyed_bottle_addrs)
      end

      def get_proxyed_addrs_or(default)
        args && args.proxies ? args.proxies : default
      end

      def is_proxyed_files(url)
        is_proxyed(url, proxyed_files_addrs())
      end

      def is_proxyed_bottle(url)
        is_proxyed(url, proxyed_bottle_addrs())
      end

      def is_proxyed(url, proxy_addrs)
        uri = URI.parse(url.to_s)
        !uri.nil? && proxy_addrs.include?(uri.host)
        # url.match?(/\Ahttps?:\/\/mirrors\.ustc\.edu\.cn/)
      end

      def concat_with_proxy(url, proxy)
        # url.to_s.sub(/https?:\/\//, "https://#{proxy}/")
        url.to_s.sub(%r{https?://}, "https://#{proxy}/")
      end

      def replace_with_proxy(url, proxy)
        url.to_s.sub(%r{https?://[^/]+/}, "https://#{proxy}/")
      end

      def get_target_dir
        output_dir = args.output || (args.url? ? ("#{ENV["HOME"]}/Downloads" || "#{get_cache_dir()}/downloads") : ("#{get_cache_dir()}/downloads" || "#{ENV["HOME"]}/Downloads"))
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
        output_dir
      end

      def get_cache_dir
        Homebrew::EnvConfig.cache || ENV["HOMEBREW_CACHE"] || "#{ENV["HOME"]}/Library/Caches/Homebrew"
      end

      def calculate_hash(input, algorithm: @@default_algorithm, iterations: @@default_iterations)
        digest_class = case algorithm.downcase
                      when "sha256" then Digest::SHA256
                      when "sha1" then Digest::SHA1
                      when "md5" then Digest::MD5
                      else
                        odie "Unsupported algorithm: #{algorithm}. Supported: sha256, sha1, md5"
                      end

        hash = input
        iterations.times do |i|
          hash = digest_class.hexdigest(hash)
        end

        hash
      end

      public
      def download_file(f)
        pos = 0
        proxies = proxyed_files_addrs
        using_proxy = !proxies.empty?
        file_name = File.basename(f.to_s)
        begin
          url = using_proxy && !is_proxyed_files(f.to_s) ? concat_with_proxy(f.to_s, proxies[pos]) : f.to_s
          system "curl", "-SL", "-#", "-o", "#{get_target_dir()}/#{file_name}", url
          return true
        rescue ErrorDuringExecution => e
          if !using_proxy || pos + 1 >= proxies.length
            onoe "Failed to download #{file_name}: #{e}"
            return false
          else
            onoe "Failed to download #{file_name} while using proxy(#{proxies[pos]}): #{e}"
            pos += 1
            using_proxy = false if pos >= proxies.length
            retry
          end
        end
      end

      def download_cask(c)
        require 'cask'

        if !c.is_a?(Cask)
          c = Cask::CaskLoader.load(c.to_s)
        end
        pos = 0
        proxies = proxyed_files_addrs
        using_proxy = !proxies.empty?
        begin
          cask = c.dup
          if using_proxy
            proxy_url = concat_with_proxy(c.url, proxies[pos])
            cask.define_singleton_method(:url) { Cask::URL.new(proxy_url) }
          end
          if args.download_only?
            downloader = Cask::Download.new(cask)
            downloader.fetch
          else
            installer = Cask::Installer.new(cask)
            installer.install
          end
          return true
        rescue ErrorDuringExecution => e
          if using_proxy
            onoe "Failed to upgrade #{c.name} while using proxy(#{proxies[pos]}): #{e}"
            pos += 1
            using_proxy = false if pos >= proxies.length
            retry
          else
            onoe "Failed to upgrade #{c.name}: #{e}"
            return false
          end
        end
      end

      def download_formula(f)
        require 'formula'
        require 'formula_installer'

        if !f.is_a?(Formula)
          f = Formula[f.to_s]
        end

        pos = 0
        proxies = proxyed_bottle_addrs
        using_proxy = !proxies.empty? && !is_proxyed(f.bottle.url, proxies)
        begin
          formula = f.dup
          if using_proxy
            url = replace_with_proxy(f.bottle.url, proxies[pos])
            formula.bottle.define_singleton_method(:url) { url }
          end

          installer = FormulaInstaller::new(formula)
          installer.fetch
          installer.install unless args.download_only?
          return true
        rescue ErrorDuringExecution => e
          if proxies.empty? || (pos + 1 >= proxies.length)
            onoe "Failed to upgrade #{f.name}: #{e}"
            return false
          else
            onoe "Failed to upgrade #{f.name} while using proxy(#{proxies[pos]}): #{e}"
            using_proxy = !proxies.empty? && pos < proxies.length
            pos += 1
            retry
          end
        end
      end
    end
  end
end
