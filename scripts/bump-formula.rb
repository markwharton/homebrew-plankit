#!/usr/bin/env ruby
# frozen_string_literal: true

# Bump Formulas to the latest upstream GitHub release.
#
# Usage:
#   scripts/bump-formula.rb              # every formula in formulas.yml
#   scripts/bump-formula.rb <formula>    # just the named formula(s)
#
# Rewrites the `version` line and the four platform `sha256` lines using the
# release's checksums.txt. Exits non-zero if the release, an expected asset,
# or a url/sha256 block is missing. When GITHUB_OUTPUT is set and exactly one
# formula was named, writes `updated` and `version` outputs for the workflow.

require "json"
require "net/http"
require "uri"
require "yaml"

PLATFORM_ASSETS = %w[darwin-arm64 darwin-amd64 linux-arm64 linux-amd64].freeze
ROOT = File.expand_path("..", __dir__)

def http_get(url, redirects_left = 5)
  abort "too many redirects fetching #{url}" if redirects_left.zero?
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  token = ENV["GITHUB_TOKEN"]
  request["Authorization"] = "Bearer #{token}" if token && uri.host == "api.github.com"
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  return http_get(response["location"], redirects_left - 1) if response.is_a?(Net::HTTPRedirection)

  abort "GET #{url} failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
  response.body
end

def parse_checksums(text)
  text.each_line.to_h do |line|
    sha, file = line.split
    abort "malformed checksums.txt line: #{line.inspect}" unless sha&.match?(/\A[0-9a-f]{64}\z/) && file
    [file, sha]
  end
end

# Returns the new version string, or nil if already up to date.
def bump(entry)
  formula = entry.fetch("formula")
  repo = entry.fetch("repo")
  prefix = entry.fetch("asset_prefix")
  path = File.join(ROOT, "Formula", "#{formula}.rb")
  contents = File.read(path)
  current = contents[/^\s*version "([^"]+)"/, 1] || abort("#{path}: no version line found")

  release = JSON.parse(http_get("https://api.github.com/repos/#{repo}/releases/latest"))
  tag = release.fetch("tag_name")
  latest = tag.delete_prefix("v")
  if latest == current
    puts "#{formula} #{current} is up to date"
    return nil
  end

  puts "#{formula}: #{current} -> #{latest}"
  checksums = parse_checksums(http_get("https://github.com/#{repo}/releases/download/#{tag}/checksums.txt"))

  updated = contents.sub(/^(\s*version ")[^"]+(")/) { "#{Regexp.last_match(1)}#{latest}#{Regexp.last_match(2)}" }
  PLATFORM_ASSETS.each do |platform|
    asset = "#{prefix}-#{platform}"
    sha = checksums[asset] || abort("#{asset} missing from #{tag} checksums.txt")
    pattern = %r{(url "[^"]*/#{Regexp.escape(asset)}"\n\s*sha256 ")[0-9a-f]{64}(")}
    updated.sub!(pattern) { "#{Regexp.last_match(1)}#{sha}#{Regexp.last_match(2)}" } ||
      abort("#{formula}.rb: no url/sha256 block found for #{asset}")
  end

  File.write(path, updated)
  latest
end

entries = YAML.load_file(File.join(ROOT, "formulas.yml")).fetch("formulas")
unless ARGV.empty?
  entries = ARGV.map do |name|
    entries.find { |e| e["formula"] == name } || abort("#{name} is not listed in formulas.yml")
  end
end

versions = entries.map { |entry| bump(entry) }

if ENV["GITHUB_OUTPUT"] && entries.size == 1
  File.open(ENV["GITHUB_OUTPUT"], "a") do |f|
    f.puts "updated=#{!versions.first.nil?}"
    f.puts "version=#{versions.first}" if versions.first
  end
end
