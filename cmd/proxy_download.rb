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
      end

      def concat_with_proxy(url, proxy)
        url.to_s.sub(%r{https?://}, "https://#{proxy}/")
      end

      def replace_with_proxy(url, proxy)
        url.to_s.sub(%r{https?://[^/]+/}, "https://#{proxy}/")
      end

      # Download a file from proxy (concat_with_proxy format) to the expected cache path.
      # URL format: https://proxy/github.com/a/b/c -> saved as original filename.
      # Returns true if successfully downloaded via proxy, false if all proxies failed.
      def proxy_download_to_cache(original_url, cache_path, proxies)
        return false if proxies.empty?

        proxies.each_with_index do |proxy, idx|
          next if is_proxyed(original_url, [proxy])

          proxy_url = concat_with_proxy(original_url, proxy)
          begin
            ohai "Downloading via proxy: #{proxy}"
            cache_path.dirname.mkpath unless cache_path.dirname.exist?
            system "curl", "-fsSL", "--retry", "3", "--retry-delay", "2",
                   "-o", cache_path.to_s, proxy_url
            if $?.success? && cache_path.exist? && cache_path.size.positive?
              return true
            end
          rescue
            # Continue to next proxy on error
          end
          opoo "Proxy #{proxy} failed, trying next..." if idx + 1 < proxies.length
        end
        false
      end

      # Download a file from mirror (replace_with_proxy format) to the expected cache path.
      # URL format: https://mirror/a/b/c.
      # Returns true if successfully downloaded via mirror, false if all mirrors failed.
      def mirror_download_to_cache(original_url, cache_path, proxies)
        return false if proxies.empty?

        proxies.each_with_index do |proxy, idx|
          next if is_proxyed(original_url, [proxy])

          mirror_url = replace_with_proxy(original_url, proxy)
          begin
            ohai "Downloading via mirror: #{proxy}"
            cache_path.dirname.mkpath unless cache_path.dirname.exist?
            system "curl", "-fsSL", "--retry", "3", "--retry-delay", "2",
                   "-o", cache_path.to_s, mirror_url
            if $?.success? && cache_path.exist? && cache_path.size.positive?
              return true
            end
          rescue
            # Continue to next proxy on error
          end
          opoo "Mirror #{proxy} failed, trying next..." if idx + 1 < proxies.length
        end
        false
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

        proxies = proxyed_files_addrs
        using_proxy = !proxies.empty?

        begin
          download = Cask::Download.new(c)
          cache_path = download.cached_download
          cached = cache_path.exist? && cache_path.size.positive?

          # Pre-download via proxy if not already cached
          if using_proxy && !cached
            # Try proxyed_files_addrs first (concat_with_proxy format: https://proxy/github.com/a/b/c)
            cached = proxy_download_to_cache(c.url.to_s, cache_path, proxies)
            # Fall back to mirror addresses (replace_with_proxy format)
            cached ||= mirror_download_to_cache(c.url.to_s, cache_path, proxyed_bottle_addrs)
          end

          if cached
            ohai "Cask cached via proxy: #{cache_path}"
            if args.download_only?
              return true
            end
          elsif args.download_only?
            onoe "Failed to download #{c.token} via proxy, aborting to avoid direct request"
            return false
          end

          # Install with original cask (URL unchanged) — installer finds cached file
          installer = Cask::Installer.new(c, force: true)
          if args.download_only?
            download = Cask::Download.new(c)
            download.fetch
          else
            installer.install
          end
          return true
        rescue ErrorDuringExecution => e
          onoe "Failed to install #{c.token}: #{e}"
          return false
        end
      end

      def download_formula(f)
        require 'formula'
        require 'formula_installer'

        if !f.is_a?(Formula)
          f = Formula[f.to_s]
        end

        begin
          # Pre-download via proxy: download bottle to the expected cache path
          bottle = f.bottle
          bottle_cached = false
          if !bottle.nil? && !bottle.url.nil? && !is_proxyed_files(bottle.url)
            cache_path = bottle.cached_download
            if cache_path.exist? && cache_path.size.positive?
              bottle_cached = true
            else
              # Try proxyed_files_addrs first (concat_with_proxy format: https://proxy/github.com/a/b/c)
              bottle_cached = proxy_download_to_cache(bottle.url, cache_path, proxyed_files_addrs)
              # Fall back to proxyed_bottle_addrs (replace_with_proxy / mirror format)
              bottle_cached ||= mirror_download_to_cache(bottle.url, cache_path, proxyed_bottle_addrs)
            end
          end

          if bottle_cached
            # Bottle is already cached, pour directly without fetch (avoids HEAD requests)
            ohai "Bottle cached via proxy, pouring directly"
            installer = FormulaInstaller::new(f)
            installer.pour
          else
            installer = FormulaInstaller::new(f)
            installer.fetch
            installer.install unless args.respond_to?(:download_only?) && args.download_only?
          end
          return true
        rescue ErrorDuringExecution => e
          onoe "Failed to install #{f.name}: #{e}"
          return false
        end
      end
    end
  end
end
