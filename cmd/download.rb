#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

module Homebrew
  module Cmd
    class Download < AbstractCommand
      cmd_args do
        description <<~EOS
          Download formula, cask or files from given arguments.
        EOS
        flag   "-p", "--proxy=", description: "Specify the download proxy address."
        comma_array  "--proxies=", description: "Specify multiple download proxy addresses."
        named_args [:formula, :cask, :urls], min: 1
        switch "-u", "--url", description: "Download file(s) from given url(s)."
        switch "-c", "--cask", description: "Download (and install) cask(s)."
        switch "-f", "--formula", description: "Download (and install) formula(s)."
        switch "--download-only", description: "Only download the updates, do not install."
        flag   "-o", "--output=",
              description: "Specify the file download directory.",
              depends_on: "--url"
        conflicts "--proxy", "--proxies"
        conflicts "--url", "--cask", "--formula"
        conflicts "--url", "--download-only"
      end

      def run
        if args.proxy
          @@proxyed_files_addrs = [args.proxy]
          @@proxyed_bottle_addrs = [args.proxy]
        end
        args.named.each do |a|
          if args.url?
            download_file(a)
          elsif args.formula?
            download_formula(a)
          else
            download_cask(a)
          end
        end
      end

      private
      require_relative 'proxy_download'
      include Homebrew::Custom::ProxyDownload
    end
  end
end
