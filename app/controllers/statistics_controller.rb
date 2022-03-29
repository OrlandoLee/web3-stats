require 'faraday'
require 'twitter'

class StatisticsController < ApplicationController
  before_action :set_statistic, only: %i[ show edit update destroy ]

  ETH = ['ethers','web3','ganache-cli','hardhat','truffle','ganache']
  AVALANCHE = ['avalanche']
  POLKDOT = ['polkadot']
  ALGORAND = ['algosdk']
  FLOW = ['flow']
  STELLAR = ['stellar-sdk']
  NEAR = ['near-api-js', 'near-cli']
  LAST_WEEK_BASE_URL = 'https://api.npmjs.org/downloads/point/last-week/'


  # GET /statistics or /statistics.json
  def index
    @eth_statistics = fetch_eth_statistics
    @other_statistics = fetch_other_statistics
    @mapping = build_mapping
  end

  def eth
    if !password_match
      render plain: 'not allowed' and return
    end
    
    statistics = fetch_eth_statistics
    content = "Downloads of eth dev packages this week \n" + statistics.map {|statistic| "#{statistic.package} #{view_context.number_to_human(statistic.downloads, units: { unit: "", thousand: "k", million: "m"})}"}.join("\n")+"\n"+"For more: web3stats.com"
    
    post_tweet(content)

    render plain: content
  end

  def other
    if !password_match
      render plain: 'not allowed' and return
    end
    statistics = fetch_other_statistics
    content = "Downloads of non-eth web3 packages this week \n" + statistics.map {|statistic| "#{statistic.package} #{view_context.number_to_human(statistic.downloads, units: { unit: "", thousand: "k", million: "m"})}"}.join("\n")+"\n"+"For more: web3stats.com"

    post_tweet(content)
    
    render plain: content
  end

  private

    def password_match
      params[:password] == ENV["password"]
    end

    def post_tweet(content)
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["consumer_key"]
        config.consumer_secret     = ENV["consumer_secret"]
        config.access_token        = ENV["access_token"]
        config.access_token_secret = ENV["access_token_secret"]
      end
      client.update(content)
    end

    def fetch_eth_statistics
      eth_url = LAST_WEEK_BASE_URL+ETH.join(',')
      eth_openzeppelin_url = LAST_WEEK_BASE_URL+'@openzeppelin/contracts'
 
      Rails.cache.fetch("eth_stats", expires_in: 1.day) do
        [eth_url, eth_openzeppelin_url].map do |url|
          parse_stats(url)
        end.flatten.sort_by{|stat| -stat.downloads}
      end
    end

    def fetch_other_statistics
      solana_solana_url = LAST_WEEK_BASE_URL+ '@solana/web3.js'
other_url = LAST_WEEK_BASE_URL + [AVALANCHE, POLKDOT, ALGORAND, FLOW, STELLAR, NEAR].flatten.join(',')

      Rails.cache.fetch("other_stats", expires_in: 1.day) do
      [solana_solana_url, other_url].map do |url|
        parse_stats(url)
      end.flatten.sort_by{|stat| -stat.downloads}
    end
    end


    def parse_stats(url)
      response = Faraday.get url
      parsed_json = JSON.parse(response.body)
      # single url
      if(parsed_json.has_key?('package'))
        stat = parsed_json
        return Statistic.new(
            package: stat['package'],
            downloads: stat['downloads'],
            start_date: stat['start'],
            end_date: stat['end']
            )
      else
      # array of urls
        return parsed_json.values.map do |stat|
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
        mapping[lib] = "NEAR Protocol (NEAR)"
      end

      ETH.map do |lib|
        mapping[lib] = "ETH"
      end

      AVALANCHE.map do |lib|
        mapping[lib] = "Avalanche (AVAX)"
      end

      POLKDOT.map do |lib|
        mapping[lib] = "Polkadot (DOT)"
      end

      ALGORAND.map do |lib|
        mapping[lib] = "Algorand (ALGO)"
      end

      FLOW.map do |lib|
        mapping[lib] = "Flow (FLOW)"
      end

      STELLAR.map do |lib|
        mapping[lib] = "Stellar (XLM)"
      end

      ['@solana/web3.js'].map do |lib|
        mapping[lib] = "Solana (SOL)"
      end

      return mapping
    end
end
