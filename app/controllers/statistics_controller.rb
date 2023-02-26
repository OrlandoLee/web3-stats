require 'faraday'
require 'twitter'

class StatisticsController < ApplicationController
  before_action :set_statistic, only: %i[show edit update destroy]

  ETH = %w[ethers web3 ganache-cli hardhat truffle ganache].freeze
  AVALANCHE = ['avalanche'].freeze
  POLKDOT = ['polkadot'].freeze
  ALGORAND = ['algosdk'].freeze
  FLOW = ['flow'].freeze
  STELLAR = ['stellar-sdk'].freeze
  NEAR = %w[near-api-js near-cli].freeze
  LAST_WEEK_BASE_URL = 'https://api.npmjs.org/downloads/point/last-week/'.freeze

  # GET /statistics or /statistics.json
  def index
    @eth_statistics = fetch_eth_statistics
    @other_statistics = fetch_other_statistics
    @mapping = build_mapping
  end

  def eth
    render plain: 'not allowed' and return unless password_match

    statistics = fetch_eth_statistics
    content = "Downloads of $eth dev packages this week \n" + statistics.map { |statistic| "#{statistic.package} #{view_context.number_to_human(statistic.downloads, units: { unit: '', thousand: 'k', million: 'm' })}" }.join("\n") + "\n" + 'Comment to add more stats'

    post_tweet(content)

    render plain: content
  end

  def other
    render plain: 'not allowed' and return unless password_match

    mapping = build_mapping
    statistics = fetch_other_statistics
    content = "Downloads of non-eth web3 packages this week \n" + statistics.map { |statistic| "#{statistic.package} #{mapping[statistic.package]} #{view_context.number_to_human(statistic.downloads, units: { unit: '', thousand: 'k', million: 'm' })}" }.join("\n") + "\n" + 'Comment to add more stats'

    post_tweet(content)

    render plain: content
  end

  private

  def password_match
    params[:password] == ENV['password']
  end

  def post_tweet(content)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['consumer_key']
      config.consumer_secret = ENV['consumer_secret']
      config.access_token = ENV['access_token']
      config.access_token_secret = ENV['access_token_secret']
    end
    client.update(content)
  end

  def fetch_eth_statistics
    eth_url = LAST_WEEK_BASE_URL + ETH.join(',')
    eth_openzeppelin_url = LAST_WEEK_BASE_URL + '@openzeppelin/contracts'

    Rails.cache.fetch('eth_stats', expires_in: 1.day) do
      [eth_url, eth_openzeppelin_url].map do |url|
        parse_stats(url)
      end.flatten.sort_by { |stat| -stat.downloads }
    end
  end

  def fetch_other_statistics
    solana_solana_url = LAST_WEEK_BASE_URL + '@solana/web3.js'
    other_url = LAST_WEEK_BASE_URL + [AVALANCHE, POLKDOT, ALGORAND, FLOW, STELLAR, NEAR].flatten.join(',')

    Rails.cache.fetch('other_stats', expires_in: 1.day) do
      [solana_solana_url, other_url].map do |url|
        parse_stats(url)
      end.flatten.sort_by { |stat| -stat.downloads }
    end
  end

  def parse_stats(url)
    response = Faraday.get url
    parsed_json = JSON.parse(response.body)
    # single url
    if parsed_json.has_key?('package')
      stat = parsed_json
      Statistic.new(
        package: stat['package'],
        downloads: stat['downloads'],
        start_date: stat['start'],
        end_date: stat['end']
      )
    else
      # array of urls
      parsed_json.values.map do |stat|
        Statistic.new(
          package: stat['package'],
          downloads: stat['downloads'],
          start_date: stat['start'],
          end_date: stat['end']
        )
      end
    end
  end

  def build_mapping
    mapping = {}
    NEAR.map do |lib|
      mapping[lib] = '$NEAR'
    end

    ETH.map do |lib|
      mapping[lib] = '$ETH'
    end

    AVALANCHE.map do |lib|
      mapping[lib] = '$AVAX'
    end

    POLKDOT.map do |lib|
      mapping[lib] = '$DOT'
    end

    ALGORAND.map do |lib|
      mapping[lib] = '$ALGO'
    end

    FLOW.map do |lib|
      mapping[lib] = '$FLOW'
    end

    STELLAR.map do |lib|
      mapping[lib] = '$XLM'
    end

    ['@solana/web3.js'].map do |lib|
      mapping[lib] = '$SOL'
    end

    mapping
  end
end
