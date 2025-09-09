#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

module Homebrew
  module Cmd
    class UpgradeAll < AbstractCommand
      cmd_args do
        description <<~EOS
          List all outdated formulae, download their updates, and install them.
          This is similar to 'brew upgrade' but provides more control and feedback.
        EOS
        flag   "-p", "--proxy=", description: "Specify the download proxy address."
        comma_array  "--proxies=", description: "Specify multiple download proxy addresses."
        switch "--dry-run", description: "Show what would be upgraded without actually doing it"
        switch "--download-only", description: "Only download the updates, do not install"
        switch "--verbose", description: "Show verbose output"
        switch "--force", description: "Install formulae even if they are already up-to-date"
        comma_array "--only=", description: "Only upgrade specified formulae (comma-separated)"
        comma_array "--except=", description: "Exclude specified formulae from upgrade (comma-separated)"
        conflicts "--proxy", "--proxies"
        conflicts "--only", "--except"
        conflicts "--dry-run", "--download-only"
      end

      def run
        upgrade_formulae
        upgrade_cask
        display_installation_summary
      end

      private
      require 'formula'
      require_relative 'proxy_download'
      include Homebrew::Custom::ProxyDownload

      @@installed = []
      @@failed = []
      @@display = false

      def upgrade_cask
        outdated_casks = list_outdated_cask

        if outdated_casks.empty?
          ohai "All cask are up-to-date!"
          return
        end

        filtered_casks = filter_outdated(outdated_casks)

        if filtered_casks.empty?
          ohai "No cask to upgrade after filtering."
          return
        end

        display_upgrade_casks(filtered_casks)

        if args.dry_run?
          ohai "Dry run complete. Would upgrade #{filtered_casks.size} cask."
          return
        end

        ohai "Upgrading cask..."
        @@display = true unless @@display

        filtered_casks.each do |c|
          (download_cask(c) ? @@installed : @@failed) << c
        end
      end

      def list_outdated_cask
        ohai "Checking for outdated cask..."

        outdated = Cask::Caskroom.casks.select do |c|
          c.outdated?
        end

        puts "Found #{outdated.size} outdated cask." if args.verbose?
        outdated
      end

      def display_upgrade_casks(casks)
        ohai "The following formulae will be upgraded:"
        casks.each do |c|
          puts "  #{c.name} (#{c.installed_version.to_s.split("_").first} -> #{c.version})"
        end
        puts ""
      end

      def upgrade_formulae
        outdated_formulae = list_outdated_formulae
        if outdated_formulae.empty?
          ohai "All formulae are up-to-date!"
          return
        end

        filtered_formulae = filter_outdated(outdated_formulae)
        if filtered_formulae.empty?
          ohai "No formulae to upgrade after filtering."
          return
        end

        display_upgrade_formulae(filtered_formulae) if args.verbose?

        if args.dry_run?
          ohai "Dry run complete. Would upgrade #{filtered_formulae.size} formulae."
          return
        end

        ohai "Upgrading formulae..."
        @@display = true unless @@display

        filtered_formulae.each do |f|
          (download_formula(f) ? @@installed : @@failed) << f
        end
      end

      def list_outdated_formulae
        ohai "Checking for outdated formulae..."

        #outdated = Formula.installed.select do |formula|
        #  formula.outdated?(fetch_head: true)
        #end

        outdated = []

        Formula.installed.each do |formula|
          if formula.outdated?(fetch_head: true)
            formula.recursive_dependencies.each do |d|
              outdated << d if d.outdated?(fetch_head: true)
            end
            outdated << formula
          end
        end

        puts "Found #{outdated.size} outdated formulae." if args.verbose?
        outdated
      end

      def filter_outdated(outdated)
        return outdated if args.only.nil? && args.except.nil?

        filtered = outdated.dup

        if args.only && !args.only.empty?
          only_list = args.only
          filtered.select! { |f| only_list.include?(f.name) }
        end

        if args.except && !args.except.empty?
          except_list = args.except
          filtered.reject! { |f| except_list.include?(f.name) }
        end

        filtered
      end

      def display_upgrade_formulae(formulae)
        ohai "The following formulae will be upgraded:"
        formulae.each do |f|
          puts "  #{f.name} (#{f.pkg_version.to_s.split("_").first} -> #{f.version})"
        end
        puts ""
      end

      def is_proxyed_bottle(url)
        url.match?(/\Ahttps?:\/\/mirrors\.ustc\.edu\.cn/)
      end

      def get_proxyed_url(url)
        url.sub(/https?:\/\//, "https://files.m.daocloud.io/")
      end

      def display_installation_summary()
        return unless @@display
        puts ""
        ohai "Upgrade summary:"
        puts "  Successfully installed: #{@@installed.size}"
        puts "  Failed: #{@@failed.size}"

        unless @@failed.empty?
          puts ""
          onoe "The following formulae failed to install:"
          @@failed.each { |f| puts "  #{f.name}" }
        end

        unless @@installed.empty?
          puts ""
          ohai "Successfully upgraded #{@@installed.size} formulae:"
          @@installed.each { |f| puts "  #{f.name}" }
        end
      end
    end
  end
end
